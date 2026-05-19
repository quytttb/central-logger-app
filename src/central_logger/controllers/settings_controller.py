"""Controller cho `AppSettings` — load/save row id=1 và expose properties tới QML."""
from __future__ import annotations

import logging

from PySide6.QtCore import Property, QObject, Signal, Slot
from PySide6.QtQml import QmlElement

from central_logger.db import AppSettings, get_session, init_db
from central_logger.db.models import DEFAULT_SYSTEM_TIMEZONE

QML_IMPORT_NAME = "CentralLogger.Core"
QML_IMPORT_MAJOR_VERSION = 1

log = logging.getLogger(__name__)


@QmlElement
class SettingsController(QObject):
    """Bridge cho bảng `app_settings` (single-row config)."""

    themeChanged = Signal()
    systemTimezoneChanged = Signal()
    dataRetentionDaysChanged = Signal()
    defaultMapZoomChanged = Signal()
    maintenanceModeChanged = Signal()
    alertEmailContactsChanged = Signal()
    saved = Signal()
    loadError = Signal(str)

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._theme = "dark"
        self._timezone = "UTC"
        self._retention_days = 30
        self._map_zoom = 12
        self._maintenance = False
        self._emails = ""

    # ---------- properties ----------
    @Property(str, notify=themeChanged)
    def theme(self) -> str:
        return self._theme

    @theme.setter
    def theme(self, value: str) -> None:
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
        if self._retention_days != value:
            self._retention_days = int(value)
            self.dataRetentionDaysChanged.emit()

    @Property(int, notify=defaultMapZoomChanged)
    def defaultMapZoom(self) -> int:
        return self._map_zoom

    @defaultMapZoom.setter
    def defaultMapZoom(self, value: int) -> None:
        if self._map_zoom != value:
            self._map_zoom = int(value)
            self.defaultMapZoomChanged.emit()

    @Property(bool, notify=maintenanceModeChanged)
    def maintenanceMode(self) -> bool:
        return self._maintenance

    @maintenanceMode.setter
    def maintenanceMode(self, value: bool) -> None:
        if self._maintenance != bool(value):
            self._maintenance = bool(value)
            self.maintenanceModeChanged.emit()

    @Property(str, notify=alertEmailContactsChanged)
    def alertEmailContacts(self) -> str:
        return self._emails

    @alertEmailContacts.setter
    def alertEmailContacts(self, value: str) -> None:
        if self._emails != value:
            self._emails = value or ""
            self.alertEmailContactsChanged.emit()

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
                self.defaultMapZoom = row.default_map_zoom
                self.maintenanceMode = row.maintenance_mode
                self.alertEmailContacts = row.alert_email_contacts or ""
        except Exception as exc:  # noqa: BLE001
            log.exception("SettingsController.load failed")
            self.loadError.emit(str(exc))

    @Slot(str, str, int, int, bool, str)
    def save(
        self,
        theme: str,
        timezone: str,
        retention_days: int,
        map_zoom: int,
        maintenance: bool,
        emails: str,
    ) -> None:
        try:
            with get_session() as session:
                row = session.get(AppSettings, 1) or AppSettings(id=1)
                row.theme = theme or "dark"
                row.system_timezone = timezone or DEFAULT_SYSTEM_TIMEZONE
                row.data_retention_days = int(retention_days)
                row.default_map_zoom = int(map_zoom)
                row.maintenance_mode = bool(maintenance)
                row.alert_email_contacts = emails or ""
                session.add(row)
                session.commit()
            self.theme = theme
            self.systemTimezone = timezone
            self.dataRetentionDays = retention_days
            self.defaultMapZoom = map_zoom
            self.maintenanceMode = maintenance
            self.alertEmailContacts = emails
            self.saved.emit()
        except Exception as exc:  # noqa: BLE001
            log.exception("SettingsController.save failed")
            self.loadError.emit(str(exc))
