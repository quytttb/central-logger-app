"""Tests for provisioning QR decode (central-logger-provision/v1)."""
from __future__ import annotations

import json
from pathlib import Path

import pytest

from central_logger.services.qr_provision import (
    PROVISION_SCHEMA,
    decode_provision_qr_image,
    import_provision_from_qr_image,
    parse_provision_payload,
)
from central_logger.utils.native_libs import is_qr_scan_available, qr_scan_unavailable_reason

qrcode = pytest.importorskip("qrcode")


@pytest.fixture
def require_qr_scan():
    if not is_qr_scan_available():
        pytest.skip(qr_scan_unavailable_reason())


def _sample_payload() -> dict:
    return {
        "schema": PROVISION_SCHEMA,
        "api_token": "test-bearer-token-abc",
        "host": "192.168.1.99",
        "api_port": 8080,
        "modbus_port": 5020,
        "modbus_unit_id": 2,
        "station_code": "TRAM-TST",
        "station_name": "Test Station",
    }


def test_parse_provision_payload_ok():
    prov = parse_provision_payload(json.dumps(_sample_payload()))
    assert prov.api_token == "test-bearer-token-abc"
    assert prov.host == "192.168.1.99"
    assert prov.station_code == "TRAM-TST"


def test_parse_rejects_wrong_schema():
    bad = _sample_payload()
    bad["schema"] = "other/v0"
    with pytest.raises(ValueError, match="Invalid provisioning QR"):
        parse_provision_payload(json.dumps(bad))


def test_parse_requires_token():
    bad = _sample_payload()
    del bad["api_token"]
    with pytest.raises(ValueError, match="Invalid provisioning QR"):
        parse_provision_payload(json.dumps(bad))


def test_decode_qr_roundtrip(require_qr_scan, tmp_path: Path):
    payload = json.dumps(_sample_payload(), separators=(",", ":"))
    img_path = tmp_path / "provision.png"
    qrcode.make(payload).save(str(img_path))
    prov = decode_provision_qr_image(str(img_path))
    assert prov.api_token == "test-bearer-token-abc"
    assert prov.modbus_unit_id == 2


def test_import_from_image_wrapper(require_qr_scan, tmp_path: Path):
    payload = json.dumps(_sample_payload(), separators=(",", ":"))
    img_path = tmp_path / "provision.png"
    qrcode.make(payload).save(str(img_path))
    result = import_provision_from_qr_image(str(img_path))
    assert result["ok"] is True
    assert result["fields"]["host"] == "192.168.1.99"


def test_import_missing_file():
    result = import_provision_from_qr_image("/nonexistent/qr.png")
    assert result["ok"] is False
    assert result["error"]
