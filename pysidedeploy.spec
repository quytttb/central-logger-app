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
qml_files = qml/main.qml,qml/components,qml/pages,qml/modules
excluded_qml_plugins = QtCharts,QtQuick3D,QtSensors,QtTest,QtWebEngine
modules = Core,Gui,Qml,Quick,QuickControls2

[nuitka]
mode = standalone
macos.permissions =
extra_args = --quiet --noinclude-qt-translations --enable-plugin=pyside6 --lto=yes

[buildozer]
mode =
