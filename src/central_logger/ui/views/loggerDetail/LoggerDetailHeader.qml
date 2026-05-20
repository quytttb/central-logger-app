import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qaterial 1.0 as Qaterial

import "../../"
import "../../components/common"

Rectangle {
    id: root

    property bool isDark: true
    property var detail: ({})
    signal goBack()
    signal editClicked()
    signal deleteClicked()

    implicitHeight: 72
    color: isDark ? Qt.rgba(0.035, 0.035, 0.043, 0.9) : Qt.rgba(0.98, 0.98, 0.98, 0.9)

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: isDark ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(0, 0, 0, 0.06)
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        spacing: 16

        Rectangle {
            width: 36
            height: 36
            radius: 6
            color: "transparent"
            HoverHighlight {
                anchors.fill: parent
                cornerRadius: 6
                hovered: backMouse.containsMouse
                isDark: root.isDark
            }
            Qaterial.Icon {
                anchors.centerIn: parent
                icon: Qaterial.Icons.arrowLeft
                size: 20
                color: Colors.textSecondary(root.isDark)
            }
            MouseArea {
                id: backMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.goBack()
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Qaterial.LabelHeadline5 {
                text: detail.loggerName
                color: Colors.textPrimary(root.isDark)
                font.family: "Inter"
                font.pixelSize: 24
                font.weight: Font.Bold
            }
            Qaterial.LabelBody2 {
                text: detail.host + ":" + detail.port
                color: Colors.textSecondary(root.isDark)
                font.family: "Inter"
                font.pixelSize: 14
            }
        }

        Item { Layout.fillWidth: true }

        Rectangle {
            width: 36
            height: 36
            radius: 6
            color: "transparent"
            HoverHighlight {
                anchors.fill: parent
                cornerRadius: 6
                hovered: editMouse.containsMouse
                isDark: root.isDark
            }
            Qaterial.Icon {
                anchors.centerIn: parent
                icon: Qaterial.Icons.pencil
                size: 20
                color: Colors.textSecondary(root.isDark)
            }
            MouseArea {
                id: editMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.editClicked()
            }
            ToolTip.visible: editMouse.containsMouse
            ToolTip.text: "Edit Logger"
        }

        Rectangle {
            width: 36
            height: 36
            radius: 6
            color: "transparent"
            Rectangle {
                anchors.fill: parent
                radius: 6
                color: root.isDark ? "#450505" : "#fef2f2"
                opacity: delMouse.containsMouse ? 1.0 : 0.0
                Behavior on opacity {
                    NumberAnimation {
                        duration: UiMotion.durationFast
                        easing.type: UiMotion.easingOut
                    }
                }
            }
            Qaterial.Icon {
                anchors.centerIn: parent
                icon: Qaterial.Icons.trashCan
                size: 20
                color: delMouse.containsMouse ? "#ef4444" : Colors.textSecondary(root.isDark)
            }
            MouseArea {
                id: delMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.deleteClicked()
            }
            ToolTip.visible: delMouse.containsMouse
            ToolTip.text: "Delete Logger"
        }
    }
}
