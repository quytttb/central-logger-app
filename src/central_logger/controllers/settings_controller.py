"""Controller cho `AppSettings` — load/save row id=1 và expose properties tới QML."""

from __future__ import annotations

import logging
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from PySide6.QtCore import Property, QObject, Signal, Slot
from PySide6.QtQml import QmlElement

from central_logger.db import AppSettings, get_session, init_db
from central_logger.db.models import DEFAULT_SYSTEM_TIMEZONE

QML_IMPORT_NAME = "CentralLogger.Core"
QML_IMPORT_MAJOR_VERSION = 1

log = logging.getLogger(__name__)

_RETENTION_MIN = 1
_RETENTION_MAX = 3650
_ALLOWED_THEMES = frozenset({"dark", "light"})


def _normalize_theme(theme: str) -> str:
    t = (theme or "dark").strip().lower()
    return t if t in _ALLOWED_THEMES else "dark"


def _validate_timezone(tz: str) -> str:
    name = (tz or DEFAULT_SYSTEM_TIMEZONE).strip() or DEFAULT_SYSTEM_TIMEZONE
    try:
        ZoneInfo(name)
    except ZoneInfoNotFoundError as exc:
        raise ValueError(f"Invalid timezone: {name}") from exc
    return name


def _clamp_retention(days: int) -> int:
    return max(_RETENTION_MIN, min(_RETENTION_MAX, int(days)))


@QmlElement
class SettingsController(QObject):
    """Bridge cho bảng `app_settings` (single-row config)."""

    themeChanged = Signal()
    systemTimezoneChanged = Signal()
    dataRetentionDaysChanged = Signal()
    maintenanceModeChanged = Signal()
    saved = Signal()
    loadError = Signal(str)

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._theme = "dark"
        self._timezone = DEFAULT_SYSTEM_TIMEZONE
        self._retention_days = 30
        self._maintenance = False

    # ---------- properties ----------
    @Property(str, notify=themeChanged)
    def theme(self) -> str:
        return self._theme

    @theme.setter
    def theme(self, value: str) -> None:
        value = _normalize_theme(value)
        if self._theme != value:
            self._theme = value
            self.themeChanged.emit()

    @Property(str, notify=systemTimezoneChanged)
    def systemTimezone(self) -> str:
        return self._timezone

    @systemTimezone.setter
    def systemTimezone(self, value: str) -> None:
        if self._timezone != value:
            self._timezone = value
            self.systemTimezoneChanged.emit()

    @Property(int, notify=dataRetentionDaysChanged)
    def dataRetentionDays(self) -> int:
        return self._retention_days

    @dataRetentionDays.setter
    def dataRetentionDays(self, value: int) -> None:
        value = _clamp_retention(value)
        if self._retention_days != value:
            self._retention_days = value
            self.dataRetentionDaysChanged.emit()

    @Property(bool, notify=maintenanceModeChanged)
    def maintenanceMode(self) -> bool:
        return self._maintenance

    @maintenanceMode.setter
    def maintenanceMode(self, value: bool) -> None:
        if self._maintenance != bool(value):
            self._maintenance = bool(value)
            self.maintenanceModeChanged.emit()

    # ---------- slots ----------
    @Slot()
    def load(self) -> None:
        try:
            init_db()
            with get_session() as session:
                row = session.get(AppSettings, 1)
                if row is None:
                    row = AppSettings(id=1)
                    session.add(row)
                    session.commit()
                    session.refresh(row)
                self.theme = row.theme
                self.systemTimezone = row.system_timezone
                self.dataRetentionDays = row.data_retention_days
                self.maintenanceMode = row.maintenance_mode
        except Exception as exc:  # noqa: BLE001
            log.exception("SettingsController.load failed")
            self.loadError.emit(str(exc))

    @Slot(str)
    def saveTheme(self, theme: str) -> None:
        theme_value = _normalize_theme(theme)
        try:
            with get_session() as session:
                row = session.get(AppSettings, 1) or AppSettings(id=1)
                row.theme = theme_value
                session.add(row)
                session.commit()
            self.theme = theme_value
        except Exception as exc:  # noqa: BLE001
            log.exception("SettingsController.saveTheme failed")
            self.loadError.emit(str(exc))

    @Slot(str, str, int, bool)
    def save(
        self,
        theme: str,
        timezone: str,
        retention_days: int,
        maintenance: bool,
    ) -> None:
        try:
            theme_value = _normalize_theme(theme)
            tz_value = _validate_timezone(timezone)
            retention_value = _clamp_retention(retention_days)
        except ValueError as exc:
            self.loadError.emit(str(exc))
            return

        try:
            with get_session() as session:
                row = session.get(AppSettings, 1) or AppSettings(id=1)
                row.theme = theme_value
                row.system_timezone = tz_value
                row.data_retention_days = retention_value
                row.maintenance_mode = bool(maintenance)
                session.add(row)
                session.commit()
            self.theme = theme_value
            self.systemTimezone = tz_value
            self.dataRetentionDays = retention_value
            self.maintenanceMode = maintenance
            self.saved.emit()
        except Exception as exc:  # noqa: BLE001
            log.exception("SettingsController.save failed")
            self.loadError.emit(str(exc))
