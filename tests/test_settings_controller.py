"""Tests cho SettingsController — load defaults, save, reload."""
from __future__ import annotations

import pytest
from sqlmodel import SQLModel

from central_logger.controllers.settings_controller import SettingsController
from central_logger.db import session as db_session


@pytest.fixture
def fresh_db(tmp_path, monkeypatch):
    url = f"sqlite:///{tmp_path}/settings.db"
    monkeypatch.setenv("CENTRAL_LOGGER_DB_URL", url)
    db_session._engine = None  # noqa: SLF001
    yield
    db_session._engine = None  # noqa: SLF001


def test_load_seeds_defaults(qtbot, fresh_db):
    ctrl = SettingsController()
    ctrl.load()
    assert ctrl.theme == "dark"
    assert ctrl.systemTimezone == "Asia/Ho_Chi_Minh"
    assert ctrl.dataRetentionDays == 30
    assert ctrl.maintenanceMode is False


def test_save_persists(qtbot, fresh_db):
    ctrl = SettingsController()
    ctrl.load()
    ctrl.save("light", "Asia/Ho_Chi_Minh", 60, 15, True, "ops@example.com\nadmin@example.com")
    assert ctrl.theme == "light"
    assert ctrl.dataRetentionDays == 60
    assert ctrl.maintenanceMode is True

    other = SettingsController()
    other.load()
    assert other.theme == "light"
    assert other.systemTimezone == "Asia/Ho_Chi_Minh"
    assert other.alertEmailContacts.startswith("ops@example.com")
