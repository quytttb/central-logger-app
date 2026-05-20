import QtQuick
import QtQuick.Layouts
import Qaterial 1.0 as Qaterial

import "../../"
import "../../components/cards"

PanelCard {
    id: root

    property var detail: ({})

    title: "Device Overview"
    titleFontFamily: "Roboto"
    hoverable: false
    bodyMargins: 24
    sizeBodyToContent: true

    readonly property int _headerHeight: showHeader ? 56 : 0
    implicitHeight: _headerHeight + overviewGrid.implicitHeight + bodyMargins * 2

    GridLayout {
        id: overviewGrid
        width: parent.width
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

    component OverviewCell: ColumnLayout {
        property string label: ""
        property string value: ""
        property bool isMono: false
        property bool isDark: true

        Layout.fillWidth: true
        spacing: 4

        Qaterial.LabelCaption {
            text: parent.label
            color: Colors.textMuted(parent.isDark)
            font.family: "Roboto"
            font.pixelSize: 11
            font.weight: Font.Medium
            font.letterSpacing: 0.6
        }
        Qaterial.LabelBody2 {
            text: parent.value
            color: Colors.textPrimary(parent.isDark)
            font.family: parent.isMono ? "Roboto Mono" : "Roboto"
            font.pixelSize: 14
            font.weight: Font.Medium
        }
    }
}
