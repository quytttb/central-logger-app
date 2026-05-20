[app]
title = Central Logger App
project_dir = .
input_file = src/central_logger/main.py
project_file = 
icon = /home/haiquy/Documents/Projects/central-logger-app/.venv/lib/python3.14/site-packages/PySide6/scripts/deploy_lib/pyside_icon.jpg
exec_directory = .

[python]
python_path = /home/haiquy/Documents/Projects/central-logger-app/.venv/bin/python
packages = Nuitka==2.5.4

[qt]
qml_files = src/central_logger/ui/main.qml,src/central_logger/ui/components,src/central_logger/ui/views
excluded_qml_plugins = QtCharts,QtQuick3D,QtSensors,QtTest,QtWebEngine
modules = Core,DBus,Gui,Network,OpenGL,Qml,QmlMeta,QmlModels,QmlWorkerScript,Quick,QuickControls2,QuickTemplates2,Widgets
plugins = accessiblebridge,egldeviceintegrations,generic,iconengines,imageformats,networkaccess,networkinformation,platforminputcontexts,platforms,platforms/darwin,platformthemes,qmllint,qmltooling,scenegraph,styles,tls,vectorimageformats,wayland-decoration-client,wayland-graphics-integration-client,wayland-shell-integration,xcbglintegrations

[nuitka]
mode = standalone
macos.permissions = 
extra_args = --quiet --noinclude-qt-translations --enable-plugin=pyside6 --lto=no --nofollow-import-to=pytest,tests --include-data-dir=resources/native/windows=native/windows --include-qt-plugins=sensible

[buildozer]
mode = 

