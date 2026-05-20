import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "../../"
import "../../components/common"
import "../../components/cards"
import components

PanelCard {
    id: root
    property var detail: ({})

    title: "Sensor Monitoring"
    titleFontFamily: "Roboto"
    headerNote: (detail.catalogError && detail.catalogError.length > 0) ? detail.catalogError : ""
    subtitle: (detail.sensorList ? detail.sensorList.length : 0) + " Total Sensors"
    clipBody: true

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            color: Colors.surfaceSubtle(root.isDark)
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: Colors.border(root.isDark)
            }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 24
                anchors.rightMargin: 24
                spacing: 0
                TableHeaderCell { text: "ID"; rowHeight: 40; Layout.preferredWidth: 60; isDark: root.isDark }
                TableHeaderCell { text: "SENSOR NAME"; rowHeight: 40; Layout.fillWidth: true; isDark: root.isDark }
                TableHeaderCell { text: "VALUE"; rowHeight: 40; Layout.preferredWidth: 100; isDark: root.isDark }
                TableHeaderCell { text: "UNIT"; rowHeight: 40; Layout.preferredWidth: 72; isDark: root.isDark }
                TableHeaderCell { text: "STATUS"; rowHeight: 40; Layout.preferredWidth: 120; isDark: root.isDark }
            }
        }

        ListView {
            id: sensorListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            reuseItems: true
            boundsBehavior: Flickable.StopAtBounds
            model: detail.sensorList
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }
            delegate: ListRowDelegate {
                width: sensorListView.width
                height: 48
                isDark: root.isDark

                readonly property string stype: (modelData.sensor_type || "").toUpperCase()
                readonly property bool isDigital: stype === "DI" || stype === "DO"
                readonly property string dstatus: modelData.display_status || ""
                readonly property bool hasValue: modelData.value !== null && modelData.value !== undefined

                function _valueText() {
                    if (!hasValue) return "—"
                    if (isDigital)
                        return modelData.value >= 0.5 ? "ON" : "OFF"
                    return String(modelData.value)
                }

                function _unitText() {
                    if (isDigital) return "—"
                    if (hasValue && modelData.unit && modelData.unit.length > 0)
                        return modelData.unit
                    return "—"
                }

                RowLayout {
                    width: parent.width
                    height: 48
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 24
                    anchors.rightMargin: 24
                    spacing: 0
                    UiLabel {
        textType: UiLabel.Caption
                        Layout.preferredWidth: 60
                        text: String(modelData.sensor_id)
                        color: Colors.textSecondary(root.isDark)
                        font.family: "Roboto Mono"
                        font.pixelSize: 12
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        UiLabel {
        textType: UiLabel.Body2
                            Layout.fillWidth: true
                            text: modelData.name || modelData.type || ("Sensor " + modelData.sensor_id)
                            font.family: "Roboto"
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            color: SensorPalette.colorForSensorId(
                                modelData.sensor_id,
                                SensorPalette.orderedSensorIds(root.detail.sensorList)
                            )
                            elide: Text.ElideRight
                        }
                        UiLabel {
        textType: UiLabel.Caption
                            visible: modelData.sensor_type && modelData.sensor_type.length > 0
                            text: modelData.sensor_type
                            color: Colors.textMuted(root.isDark)
                            font.family: "Roboto"
                            font.pixelSize: 11
                        }
                    }
                    UiLabel {
        textType: UiLabel.Body2
                        Layout.preferredWidth: 100
                        text: _valueText()
                        color: (dstatus === "ALARM" || modelData.alarm)
                            ? Colors.destructiveHover(root.isDark)
                            : (isDigital && hasValue && modelData.value >= 0.5
                                ? Colors.badgeText(root.isDark, "blue")
                                : Colors.textPrimary(root.isDark))
                        font.family: "Roboto"
                        font.pixelSize: 14
                        font.weight: (dstatus === "ALARM" || modelData.alarm) ? Font.Bold : Font.Normal
                    }
                    UiLabel {
        textType: UiLabel.Caption
                        Layout.preferredWidth: 72
                        text: _unitText()
                        color: Colors.textMuted(root.isDark)
                        font.family: "Roboto"
                        font.pixelSize: 12
                    }
                    Item {
                        Layout.preferredWidth: 120
                        Layout.fillHeight: true
                        SensorStatusBadge {
                            anchors.verticalCenter: parent.verticalCenter
                            status: dstatus
                            alarmType: modelData.alarm_type || ""
                            isDark: root.isDark
                        }
                    }
                }
            }
        }
    }
}
