"""Tests for data retention purge and sensor_reading indexes."""
from __future__ import annotations

from datetime import datetime, timedelta, timezone

import pytest
from sqlalchemy import inspect, text

from central_logger.db import LoggerInfo, SensorReading, SystemEvent, get_session, init_db
from central_logger.db import session as db_session
from central_logger.db.retention import purge_old_data


@pytest.fixture
def fresh_db(tmp_path, monkeypatch):
    url = f"sqlite:///{tmp_path}/retention.db"
    monkeypatch.setenv("CENTRAL_LOGGER_DB_URL", url)
    db_session._engine = None  # noqa: SLF001
    init_db()
    yield
    db_session._engine = None  # noqa: SLF001


def test_sensor_reading_indexes_created(fresh_db):
    engine = db_session.get_engine()
    indexes = {idx["name"] for idx in inspect(engine).get_indexes("sensor_reading")}
    assert "ix_sensor_reading_logger_recorded" in indexes
    assert "ix_sensor_reading_recorded_at" in indexes


def test_purge_old_data_removes_stale_rows(fresh_db):
    old = datetime.now(timezone.utc) - timedelta(days=40)
    with get_session() as session:
        session.add(LoggerInfo(id=1, name="Test", host="127.0.0.1", port=502))
        session.add(
            SensorReading(
                logger_id=1,
                sensor_id=1,
                value=1.0,
                recorded_at=old,
            )
        )
        session.add(
            SystemEvent(
                logger_id=1,
                logger_name="L",
                event_type="Info",
                message="old",
                level="info",
                created_at=old,
            )
        )
        session.commit()

    deleted = purge_old_data()
    assert deleted >= 2

    with get_session() as session:
        remaining = session.exec(text("SELECT COUNT(*) FROM sensor_reading")).one()
        count = remaining[0] if hasattr(remaining, "__getitem__") else remaining
        assert int(count) == 0
