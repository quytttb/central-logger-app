"""Data retention — purge old sensor readings and system events."""
from __future__ import annotations

import logging
from datetime import datetime, timedelta, timezone

from sqlalchemy import delete, func, select
from sqlmodel import Session

from central_logger.db.models import AppSettings, SensorReading, SystemEvent
from central_logger.db.session import get_engine

log = logging.getLogger(__name__)


def purge_old_data(session: Session | None = None) -> int:
    """Delete rows older than ``AppSettings.data_retention_days``. Returns rows removed."""
    if session is not None:
        return _purge_with_session(session)

    with Session(get_engine()) as owned:
        deleted = _purge_with_session(owned)
        owned.commit()
        return deleted


def _purge_with_session(session: Session) -> int:
    settings = session.get(AppSettings, 1)
    days = int(settings.data_retention_days) if settings else 30
    if days <= 0:
        return 0

    cutoff = datetime.now(timezone.utc) - timedelta(days=days)
    r_readings = session.execute(
        delete(SensorReading).where(SensorReading.recorded_at < cutoff)  # type: ignore[arg-type]
    )
    r_events = session.execute(
        delete(SystemEvent).where(SystemEvent.created_at < cutoff)  # type: ignore[arg-type]
    )
    deleted = int(r_readings.rowcount or 0) + int(r_events.rowcount or 0)
    if deleted:
        log.info("purge_old_data: removed %s rows older than %s days", deleted, days)
    return deleted


def count_rows_older_than(days: int) -> int:
    """Helper for tests — count rows that would be purged."""
    if days <= 0:
        return 0
    cutoff = datetime.now(timezone.utc) - timedelta(days=days)
    with Session(get_engine()) as session:
        readings = session.exec(
            select(func.count()).select_from(SensorReading).where(
                SensorReading.recorded_at < cutoff
            )
        ).one()
        events = session.exec(
            select(func.count()).select_from(SystemEvent).where(
                SystemEvent.created_at < cutoff
            )
        ).one()
        return int(readings) + int(events)
