import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qaterial 1.0 as Qaterial
import CentralLogger.Core 1.0

import "../../"
import "../../components/common"
import "../../components/cards"
import "../../components/dialogs"

/*
 * Loggers list page — Shadcn style tabular view.
 */
Item {
    id: view

    property bool isDark: Qaterial.Style.theme === Qaterial.Style.Theme.Dark
    property LoggerListModel loggersModel: null
    property DashboardController dashboardController: null
    property string searchQuery: ""

    signal selectLogger(int loggerId)

    function _matchesSearch(name, host) {
        if (!view.searchQuery) return true
        var q = view.searchQuery.toLowerCase()
        return (name || "").toLowerCase().indexOf(q) >= 0
            || (host || "").toLowerCase().indexOf(q) >= 0
    }

    Flickable {
        anchors.fill: parent
        contentHeight: mainCol.implicitHeight + 64
        clip: true

        ColumnLayout {
            id: mainCol
            width: parent.width
            spacing: 24

            Item { Layout.preferredHeight: 8 }

            PageHeader {
                Layout.fillWidth: true
                Layout.leftMargin: 32
                Layout.rightMargin: 32
                isDark: view.isDark
                title: "Edge Loggers"
                subtitle: "Manage and monitor all connected endpoint devices."
                actionText: "Add Logger"
                actionIcon: Qaterial.Icons.plus
                onActionClicked: addLoggerDialog.open()
            }

            PanelCard {
                Layout.fillWidth: true
                Layout.leftMargin: 32
                Layout.rightMargin: 32
                Layout.preferredHeight: tableHeader.height + tableList.contentHeight + 2
                Layout.minimumHeight: 200
                isDark: view.isDark
                hoverable: false
                clipBody: true

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    Rectangle {
                        id: tableHeader
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        color: Colors.surfaceSubtle(view.isDark)
                        radius: 12

                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 12
                            color: parent.color
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 1
                            color: Colors.border(view.isDark)
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 24
                            anchors.rightMargin: 24
                            spacing: 0

                            ListHeaderCell { text: "LOGGER NAME / HOST"; isDark: view.isDark; Layout.preferredWidth: 300; Layout.fillWidth: true }
                            ListHeaderCell { text: "STATUS"; isDark: view.isDark; Layout.preferredWidth: 200 }
                            ListHeaderCell { text: "SENSORS"; isDark: view.isDark; Layout.preferredWidth: 100 }
                            ListHeaderCell { text: "LAST UPDATE"; isDark: view.isDark; Layout.preferredWidth: 120 }
                            ListHeaderCell { text: "ERRORS"; alignment: Text.AlignRight; isDark: view.isDark; Layout.preferredWidth: 240; Layout.fillWidth: true }
                        }
                    }

                    ListView {
                        id: tableList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        model: view.loggersModel
                        interactive: false
                        clip: true

                        delegate: LoggerTableRow {
                            width: tableList.width
                            loggerId: model.loggerId
                            name: model.name
                            host: model.host
                            port: model.port
                            unitId: model.unitId
                            online: model.online
                            polling: model.polling
                            rtuConnected: model.rtuConnected
                            anyAlarm: model.anyAlarm
                            sensorCount: model.sensorCount
                            lastUpdate: model.lastUpdate
                            lastError: model.lastError
                            isDark: view.isDark
                            visible: view._matchesSearch(model.name, model.host)
                            onClicked: view.selectLogger(model.loggerId)
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: (!view.loggersModel || view.loggersModel.rowCountValue === 0) ? 120 : 0
                        visible: !view.loggersModel || view.loggersModel.rowCountValue === 0
                        Qaterial.LabelBody2 {
                            anchors.centerIn: parent
                            text: "No loggers configured. Click \"Add Logger\" to get started."
                            color: Colors.textMuted(view.isDark)
                            font.family: "Roboto"
                            font.pixelSize: 14
                        }
                    }
                }
            }

            Item { Layout.preferredHeight: 32 }
        }
    }

    AddLoggerDialog {
        id: addLoggerDialog
        isDark: view.isDark
        dashboardController: view.dashboardController
        onAddRequested: function(d) {
            if (!view.dashboardController) return
            view.dashboardController.addLogger(
                d.name,
                d.host,
                d.port || 5020,
                d.unitId || 1,
                d.pollIntervalS || 2,
                d.apiPort || 8080,
                d.apiToken || "",
                true,
                d.timeoutS || 2.0,
                d.note || "",
                d.apiBaseUrl || ""
            )
            if (typeof window !== "undefined" && window && window.notify) {
                window.notify("Added logger: " + d.name, "success")
            }
        }
    }

    Connections {
        target: view.dashboardController
        ignoreUnknownSignals: true
        function onLoggerRemoved(id) {
            if (typeof window !== "undefined" && window && window.notify) {
                window.notify("Logger removed", "success")
            }
        }
    }
}
