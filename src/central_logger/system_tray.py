"""System tray bridge for QML: hide to tray, show, quit.

Requires QApplication (not QGuiApplication alone) for QSystemTrayIcon.
"""

from __future__ import annotations

import logging

from PySide6.QtCore import Property, QCoreApplication, QObject, Slot
from PySide6.QtGui import QIcon
from PySide6.QtWidgets import QApplication, QMenu, QSystemTrayIcon

from central_logger.app_paths import resolve_logo_path

logger = logging.getLogger(__name__)


class SystemTrayBridge(QObject):
    """Exposed to QML as `TrayCtl` (see main.py); hide / show / quit slots."""

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._window: QObject | None = None
        self._tray: QSystemTrayIcon | None = None
        self._available = QSystemTrayIcon.isSystemTrayAvailable()

    @Property(bool, constant=True)  # type: ignore[misc]
    def trayAvailable(self) -> bool:
        return self._available

    def attach_window(self, window: QObject) -> None:
        """Bind the QML root window after QQmlApplicationEngine.load()."""
        self._window = window
        if self._available:
            self._ensure_tray()

    def _resolve_icon(self) -> QIcon:
        logo = resolve_logo_path()
        if logo.is_file():
            icon = QIcon(str(logo))
            if not icon.isNull():
                return icon
        logger.debug("Falling back to themed icon for system tray")
        app = QApplication.instance()
        if app is not None:
            from PySide6.QtWidgets import QStyle

            return app.style().standardIcon(QStyle.StandardPixmap.SP_ComputerIcon)
        return QIcon()

    def _ensure_tray(self) -> None:
        if not self._available or self._tray is not None:
            return
        tray = QSystemTrayIcon(self)
        tray.setIcon(self._resolve_icon())
        tray.setToolTip("Central Logger")

        menu = QMenu()
        act_show = menu.addAction("Show")
        act_show.triggered.connect(self.showFromTray)
        menu.addSeparator()
        act_quit = menu.addAction("Quit")
        act_quit.triggered.connect(self.quitApp)
        tray.setContextMenu(menu)

        tray.activated.connect(self._on_tray_activated)
        self._tray = tray

    def _on_tray_activated(self, reason: QSystemTrayIcon.ActivationReason) -> None:
        if reason in (
            QSystemTrayIcon.ActivationReason.Trigger,
            QSystemTrayIcon.ActivationReason.DoubleClick,
        ):
            self.showFromTray()

    @Slot()
    def hideToTray(self) -> None:
        if not self._available or self._window is None:
            return
        self._ensure_tray()
        if self._tray is None:
            return
        self._tray.setVisible(True)
        self._window.hide()
        self._tray.showMessage(
            "Central Logger",
            "Running in the background.",
            QSystemTrayIcon.MessageIcon.Information,
            2500,
        )

    @Slot()
    def showFromTray(self) -> None:
        w = self._window
        if w is None:
            return
        if hasattr(w, "isMinimized") and w.isMinimized() and hasattr(w, "showNormal"):
            w.showNormal()
        w.show()
        w.raise_()
        w.requestActivate()

    @Slot()
    def quitApp(self) -> None:
        if self._tray is not None:
            self._tray.hide()
        QCoreApplication.quit()
