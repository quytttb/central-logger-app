import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qaterial 1.0 as Qaterial

import "../../"
import "../../components/common"

ListRowDelegate {
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

    clickable: true
    width: ListView.view ? ListView.view.width : implicitWidth
    height: 64

    RowLayout {
        width: parent.width
        height: 64
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        spacing: 0

        RowLayout {
            Layout.preferredWidth: 300
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                width: 32; height: 32; radius: 16
                color: Colors.buttonSecondary(root.isDark)
                Qaterial.Icon {
                    anchors.centerIn: parent
                    icon: Qaterial.Icons.chip
                    size: 16
                    color: root.online ? Colors.primary(root.isDark) : Colors.textMuted(root.isDark)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Qaterial.LabelBody2 {
                    text: root.name
                    color: Colors.textPrimary(root.isDark)
                    font.family: "Roboto"
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Qaterial.LabelCaption {
                    text: root.host + ":" + root.port + " (Unit: " + root.unitId + ")"
                    color: Colors.textMuted(root.isDark)
                    font.family: "Roboto"
                    font.pixelSize: 12
                }
            }
        }

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

        Qaterial.LabelBody2 {
            Layout.preferredWidth: 100
            text: root.sensorCount + " sensors"
            color: Colors.textBody(root.isDark)
            font.family: "Roboto"
            font.pixelSize: 14
        }

        Qaterial.LabelBody2 {
            Layout.preferredWidth: 120
            text: root.lastUpdate !== "" ? root.lastUpdate : "Never"
            color: Colors.textSecondary(root.isDark)
            font.family: "Roboto"
            font.pixelSize: 14
        }

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
                    color: Colors.destructive(root.isDark)
                }
                Qaterial.LabelCaption {
                    text: root.lastError !== "" ? root.lastError : "None"
                    color: root.lastError !== ""
                        ? Colors.destructive(root.isDark)
                        : Colors.textMuted(root.isDark)
                    font.family: "Roboto"
                    font.pixelSize: 12
                    font.weight: root.lastError !== "" ? Font.Medium : Font.Normal
                    elide: Text.ElideRight
                    Layout.maximumWidth: 220
                }
            }
        }
    }
}
