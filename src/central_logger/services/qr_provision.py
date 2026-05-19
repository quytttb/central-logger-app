"""Decode provisioning QR images for pairing Central with a data-logger (LAN)."""
from __future__ import annotations

import json
import logging
from dataclasses import dataclass
from typing import Any

from central_logger.utils.native_libs import (
    ensure_zbar_loaded,
    is_qr_scan_available,
    qr_scan_unavailable_reason,
)

log = logging.getLogger(__name__)

PROVISION_SCHEMA = "central-logger-provision/v1"

_ERR_INVALID_QR = "Invalid provisioning QR"
_ERR_NO_QR_IN_IMAGE = "No QR code found in image"


@dataclass(slots=True)
class ProvisionData:
    api_token: str
    host: str = ""
    api_port: int = 8080
    modbus_port: int = 5020
    modbus_unit_id: int = 1
    station_code: str = ""
    station_name: str = ""

    def as_form_fields(self) -> dict[str, Any]:
        return {
            "api_token": self.api_token,
            "host": self.host,
            "api_port": self.api_port,
            "modbus_port": self.modbus_port,
            "modbus_unit_id": self.modbus_unit_id,
            "station_code": self.station_code,
            "station_name": self.station_name,
        }


def parse_provision_payload(raw: str) -> ProvisionData:
    """Parse JSON string from QR payload."""
    try:
        data = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise ValueError(_ERR_INVALID_QR) from exc
    if not isinstance(data, dict):
        raise ValueError(_ERR_INVALID_QR)
    schema = data.get("schema")
    if schema != PROVISION_SCHEMA:
        raise ValueError(_ERR_INVALID_QR)
    token = (data.get("api_token") or "").strip()
    if not token:
        raise ValueError(_ERR_INVALID_QR)
    return ProvisionData(
        api_token=token,
        host=(data.get("host") or "").strip(),
        api_port=int(data.get("api_port") or 8080),
        modbus_port=int(data.get("modbus_port") or 5020),
        modbus_unit_id=int(data.get("modbus_unit_id") or 1),
        station_code=(data.get("station_code") or "").strip(),
        station_name=(data.get("station_name") or "").strip(),
    )


def decode_provision_qr_image(image_path: str) -> ProvisionData:
    """Decode first QR code in image file; return validated provision data."""
    if not is_qr_scan_available():
        raise RuntimeError(qr_scan_unavailable_reason())
    ensure_zbar_loaded()
    try:
        from PIL import Image
        from pyzbar.pyzbar import decode as zbar_decode
    except ImportError as exc:
        raise RuntimeError(qr_scan_unavailable_reason()) from exc

    try:
        img = Image.open(image_path)
    except OSError as exc:
        raise ValueError("Cannot open image") from exc

    codes = zbar_decode(img)
    if not codes:
        raise ValueError(_ERR_NO_QR_IN_IMAGE)

    for code in codes:
        try:
            text = code.data.decode("utf-8")
        except UnicodeDecodeError:
            continue
        try:
            return parse_provision_payload(text)
        except ValueError:
            continue
    raise ValueError(_ERR_INVALID_QR)


def import_provision_from_qr_image(image_path: str) -> dict[str, Any]:
    """Return {ok, fields?, error?} for QML / controller."""
    path = (image_path or "").strip()
    if not path:
        return {"ok": False, "error": "Empty file path"}
    try:
        prov = decode_provision_qr_image(path)
        log.info("Provision QR decoded for host=%s", prov.host or "?")
        return {"ok": True, "fields": prov.as_form_fields()}
    except (ValueError, RuntimeError) as exc:
        log.warning("Provision QR failed: %s", exc)
        return {"ok": False, "error": str(exc)}
    except Exception as exc:  # noqa: BLE001
        log.exception("Provision QR unexpected error")
        return {"ok": False, "error": str(exc)}
