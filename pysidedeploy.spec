[app]
title = CentralLogger
project_dir = .
input_file = src/central_logger/main.py
project_file =
icon =
exec_directory = deploy

[python]
python_path =
packages = Nuitka==2.5.4

[qt]
qml_files = src/central_logger/ui/main.qml,src/central_logger/ui/components,src/central_logger/ui/views
excluded_qml_plugins = QtCharts,QtQuick3D,QtSensors,QtTest,QtWebEngine
modules = Core,DBus,Gui,Network,OpenGL,Qml,QmlMeta,QmlModels,QmlWorkerScript,Quick,QuickControls2,QuickTemplates2,Widgets
plugins = accessiblebridge,egldeviceintegrations,generic,iconengines,imageformats,networkaccess,networkinformation,platforminputcontexts,platforms,platformthemes,qmllint,qmltooling,scenegraph,styles,tls,vectorimageformats

[nuitka]
mode = standalone
macos.permissions =
extra_args = --quiet --noinclude-qt-translations --enable-plugin=pyside6 --lto=no --nofollow-import-to=pytest,tests --include-data-dir=resources/native/windows=native/windows --include-qt-plugins=sensible

[buildozer]
mode =
