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

# Qaterial: keep vendor/qaterial-install/lib on LD_LIBRARY_PATH; load libQaterial.so only
# after PySide6 (see prepare_qaterial_shared_library) so Qt resolves from the wheel.
PROJECT_ROOT = Path(__file__).resolve().parents[2]
from central_logger.qml_import_paths import bootstrap_qaterial_library_path

bootstrap_qaterial_library_path(PROJECT_ROOT)

from PySide6.QtCore import QCoreApplication, QtMsgType, QUrl, qInstallMessageHandler
from PySide6.QtGui import QFont, QIcon
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuickControls2 import QQuickStyle
from PySide6.QtWidgets import QApplication

from central_logger.qml_import_paths import prepare_qaterial_shared_library, qaterial_import_candidates

# libQaterial must load after Qt from PySide6 is in the process (see qml_import_paths).
prepare_qaterial_shared_library(PROJECT_ROOT)

# Đăng ký các QML types (decorator @QmlElement, @QmlSingleton kích hoạt khi import)
from central_logger.controllers import DashboardController, SettingsController  # noqa: F401
from central_logger.db import init_db
from central_logger.system_tray import SystemTrayBridge
from central_logger.viewmodels import AppState, LoggerListModel  # noqa: F401


def _resolve_resources_root() -> Path:
    """Trả về thư mục resources/ (chứa qtquickcontrols2.conf, ...)."""
    return PROJECT_ROOT / "resources"


def _resolve_qml_root() -> Path:
    return Path(__file__).resolve().parent / "ui"


def _resolve_logo_path() -> Path:
    return _resolve_resources_root() / "images" / "4M Technologies Blue.svg"


def _load_app_icon() -> QIcon:
    """Window / taskbar icon from brand logo (SVG)."""
    logo_path = _resolve_logo_path()
    if logo_path.is_file():
        icon = QIcon(str(logo_path))
        if not icon.isNull():
            return icon
    return QIcon()


_FONT_FILES = (
    "Lato/Lato-Regular.ttf",
    "Roboto/Roboto-Regular.ttf",
    "Roboto/Roboto-Medium.ttf",
    "RobotoMono/RobotoMono-Regular.ttf",
)


def _load_application_fonts() -> None:
    """Register UI fonts from resources/fonts/ (or :/fonts/ when embedded via qrc)."""
    from PySide6.QtGui import QFontDatabase

    fonts_dir = _resolve_resources_root() / "fonts"
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
    """Drop Qaterial/Qt warnings about `enabled` shadowing Control.enabled."""

    def _handler(mode: QtMsgType, _context: object, message: str) -> None:
        if "overrides a member of the base object" in message:
            return
        if message.startswith("Load font ") and "Qaterial/Fonts" in message:
            return
        if mode in (QtMsgType.QtInfoMsg, QtMsgType.QtWarningMsg, QtMsgType.QtCriticalMsg, QtMsgType.QtFatalMsg):
            print(message, file=sys.stderr, flush=True)

    qInstallMessageHandler(_handler)


def main() -> int:
    if os.environ.get("CENTRAL_LOGGER_DEBUG"):
        logging.basicConfig(
            level=logging.DEBUG,
            format="%(asctime)s %(levelname)s %(name)s: %(message)s",
        )

    # Im lặng các thông báo "Failed to connect [Errno 111]..." spam từ pymodbus
    # khi logger đích offline; chúng ta đã có warning gọn của riêng mình
    # (`connect failed ...`) ở `LoggerModbusClient.connect`.
    logging.getLogger("pymodbus").setLevel(logging.CRITICAL)
    logging.getLogger("pymodbus.client").setLevel(logging.CRITICAL)
    logging.getLogger("pymodbus.transport").setLevel(logging.CRITICAL)

    QCoreApplication.setOrganizationName("CentralLogger")
    QCoreApplication.setApplicationName("Central Logger App")

    # High-DPI: Qt 6 mặc định đã bật; chỉ override rounding policy nếu cần.
    os.environ.setdefault("QT_SCALE_FACTOR_ROUNDING_POLICY", "PassThrough")

    _install_qml_property_shadow_log_filter()

    # Trỏ tới qtquickcontrols2.conf của project (Material Light)
    conf_path = _resolve_resources_root() / "qtquickcontrols2.conf"
    if conf_path.exists():
        os.environ["QT_QUICK_CONTROLS_CONF"] = str(conf_path)

    app = QApplication(sys.argv)
    QQuickStyle.setStyle("Material")
    _load_application_fonts()

    app_font = QFont("Roboto", 10)
    app.setFont(app_font)

    # Tạo các bảng DB trước khi QML khởi tạo controller/view —
    # các view chart/event sẽ query ngay khi Component.onCompleted chạy.
    init_db()

    engine = QQmlApplicationEngine()
    # QML identifier `SystemTray` resolves to null in bindings on this stack; use `TrayCtl`.
    tray_bridge = SystemTrayBridge(engine)
    engine.rootContext().setContextProperty("TrayCtl", tray_bridge)

    logo_path = _resolve_logo_path()
    engine.rootContext().setContextProperty(
        "logoUrl",
        QUrl.fromLocalFile(str(logo_path)) if logo_path.is_file() else QUrl(),
    )

    app_icon = _load_app_icon()
    if not app_icon.isNull():
        app.setWindowIcon(app_icon)

    # Cho phép `import CentralLogger.Core` (Python QML modules).
    qml_root = _resolve_qml_root()
    engine.addImportPath(str(qml_root))

    # Optional: Qaterial (after `scripts/fetch_qaterial.sh` + `scripts/build_qaterial.sh`
    # or set QATERIAL_QML_PATH to the parent of the `Qaterial` folder).
    for path in qaterial_import_candidates(PROJECT_ROOT):
        engine.addImportPath(str(path))

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
