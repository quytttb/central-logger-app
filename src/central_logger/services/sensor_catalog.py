"""Merge REST sensor catalog with Modbus live readings for UI."""
from __future__ import annotations

from typing import Any


def is_top_level_sensor(raw: dict[str, Any]) -> bool:
    """True for standalone sensors (parent_id unset); False for DI/DO attached to analog."""
    if "parent_id" not in raw:
        return True
    parent_id = raw.get("parent_id")
    return parent_id is None


def normalize_catalog_entry(raw: dict[str, Any]) -> dict[str, Any]:
    """Map REST sensor object to UI row metadata."""
    sid = raw.get("id", raw.get("sensor_id"))
    if sid is None:
        raise ValueError("sensor entry missing id")
    sensor_type = (raw.get("sensor_type") or "").strip()
    name = (raw.get("name") or "").strip()
    if not name:
        name = f"{sensor_type} #{sid}" if sensor_type else f"Sensor {sid}"
    return {
        "sensor_id": int(sid),
        "name": name,
        "unit": (raw.get("unit") or "").strip(),
        "sensor_type": sensor_type,
        "active": bool(raw.get("active", True)),
    }


def extract_sensors_from_readings_raw(raw: dict[str, Any] | None) -> list[dict[str, Any]]:
    """Parse sensors[] từ body GET /readings."""
    if not raw or not isinstance(raw, dict):
        return []
    sensors_raw = raw.get("sensors")
    if not isinstance(sensors_raw, list):
        return []
    out: list[dict[str, Any]] = []
    for item in sensors_raw:
        if not isinstance(item, dict):
            continue
        sid = item.get("sensor_id", item.get("id"))
        if sid is None:
            continue
        out.append({
            "sensor_id": int(sid),
            "sensor_type": str(item.get("sensor_type", "")),
            "value": item.get("value"),
            "valid": bool(item.get("valid", False)),
            "status": str(item.get("status", "")),
            "is_alarm": bool(item.get("is_alarm", False)),
            "alarm_type": str(item.get("alarm_type", "")),
        })
    return out


def extract_sensors_from_config_raw(raw: dict[str, Any] | None) -> list[Any] | None:
    """Lấy sensors[] từ body GET /config (top-level hoặc lồng trong config)."""
    if not raw or not isinstance(raw, dict):
        return None
    top = raw.get("sensors")
    if isinstance(top, list):
        return top
    cfg = raw.get("config")
    if isinstance(cfg, dict):
        nested = cfg.get("sensors")
        if isinstance(nested, list):
            return nested
    return None


def parse_catalog_from_rest(sensors_raw: Any) -> list[dict[str, Any]]:
    """Parse top-level sensors[] from GET /config; excludes child DI/DO (parent_id set)."""
    if not isinstance(sensors_raw, list):
        return []
    out: list[dict[str, Any]] = []
    for item in sensors_raw:
        if not isinstance(item, dict):
            continue
        if not is_top_level_sensor(item):
            continue
        try:
            out.append(normalize_catalog_entry(item))
        except (TypeError, ValueError):
            continue
    out.sort(key=lambda r: r["sensor_id"])
    return out


def _modbus_index(modbus_sensors: list[dict[str, Any]]) -> dict[int, dict[str, Any]]:
    idx: dict[int, dict[str, Any]] = {}
    for m in modbus_sensors:
        sid = m.get("sensor_id")
        if sid is None:
            continue
        idx[int(sid)] = m
    return idx


def _rest_index(rest_readings: list[dict[str, Any]] | None) -> dict[int, dict[str, Any]]:
    idx: dict[int, dict[str, Any]] = {}
    if not rest_readings:
        return idx
    for r in rest_readings:
        if not isinstance(r, dict):
            continue
        sid = r.get("sensor_id")
        if sid is None:
            continue
        idx[int(sid)] = r
    return idx


def compute_display_status(
    row: dict[str, Any],
    *,
    logger_online: bool = True,
    logger_polling: bool = True,
) -> str:
    """Map row to UI badge — aligned with data-logger MonitorView."""
    if not row.get("active", True):
        return "Inactive"
    if not logger_online:
        return "ERR"
    if row.get("stale"):
        return "Stale"
    st = (row.get("sensor_type") or "").upper()
    if st in ("DI", "DO"):
        if row.get("value") is None:
            return "WAIT"
        rest_st = (row.get("rest_status") or "").upper()
        if rest_st in ("ON", "OFF"):
            return rest_st
        try:
            return "ON" if float(row["value"]) >= 0.5 else "OFF"
        except (TypeError, ValueError):
            return "WAIT"
    if row.get("value") is None:
        return "WAIT"
    if row.get("alarm"):
        return "ALARM"
    if not row.get("valid"):
        return "Invalid"
    return "OK"


def _row_from_catalog(cat: dict[str, Any], modbus: dict[str, Any] | None) -> dict[str, Any]:
    row: dict[str, Any] = {
        "sensor_id": cat["sensor_id"],
        "name": cat["name"],
        "type": cat["name"],
        "unit": cat["unit"],
        "sensor_type": cat["sensor_type"],
        "active": cat["active"],
        "alarm_type": "",
        "rest_status": "",
    }
    if modbus is not None:
        row["value"] = modbus.get("value")
        row["valid"] = bool(modbus.get("valid", False))
        row["alarm"] = bool(modbus.get("alarm", False))
        row["stale"] = bool(modbus.get("stale", False))
    else:
        row["value"] = None
        row["valid"] = False
        row["alarm"] = False
        row["stale"] = cat["active"] is False
    return row


def _apply_rest_to_row(row: dict[str, Any], rest: dict[str, Any] | None) -> dict[str, Any]:
    if rest is None:
        return row
    st = (row.get("sensor_type") or "").upper()
    row["rest_status"] = str(rest.get("status", ""))
    if st in ("DI", "DO"):
        if rest.get("value") is not None:
            row["value"] = rest.get("value")
        row["valid"] = bool(rest.get("valid", False))
        row["alarm"] = bool(rest.get("is_alarm", False))
        row["stale"] = False
    else:
        if row.get("value") is None and rest.get("valid"):
            row["value"] = rest.get("value")
            row["valid"] = True
        if rest.get("is_alarm"):
            row["alarm"] = True
        if rest.get("alarm_type"):
            row["alarm_type"] = str(rest.get("alarm_type"))
    return row


def _finalize_row(
    row: dict[str, Any],
    *,
    logger_online: bool,
    logger_polling: bool,
) -> dict[str, Any]:
    row["display_status"] = compute_display_status(
        row, logger_online=logger_online, logger_polling=logger_polling
    )
    return row


def _row_from_modbus_only(m: dict[str, Any]) -> dict[str, Any]:
    sid = int(m["sensor_id"])
    return {
        "sensor_id": sid,
        "name": f"Sensor {sid}",
        "type": f"Sensor {sid}",
        "unit": "",
        "sensor_type": "",
        "active": True,
        "value": m.get("value"),
        "valid": bool(m.get("valid", False)),
        "alarm": bool(m.get("alarm", False)),
        "stale": bool(m.get("stale", False)),
        "alarm_type": "",
        "rest_status": "",
    }


def merge_sensor_rows(
    catalog: list[dict[str, Any]] | None,
    modbus_sensors: list[dict[str, Any]],
    rest_readings: list[dict[str, Any]] | None = None,
    *,
    logger_online: bool = True,
    logger_polling: bool = True,
) -> list[dict[str, Any]]:
    """Full catalog rows with Modbus + REST overlay; fallback modbus-only if no catalog."""
    modbus_idx = _modbus_index(modbus_sensors)
    rest_idx = _rest_index(rest_readings)
    rows: list[dict[str, Any]] = []
    if catalog:
        for c in catalog:
            row = _row_from_catalog(c, modbus_idx.get(c["sensor_id"]))
            row = _apply_rest_to_row(row, rest_idx.get(c["sensor_id"]))
            rows.append(
                _finalize_row(
                    row, logger_online=logger_online, logger_polling=logger_polling
                )
            )
        seen = {c["sensor_id"] for c in catalog}
        for sid, m in sorted(modbus_idx.items()):
            if sid not in seen:
                row = _apply_rest_to_row(_row_from_modbus_only(m), rest_idx.get(sid))
                rows.append(
                    _finalize_row(
                        row, logger_online=logger_online, logger_polling=logger_polling
                    )
                )
        rows.sort(key=lambda r: r["sensor_id"])
        return rows

    for m in modbus_sensors:
        row = _apply_rest_to_row(_row_from_modbus_only(m), rest_idx.get(int(m["sensor_id"])))
        rows.append(
            _finalize_row(row, logger_online=logger_online, logger_polling=logger_polling)
        )
    rows.sort(key=lambda r: r["sensor_id"])
    return rows


def display_name_for_sensor(
    catalog: list[dict[str, Any]] | None, sensor_id: int
) -> str:
    """Label for charts — prefer catalog name."""
    if catalog:
        for c in catalog:
            if c["sensor_id"] == sensor_id:
                return c["name"]
    return f"Sensor {sensor_id}"
