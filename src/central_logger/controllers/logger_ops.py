"""Logger CRUD — DB persistence separated from DashboardController."""
from __future__ import annotations

import json
import logging
from typing import Any

from sqlmodel import Session, select

from central_logger.controllers.rest_facade import normalize_host
from central_logger.db.models import LoggerInfo, SensorReading
from central_logger.db.session import get_session

log = logging.getLogger(__name__)


def is_valid_logger_row(row: LoggerInfo) -> bool:
    return (
        bool((row.name or "").strip())
        and bool((row.host or "").strip())
        and (row.port or 0) > 0
        and (row.unit_id or 0) > 0
    )


def prune_invalid_loggers(session: Session) -> int:
    """Delete invalid logger_info rows; return count removed."""
    removed = 0
    for row in list(session.exec(select(LoggerInfo)).all()):
        if not is_valid_logger_row(row):
            log.warning(
                "removing invalid logger row id=%s name=%r host=%r port=%s unit=%s",
                row.id,
                row.name,
                row.host,
                row.port,
                row.unit_id,
            )
            session.delete(row)
            removed += 1
    return removed


def load_enabled_loggers() -> list[LoggerInfo]:
    """Valid enabled loggers after pruning invalid rows."""
    with get_session() as session:
        removed = prune_invalid_loggers(session)
        if removed:
            session.commit()
        rows = list(session.exec(select(LoggerInfo)).all())
        return [r for r in rows if is_valid_logger_row(r) and r.enabled]


def insert_logger(
    *,
    name: str,
    host: str,
    port: int,
    unit_id: int,
    poll_interval_s: int,
    api_port: int,
    api_token: str,
    enabled: bool,
    timeout_s: float,
    note: str,
    api_base_url: str,
) -> LoggerInfo | None:
    clean_name = (name or "").strip()
    clean_host = (host or "").strip()
    if not clean_name or not clean_host or port <= 0 or unit_id <= 0:
        return None
    with get_session() as session:
        row = LoggerInfo(
            name=clean_name,
            host=normalize_host(clean_host),
            port=port,
            unit_id=unit_id,
            poll_interval_s=max(1, int(poll_interval_s)),
            api_port=api_port or 8080,
            api_token=api_token or None,
            enabled=enabled,
            timeout_s=float(timeout_s) if timeout_s and float(timeout_s) > 0 else 2.0,
            note=note.strip() or None,
            api_base_url=api_base_url.strip() or None,
        )
        session.add(row)
        session.commit()
        session.refresh(row)
        return row


def update_connection(
    logger_id: int,
    *,
    name: str,
    host: str,
    port: int,
    unit_id: int,
    poll_interval_s: int,
    timeout_s: float,
    note: str,
) -> LoggerInfo | None:
    clean_name = (name or "").strip()
    clean_host = (host or "").strip()
    if not clean_name or not clean_host or port <= 0 or unit_id <= 0:
        return None
    with get_session() as session:
        row = session.get(LoggerInfo, logger_id)
        if row is None:
            return None
        row.name = clean_name
        row.host = normalize_host(clean_host)
        row.port = port
        row.unit_id = unit_id
        row.poll_interval_s = max(1, int(poll_interval_s))
        if timeout_s and float(timeout_s) > 0:
            row.timeout_s = float(timeout_s)
        row.note = note.strip() or None
        session.add(row)
        session.commit()
        session.refresh(row)
        return row


def update_api(
    logger_id: int,
    *,
    token: str,
    api_port: int,
    api_base_url: str,
) -> LoggerInfo | None:
    with get_session() as session:
        row = session.get(LoggerInfo, logger_id)
        if row is None:
            return None
        row.api_token = token or None
        row.api_port = api_port or row.api_port
        row.api_base_url = api_base_url.strip() or None
        session.add(row)
        session.commit()
        session.refresh(row)
        return row


def delete_logger_and_readings(logger_id: int) -> str | None:
    """Delete readings + logger row. Returns logger name if deleted."""
    with get_session() as session:
        for r in session.exec(
            select(SensorReading).where(SensorReading.logger_id == logger_id)
        ).all():
            session.delete(r)
        row = session.get(LoggerInfo, logger_id)
        if row is None:
            return None
        name = row.name
        session.delete(row)
        session.commit()
        return name


def logger_form_json(logger_id: int) -> str:
    try:
        with get_session() as session:
            row = session.get(LoggerInfo, logger_id)
            if row is None:
                return "{}"
            return json.dumps(
                {
                    "loggerId": row.id,
                    "name": row.name,
                    "host": row.host,
                    "port": row.port,
                    "unitId": row.unit_id,
                    "pollIntervalS": row.poll_interval_s,
                    "timeoutS": row.timeout_s,
                    "enabled": row.enabled,
                    "note": row.note or "",
                    "apiPort": row.api_port,
                    "apiToken": row.api_token or "",
                    "apiBaseUrl": row.api_base_url or "",
                    "lastRevision": row.last_revision,
                },
                ensure_ascii=False,
            )
    except Exception:  # noqa: BLE001
        log.exception("logger_form_json failed for %s", logger_id)
        return "{}"


def save_last_revision(logger_id: int, revision: int) -> None:
    try:
        with get_session() as session:
            row = session.get(LoggerInfo, logger_id)
            if row is None or row.last_revision == revision:
                return
            row.last_revision = revision
            session.add(row)
            session.commit()
    except Exception:  # noqa: BLE001
        log.exception("save_last_revision failed for %s", logger_id)


def logger_api_fields(logger_id: int) -> dict[str, Any]:
    try:
        with get_session() as session:
            row = session.get(LoggerInfo, logger_id)
            if row is None:
                return {}
            return {
                "api_token": row.api_token or "",
                "api_port": row.api_port,
                "api_base_url": row.api_base_url or "",
            }
    except Exception:  # noqa: BLE001
        return {}
