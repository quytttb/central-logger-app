"""Tests cho các slot CRUD logger mở rộng: addLogger, updateLoggerConnection, updateLoggerApi, getLoggerFormData."""
from __future__ import annotations

import json

import pytest

from central_logger.controllers.dashboard_controller import DashboardController
from central_logger.db import LoggerInfo, get_session, init_db
from central_logger.db import session as db_session


@pytest.fixture
def fresh_db(tmp_path, monkeypatch):
    url = f"sqlite:///{tmp_path}/crud.db"
    monkeypatch.setenv("CENTRAL_LOGGER_DB_URL", url)
    db_session._engine = None  # noqa: SLF001
    init_db()
    yield
    db_session._engine = None  # noqa: SLF001


def _get_row(logger_id: int) -> LoggerInfo | None:
    with get_session() as session:
        return session.get(LoggerInfo, logger_id)


# ── addLogger ─────────────────────────────────────────────────────────────────

def test_addLogger_basic_persists(qtbot, fresh_db):
    ctrl = DashboardController()
    ctrl.addLogger("PlantA", "192.168.1.10")
    with get_session() as session:
        from sqlmodel import select
        rows = session.exec(select(LoggerInfo)).all()
    assert len(rows) == 1
    r = rows[0]
    assert r.name == "PlantA"
    assert r.host == "192.168.1.10"
    assert r.port == 5020
    assert r.enabled is True
    assert r.timeout_s == 2.0
    assert r.note is None


def test_addLogger_with_all_fields(qtbot, fresh_db):
    ctrl = DashboardController()
    ctrl.addLogger(
        "Full",
        "10.0.0.1",
        502, 2, 1000, 8081,
        "tok123",
        False,   # enabled=False
        3.5,     # timeout_s
        "test note",
        "https://custom.base/api/v1",
    )
    with get_session() as session:
        from sqlmodel import select
        r = session.exec(select(LoggerInfo)).first()
    assert r.enabled is False
    assert r.timeout_s == 3.5
    assert r.note == "test note"
    assert r.api_base_url == "https://custom.base/api/v1"
    assert r.api_token == "tok123"
    assert r.api_port == 8081


def test_addLogger_rejected_empty_name(qtbot, fresh_db):
    ctrl = DashboardController()
    ctrl.addLogger("", "10.0.0.2")
    with get_session() as session:
        from sqlmodel import select
        rows = session.exec(select(LoggerInfo)).all()
    assert rows == []


# ── updateLoggerConnection ────────────────────────────────────────────────────

def test_updateLoggerConnection_updates_fields(qtbot, fresh_db):
    ctrl = DashboardController()
    ctrl.addLogger("Old", "1.2.3.4")
    with get_session() as session:
        from sqlmodel import select
        r = session.exec(select(LoggerInfo)).first()
    lid = r.id

    ctrl.updateLoggerConnection(
        lid, "New", "5.6.7.8", 5021, 2, 3,
        4.0, "updated note"
    )
    r2 = _get_row(lid)
    assert r2.name == "New"
    assert r2.host == "5.6.7.8"
    assert r2.port == 5021
    assert r2.poll_interval_s == 3
    assert r2.timeout_s == 4.0
    assert r2.note == "updated note"


def test_updateLoggerConnection_preserves_enabled(qtbot, fresh_db):
    """updateLoggerConnection không đổi enabled — chỉ cập nhật connection fields."""
    ctrl = DashboardController()
    ctrl.addLogger("Logger", "1.2.3.4", enabled=False)
    with get_session() as session:
        from sqlmodel import select
        r = session.exec(select(LoggerInfo)).first()
    lid = r.id
    assert r.enabled is False

    ctrl.updateLoggerConnection(lid, "Renamed", "1.2.3.4", 5020, 1, 2)
    r2 = _get_row(lid)
    assert r2.name == "Renamed"
    assert r2.enabled is False


# ── updateLoggerApi ───────────────────────────────────────────────────────────

def test_updateLoggerApi_updates_all(qtbot, fresh_db):
    ctrl = DashboardController()
    ctrl.addLogger("Logger", "1.2.3.4")
    with get_session() as session:
        from sqlmodel import select
        r = session.exec(select(LoggerInfo)).first()
    lid = r.id

    ctrl.updateLoggerApi(lid, "newtoken", 9090, "https://override.example/api/v1")
    r2 = _get_row(lid)
    assert r2.api_token == "newtoken"
    assert r2.api_port == 9090
    assert r2.api_base_url == "https://override.example/api/v1"


def test_updateLoggerApi_clears_base_url(qtbot, fresh_db):
    ctrl = DashboardController()
    ctrl.addLogger("L", "1.1.1.1", api_base_url="https://old.url/api/v1")
    with get_session() as session:
        from sqlmodel import select
        r = session.exec(select(LoggerInfo)).first()
    lid = r.id

    ctrl.updateLoggerApi(lid, "", 8080, "")
    r2 = _get_row(lid)
    assert r2.api_base_url is None


# ── getLoggerFormData ─────────────────────────────────────────────────────────

def test_getLoggerFormData_returns_all_fields(qtbot, fresh_db):
    ctrl = DashboardController()
    ctrl.addLogger("FormTest", "10.0.0.9", 502, 3, 5, 8082, "tok", True, 2.5, "my note", "https://x.x/api/v1")
    with get_session() as session:
        from sqlmodel import select
        r = session.exec(select(LoggerInfo)).first()
    lid = r.id

    data = json.loads(ctrl.getLoggerFormData(lid))
    assert data["name"] == "FormTest"
    assert data["host"] == "10.0.0.9"
    assert data["port"] == 502
    assert data["unitId"] == 3
    assert data["pollIntervalS"] == 5
    assert data["apiPort"] == 8082
    assert data["apiToken"] == "tok"
    assert data["timeoutS"] == 2.5
    assert data["note"] == "my note"
    assert data["apiBaseUrl"] == "https://x.x/api/v1"
    assert data["enabled"] is True


def test_getLoggerFormData_not_found_returns_empty(qtbot, fresh_db):
    ctrl = DashboardController()
    assert json.loads(ctrl.getLoggerFormData(999)) == {}
