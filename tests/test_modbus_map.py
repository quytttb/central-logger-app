"""Unit tests cho parser Modbus Map v1."""

from __future__ import annotations

import struct

import pytest

from central_logger.services import modbus_map as mmap


def encode_float_abcd(value: float) -> tuple[int, int]:
    packed = struct.pack(">f", value)
    high, low = struct.unpack(">HH", packed)
    return high, low


class TestPrimitives:
    def test_decode_uint32_be(self):
        assert mmap.decode_uint32_be(0x0001, 0x0000) == 0x00010000
        assert mmap.decode_uint32_be(0xFFFF, 0xFFFF) == 0xFFFFFFFF
        assert mmap.decode_uint32_be(0, 0) == 0

    def test_decode_float_abcd_round_trip(self):
        for v in [0.0, 1.0, -1.0, 3.14159, 1234.5, -987.65]:
            hi, lo = encode_float_abcd(v)
            assert mmap.decode_float_abcd(hi, lo) == pytest.approx(v, rel=1e-6)

    def test_decode_float_abcd_out_of_range(self):
        with pytest.raises(ValueError):
            mmap.decode_float_abcd(-1, 0)


class TestHeader:
    def _build_header(self, *, version=1, flags=0, ts=0, count=0) -> list[int]:
        regs = [0] * mmap.HEADER_REGISTERS
        regs[mmap.HR_VERSION] = version
        regs[mmap.HR_FLAGS] = flags
        regs[mmap.HR_TS_HIGH] = (ts >> 16) & 0xFFFF
        regs[mmap.HR_TS_LOW] = ts & 0xFFFF
        regs[mmap.HR_SENSOR_COUNT] = count
        return regs

    def test_parse_header_basic(self):
        regs = self._build_header(version=1, flags=0b111, ts=0x12345678, count=3)
        hdr = mmap.parse_header(regs)
        assert hdr.version == 1
        assert hdr.is_supported
        assert hdr.polling is True
        assert hdr.rtu_connected is True
        assert hdr.any_alarm is True
        assert hdr.timestamp == 0x12345678
        assert hdr.sensor_count == 3

    def test_parse_header_unsupported_version(self):
        hdr = mmap.parse_header(self._build_header(version=99))
        assert not hdr.is_supported

    def test_parse_header_individual_flags(self):
        only_poll = mmap.parse_header(self._build_header(flags=mmap.FLAG_POLLING))
        assert only_poll.polling and not only_poll.rtu_connected and not only_poll.any_alarm

        only_rtu = mmap.parse_header(self._build_header(flags=mmap.FLAG_RTU_CONNECTED))
        assert only_rtu.rtu_connected and not only_rtu.polling

        only_alarm = mmap.parse_header(self._build_header(flags=mmap.FLAG_ANY_ALARM))
        assert only_alarm.any_alarm

    def test_parse_header_too_short(self):
        with pytest.raises(ValueError):
            mmap.parse_header([1, 2])


class TestSensorBlock:
    def _make_block(self, sid=1, flags=0b001, value=42.0) -> list[int]:
        hi, lo = encode_float_abcd(value)
        return [sid, flags, hi, lo, 0, 0, 0, 0]

    def test_parse_single_block(self):
        snap = mmap.parse_sensor_block(self._make_block(sid=7, flags=0b011, value=-12.34))
        assert snap.sensor_id == 7
        assert snap.valid is True
        assert snap.alarm is True
        assert snap.stale is False
        assert snap.value == pytest.approx(-12.34, rel=1e-5)

    def test_parse_sensor_array(self):
        blocks = []
        expected = [(10, 0b001, 1.5), (20, 0b101, 0.0), (30, 0b111, 9.99)]
        for sid, flags, val in expected:
            blocks.extend(self._make_block(sid, flags, val))
        result = mmap.parse_sensor_array(blocks, 3)
        assert len(result) == 3
        for i, (sid, _, val) in enumerate(expected):
            assert result[i].sensor_id == sid
            assert result[i].value == pytest.approx(val, rel=1e-5)

    def test_parse_sensor_array_insufficient(self):
        with pytest.raises(ValueError):
            mmap.parse_sensor_array([1, 2, 3], 2)


class TestAddressing:
    def test_sensor_block_address(self):
        assert mmap.sensor_block_address(0) == 10
        assert mmap.sensor_block_address(1) == 18
        assert mmap.sensor_block_address(5) == 50

    def test_sensor_array_register_count(self):
        assert mmap.sensor_array_register_count(0) == 0
        assert mmap.sensor_array_register_count(1) == 8
        assert mmap.sensor_array_register_count(4) == 32
