"""Integration test cho ModbusManager + LoggerModbusClient với fake pymodbus client."""
from __future__ import annotations

import asyncio
import struct
from dataclasses import dataclass
from typing import Any

import pytest

from central_logger.services import modbus_map as mmap
from central_logger.services.modbus_client import LoggerConfig, LoggerModbusClient


def _pack_float_abcd(value: float) -> tuple[int, int]:
    packed = struct.pack(">f", value)
    return struct.unpack(">HH", packed)


@dataclass
class FakeResponse:
    registers: list[int]
    error: bool = False

    def isError(self) -> bool:
        return self.error


class FakePymodbusClient:
    """Giả lập AsyncModbusTcpClient để test parser end-to-end."""

    def __init__(self, *args: Any, **kwargs: Any) -> None:
        self.connected = False
        self.calls: list[tuple[int, int]] = []
        self._regs = self._build_dataset()

    def _build_dataset(self) -> dict[int, int]:
        regs: dict[int, int] = {i: 0 for i in range(64)}
        regs[mmap.HR_VERSION] = 1
        regs[mmap.HR_FLAGS] = mmap.FLAG_POLLING | mmap.FLAG_RTU_CONNECTED
        regs[mmap.HR_TS_HIGH] = 0x1234
        regs[mmap.HR_TS_LOW] = 0x5678
        regs[mmap.HR_SENSOR_COUNT] = 2

        for i, (sid, flags, val) in enumerate([(101, 0b001, 25.5), (202, 0b011, -7.25)]):
            base = mmap.sensor_block_address(i)
            hi, lo = _pack_float_abcd(val)
            regs[base + 0] = sid
            regs[base + 1] = flags
            regs[base + 2] = hi
            regs[base + 3] = lo
        return regs

    async def connect(self) -> bool:
        self.connected = True
        return True

    def close(self) -> None:
        self.connected = False

    async def read_holding_registers(self, address=0, count=1, **kwargs):
        self.calls.append((address, count))
        regs = [self._regs.get(address + i, 0) for i in range(count)]
        return FakeResponse(registers=regs)


@pytest.mark.asyncio
async def test_logger_client_reads_full_snapshot(monkeypatch):
    monkeypatch.setattr(
        "central_logger.services.modbus_client.AsyncModbusTcpClient",
        FakePymodbusClient,
    )
    cfg = LoggerConfig(id=1, name="t", host="1.2.3.4", port=5020, unit_id=1, timeout_s=0.5)
    client = LoggerModbusClient(cfg)
    outcome = await client.read_snapshot()
    assert outcome.ok
    assert outcome.snapshot is not None
    hdr = outcome.snapshot.header
    assert hdr.version == 1
    assert hdr.polling and hdr.rtu_connected
    assert hdr.timestamp == 0x12345678
    assert hdr.sensor_count == 2

    sensors = outcome.snapshot.sensors
    assert len(sensors) == 2
    assert sensors[0].sensor_id == 101
    assert sensors[0].value == pytest.approx(25.5, rel=1e-5)
    assert sensors[1].sensor_id == 202
    assert sensors[1].alarm is True


@pytest.mark.asyncio
async def test_manager_invokes_callback(monkeypatch):
    from central_logger.services.modbus_manager import ModbusManager

    monkeypatch.setattr(
        "central_logger.services.modbus_client.AsyncModbusTcpClient",
        FakePymodbusClient,
    )

    received: list[tuple[int, bool]] = []

    def on_snap(cfg, outcome):
        received.append((cfg.id, outcome.ok))

    manager = ModbusManager(on_snapshot=on_snap)
    manager.add_logger(
        LoggerConfig(id=7, name="x", host="h", poll_interval_s=1, timeout_s=0.5)
    )
    manager.start()
    # đợi vài chu kỳ
    await asyncio.sleep(0.2)
    await manager.stop()
    assert any(r == (7, True) for r in received)
