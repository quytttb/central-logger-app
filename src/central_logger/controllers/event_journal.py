"""System event log — DB writes with maintenance-mode filter."""

from __future__ import annotations

import logging
from collections.abc import Callable

from central_logger.db import AppSettings, SystemEvent, get_session

log = logging.getLogger(__name__)

_SUPPRESSIBLE = frozenset({"Alarm", "Offline", "Warning"})


class EventJournal:
    def __init__(
        self,
        *,
        on_events_changed: Callable[[], None],
        on_invalidate_ingestion: Callable[[], None],
    ) -> None:
        self._on_events_changed = on_events_changed
        self._on_invalidate_ingestion = on_invalidate_ingestion
        self._last_event_key: dict[tuple[int, str], str] = {}

    def maintenance_mode_enabled(self) -> bool:
        try:
            with get_session() as session:
                row = session.get(AppSettings, 1)
                return bool(row.maintenance_mode) if row else False
        except Exception:  # noqa: BLE001
            return False

    def log_event(
        self,
        logger_id: int | None,
        logger_name: str,
        event_type: str,
        message: str,
        level: str,
    ) -> None:
        if event_type in _SUPPRESSIBLE and self.maintenance_mode_enabled():
            return
        try:
            with get_session() as session:
                session.add(
                    SystemEvent(
                        logger_id=logger_id,
                        logger_name=logger_name or "",
                        event_type=event_type,
                        message=message,
                        level=level,
                    )
                )
                session.commit()
            if logger_id is not None:
                self._last_event_key[(logger_id, event_type)] = message
            self._on_events_changed()
            self._on_invalidate_ingestion()
        except Exception:  # noqa: BLE001
            log.exception("log_event failed: %s/%s", event_type, message)

    def log_event_dedup(
        self,
        logger_id: int,
        logger_name: str,
        event_type: str,
        message: str,
        level: str,
    ) -> None:
        key = (logger_id, event_type)
        if self._last_event_key.get(key) == message:
            return
        self.log_event(logger_id, logger_name, event_type, message, level)
