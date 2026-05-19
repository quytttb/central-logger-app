import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qaterial 1.0 as Qaterial
import CentralLogger.Core 1.0

import "../../"
import "../../components/dialogs"

/*
 * Loggers list page — Shadcn style tabular view.
 * Shows a table of all edge loggers. Click row → navigate to detail.
 */
Item {
    id: view

    property bool isDark: Qaterial.Style.theme === Qaterial.Style.Theme.Dark
    // Phải khai báo đúng kiểu — `property var` khiến ListView không bind role từ QAbstractListModel.
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

            // ── Page Header ──────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 32
                Layout.rightMargin: 32
                spacing: 16

                ColumnLayout {
                    spacing: 4

                    Qaterial.LabelHeadline5 {
                        text: "Edge Loggers"
                        color: view.isDark ? "#fafafa" : "#18181b"
                        font.family: "Inter"
                        font.pixelSize: 24
                        font.weight: Font.Bold
                    }
                    Qaterial.LabelBody2 {
                        text: "Manage and monitor all connected endpoint devices."
                        color: view.isDark ? "#a1a1aa" : "#71717a"
                        font.family: "Inter"
                        font.pixelSize: 14
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                Rectangle {
                    Layout.preferredWidth: addRow.implicitWidth + 32
                    Layout.preferredHeight: 36
                    radius: 6
                    property color addFill: addMouse.pressed ? "#2563eb"
                         : addMouse.containsMouse ? "#3b82f6"
                         : "#2563eb"
                    color: addFill
                    Behavior on color {
                        ColorAnimation {
                            duration: UiMotion.durationFast
                            easing.type: UiMotion.easingOut
                        }
                    }

                    RowLayout {
                        id: addRow
                        anchors.centerIn: parent
                        spacing: 8
                        Qaterial.Icon {
                            icon: Qaterial.Icons.plus
                            size: 16
                            color: "#ffffff"
                        }
                        Qaterial.LabelBody2 {
                            text: "Add Logger"
                            color: "#ffffff"
                            font.family: "Inter"
                            font.pixelSize: 14
                            font.weight: Font.Medium
                        }
                    }
                    MouseArea {
                        id: addMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: addLoggerDialog.open()
                    }
                }
            }

            // ── Logger Table ─────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 32
                Layout.rightMargin: 32
                Layout.preferredHeight: tableHeader.height + tableList.contentHeight + 2
                Layout.minimumHeight: 200
                radius: 12
                color: view.isDark ? "#09090b" : "#ffffff"
                clip: true

                // Overlay border to prevent children from painting over it
                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    color: "transparent"
                    border.width: 1
                    border.color: view.isDark ? "#27272a" : "#e4e4e7"
                    z: 10
                }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    // Table header
                    Rectangle {
                        id: tableHeader
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        color: view.isDark ? Qt.rgba(0.09,0.09,0.11,0.5) : "#fafafa"
                        radius: 12

                        // Square bottom corners for the header
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width; height: 12
                            color: parent.color
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width; height: 1
                            color: view.isDark ? "#27272a" : "#e4e4e7"
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 24
                            anchors.rightMargin: 24
                            spacing: 0

                            ListHeaderCell { text: "LOGGER NAME / HOST"; isDark: view.isDark; Layout.preferredWidth: 300; Layout.fillWidth: true }
                            ListHeaderCell { text: "STATUS";             isDark: view.isDark; Layout.preferredWidth: 200 }
                            ListHeaderCell { text: "SENSORS";            isDark: view.isDark; Layout.preferredWidth: 100 }
                            ListHeaderCell { text: "LAST UPDATE";        isDark: view.isDark; Layout.preferredWidth: 120 }
                            ListHeaderCell { text: "ERRORS"; alignment: Text.AlignRight; isDark: view.isDark; Layout.preferredWidth: 240; Layout.fillWidth: true }
                        }
                    }

                    // Table body
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

                    // Empty state — chỉ hiện khi model rỗng, không chồng lên bảng
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: (!view.loggersModel || view.loggersModel.rowCountValue === 0) ? 120 : 0
                        visible: !view.loggersModel || view.loggersModel.rowCountValue === 0
                        Qaterial.LabelBody2 {
                            anchors.centerIn: parent
                            text: "No loggers configured. Click \"Add Logger\" to get started."
                            color: view.isDark ? "#71717a" : "#a1a1aa"
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
