import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qaterial 1.0 as Qaterial

import "../.."
import "../../components/common"

Rectangle {
    id: root
    property bool isDark: true
    property var detail: ({})

    radius: 12
    color: isDark ? "#09090b" : "#ffffff"
    clip: true

    Rectangle { 
        anchors.fill: parent; radius: 12; color: "transparent"; 
        border.width: 1; border.color: root.isDark ? "#27272a" : "#e4e4e7"; z: 10 
    }

    ColumnLayout {
        anchors.fill: parent; spacing: 0

        // Header
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 56
            color: "transparent"
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: root.isDark ? "#27272a" : "#f4f4f5" }
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 24; anchors.rightMargin: 24
                Qaterial.LabelBody1 { text: "Sensor Monitoring"; Layout.fillWidth: true; color: root.isDark ? "#fafafa" : "#18181b"; font.family: "Roboto"; font.pixelSize: 18; font.weight: Font.Medium }
                Qaterial.LabelCaption {
                    visible: !!(detail.catalogError && detail.catalogError.length > 0)
                    text: detail.catalogError || ""
                    color: "#f97316"
                    font.family: "Roboto"
                    font.pixelSize: 11
                }
                Qaterial.LabelCaption {
                    text: (detail.sensorList ? detail.sensorList.length : 0) + " Total Sensors"
                    color: root.isDark ? "#a1a1aa" : "#71717a"
                    font.family: "Roboto"
                    font.pixelSize: 12
                }
            }
        }

        // Table header
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 40
            color: root.isDark ? Qt.rgba(0.09,0.09,0.11,0.5) : "#fafafa"
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: root.isDark ? "#27272a" : "#e4e4e7" }
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 24; anchors.rightMargin: 24; spacing: 0
                SensorHeaderCell { text: "ID";     Layout.preferredWidth: 60; isDark: root.isDark }
                SensorHeaderCell { text: "SENSOR NAME"; Layout.fillWidth: true; isDark: root.isDark }
                SensorHeaderCell { text: "VALUE";  Layout.preferredWidth: 140; isDark: root.isDark }
                SensorHeaderCell { text: "STATUS"; Layout.preferredWidth: 120; isDark: root.isDark }
            }
        }

        // Table body (scrollable — same pattern as RecentEventsList)
        ListView {
            id: sensorListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: detail.sensorList
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }
            delegate: Rectangle {
                width: ListView.view.width; height: 48
                color: "transparent"

                readonly property string stype: (modelData.sensor_type || "").toUpperCase()
                readonly property bool isDigital: stype === "DI" || stype === "DO"
                readonly property string dstatus: modelData.display_status || ""
                readonly property bool hasValue: modelData.value !== null && modelData.value !== undefined

                function _alarmBadgeText() {
                    var at = modelData.alarm_type || ""
                    if (at === "min") return "MIN"
                    if (at === "max") return "MAX"
                    return "Alarm"
                }

                function _valueText() {
                    if (!hasValue) return "N/A"
                    if (isDigital)
                        return modelData.value >= 0.5 ? "ON" : "OFF"
                    return String(modelData.value)
                }

                HoverHighlight {
                    hovered: sMouse.containsMouse
                    isDark: root.isDark
                }

                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: root.isDark ? "#27272a" : "#f4f4f5" }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 24; anchors.rightMargin: 24; spacing: 0
                    Qaterial.LabelCaption {
                        Layout.preferredWidth: 60
                        text: String(modelData.sensor_id)
                        color: root.isDark ? "#a1a1aa" : "#71717a"
                        font.family: "Roboto Mono"; font.pixelSize: 12
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Qaterial.LabelBody2 {
                            Layout.fillWidth: true
                            text: modelData.name || modelData.type || ("Sensor " + modelData.sensor_id)
                            font.family: "Roboto"; font.pixelSize: 14; font.weight: Font.Medium
                            color: SensorPalette.colorForSensorId(
                                modelData.sensor_id,
                                SensorPalette.orderedSensorIds(root.detail.sensorList)
                            )
                            elide: Text.ElideRight
                        }
                        Qaterial.LabelCaption {
                            visible: modelData.sensor_type && modelData.sensor_type.length > 0
                            text: modelData.sensor_type
                            color: root.isDark ? "#71717a" : "#a1a1aa"
                            font.family: "Roboto"; font.pixelSize: 11
                        }
                    }
                    Item {
                        Layout.preferredWidth: 140
                        Layout.fillHeight: true
                        Qaterial.LabelBody2 {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: hasValue || !isDigital
                            text: _valueText()
                            color: (dstatus === "ALARM" || modelData.alarm) ? "#ef4444"
                                : (isDigital && hasValue && modelData.value >= 0.5 ? "#42A5F5"
                                    : (root.isDark ? "#fafafa" : "#18181b"))
                            font.family: isDigital ? "Roboto" : "Roboto"
                            font.pixelSize: 14
                            font.weight: (dstatus === "ALARM" || modelData.alarm) ? Font.Bold : Font.Normal
                        }
                        Qaterial.LabelCaption {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: hasValue && !isDigital && modelData.unit && modelData.unit.length > 0
                            anchors.left: parent.children[0].right
                            anchors.leftMargin: 4
                            text: modelData.unit
                            color: root.isDark ? "#71717a" : "#a1a1aa"
                            font.family: "Roboto"; font.pixelSize: 12
                        }
                        Qaterial.LabelCaption {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !hasValue
                            text: "N/A"
                            color: root.isDark ? "#52525b" : "#a1a1aa"
                            font.family: "Roboto"; font.pixelSize: 12
                        }
                    }
                    Item {
                        Layout.preferredWidth: 120
                        Layout.fillHeight: true
                        RowLayout {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4
                            Badge { visible: dstatus === "Inactive"; text: "Inactive"; badgeColor: "zinc"; isDark: root.isDark }
                            Badge { visible: dstatus === "ERR"; text: "ERR"; badgeColor: "red"; isDark: root.isDark }
                            Badge { visible: dstatus === "WAIT"; text: "WAIT"; badgeColor: "zinc"; isDark: root.isDark }
                            Badge { visible: dstatus === "Stale"; text: "Stale"; badgeColor: "amber"; isDark: root.isDark }
                            Badge { visible: dstatus === "Invalid"; text: "Invalid"; badgeColor: "zinc"; isDark: root.isDark }
                            Badge { visible: dstatus === "ALARM"; text: _alarmBadgeText(); badgeColor: "red"; isDark: root.isDark }
                            Badge { visible: dstatus === "OK"; text: "OK"; badgeColor: "green"; isDark: root.isDark }
                            Badge { visible: dstatus === "ON"; text: "ON"; badgeColor: "blue"; isDark: root.isDark }
                            Badge { visible: dstatus === "OFF"; text: "OFF"; badgeColor: "zinc"; isDark: root.isDark }
                        }
                    }
                }
                MouseArea { id: sMouse; anchors.fill: parent; hoverEnabled: true }
            }
        }
    }

    component SensorHeaderCell: Item {
        property string text: ""
        property bool isDark: true
        implicitHeight: 40
        Qaterial.LabelCaption {
            anchors.verticalCenter: parent.verticalCenter
            text: parent.text
            color: parent.isDark ? "#a1a1aa" : "#71717a"
            font.family: "Roboto"; font.pixelSize: 11; font.weight: Font.Medium; font.letterSpacing: 0.8
        }
    }
}
