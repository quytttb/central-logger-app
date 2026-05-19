import QtQuick
import QtQuick.Layouts
import Qaterial 1.0 as Qaterial

Rectangle {
    id: root

    property bool isDark: true
    property var detail: ({})

    radius: 12
    color: isDark ? "#09090b" : "#ffffff"
    implicitHeight: gridCol.implicitHeight + 48

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: "transparent"
        border.width: 1
        border.color: root.isDark ? "#27272a" : "#e4e4e7"
        z: 10
    }

    ColumnLayout {
        id: gridCol
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16

        Qaterial.LabelBody1 {
            text: "Device Overview"
            color: root.isDark ? "#fafafa" : "#18181b"
            font.family: "Roboto"
            font.pixelSize: 18
            font.weight: Font.Medium
        }

        GridLayout {
            Layout.fillWidth: true
            columns: root.width > 700 ? 3 : (root.width > 400 ? 2 : 1)
            columnSpacing: 24
            rowSpacing: 12

            OverviewCell { label: "Host / IP"; value: detail.host || "—"; isDark: root.isDark }
            OverviewCell { label: "Port"; value: detail.port !== undefined ? String(detail.port) : "—"; isDark: root.isDark }
            OverviewCell { label: "Unit ID"; value: detail.unitId !== undefined ? String(detail.unitId) : "—"; isDark: root.isDark }
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
            }
            OverviewCell {
                label: "Note"
                value: (detail.note && detail.note.length > 0) ? detail.note : "—"
                isDark: root.isDark
            }
        }
    }

    component OverviewCell: ColumnLayout {
        property string label: ""
        property string value: ""
        property bool isMono: false
        property bool isDark: true

        Layout.fillWidth: true
        spacing: 4

        Qaterial.LabelCaption {
            text: parent.label
            color: parent.isDark ? "#71717a" : "#a1a1aa"
            font.family: "Roboto"
            font.pixelSize: 11
            font.weight: Font.Medium
            font.letterSpacing: 0.6
        }
        Qaterial.LabelBody2 {
            text: parent.value
            color: parent.isDark ? "#fafafa" : "#18181b"
            font.family: parent.isMono ? "Roboto Mono" : "Roboto"
            font.pixelSize: 14
            font.weight: Font.Medium
        }
    }
}
