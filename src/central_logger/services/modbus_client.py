"""Async Modbus TCP client wrapper - 1 client / device.

Sử dụng `pymodbus.client.AsyncModbusTcpClient` (pymodbus >= 3.13).
Tách rõ:
    - TCP connected: client.connected
    - Modbus PDU OK: response.isError() False
"""
from __future__ import annotations

import asyncio
import logging
from dataclasses import dataclass, field

from pymodbus.client import AsyncModbusTcpClient
from pymodbus.exceptions import ConnectionException, ModbusException

from central_logger.services import modbus_map as mmap
from central_logger.services.modbus_map import LoggerSnapshot

log = logging.getLogger(__name__)


@dataclass(slots=True)
class LoggerConfig:
    """Cấu hình kết nối tới 1 Data Logger."""

    id: int
    name: str
    host: str
    port: int = 5020
    unit_id: int = 1
    poll_interval_s: int = 2
    timeout_s: float = 2.0
    max_retries: int = 3
    backoff_start_s: float = 1.0
    backoff_max_s: float = 5.0


@dataclass
class ReadOutcome:
    ok: bool
    snapshot: LoggerSnapshot | None = None
    error: str = ""
    tcp_connected: bool = False


class LoggerModbusClient:
    """Wrapper cho 1 logger: handle connect/reconnect, đọc map v1."""

    def __init__(self, config: LoggerConfig) -> None:
        self.config = config
        self._client: AsyncModbusTcpClient | None = None
        self._lock = asyncio.Lock()
        # Dedupe log: chỉ in 1 dòng "connect failed" cho tới khi reconnect OK.
        self._connect_failure_logged = False

    @property
    def connected(self) -> bool:
        return bool(self._client and self._client.connected)

    async def connect(self) -> bool:
        if self._client is None:
            self._client = AsyncModbusTcpClient(
                host=self.config.host,
                port=self.config.port,
                timeout=self.config.timeout_s,
            )
        if self._client.connected:
            if self._connect_failure_logged:
                log.info(
                    "connect recovered for %s:%s",
                    self.config.host,
                    self.config.port,
                )
                self._connect_failure_logged = False
            return True
        try:
            await self._client.connect()
        except Exception as exc:  # pragma: no cover - network error
            if not self._connect_failure_logged:
                log.warning(
                    "connect failed for %s:%s: %s",
                    self.config.host,
                    self.config.port,
                    exc,
                )
                self._connect_failure_logged = True
            return False
        connected = bool(self._client.connected)
        if connected and self._connect_failure_logged:
            log.info(
                "connect recovered for %s:%s",
                self.config.host,
                self.config.port,
            )
            self._connect_failure_logged = False
        elif not connected and not self._connect_failure_logged:
            log.warning(
                "connect failed for %s:%s",
                self.config.host,
                self.config.port,
            )
            self._connect_failure_logged = True
        return connected

    async def close(self) -> None:
        if self._client is not None:
            try:
                self._client.close()
            except Exception:  # pragma: no cover
                log.exception("close error")
            self._client = None

    async def _read_holding(self, address: int, count: int) -> list[int]:
        assert self._client is not None
        try:
            rr = await self._client.read_holding_registers(
                address=address, count=count, device_id=self.config.unit_id
            )
        except TypeError:
            # Fallback cho pymodbus phiên bản dùng `slave=` thay vì `device_id=`
            rr = await self._client.read_holding_registers(
                address=address, count=count, slave=self.config.unit_id
            )
        if rr.isError():
            raise ModbusException(f"PDU error: {rr}")
        return list(rr.registers)

    async def read_snapshot(self) -> ReadOutcome:
        """Đọc HR0..HR9 (header) rồi đọc tiếp khối sensors theo HR4."""
        if not await self.connect():
            return ReadOutcome(ok=False, error="TCP connect failed", tcp_connected=False)
        try:
            header_regs = await self._read_holding(
                mmap.HR_VERSION, mmap.HEADER_REGISTERS
            )
            header = mmap.parse_header(header_regs)

            if not header.is_supported:
                return ReadOutcome(
                    ok=False,
                    error=f"Unsupported map version {header.version}",
                    tcp_connected=True,
                )

            sensors: list = []
            if header.sensor_count > 0:
                count_regs = mmap.sensor_array_register_count(header.sensor_count)
                sensor_regs = await self._read_holding(
                    mmap.HR_SENSOR_BLOCK_START, count_regs
                )
                sensors = mmap.parse_sensor_array(sensor_regs, header.sensor_count)

            return ReadOutcome(
                ok=True,
                snapshot=LoggerSnapshot(header=header, sensors=sensors),
                tcp_connected=True,
            )
        except ConnectionException as exc:
            await self.close()
            return ReadOutcome(ok=False, error=f"Connection: {exc}", tcp_connected=False)
        except ModbusException as exc:
            return ReadOutcome(ok=False, error=f"Modbus: {exc}", tcp_connected=True)
        except asyncio.TimeoutError:
            return ReadOutcome(ok=False, error="Timeout", tcp_connected=self.connected)
        except Exception as exc:  # noqa: BLE001
            log.exception("unexpected error reading %s", self.config.host)
            return ReadOutcome(ok=False, error=f"Unexpected: {exc}", tcp_connected=self.connected)
