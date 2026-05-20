"""Chart JSON builders — SQL aggregation where possible."""

from __future__ import annotations

import json
import logging
from datetime import datetime, timedelta, timezone
from typing import Any
from zoneinfo import ZoneInfo

from sqlalchemy import text
from sqlmodel import Session, select

from central_logger.db.models import DEFAULT_SYSTEM_TIMEZONE, AppSettings, SensorReading
from central_logger.db.session import get_session
from central_logger.services.sensor_catalog import display_name_for_sensor

log = logging.getLogger(__name__)

INGESTION_BUCKET_MINUTES = 5
# Poll points kept in memory and shown on Logger Detail trending chart (~1 min at ~2.5s/poll).
POLL_HISTORY_MAX = 24


def chart_timezone(session: Session | None = None) -> ZoneInfo:
    tz_name = DEFAULT_SYSTEM_TIMEZONE
    try:
        if session is not None:
            row = session.get(AppSettings, 1)
        else:
            with get_session() as owned:
                row = owned.get(AppSettings, 1)
        if row and row.system_timezone:
            tz_name = row.system_timezone.strip() or DEFAULT_SYSTEM_TIMEZONE
        return ZoneInfo(tz_name)
    except Exception:  # noqa: BLE001
        return ZoneInfo(DEFAULT_SYSTEM_TIMEZONE)


def build_ingestion_chart_24h(*, bucket_minutes: int = INGESTION_BUCKET_MINUTES) -> str:
    """Network traffic chart — bucket counts via SQL, labels in local TZ."""
    hours = 24
    bucket_count = hours * 60 // bucket_minutes
    bucket_seconds = bucket_minutes * 60

    with get_session() as session:
        tz = chart_timezone(session)
        now_local = datetime.now(tz).replace(second=0, microsecond=0)
        minute_floor = (now_local.minute // bucket_minutes) * bucket_minutes
        now_local = now_local.replace(minute=minute_floor)
        start_local = now_local - timedelta(minutes=bucket_minutes * (bucket_count - 1))
        start_utc = start_local.astimezone(timezone.utc)
        start_epoch = int(start_utc.timestamp())

        counts: dict[int, int] = {i: 0 for i in range(bucket_count)}
        active: dict[int, int] = {i: 0 for i in range(bucket_count)}

        try:
            rows = session.execute(
                text("""
                    SELECT
                        CAST((strftime('%s', recorded_at) - :start_epoch) / :bucket_sec AS INTEGER) AS bidx,
                        COUNT(*) AS readings,
                        COUNT(DISTINCT logger_id) AS active_loggers
                    FROM sensor_reading
                    WHERE recorded_at >= :start_utc
                    GROUP BY bidx
                    """),
                {
                    "start_epoch": start_epoch,
                    "bucket_sec": bucket_seconds,
                    "start_utc": start_utc.isoformat(),
                },
            ).all()
            for bidx, readings, active_loggers in rows:
                if bidx is None:
                    continue
                bi = int(bidx)
                if 0 <= bi < bucket_count:
                    counts[bi] = int(readings or 0)
                    active[bi] = int(active_loggers or 0)
        except Exception:  # noqa: BLE001
            log.exception("build_ingestion_chart_24h SQL failed")

    buckets: list[dict[str, Any]] = []
    for i in range(bucket_count):
        label = (start_local + timedelta(minutes=bucket_minutes * i)).strftime("%H:%M")
        buckets.append(
            {
                "hour": label,
                "readings": counts[i],
                "activeLoggers": active[i],
            }
        )
    return json.dumps(
        {
            "buckets": buckets,
            "timezone": str(tz),
            "hours": hours,
            "bucketMinutes": bucket_minutes,
        },
        ensure_ascii=False,
    )


def _humanize_age(then: Any) -> str:
    if then is None:
        return ""
    try:
        ts = then
        if ts.tzinfo is None:
            ts = ts.replace(tzinfo=timezone.utc)
        delta = datetime.now(timezone.utc) - ts
        secs = int(delta.total_seconds())
    except Exception:  # noqa: BLE001
        return ""
    if secs < 30:
        return "just now"
    if secs < 3600:
        m = max(1, secs // 60)
        return f"{m} min{'s' if m > 1 else ''} ago"
    if secs < 86400:
        h = secs // 3600
        return f"{h} hour{'s' if h > 1 else ''} ago"
    d = secs // 86400
    return f"{d} day{'s' if d > 1 else ''} ago"


def build_recent_events_json(limit: int = 20) -> str:
    from central_logger.db.models import SystemEvent

    if limit <= 0:
        limit = 20
    try:
        with get_session() as session:
            rows = session.exec(
                select(SystemEvent)
                .order_by(SystemEvent.created_at.desc())  # type: ignore[union-attr]
                .limit(limit)
            ).all()
    except Exception:  # noqa: BLE001
        log.exception("build_recent_events_json failed")
        return "[]"

    events = [
        {
            "id": r.id,
            "type": r.event_type,
            "logger": r.logger_name,
            "loggerId": r.logger_id,
            "message": r.message,
            "level": r.level,
            "time": _humanize_age(r.created_at),
            "iso": r.created_at.isoformat() if r.created_at else "",
        }
        for r in rows
    ]
    return json.dumps(events, ensure_ascii=False)


def build_sensor_trending_chart(
    logger_id: int,
    hours: int,
    *,
    last_snapshot: dict[str, Any] | None = None,
) -> str:
    """Hourly averaged trending (legacy slot; kept for tests)."""
    if hours <= 0:
        hours = 24
    tz = chart_timezone()
    now_local = datetime.now(tz).replace(minute=0, second=0, microsecond=0)
    start_local = now_local - timedelta(hours=hours - 1)
    start_utc = start_local.astimezone(timezone.utc)
    try:
        with get_session() as session:
            rows = session.exec(
                select(
                    SensorReading.sensor_id,
                    SensorReading.value,
                    SensorReading.recorded_at,
                )
                .where(SensorReading.logger_id == logger_id)
                .where(SensorReading.recorded_at >= start_utc)
            ).all()
    except Exception:  # noqa: BLE001
        log.exception("build_sensor_trending_chart failed")
        rows = []

    per_sensor: dict[int, list[list[float]]] = {}
    sensor_total: dict[int, int] = {}
    for sid, value, ts in rows:
        if ts is None:
            continue
        if ts.tzinfo is None:
            ts = ts.replace(tzinfo=timezone.utc)
        ts_local = ts.astimezone(tz)
        h = int((ts_local - start_local).total_seconds() // 3600)
        if not (0 <= h < hours):
            continue
        agg = per_sensor.setdefault(sid, [[0.0, 0.0] for _ in range(hours)])
        agg[h][0] += float(value)
        agg[h][1] += 1.0
        sensor_total[sid] = sensor_total.get(sid, 0) + 1

    current_h = hours - 1
    if last_snapshot:
        for s in last_snapshot.get("sensors") or []:
            sid = int(s.get("sensor_id", -1))
            if sid < 0:
                continue
            agg = per_sensor.setdefault(sid, [[0.0, 0.0] for _ in range(hours)])
            agg[current_h][0] += float(s.get("value", 0))
            agg[current_h][1] += 1.0
            sensor_total[sid] = sensor_total.get(sid, 0) + 1

    top_sensors = sorted(sensor_total.items(), key=lambda kv: kv[1], reverse=True)[:4]
    series = []
    for sid, _count in top_sensors:
        agg = per_sensor[sid]
        values = [(s / c) if c > 0 else 0.0 for s, c in agg]
        series.append({"sensorId": sid, "label": f"Sensor {sid}", "values": values})

    labels = [(start_local + timedelta(hours=i)).strftime("%H:00") for i in range(hours)]
    return json.dumps(
        {"labels": labels, "series": series, "timezone": str(tz), "hours": hours},
        ensure_ascii=False,
    )


def seed_poll_history_from_db(logger_id: int, max_points: int) -> list[dict[str, Any]]:
    tz = chart_timezone()
    try:
        with get_session() as session:
            rows = session.exec(
                select(
                    SensorReading.sensor_id,
                    SensorReading.value,
                    SensorReading.recorded_at,
                )
                .where(SensorReading.logger_id == logger_id)
                .order_by(SensorReading.recorded_at.desc())  # type: ignore[union-attr]
                .limit(max_points * 8)
            ).all()
    except Exception:  # noqa: BLE001
        log.exception("seed_poll_history_from_db failed")
        return []

    by_ts: dict[datetime, dict[int, float]] = {}
    for sid, value, ts in reversed(rows):
        if ts is None:
            continue
        if ts.tzinfo is None:
            ts = ts.replace(tzinfo=timezone.utc)
        bucket = by_ts.setdefault(ts, {})
        bucket[int(sid)] = float(value)

    points: list[dict[str, Any]] = []
    for ts, values in sorted(by_ts.items()):
        label = ts.astimezone(tz).strftime("%H:%M:%S")
        points.append({"label": label, "values": values})
    return points[-max_points:]


def build_poll_trending_series(
    logger_id: int,
    points: list[dict[str, Any]],
    *,
    sensor_catalog: list[dict[str, Any]] | None = None,
) -> tuple[list[str], list[dict[str, Any]]]:
    sensor_total: dict[int, int] = {}
    for pt in points:
        for sid in pt.get("values") or {}:
            sensor_total[int(sid)] = sensor_total.get(int(sid), 0) + 1
    top_sensors = sorted(sensor_total.items(), key=lambda kv: kv[1], reverse=True)[:4]
    labels = [str(pt.get("label", "")) for pt in points]
    catalog = sensor_catalog or []
    series: list[dict[str, Any]] = []
    for sid, _count in top_sensors:
        values = [float((pt.get("values") or {}).get(sid, 0.0)) for pt in points]
        series.append(
            {
                "sensorId": sid,
                "label": display_name_for_sensor(catalog, sid),
                "values": values,
            }
        )
    return labels, series


def build_sensor_trending_poll_chart(
    logger_id: int,
    poll_history: list[dict[str, Any]] | None,
    *,
    max_points: int = POLL_HISTORY_MAX,
    sensor_catalog: list[dict[str, Any]] | None = None,
) -> str:
    if max_points <= 0:
        max_points = POLL_HISTORY_MAX
    max_points = min(max_points, POLL_HISTORY_MAX)

    if poll_history:
        points = list(poll_history)[-max_points:]
    else:
        points = seed_poll_history_from_db(logger_id, max_points)

    tz = chart_timezone()
    if not points:
        return json.dumps(
            {
                "mode": "poll",
                "labels": [],
                "series": [],
                "pointCount": 0,
                "timezone": str(tz),
            },
            ensure_ascii=False,
        )

    labels, series = build_poll_trending_series(logger_id, points, sensor_catalog=sensor_catalog)
    return json.dumps(
        {
            "mode": "poll",
            "labels": labels,
            "series": series,
            "pointCount": len(labels),
            "timezone": str(tz),
        },
        ensure_ascii=False,
    )
