"""QAbstractTableModel for Sensor Monitoring TableView in Logger Detail."""

from __future__ import annotations

from dataclasses import dataclass
from enum import IntEnum
from typing import Any

from PySide6.QtCore import (
    QAbstractTableModel,
    QByteArray,
    QModelIndex,
    Qt,
    Slot,
)
from PySide6.QtQml import QmlElement

QML_IMPORT_NAME = "CentralLogger.Core"
QML_IMPORT_MAJOR_VERSION = 1

COLUMN_COUNT = 5


class SensorRoles(IntEnum):
    SensorIdRole = Qt.UserRole + 1
    NameRole = Qt.UserRole + 2
    ValueTextRole = Qt.UserRole + 3
    UnitTextRole = Qt.UserRole + 4
    DisplayStatusRole = Qt.UserRole + 5


@dataclass
class SensorRow:
    sensor_id: int
    name: str
    value_text: str
    unit_text: str
    display_status: str

    def role_value(self, role: int) -> str | None:
        mapping = {
            int(SensorRoles.SensorIdRole): str(self.sensor_id),
            int(SensorRoles.NameRole): self.name,
            int(SensorRoles.ValueTextRole): self.value_text,
            int(SensorRoles.UnitTextRole): self.unit_text,
            int(SensorRoles.DisplayStatusRole): self.display_status,
        }
        return mapping.get(role)


def _value_text(sensor_type: str, value: Any) -> str:
    stype = (sensor_type or "").upper()
    is_digital = stype in ("DI", "DO")
    if value is None:
        return "—"
    if is_digital:
        try:
            return "ON" if float(value) >= 0.5 else "OFF"
        except (TypeError, ValueError):
            return "—"
    return str(value)


def _unit_text(sensor_type: str, value: Any, unit: str) -> str:
    stype = (sensor_type or "").upper()
    if stype in ("DI", "DO"):
        return "—"
    if value is not None and unit:
        return unit
    return "—"


def _display_name(raw: dict[str, Any]) -> str:
    name = raw.get("name") or raw.get("type") or ""
    if name:
        return str(name)
    sid = raw.get("sensor_id", "?")
    return f"Sensor {sid}"


def _parse_sensor(raw: Any) -> SensorRow | None:
    if raw is None:
        return None
    if hasattr(raw, "toVariant"):
        raw = raw.toVariant()
    if not isinstance(raw, dict):
        return None
    try:
        sensor_id = int(raw.get("sensor_id", 0))
    except (TypeError, ValueError):
        return None
    sensor_type = str(raw.get("sensor_type") or "")
    value = raw.get("value")
    unit = str(raw.get("unit") or "")
    return SensorRow(
        sensor_id=sensor_id,
        name=_display_name(raw),
        value_text=_value_text(sensor_type, value),
        unit_text=_unit_text(sensor_type, value, unit),
        display_status=str(raw.get("display_status") or ""),
    )


@QmlElement
class SensorMonitoringTableModel(QAbstractTableModel):
    """Row count and column roles for TableView; cell UI reads detail.sensorList in QML."""

    def __init__(self, parent=None) -> None:
        super().__init__(parent)
        self._rows: list[SensorRow] = []

    def rowCount(self, parent: QModelIndex = QModelIndex()) -> int:  # noqa: B008
        if parent.isValid():
            return 0
        return len(self._rows)

    def columnCount(self, parent: QModelIndex = QModelIndex()) -> int:  # noqa: B008
        if parent.isValid():
            return 0
        return COLUMN_COUNT

    def data(self, index: QModelIndex, role: int = Qt.DisplayRole):
        if not index.isValid():
            return None
        row = index.row()
        if not (0 <= row < len(self._rows)):
            return None
        if role == Qt.DisplayRole:
            col = index.column()
            if 0 <= col < COLUMN_COUNT:
                role = int(SensorRoles.SensorIdRole) + col
            else:
                return None
        return self._rows[row].role_value(role)

    def roleNames(self) -> dict[int, QByteArray]:
        return {
            int(Qt.DisplayRole): QByteArray(b"display"),
            int(SensorRoles.SensorIdRole): QByteArray(b"sensorId"),
            int(SensorRoles.NameRole): QByteArray(b"name"),
            int(SensorRoles.ValueTextRole): QByteArray(b"valueText"),
            int(SensorRoles.UnitTextRole): QByteArray(b"unitText"),
            int(SensorRoles.DisplayStatusRole): QByteArray(b"displayStatus"),
        }

    @Slot("QVariantList")
    def setSensors(self, sensors: list) -> None:
        rows: list[SensorRow] = []
        for item in sensors or []:
            parsed = _parse_sensor(item)
            if parsed is not None:
                rows.append(parsed)
        self.beginResetModel()
        self._rows = rows
        self.endResetModel()
