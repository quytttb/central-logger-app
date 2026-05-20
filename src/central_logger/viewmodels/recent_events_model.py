"""QAbstractListModel for dashboard recent events (replaces JSON pull in QML)."""
from __future__ import annotations

import json
from typing import Any

from PySide6.QtCore import QAbstractListModel, QModelIndex, Qt, Signal, Slot
from PySide6.QtQml import QmlElement

from central_logger.controllers import chart_queries

QML_IMPORT_NAME = "CentralLogger.Core"
QML_IMPORT_MAJOR_VERSION = 1


class RecentEventRoles:
    TypeRole = Qt.UserRole + 1
    LoggerRole = Qt.UserRole + 2
    MessageRole = Qt.UserRole + 3
    LevelRole = Qt.UserRole + 4
    TimeRole = Qt.UserRole + 5
    LoggerIdRole = Qt.UserRole + 6


@QmlElement
class RecentEventsModel(QAbstractListModel):
    """List model backed by cached event dicts from ``chart_queries``."""

    countChanged = Signal()

    def __init__(self, parent=None) -> None:
        super().__init__(parent)
        self._events: list[dict[str, Any]] = []

    def roleNames(self) -> dict[int, bytes]:  # type: ignore[override]
        return {
            int(RecentEventRoles.TypeRole): b"type",
            int(RecentEventRoles.LoggerRole): b"logger",
            int(RecentEventRoles.MessageRole): b"message",
            int(RecentEventRoles.LevelRole): b"level",
            int(RecentEventRoles.TimeRole): b"time",
            int(RecentEventRoles.LoggerIdRole): b"loggerId",
        }

    def rowCount(self, parent: QModelIndex = QModelIndex()) -> int:  # noqa: B008
        if parent.isValid():
            return 0
        return len(self._events)

    def data(self, index: QModelIndex, role: int = Qt.DisplayRole):  # type: ignore[override]
        if not index.isValid() or index.row() < 0 or index.row() >= len(self._events):
            return None
        item = self._events[index.row()]
        mapping = {
            int(RecentEventRoles.TypeRole): item.get("type", ""),
            int(RecentEventRoles.LoggerRole): item.get("logger", ""),
            int(RecentEventRoles.MessageRole): item.get("message", ""),
            int(RecentEventRoles.LevelRole): item.get("level", ""),
            int(RecentEventRoles.TimeRole): item.get("time", ""),
            int(RecentEventRoles.LoggerIdRole): item.get("loggerId"),
        }
        return mapping.get(role)

    @Slot(int)
    def reload(self, limit: int = 20) -> None:
        raw = chart_queries.build_recent_events_json(limit)
        try:
            parsed = json.loads(raw or "[]")
            events = parsed if isinstance(parsed, list) else []
        except json.JSONDecodeError:
            events = []
        self.beginResetModel()
        self._events = events
        self.endResetModel()
        self.countChanged.emit()
