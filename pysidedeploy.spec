; pysidedeploy.spec - cấu hình cho `pyside6-deploy` (Nuitka backend).
; Sinh tự động lần đầu chạy `pyside6-deploy src/central_logger/main.py`; commit lại để
; reproducible builds. Đây là TEMPLATE - chỉnh sau khi chạy thực tế trên Windows.

[app]
title = Central Logger App
project_dir = .
input_file = src/central_logger/main.py
project_file =
icon =
exec_directory = .

[python]
python_path = python
packages = Nuitka==2.5.4

[qt]
qml_files = src/central_logger/ui/main.qml,src/central_logger/ui/components,src/central_logger/ui/views
excluded_qml_plugins = QtCharts,QtQuick3D,QtSensors,QtTest,QtWebEngine
modules = Core,Gui,Qml,Quick,QuickControls2

[nuitka]
mode = standalone
macos.permissions =
; Bundle ZBar DLLs for QR scan on Windows (place files under resources/native/windows first).
extra_args = --quiet --noinclude-qt-translations --enable-plugin=pyside6 --lto=yes --include-data-dir=resources/native/windows=native/windows

[buildozer]
mode =
