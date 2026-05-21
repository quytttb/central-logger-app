import QtQuick
import QtQuick.Layouts

import "../../"
import "../../components/cards"
import "../../components/common"
import components

PanelCard {
    id: root

    property var detail: ({})

    title: ""
    hoverable: false
    bodyMargins: 16
    sizeBodyToContent: true

    readonly property int gridColumns: width > 520 ? 4 : (width > 360 ? 2 : 1)
    implicitHeight: overviewGrid.implicitHeight + bodyMargins * 2

    GridLayout {
        id: overviewGrid
        width: parent.width
        columns: root.gridColumns
        columnSpacing: 20
        rowSpacing: 10

        OverviewCell {
            label: "Modbus port"
            value: detail.port !== undefined ? String(detail.port) : "—"
            isDark: root.isDark
        }
        OverviewCell {
            label: "REST port"
            value: detail.apiPort !== undefined ? String(detail.apiPort) : "8080"
            isDark: root.isDark
        }
        OverviewCell {
            label: "Unit ID"
            value: detail.unitId !== undefined ? String(detail.unitId) : "—"
            isDark: root.isDark
        }
        OverviewCell {
            label: "Poll interval"
            value: detail.configForm && detail.configForm.poll_interval
                ? (detail.configForm.poll_interval + " s")
                : (detail.pollIntervalS !== undefined ? (detail.pollIntervalS + " s") : "—")
            isDark: root.isDark
        }
        OverviewCell {
            label: "Station code"
            value: detail.configForm ? (detail.configForm.station_code || "—") : "—"
            isMono: true
            isDark: root.isDark
            Layout.columnSpan: Math.min(2, root.gridColumns)
        }
        Item {
            visible: root.gridColumns >= 4
            Layout.columnSpan: 2
            Layout.fillWidth: true
            Layout.preferredHeight: 0
        }
        OverviewStatusCell {
            label: "Connection"
            badgeText: detail.online ? "Online" : "Offline"
            badgeColor: detail.online ? "green" : "zinc"
            isDark: root.isDark
        }
        OverviewStatusCell {
            label: "Polling"
            badgeText: detail.polling ? "Active" : "Inactive"
            badgeColor: detail.polling ? "blue" : "zinc"
            isDark: root.isDark
        }
        OverviewStatusCell {
            label: "RTU"
            badgeText: detail.rtuConnected ? "Connected" : "Disconnected"
            badgeColor: detail.rtuConnected ? "blue" : "red"
            isDark: root.isDark
        }
        OverviewStatusCell {
            label: "Alarms"
            badgeText: detail.anyAlarm ? "Alarm" : "Clear"
            badgeColor: detail.anyAlarm ? "red" : "green"
            isDark: root.isDark
        }
    }

    component OverviewCell: ColumnLayout {
        property string label: ""
        property string value: ""
        property bool isMono: false
        property bool isDark: true

        Layout.fillWidth: true
        spacing: 2

        UiLabel {
            textType: UiLabel.Caption
            text: parent.label
            color: Colors.textMuted(parent.isDark)
            font.family: "Roboto"
            font.pixelSize: 13
            font.weight: Font.Medium
            font.letterSpacing: 0.5
        }
        UiLabel {
            textType: UiLabel.Body2
            text: parent.value
            color: Colors.textPrimary(parent.isDark)
            font.family: parent.isMono ? "Roboto Mono" : "Roboto"
            font.pixelSize: 16
            font.weight: Font.Medium
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }

    component OverviewStatusCell: ColumnLayout {
        property string label: ""
        property string badgeText: ""
        property string badgeColor: "zinc"
        property bool isDark: true

        Layout.fillWidth: true
        spacing: 2

        UiLabel {
            textType: UiLabel.Caption
            text: parent.label
            color: Colors.textMuted(parent.isDark)
            font.family: "Roboto"
            font.pixelSize: 13
            font.weight: Font.Medium
            font.letterSpacing: 0.5
        }
        Badge {
            text: parent.badgeText
            badgeColor: parent.badgeColor
            isDark: parent.isDark
        }
    }
}
