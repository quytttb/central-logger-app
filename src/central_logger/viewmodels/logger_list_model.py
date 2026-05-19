"""QAbstractListModel cho danh sách Data Logger - hiển thị trong GridView/ListView."""
from __future__ import annotations

from dataclasses import dataclass, field
from enum import IntEnum

from PySide6.QtCore import (
    Property,
    QAbstractListModel,
    QByteArray,
    QModelIndex,
    Qt,
    Signal,
    Slot,
)
from PySide6.QtQml import QmlElement

QML_IMPORT_NAME = "CentralLogger.Core"
QML_IMPORT_MAJOR_VERSION = 1


class LoggerRoles(IntEnum):
    IdRole = Qt.UserRole + 1
    NameRole = Qt.UserRole + 2
    HostRole = Qt.UserRole + 3
    PortRole = Qt.UserRole + 4
    UnitIdRole = Qt.UserRole + 5
    OnlineRole = Qt.UserRole + 6
    PollingRole = Qt.UserRole + 7
    RtuConnectedRole = Qt.UserRole + 8
    AnyAlarmRole = Qt.UserRole + 9
    SensorCountRole = Qt.UserRole + 10
    LastUpdateRole = Qt.UserRole + 11
    LastErrorRole = Qt.UserRole + 12


@dataclass
class LoggerItem:
    """Trạng thái runtime một Data Logger."""

    id: int
    name: str
    host: str
    port: int = 5020
    unit_id: int = 1
    poll_interval_s: int = 2
    online: bool = False
    polling: bool = False
    rtu_connected: bool = False
    any_alarm: bool = False
    sensor_count: int = 0
    last_update: str = ""
    last_error: str = ""
    # Extended DB fields
    enabled: bool = True
    timeout_s: float = 2.0
    note: str = ""
    api_port: int = 8080
    api_base_url: str = ""

    def as_role_value(self, role: int):
        mapping = {
            int(LoggerRoles.IdRole): self.id,
            int(LoggerRoles.NameRole): self.name,
            int(LoggerRoles.HostRole): self.host,
            int(LoggerRoles.PortRole): self.port,
            int(LoggerRoles.UnitIdRole): self.unit_id,
            int(LoggerRoles.OnlineRole): self.online,
            int(LoggerRoles.PollingRole): self.polling,
            int(LoggerRoles.RtuConnectedRole): self.rtu_connected,
            int(LoggerRoles.AnyAlarmRole): self.any_alarm,
            int(LoggerRoles.SensorCountRole): self.sensor_count,
            int(LoggerRoles.LastUpdateRole): self.last_update,
            int(LoggerRoles.LastErrorRole): self.last_error,
        }
        return mapping.get(role)


@QmlElement
class LoggerListModel(QAbstractListModel):
    """Mô hình danh sách logger; dùng trong QML như:

        ListView { model: LoggerListModel { id: loggers } }
    """

    countChanged = Signal()

    def __init__(self, parent=None) -> None:
        super().__init__(parent)
        self._items: list[LoggerItem] = []

    # ----- bắt buộc cho QAbstractListModel -----
    def rowCount(self, parent: QModelIndex = QModelIndex()) -> int:  # noqa: B008
        if parent.isValid():
            return 0
        return len(self._items)

    def data(self, index: QModelIndex, role: int = Qt.DisplayRole):
        if not index.isValid() or not (0 <= index.row() < len(self._items)):
            return None
        return self._items[index.row()].as_role_value(role)

    def roleNames(self) -> dict[int, QByteArray]:
        return {
            int(LoggerRoles.IdRole): QByteArray(b"loggerId"),
            int(LoggerRoles.NameRole): QByteArray(b"name"),
            int(LoggerRoles.HostRole): QByteArray(b"host"),
            int(LoggerRoles.PortRole): QByteArray(b"port"),
            int(LoggerRoles.UnitIdRole): QByteArray(b"unitId"),
            int(LoggerRoles.OnlineRole): QByteArray(b"online"),
            int(LoggerRoles.PollingRole): QByteArray(b"polling"),
            int(LoggerRoles.RtuConnectedRole): QByteArray(b"rtuConnected"),
            int(LoggerRoles.AnyAlarmRole): QByteArray(b"anyAlarm"),
            int(LoggerRoles.SensorCountRole): QByteArray(b"sensorCount"),
            int(LoggerRoles.LastUpdateRole): QByteArray(b"lastUpdate"),
            int(LoggerRoles.LastErrorRole): QByteArray(b"lastError"),
        }

    # ----- API thao tác list -----
    def add_logger(self, item: LoggerItem) -> None:
        row = len(self._items)
        self.beginInsertRows(QModelIndex(), row, row)
        self._items.append(item)
        self.endInsertRows()
        self.countChanged.emit()

    def remove_logger(self, logger_id: int) -> bool:
        for row, item in enumerate(self._items):
            if item.id == logger_id:
                self.beginRemoveRows(QModelIndex(), row, row)
                self._items.pop(row)
                self.endRemoveRows()
                self.countChanged.emit()
                return True
        return False

    def clear(self) -> None:
        if not self._items:
            return
        self.beginResetModel()
        self._items.clear()
        self.endResetModel()
        self.countChanged.emit()

    def update_connection(
        self,
        logger_id: int,
        *,
        name: str | None = None,
        host: str | None = None,
        port: int | None = None,
        unit_id: int | None = None,
        poll_interval_s: int | None = None,
        enabled: bool | None = None,
        timeout_s: float | None = None,
        note: str | None = None,
    ) -> None:
        for row, item in enumerate(self._items):
            if item.id != logger_id:
                continue
            changed_roles: list[int] = []
            if name is not None and item.name != name:
                item.name = name
                changed_roles.append(int(LoggerRoles.NameRole))
            if host is not None and item.host != host:
                item.host = host
                changed_roles.append(int(LoggerRoles.HostRole))
            if port is not None and item.port != port:
                item.port = port
                changed_roles.append(int(LoggerRoles.PortRole))
            if unit_id is not None and item.unit_id != unit_id:
                item.unit_id = unit_id
                changed_roles.append(int(LoggerRoles.UnitIdRole))
            if poll_interval_s is not None and item.poll_interval_s != poll_interval_s:
                item.poll_interval_s = poll_interval_s
            if enabled is not None:
                item.enabled = enabled
            if timeout_s is not None:
                item.timeout_s = timeout_s
            if note is not None:
                item.note = note or ""
            if changed_roles:
                idx = self.index(row, 0)
                self.dataChanged.emit(idx, idx, changed_roles)
            return

    def update_status(
        self,
        logger_id: int,
        *,
        online: bool | None = None,
        polling: bool | None = None,
        rtu_connected: bool | None = None,
        any_alarm: bool | None = None,
        sensor_count: int | None = None,
        last_update: str | None = None,
        last_error: str | None = None,
    ) -> None:
        for row, item in enumerate(self._items):
            if item.id != logger_id:
                continue
            changed_roles: list[int] = []
            if online is not None and item.online != online:
                item.online = online
                changed_roles.append(int(LoggerRoles.OnlineRole))
            if polling is not None and item.polling != polling:
                item.polling = polling
                changed_roles.append(int(LoggerRoles.PollingRole))
            if rtu_connected is not None and item.rtu_connected != rtu_connected:
                item.rtu_connected = rtu_connected
                changed_roles.append(int(LoggerRoles.RtuConnectedRole))
            if any_alarm is not None and item.any_alarm != any_alarm:
                item.any_alarm = any_alarm
                changed_roles.append(int(LoggerRoles.AnyAlarmRole))
            if sensor_count is not None and item.sensor_count != sensor_count:
                item.sensor_count = sensor_count
                changed_roles.append(int(LoggerRoles.SensorCountRole))
            if last_update is not None and item.last_update != last_update:
                item.last_update = last_update
                changed_roles.append(int(LoggerRoles.LastUpdateRole))
            if last_error is not None and item.last_error != last_error:
                item.last_error = last_error
                changed_roles.append(int(LoggerRoles.LastErrorRole))

            if changed_roles:
                idx = self.index(row, 0)
                self.dataChanged.emit(idx, idx, changed_roles)
            return

    @Slot(result=int)
    def count(self) -> int:
        return len(self._items)

    # `Property` để QML có thể bind trực tiếp (`model.rowCountValue`) và tự
    # re-evaluate khi `countChanged` emit. Slot `count()` ở trên KHÔNG reactive
    # nên dùng property này cho binding (ví dụ: empty-state visible).
    @Property(int, notify=countChanged)
    def rowCountValue(self) -> int:
        return len(self._items)

    @Slot(result=int)
    def onlineCount(self) -> int:
        return sum(1 for it in self._items if it.online)

    @Slot(result=int)
    def alarmCount(self) -> int:
        return sum(1 for it in self._items if it.any_alarm)

    @Slot(int, result="QVariant")
    def itemAt(self, row: int):
        if 0 <= row < len(self._items):
            item = self._items[row]
            return {
                "loggerId": item.id,
                "name": item.name,
                "host": item.host,
                "port": item.port,
                "unitId": item.unit_id,
                "pollIntervalS": item.poll_interval_s,
                "online": item.online,
                "polling": item.polling,
                "rtuConnected": item.rtu_connected,
                "anyAlarm": item.any_alarm,
                "sensorCount": item.sensor_count,
                "lastUpdate": item.last_update,
                "lastError": item.last_error,
                "enabled": item.enabled,
                "timeoutS": item.timeout_s,
                "note": item.note,
                "apiPort": item.api_port,
                "apiBaseUrl": item.api_base_url,
            }
        return None
