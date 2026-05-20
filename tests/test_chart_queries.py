"""Tests for SQL-backed chart query helpers."""
from __future__ import annotations

import json
from datetime import datetime, timedelta, timezone

import pytest

from central_logger.controllers import chart_queries
from central_logger.db import LoggerInfo, SensorReading, get_session, init_db
from central_logger.db import session as db_session


@pytest.fixture
def chart_db(tmp_path, monkeypatch):
    url = f"sqlite:///{tmp_path}/charts.db"
    monkeypatch.setenv("CENTRAL_LOGGER_DB_URL", url)
    db_session._engine = None  # noqa: SLF001
    init_db()
    now = datetime.now(timezone.utc)
    with get_session() as session:
        session.add(LoggerInfo(id=1, name="L1", host="10.0.0.1", port=502))
        for i in range(5):
            session.add(
                SensorReading(
                    logger_id=1,
                    sensor_id=1,
                    value=float(i),
                    recorded_at=now - timedelta(minutes=i * 10),
                )
            )
        session.commit()
    yield
    db_session._engine = None  # noqa: SLF001


def test_build_ingestion_chart_24h_returns_labels_and_values(chart_db):
    raw = chart_queries.build_ingestion_chart_24h()
    data = json.loads(raw)
    assert "buckets" in data
    assert isinstance(data["buckets"], list)
    assert data["hours"] == 24
