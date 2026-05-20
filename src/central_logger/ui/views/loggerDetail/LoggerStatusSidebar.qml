import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import Qaterial 1.0 as Qaterial

import "../../"
import "../../components/cards"

PanelCard {
    id: root

    property var detail: ({})
    property var dashboardController: null
    property int loggerId: -1

    readonly property bool canDownloadReport: detail.online
        && dashboardController !== null
        && loggerId >= 0

    showHeader: false
    bodyMargins: 24
    implicitHeight: 520

    FileDialog {
        id: reportSaveDialog
        title: "Save report file"
        nameFilters: ["Text files (*.txt)"]
        onAccepted: {
            if (!root.dashboardController || root.loggerId < 0) return
            var path = selectedFile.toString()
            if (path.startsWith("file://"))
                path = path.substring(7)
            root.dashboardController.downloadLatestReport(root.loggerId, path)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Qaterial.LabelBody1 {
            text: "Status"
            color: Colors.textPrimary(root.isDark)
            font.family: "Roboto"
            font.pixelSize: 18
            font.weight: Font.Medium
        }
        Item { Layout.preferredHeight: 16 }
        DetailStatusRow {
            label: "Connection"
            badgeText: detail.online ? "Online" : "Offline"
            badgeColor: detail.online ? "green" : "zinc"
            isDark: root.isDark
        }
        DetailStatusRow {
            label: "Polling"
            badgeText: detail.polling ? "Active" : "Inactive"
            badgeColor: detail.polling ? "blue" : "zinc"
            isDark: root.isDark
        }
        DetailStatusRow {
            label: "RTU Status"
            badgeText: detail.rtuConnected ? "Connected" : "Disconnected"
            badgeColor: detail.rtuConnected ? "blue" : "red"
            isDark: root.isDark
        }

        Item { Layout.preferredHeight: 24 }
        Rectangle { Layout.fillWidth: true; height: 1; color: Colors.divider(root.isDark) }
        Item { Layout.preferredHeight: 24 }

        Qaterial.LabelBody1 {
            text: "Hardware Health"
            color: Colors.textPrimary(root.isDark)
            font.family: "Roboto"
            font.pixelSize: 18
            font.weight: Font.Medium
        }
        Item { Layout.preferredHeight: 16 }
        DetailStatusRow {
            label: "Active Alarms"
            badgeText: detail.anyAlarm ? "Alarm" : "Clear"
            badgeColor: detail.anyAlarm ? "red" : "green"
            isDark: root.isDark
        }
        DetailStatusRow {
            label: "Sensor Count"
            badgeText: (detail.sensorCount !== undefined ? detail.sensorCount : 0) + " sensors"
            badgeColor: "zinc"
            isDark: root.isDark
        }

        Item { Layout.preferredHeight: 24 }
        Rectangle { Layout.fillWidth: true; height: 1; color: Colors.divider(root.isDark) }
        Item { Layout.preferredHeight: 24 }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            radius: 6
            opacity: root.canDownloadReport ? 1.0 : 0.45
            color: dlMouse.containsMouse && root.canDownloadReport
                ? Colors.buttonSecondaryHover(root.isDark)
                : Colors.buttonSecondary(root.isDark)
            Qaterial.LabelBody2 {
                anchors.centerIn: parent
                text: "Download Report"
                color: Colors.textPrimary(root.isDark)
                font.family: "Roboto"
                font.pixelSize: 14
                font.weight: Font.Medium
            }
            MouseArea {
                id: dlMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: root.canDownloadReport ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    if (!root.canDownloadReport) return
                    reportSaveDialog.open()
                }
            }
            ToolTip.visible: dlMouse.containsMouse && !root.canDownloadReport
            ToolTip.text: "Logger must be online with API token configured"
        }

        Item { Layout.fillHeight: true }
    }
}
