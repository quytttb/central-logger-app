"""Global application state exposed to QML as a Singleton.

Đăng ký qua QML_IMPORT_NAME = "CentralLogger.Core" để dùng trong QML:
    import CentralLogger.Core 1.0
    Label { text: AppState.statusText }
"""
from __future__ import annotations

from PySide6.QtCore import Property, QObject, Signal, Slot
from PySide6.QtQml import QmlElement, QmlSingleton

QML_IMPORT_NAME = "CentralLogger.Core"
QML_IMPORT_MAJOR_VERSION = 1


@QmlElement
@QmlSingleton
class AppState(QObject):
    """Trạng thái toàn cục: tổng số logger, online/offline, alarms..."""

    totalLoggersChanged = Signal()
    onlineLoggersChanged = Signal()
    alarmCountChanged = Signal()
    statusTextChanged = Signal()

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._total = 0
        self._online = 0
        self._alarms = 0
        self._status = "Ready"

    @Property(int, notify=totalLoggersChanged)
    def totalLoggers(self) -> int:
        return self._total

    @totalLoggers.setter
    def totalLoggers(self, value: int) -> None:
        if self._total != value:
            self._total = value
            self.totalLoggersChanged.emit()

    @Property(int, notify=onlineLoggersChanged)
    def onlineLoggers(self) -> int:
        return self._online

    @onlineLoggers.setter
    def onlineLoggers(self, value: int) -> None:
        if self._online != value:
            self._online = value
            self.onlineLoggersChanged.emit()

    @Property(int, notify=alarmCountChanged)
    def alarmCount(self) -> int:
        return self._alarms

    @alarmCount.setter
    def alarmCount(self, value: int) -> None:
        if self._alarms != value:
            self._alarms = value
            self.alarmCountChanged.emit()

    @Property(str, notify=statusTextChanged)
    def statusText(self) -> str:
        return self._status

    @statusText.setter
    def statusText(self, value: str) -> None:
        if self._status != value:
            self._status = value
            self.statusTextChanged.emit()

    @Slot(str)
    def setStatus(self, value: str) -> None:
        self.statusText = value
