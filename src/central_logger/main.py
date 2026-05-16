"""Entry point cho Central Logger App.

Khởi tạo QApplication (cần cho QSystemTrayIcon), đăng ký QML types qua import
central_logger.viewmodels (decorators chạy khi import), nạp Material Light từ
qtquickcontrols2.conf, và load qml/main.qml.
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

from PySide6.QtCore import QCoreApplication, QUrl
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuickControls2 import QQuickStyle
from PySide6.QtWidgets import QApplication

from central_logger.qml_import_paths import prepare_qaterial_shared_library, qaterial_import_candidates

# libQaterial must load after Qt from PySide6 is in the process (see qml_import_paths).
prepare_qaterial_shared_library(PROJECT_ROOT)

# Đăng ký các QML types (decorator @QmlElement, @QmlSingleton kích hoạt khi import)
from central_logger.controllers import DashboardController  # noqa: F401
from central_logger.system_tray import SystemTrayBridge
from central_logger.viewmodels import AppState, LoggerListModel  # noqa: F401


def _resolve_resources_root() -> Path:
    """Trả về thư mục resources/ (chứa qtquickcontrols2.conf, qml/...)."""
    return PROJECT_ROOT / "resources"


def _resolve_qml_root() -> Path:
    return PROJECT_ROOT / "qml"


def main() -> int:
    if os.environ.get("CENTRAL_LOGGER_DEBUG"):
        logging.basicConfig(
            level=logging.DEBUG,
            format="%(asctime)s %(levelname)s %(name)s: %(message)s",
        )

    QCoreApplication.setOrganizationName("CentralLogger")
    QCoreApplication.setApplicationName("Central Logger App")

    # High-DPI: Qt 6 mặc định đã bật; chỉ override rounding policy nếu cần.
    os.environ.setdefault("QT_SCALE_FACTOR_ROUNDING_POLICY", "PassThrough")

    # Trỏ tới qtquickcontrols2.conf của project (Material Light)
    conf_path = _resolve_resources_root() / "qtquickcontrols2.conf"
    if conf_path.exists():
        os.environ["QT_QUICK_CONTROLS_CONF"] = str(conf_path)

    app = QApplication(sys.argv)
    QQuickStyle.setStyle("Material")

    engine = QQmlApplicationEngine()
    # QML identifier `SystemTray` resolves to null in bindings on this stack; use `TrayCtl`.
    tray_bridge = SystemTrayBridge(engine)
    engine.rootContext().setContextProperty("TrayCtl", tray_bridge)

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

    tray_bridge.attach_window(roots[0])

    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
