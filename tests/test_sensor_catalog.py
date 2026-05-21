"""Tests for REST catalog + Modbus sensor merge."""

from __future__ import annotations

from central_logger.services.sensor_catalog import (
    analog_sensor_ids,
    compute_display_status,
    display_name_for_sensor,
    extract_sensors_from_config_raw,
    extract_sensors_from_readings_raw,
    is_digital_sensor_type,
    is_top_level_sensor,
    merge_sensor_rows,
    normalize_catalog_entry,
    parse_catalog_from_rest,
)


def test_extract_sensors_top_level_and_nested():
    top = {"sensors": [{"id": 1, "name": "A", "sensor_type": "ANALOG"}]}
    assert len(parse_catalog_from_rest(extract_sensors_from_config_raw(top))) == 1
    nested_cfg = {
        "api_version": 1,
        "revision": 1,
        "config": {"sensors": [{"id": 2, "name": "B", "sensor_type": "DI"}]},
    }
    assert len(parse_catalog_from_rest(extract_sensors_from_config_raw(nested_cfg))) == 1


def test_analog_sensor_ids_excludes_di_do():
    catalog = [
        {"sensor_id": 1, "name": "T", "sensor_type": "AI", "unit": "", "active": True},
        {"sensor_id": 2, "name": "D", "sensor_type": "DI", "unit": "", "active": True},
        {"sensor_id": 3, "name": "O", "sensor_type": "DO", "unit": "", "active": True},
    ]
    assert is_digital_sensor_type("DI")
    assert not is_digital_sensor_type("AI")
    assert analog_sensor_ids(catalog) == {1}


def test_is_top_level_sensor():
    assert is_top_level_sensor({"id": 1, "name": "A"})
    assert is_top_level_sensor({"id": 1, "parent_id": None})
    assert not is_top_level_sensor({"id": 4, "parent_id": 1, "name": "DI attach"})


def test_parse_catalog_skips_attached_children():
    raw = [
        {"id": 1, "name": "Temp", "sensor_type": "ANALOG", "parent_id": None},
        {"id": 2, "name": "Humidity", "sensor_type": "ANALOG"},
        {"id": 4, "name": "dang do DI_1", "sensor_type": "DI", "parent_id": 1},
        {"id": 5, "name": "dang hieu chuan DI_2", "sensor_type": "DI", "parent_id": 2},
    ]
    cat = parse_catalog_from_rest(raw)
    assert len(cat) == 2
    assert {c["sensor_id"] for c in cat} == {1, 2}


def test_merge_excludes_attached_from_catalog():
    catalog = parse_catalog_from_rest(
        [
            {"id": 1, "name": "Temp", "sensor_type": "ANALOG"},
            {"id": 10, "name": "child DI", "sensor_type": "DI", "parent_id": 1},
        ]
    )
    assert len(catalog) == 1
    rows = merge_sensor_rows(catalog, [])
    assert len(rows) == 1
    assert rows[0]["name"] == "Temp"


def test_parse_catalog_from_rest():
    raw = [
        {"id": 2, "name": "pH", "unit": "pH", "sensor_type": "ANALOG", "active": True},
        {"id": 1, "name": "Flow", "unit": "m3/h", "sensor_type": "ANALOG", "active": False},
    ]
    cat = parse_catalog_from_rest(raw)
    assert len(cat) == 2
    assert cat[0]["sensor_id"] == 1
    assert cat[1]["name"] == "pH"


def test_merge_catalog_with_modbus_overlay():
    catalog = parse_catalog_from_rest(
        [
            {"id": 1, "name": "Temp", "unit": "C", "sensor_type": "ANALOG", "active": True},
            {"id": 2, "name": "Door", "unit": "", "sensor_type": "DI", "active": True},
        ]
    )
    modbus = [
        {"sensor_id": 1, "value": 25.5, "valid": True, "alarm": False, "stale": False},
    ]
    rows = merge_sensor_rows(catalog, modbus)
    assert len(rows) == 2
    assert rows[0]["name"] == "Temp"
    assert rows[0]["value"] == 25.5
    assert rows[1]["name"] == "Door"
    assert rows[1]["value"] is None


def test_merge_inactive_in_catalog():
    catalog = parse_catalog_from_rest(
        [
            {"id": 3, "name": "Old", "sensor_type": "ANALOG", "active": False},
        ]
    )
    rows = merge_sensor_rows(catalog, [])
    assert len(rows) == 1
    assert rows[0]["active"] is False
    assert rows[0]["value"] is None


def test_merge_modbus_only_fallback():
    modbus = [{"sensor_id": 5, "value": 1.0, "valid": True, "alarm": False, "stale": False}]
    rows = merge_sensor_rows(None, modbus)
    assert len(rows) == 1
    assert rows[0]["name"] == "Sensor 5"


def test_normalize_missing_name_uses_type():
    row = normalize_catalog_entry({"id": 9, "sensor_type": "DO"})
    assert row["name"] == "DO #9"


def test_merge_rest_di_do_values():
    catalog = parse_catalog_from_rest(
        [
            {"id": 1, "name": "Temp", "sensor_type": "ANALOG", "active": True},
            {"id": 3, "name": "Buzzer", "sensor_type": "DO", "active": True},
        ]
    )
    modbus = [
        {"sensor_id": 1, "value": 22.0, "valid": True, "alarm": False, "stale": False},
    ]
    rest = [
        {
            "sensor_id": 1,
            "sensor_type": "ANALOG",
            "value": 22.0,
            "status": "OK",
            "is_alarm": False,
            "alarm_type": "",
            "valid": True,
        },
        {
            "sensor_id": 3,
            "sensor_type": "DO",
            "value": 1.0,
            "status": "ON",
            "is_alarm": False,
            "alarm_type": "",
            "valid": True,
        },
    ]
    rows = merge_sensor_rows(catalog, modbus, rest, logger_online=True)
    do_row = next(r for r in rows if r["sensor_id"] == 3)
    assert do_row["value"] == 1.0
    assert do_row["display_status"] == "ON"
    assert rows[0]["display_status"] == "OK"


def test_compute_display_status_analog_alarm():
    row = {"sensor_type": "ANALOG", "active": True, "value": 1.0, "valid": True, "alarm": True}
    assert compute_display_status(row, logger_online=True) == "ALARM"


def test_extract_sensors_from_readings_raw():
    raw = {
        "sensors": [
            {"sensor_id": 3, "sensor_type": "DO", "value": 0, "valid": True, "status": "OFF"},
        ]
    }
    out = extract_sensors_from_readings_raw(raw)
    assert len(out) == 1
    assert out[0]["sensor_id"] == 3
    assert out[0]["value"] == 0


def test_di_do_wait_without_rest():
    catalog = parse_catalog_from_rest(
        [
            {"id": 2, "name": "DI1", "sensor_type": "DI", "active": True},
        ]
    )
    rows = merge_sensor_rows(catalog, [], None)
    assert rows[0]["value"] is None
    assert rows[0]["display_status"] == "WAIT"


def test_display_name_for_sensor():
    catalog = parse_catalog_from_rest([{"id": 1, "name": "EC", "sensor_type": "ANALOG"}])
    assert display_name_for_sensor(catalog, 1) == "EC"
    assert display_name_for_sensor(catalog, 99) == "Sensor 99"
