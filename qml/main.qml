import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qaterial 1.0 as Qaterial

import CentralLogger.Core 1.0
import "pages"
import "components"

Qaterial.ApplicationWindow {
    id: window
    width: 1440
    height: 880
    minimumWidth: 1100
    minimumHeight: 680
    visibility: Window.Maximized
    visible: true
    title: "Central Logger"
    flags: Qt.Window | Qt.FramelessWindowHint

    Component.onCompleted: {
        Qaterial.Style.theme = Qaterial.Style.Theme.Light
        Qaterial.Style.primaryColorLight = "#000666"
        Qaterial.Style.accentColorLight = "#4C56AF"
    }

    onClosing: function (close) {
        close.accepted = false
        TrayCtl.quitApp()
    }

    function notify(message, severity) {
        var t = severity === "error" ? 7000 : 4000
        Qaterial.SnackbarManager.show({ text: message, timeout: t })
    }

    property int activeTab: 0

    Qaterial.Drawer {
        id: navDrawer
        width: 280
        height: window.height
        edge: Qt.LeftEdge
        modal: true
        dim: true
        backgroundColor: "#1B2838"

        AppSidebar {
            anchors.fill: parent
            currentTab: window.activeTab
            onSelectTab: function (i) {
                window.activeTab = i
                navDrawer.close()
            }
        }
    }

    Item {
        id: contentRoot
        anchors.fill: parent

        ColumnLayout {
            id: contentColumn
            anchors.fill: parent
            spacing: 0

            AppTopBar {
                id: topBar
                Layout.fillWidth: true
                title: window.activeTab === 0 ? "Dashboard"
                     : (window.activeTab === 1 ? "Map View" : "Global Settings")
                onMenuRequested: navDrawer.open()
            }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: window.activeTab

                DashboardPage {
                    id: dashPage
                    onOpenDetailRequested: function (loggerId, name, host, port,
                                                    unitId, sensorCount,
                                                    online, polling, rtuConnected, anyAlarm) {
                        detailView.openFor(loggerId, name, host, port, unitId, sensorCount,
                                           online, polling, rtuConnected, anyAlarm)
                    }
                }

                Qaterial.Page {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Qaterial.LabelBody1 {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        text: "Map View — coming in a future release"
                    }
                }

                Qaterial.Page {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Qaterial.LabelBody1 {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        text: "Global Settings — coming in a future release"
                    }
                }
            }
        }

        LoggerDetailDialog {
            id: detailView
            anchors.fill: parent
            z: 10
            controllerRef: dashPage.dashController
        }

        Connections {
            target: dashPage.dashController
            ignoreUnknownSignals: true
            function onLoggerRemoved(id) {
                if (detailView.loggerId === id)
                    detailView.close()
            }
        }

        FrameResizeHandles {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.top: topBar.bottom
            z: 100
        }
    }
}
