"""Tests cho chart JSON helpers và DashboardController chart slots."""

from __future__ import annotations

import json

import pytest

from central_logger.controllers import chart_queries
from central_logger.controllers.dashboard_controller import DashboardController
from central_logger.db import SensorReading, SystemEvent, get_session, init_db
from central_logger.db import session as db_session


@pytest.fixture
def fresh_db(tmp_path, monkeypatch):
    url = f"sqlite:///{tmp_path}/dash.db"
    monkeypatch.setenv("CENTRAL_LOGGER_DB_URL", url)
    db_session._engine = None  # noqa: SLF001
    init_db()
    yield
    db_session._engine = None  # noqa: SLF001


def test_recent_events_empty(qtbot, fresh_db):
    assert json.loads(chart_queries.build_recent_events_json(10)) == []


def test_recent_events_returns_inserted(qtbot, fresh_db):
    with get_session() as session:
        session.add(
            SystemEvent(
                logger_id=None,
                logger_name="Plant A",
                event_type="Info",
                message="Hello",
                level="info",
            )
        )
        session.commit()
    events = json.loads(chart_queries.build_recent_events_json(10))
    assert len(events) == 1
    assert events[0]["type"] == "Info"
    assert events[0]["logger"] == "Plant A"


def test_ingestion_chart_shape(qtbot, fresh_db):
    ctrl = DashboardController()
    payload = json.loads(ctrl.getIngestionChart24h())
    buckets = payload["buckets"] if isinstance(payload, dict) else payload
    assert len(buckets) == 288
    assert all("hour" in b and "readings" in b and "activeLoggers" in b for b in buckets)
    assert all(b["readings"] == 0 for b in buckets)
    if isinstance(payload, dict):
        assert "timezone" in payload
        assert payload.get("bucketMinutes") == 5
        assert "Ho_Chi_Minh" in payload["timezone"] or "+07" in payload["timezone"]


def test_sensor_trending_hourly_empty(qtbot, fresh_db):
    from central_logger.controllers import chart_queries

    payload = json.loads(chart_queries.build_sensor_trending_chart(1, 24))
    assert payload["labels"] and len(payload["labels"]) == 24
    assert payload["series"] == []


def test_sensor_trending_hourly_aggregates(qtbot, fresh_db):
    from central_logger.controllers import chart_queries

    with get_session() as session:
        for i in range(5):
            session.add(SensorReading(logger_id=1, sensor_id=7, value=float(i)))
        session.commit()
    payload = json.loads(chart_queries.build_sensor_trending_chart(1, 24))
    assert any(s["sensorId"] == 7 for s in payload["series"])


def test_sensor_trending_poll_history(qtbot, fresh_db):
    ctrl = DashboardController()
    sensors = [
        {"sensor_id": 3, "value": 10.0, "valid": True, "alarm": False, "stale": False},
    ]
    ctrl._sensors.append_poll_history(1, sensors)
    sensors[0]["value"] = 20.0
    ctrl._sensors.append_poll_history(1, sensors)
    sensors[0]["value"] = 30.0
    ctrl._sensors.append_poll_history(1, sensors)

    payload = json.loads(ctrl.getSensorTrendingPollChart(1, 120))
    assert payload["mode"] == "poll"
    assert payload["pointCount"] == 3
    assert len(payload["labels"]) == 3
    series = payload["series"]
    assert len(series) == 1
    assert series[0]["sensorId"] == 3
    assert series[0]["values"] == [10.0, 20.0, 30.0]


def test_poll_trending_analog_only():
    catalog = [
        {"sensor_id": 1, "name": "Temp", "sensor_type": "AI", "unit": "C", "active": True},
        {"sensor_id": 2, "name": "Door", "sensor_type": "DI", "unit": "", "active": True},
    ]
    points = [
        {"label": "10:00:00", "values": {1: 20.0, 2: 1.0}},
        {"label": "10:00:05", "values": {1: 21.0, 2: 0.0}},
    ]
    _labels, series = chart_queries.build_poll_trending_series(
        1, points, sensor_catalog=catalog
    )
    assert len(series) == 1
    assert series[0]["sensorId"] == 1


def test_poll_trending_no_top_four_cap():
    catalog = [
        {
            "sensor_id": i,
            "name": f"S{i}",
            "sensor_type": "AI",
            "unit": "",
            "active": True,
        }
        for i in range(1, 8)
    ]
    points = [{"label": "t", "values": {i: float(i) for i in range(1, 8)}}]
    _labels, series = chart_queries.build_poll_trending_series(
        1, points, sensor_catalog=catalog
    )
    assert len(series) == 7
    assert [s["sensorId"] for s in series] == list(range(1, 8))


def test_sensor_trending_poll_seeds_from_db(qtbot, fresh_db):
    from datetime import datetime, timezone

    ts = datetime.now(timezone.utc)
    with get_session() as session:
        session.add(SensorReading(logger_id=2, sensor_id=5, value=1.0, recorded_at=ts))
        session.add(SensorReading(logger_id=2, sensor_id=5, value=2.0, recorded_at=ts))
        session.commit()
    ctrl = DashboardController()
    payload = json.loads(ctrl.getSensorTrendingPollChart(2, 120))
    assert payload["pointCount"] >= 1
    assert any(s["sensorId"] == 5 for s in payload["series"])
