"""Tests for SensorMonitoringTableModel (QAbstractTableModel)."""

from __future__ import annotations

import pytest

from central_logger.viewmodels.sensor_monitoring_table_model import (
    COLUMN_COUNT,
    SensorMonitoringTableModel,
    SensorRoles,
    _parse_sensor,
    _unit_text,
    _value_text,
)


@pytest.fixture
def model():
    return SensorMonitoringTableModel()


def test_initial_empty(model):
    assert model.rowCount() == 0
    assert model.columnCount() == COLUMN_COUNT


def test_set_sensors_empty(model):
    model.setSensors([])
    assert model.rowCount() == 0


def test_set_sensors_analog(model):
    model.setSensors([
        {
            "sensor_id": 1,
            "name": "Temperature",
            "sensor_type": "AI",
            "value": 22.5,
            "unit": "°C",
            "display_status": "OK",
        }
    ])
    assert model.rowCount() == 1
    idx = model.index(0, 0)
    assert model.data(idx, int(SensorRoles.SensorIdRole)) == "1"
    assert model.data(idx, int(SensorRoles.NameRole)) == "Temperature"
    idx_val = model.index(0, 2)
    assert model.data(idx_val, int(SensorRoles.ValueTextRole)) == "22.5"
    idx_unit = model.index(0, 3)
    assert model.data(idx_unit, int(SensorRoles.UnitTextRole)) == "°C"
    idx_status = model.index(0, 4)
    assert model.data(idx_status, int(SensorRoles.DisplayStatusRole)) == "OK"


def test_set_sensors_digital_on(model):
    model.setSensors([
        {
            "sensor_id": 2,
            "sensor_type": "DI",
            "value": 1.0,
            "display_status": "NORMAL",
        }
    ])
    idx = model.index(0, 2)
    assert model.data(idx, int(SensorRoles.ValueTextRole)) == "ON"
    idx_unit = model.index(0, 3)
    assert model.data(idx_unit, int(SensorRoles.UnitTextRole)) == "—"


def test_role_names(model):
    roles = {bytes(v).decode() for v in model.roleNames().values()}
    assert {"sensorId", "name", "valueText", "unitText", "displayStatus"}.issubset(roles)


def test_value_text_helpers():
    assert _value_text("DI", 1) == "ON"
    assert _value_text("DI", 0) == "OFF"
    assert _value_text("AI", None) == "—"
    assert _unit_text("DI", 1, "x") == "—"
    assert _unit_text("AI", 10, "bar") == "bar"


def test_parse_sensor_fallback_name():
    row = _parse_sensor({"sensor_id": 5, "type": "Flow", "value": 1.0})
    assert row is not None
    assert row.name == "Flow"
    assert row.sensor_id == 5
