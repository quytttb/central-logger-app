import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qaterial 1.0 as Qaterial

import "../../components/common"

Rectangle {
    id: root

    property int loggerId: -1
    property string name: ""
    property string host: ""
    property int port: 0
    property int unitId: 0
    property bool online: false
    property bool polling: false
    property bool rtuConnected: false
    property bool anyAlarm: false
    property int sensorCount: 0
    property string lastUpdate: ""
    property string lastError: ""

    property bool isDark: true
    signal clicked()

    width: ListView.view ? ListView.view.width : implicitWidth
    height: 64
    color: "transparent"

    HoverHighlight {
        hovered: rowMouse.containsMouse
        isDark: root.isDark
    }

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width; height: 1
        color: root.isDark ? "#27272a" : "#f4f4f5"
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        spacing: 0

        // Name + Host cell
        RowLayout {
            Layout.preferredWidth: 300
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                width: 32; height: 32; radius: 16
                color: root.isDark ? "#27272a" : "#f4f4f5"
                Qaterial.Icon {
                    anchors.centerIn: parent
                    icon: Qaterial.Icons.chip
                    size: 16
                    color: root.online ? "#3b82f6" : "#71717a"
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Qaterial.LabelBody2 {
                    text: root.name
                    color: root.isDark ? "#fafafa" : "#18181b"
                    font.family: "Roboto"
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Qaterial.LabelCaption {
                    text: root.host + ":" + root.port + " (Unit: " + root.unitId + ")"
                    color: root.isDark ? "#71717a" : "#a1a1aa"
                    font.family: "Roboto"
                    font.pixelSize: 12
                }
            }
        }

        // Status badges
        RowLayout {
            Layout.preferredWidth: 200
            spacing: 6
            Badge {
                text: root.online ? "Online" : "Offline"
                badgeColor: root.online ? "green" : "zinc"
                isDark: root.isDark
            }
            Badge {
                text: root.rtuConnected ? "RTU Linked" : "RTU Fail"
                badgeColor: root.rtuConnected ? "blue" : "red"
                isDark: root.isDark
            }
        }

        // Sensors
        Qaterial.LabelBody2 {
            Layout.preferredWidth: 100
            text: root.sensorCount + " sensors"
            color: root.isDark ? "#d4d4d8" : "#3f3f46"
            font.family: "Roboto"
            font.pixelSize: 14
        }

        // Last Update
        Qaterial.LabelBody2 {
            Layout.preferredWidth: 120
            text: root.lastUpdate !== "" ? root.lastUpdate : "Never"
            color: root.isDark ? "#a1a1aa" : "#71717a"
            font.family: "Roboto"
            font.pixelSize: 14
        }

        // Errors
        Item {
            Layout.preferredWidth: 240
            Layout.fillWidth: true
            Layout.fillHeight: true

            RowLayout {
                anchors.fill: parent
                spacing: 4
                Item { Layout.fillWidth: true }
                Qaterial.Icon {
                    visible: root.lastError !== ""
                    icon: Qaterial.Icons.alertOutline
                    size: 12
                    color: "#ef4444"
                }
                Qaterial.LabelCaption {
                    text: root.lastError !== "" ? root.lastError : "None"
                    color: root.lastError !== ""
                        ? "#ef4444"
                        : (root.isDark ? "#71717a" : "#a1a1aa")
                    font.family: "Roboto"
                    font.pixelSize: 12
                    font.weight: root.lastError !== "" ? Font.Medium : Font.Normal
                    elide: Text.ElideRight
                    Layout.maximumWidth: 220
                }
            }
        }
    }

    MouseArea {
        id: rowMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
