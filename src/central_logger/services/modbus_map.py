"""Parser cho Modbus TCP Map v1 của Data Logger.

Layout (holding registers, PDU 0-based):
    HR0           : Map version (= 1)
    HR1           : Status flags (bit0=polling, bit1=rtu_connected, bit2=any_alarm)
    HR2..HR3      : Unix timestamp (uint32, big-endian; HR2=high, HR3=low)
    HR4           : N - số sensor trong map
    HR10 + i*8    : Khối sensor i (i = 0..N-1)
        +0  : sensor_id   (uint16)
        +1  : flags       (bit0=valid, bit1=alarm, bit2=stale)
        +2..+3 : float32 ABCD (big-endian)
        +4..+7 : reserved

Float endian cố định **ABCD** trên TCP (không theo data_format của RTU).
"""

from __future__ import annotations

import struct
from dataclasses import dataclass

# Hằng số map v1
MAP_VERSION = 1
HR_VERSION = 0
HR_FLAGS = 1
HR_TS_HIGH = 2
HR_TS_LOW = 3
HR_SENSOR_COUNT = 4
HR_SENSOR_BLOCK_START = 10
SENSOR_BLOCK_SIZE = 8

# Header gồm HR0..HR4 + reserved HR5..HR9 => đọc 10 registers từ HR0 là đủ.
HEADER_REGISTERS = 10

# Status flags ở HR1
FLAG_POLLING = 1 << 0
FLAG_RTU_CONNECTED = 1 << 1
FLAG_ANY_ALARM = 1 << 2

# Sensor flags ở khối +1
SENSOR_FLAG_VALID = 1 << 0
SENSOR_FLAG_ALARM = 1 << 1
SENSOR_FLAG_STALE = 1 << 2


@dataclass
class LoggerHeader:
    version: int
    polling: bool
    rtu_connected: bool
    any_alarm: bool
    timestamp: int
    sensor_count: int

    @property
    def is_supported(self) -> bool:
        return self.version == MAP_VERSION


@dataclass
class SensorSnapshot:
    sensor_id: int
    valid: bool
    alarm: bool
    stale: bool
    value: float


@dataclass
class LoggerSnapshot:
    header: LoggerHeader
    sensors: list[SensorSnapshot]


def decode_float_abcd(reg_high: int, reg_low: int) -> float:
    """Giải mã float32 từ 2 registers theo thứ tự big-endian ABCD.

    reg_high = AB (high word), reg_low = CD (low word).
    """
    if not (0 <= reg_high <= 0xFFFF and 0 <= reg_low <= 0xFFFF):
        raise ValueError(f"register ngoài 16-bit: high={reg_high}, low={reg_low}")
    packed = struct.pack(">HH", reg_high & 0xFFFF, reg_low & 0xFFFF)
    return struct.unpack(">f", packed)[0]


def decode_uint32_be(reg_high: int, reg_low: int) -> int:
    """Giải mã uint32 big-endian từ 2 registers (HR2=high, HR3=low)."""
    return ((reg_high & 0xFFFF) << 16) | (reg_low & 0xFFFF)


def parse_header(regs: list[int]) -> LoggerHeader:
    """Phân tích 10 register đầu (HR0..HR9) thành LoggerHeader."""
    if len(regs) < 5:
        raise ValueError(f"Header cần >= 5 registers, nhận {len(regs)}")
    flags = regs[HR_FLAGS]
    ts = decode_uint32_be(regs[HR_TS_HIGH], regs[HR_TS_LOW])
    return LoggerHeader(
        version=regs[HR_VERSION],
        polling=bool(flags & FLAG_POLLING),
        rtu_connected=bool(flags & FLAG_RTU_CONNECTED),
        any_alarm=bool(flags & FLAG_ANY_ALARM),
        timestamp=ts,
        sensor_count=regs[HR_SENSOR_COUNT],
    )


def parse_sensor_block(block: list[int]) -> SensorSnapshot:
    """Phân tích 1 khối sensor (8 registers)."""
    if len(block) < 4:
        raise ValueError(f"Sensor block cần >= 4 registers, nhận {len(block)}")
    sid = block[0]
    flags = block[1]
    value = decode_float_abcd(block[2], block[3])
    return SensorSnapshot(
        sensor_id=sid,
        valid=bool(flags & SENSOR_FLAG_VALID),
        alarm=bool(flags & SENSOR_FLAG_ALARM),
        stale=bool(flags & SENSOR_FLAG_STALE),
        value=value,
    )


def parse_sensor_array(regs: list[int], count: int) -> list[SensorSnapshot]:
    """Phân tích `count` khối sensor liên tiếp từ registers (HR10 trở đi)."""
    sensors: list[SensorSnapshot] = []
    needed = count * SENSOR_BLOCK_SIZE
    if len(regs) < needed:
        raise ValueError(f"Cần {needed} registers cho {count} sensor, nhận {len(regs)}")
    for i in range(count):
        start = i * SENSOR_BLOCK_SIZE
        sensors.append(parse_sensor_block(regs[start : start + SENSOR_BLOCK_SIZE]))
    return sensors


def sensor_block_address(index: int) -> int:
    """Trả về địa chỉ thanh ghi đầu của khối sensor thứ `index`."""
    return HR_SENSOR_BLOCK_START + index * SENSOR_BLOCK_SIZE


def sensor_array_register_count(count: int) -> int:
    return count * SENSOR_BLOCK_SIZE
