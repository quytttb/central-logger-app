"""Tests cho LoggerListModel (QAbstractListModel)."""
from __future__ import annotations

import pytest

from central_logger.viewmodels.logger_list_model import LoggerItem, LoggerListModel, LoggerRoles


@pytest.fixture
def model(qtbot):
    m = LoggerListModel()
    return m


def test_initial_empty(model):
    assert model.rowCount() == 0
    assert model.count() == 0


def test_add_and_remove(model, qtbot):
    with qtbot.waitSignal(model.countChanged, timeout=1000):
        model.add_logger(LoggerItem(id=1, name="A", host="10.0.0.1"))
    assert model.count() == 1

    with qtbot.waitSignal(model.countChanged, timeout=1000):
        assert model.remove_logger(1) is True
    assert model.count() == 0
    assert model.remove_logger(999) is False


def test_role_names_have_required_keys(model):
    roles = {bytes(v).decode(): k for k, v in model.roleNames().items()}
    expected = {"loggerId", "name", "host", "port", "online", "polling", "anyAlarm"}
    assert expected.issubset(roles.keys())


def test_data_lookup(model):
    model.add_logger(LoggerItem(id=42, name="X", host="192.168.1.5", port=5020))
    idx = model.index(0, 0)
    assert model.data(idx, int(LoggerRoles.IdRole)) == 42
    assert model.data(idx, int(LoggerRoles.NameRole)) == "X"
    assert model.data(idx, int(LoggerRoles.HostRole)) == "192.168.1.5"
    assert model.data(idx, int(LoggerRoles.PortRole)) == 5020
    assert model.data(idx, int(LoggerRoles.OnlineRole)) is False


def test_update_status_emits_data_changed(model, qtbot):
    model.add_logger(LoggerItem(id=1, name="A", host="h"))
    with qtbot.waitSignal(model.dataChanged, timeout=1000):
        model.update_status(1, online=True, polling=True, sensor_count=4)
        model.update_connection(1, poll_interval_s=5)

    idx = model.index(0, 0)
    assert model.data(idx, int(LoggerRoles.OnlineRole)) is True
    assert model.data(idx, int(LoggerRoles.PollingRole)) is True
    assert model.data(idx, int(LoggerRoles.SensorCountRole)) == 4


def test_clear(model):
    for i in range(3):
        model.add_logger(LoggerItem(id=i, name=f"L{i}", host="h"))
    assert model.count() == 3
    model.clear()
    assert model.count() == 0
