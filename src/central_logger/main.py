"""Entry point cho Central Logger App.

Khởi tạo QApplication (cần cho QSystemTrayIcon), đăng ký QML types qua import
central_logger.viewmodels (decorators chạy khi import), nạp Material Light từ
qtquickcontrols2.conf, và load ui/main.qml.
"""

from __future__ import annotations

import logging
import os
import sys
from pathlib import Path

from PySide6.QtCore import QCoreApplication, QtMsgType, QUrl, qInstallMessageHandler
from PySide6.QtGui import QFont, QGuiApplication, QIcon
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuickControls2 import QQuickStyle
from PySide6.QtWidgets import QApplication

from central_logger.app_paths import resolve_logo_path, resolve_resources_root
from central_logger.controllers import DashboardController, SettingsController  # noqa: F401
from central_logger.db import init_db
from central_logger.system_tray import SystemTrayBridge
from central_logger.viewmodels import AppState, LoggerListModel, RecentEventsModel  # noqa: F401


def _resolve_qml_root() -> Path:
    return Path(__file__).resolve().parent / "ui"


def _load_app_icon() -> QIcon:
    """Window / taskbar icon from brand logo (SVG)."""
    logo_path = resolve_logo_path()
    if logo_path.is_file():
        icon = QIcon(str(logo_path))
        if not icon.isNull():
            return icon
    return QIcon()


_FONT_FILES = (
    "Roboto/Roboto-Regular.ttf",
    "Roboto/Roboto-Medium.ttf",
    "RobotoMono/RobotoMono-Regular.ttf",
    "MaterialSymbols/MaterialSymbolsOutlined.ttf",
)


def _load_application_fonts() -> None:
    """Register UI fonts from resources/fonts/ (or :/fonts/ when embedded via qrc)."""
    from PySide6.QtGui import QFontDatabase

    fonts_dir = resolve_resources_root() / "fonts"
    if fonts_dir.is_dir():
        for rel in _FONT_FILES:
            path = fonts_dir / rel
            if path.is_file():
                QFontDatabase.addApplicationFont(str(path))
        return

    try:
        import central_logger.resources_rc  # noqa: F401
    except ImportError:
        return

    for rel in _FONT_FILES:
        QFontDatabase.addApplicationFont(f":/fonts/{rel}")


def _install_qml_property_shadow_log_filter() -> None:
    """Drop Qt warnings about `enabled` shadowing Control.enabled."""

    def _handler(mode: QtMsgType, _context: object, message: str) -> None:
        if "overrides a member of the base object" in message:
            return
        if mode in (
            QtMsgType.QtInfoMsg,
            QtMsgType.QtWarningMsg,
            QtMsgType.QtCriticalMsg,
            QtMsgType.QtFatalMsg,
        ):
            print(message, file=sys.stderr, flush=True)

    qInstallMessageHandler(_handler)


def main() -> int:
    if os.environ.get("CENTRAL_LOGGER_DEBUG"):
        logging.basicConfig(
            level=logging.DEBUG,
            format="%(asctime)s %(levelname)s %(name)s: %(message)s",
        )

    logging.getLogger("pymodbus").setLevel(logging.CRITICAL)
    logging.getLogger("pymodbus.client").setLevel(logging.CRITICAL)
    logging.getLogger("pymodbus.transport").setLevel(logging.CRITICAL)

    QCoreApplication.setOrganizationName("CentralLogger")
    QCoreApplication.setApplicationName("Central Logger App")

    os.environ.setdefault("QT_SCALE_FACTOR_ROUNDING_POLICY", "PassThrough")

    _install_qml_property_shadow_log_filter()

    conf_path = resolve_resources_root() / "qtquickcontrols2.conf"
    if conf_path.exists():
        os.environ["QT_QUICK_CONTROLS_CONF"] = str(conf_path)

    app = QApplication(sys.argv)
    app.setApplicationDisplayName("Central Logger")
    if hasattr(QGuiApplication, "setDesktopFileName"):
        QGuiApplication.setDesktopFileName("central-logger")

    QQuickStyle.setStyle("Material")
    _load_application_fonts()

    app_font = QFont("Roboto", 10)
    app.setFont(app_font)

    init_db()

    engine = QQmlApplicationEngine()
    tray_bridge = SystemTrayBridge(engine)
    engine.rootContext().setContextProperty("TrayCtl", tray_bridge)

    logo_path = resolve_logo_path()
    engine.rootContext().setContextProperty(
        "logoUrl",
        QUrl.fromLocalFile(str(logo_path)) if logo_path.is_file() else QUrl(),
    )

    app_icon = _load_app_icon()
    if not app_icon.isNull():
        app.setWindowIcon(app_icon)

    qml_root = _resolve_qml_root()
    engine.addImportPath(str(qml_root))

    main_qml = qml_root / "main.qml"
    engine.load(QUrl.fromLocalFile(str(main_qml)))

    roots = engine.rootObjects()
    if not roots:
        return 1

    root_window = roots[0]
    if not app_icon.isNull() and hasattr(root_window, "setIcon"):
        root_window.setIcon(app_icon)

    tray_bridge.attach_window(root_window)

    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
