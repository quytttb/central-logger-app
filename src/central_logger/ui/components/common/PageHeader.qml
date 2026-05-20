import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qaterial 1.0 as Qaterial

import "../.."
import "."

/*
 * Page title + subtitle + optional primary action button.
 */
RowLayout {
    id: root

    property string title: ""
    property string subtitle: ""
    property bool isDark: true
    property string titleFontFamily: "Inter"
    property string actionText: ""
    property string actionIcon: ""

    signal actionClicked()

    spacing: 16

    ColumnLayout {
        spacing: 4
        Layout.fillWidth: root.actionText.length === 0

        Qaterial.LabelHeadline5 {
            text: root.title
            color: Colors.textPrimary(root.isDark)
            font.family: root.titleFontFamily
            font.pixelSize: 24
            font.weight: Font.Bold
        }
        Qaterial.LabelBody2 {
            visible: root.subtitle.length > 0
            text: root.subtitle
            color: Colors.textSecondary(root.isDark)
            font.family: root.titleFontFamily
            font.pixelSize: 14
        }
    }

    Item {
        Layout.fillWidth: true
        visible: root.actionText.length > 0
    }

    Rectangle {
        visible: root.actionText.length > 0
        Layout.preferredWidth: actionRow.implicitWidth + 32
        Layout.preferredHeight: 36
        radius: 6
        color: actionMouse.pressed ? Colors.primaryPressed(root.isDark)
            : actionMouse.containsMouse ? Colors.primaryHover(root.isDark)
            : Colors.primary(root.isDark)
        Behavior on color {
            ColorAnimation {
                duration: UiMotion.durationFast
                easing.type: UiMotion.easingOut
            }
        }

        RowLayout {
            id: actionRow
            anchors.centerIn: parent
            spacing: 8
            Qaterial.Icon {
                visible: root.actionIcon.length > 0
                icon: root.actionIcon
                size: 16
                color: "#ffffff"
            }
            Qaterial.LabelBody2 {
                text: root.actionText
                color: "#ffffff"
                font.family: root.titleFontFamily
                font.pixelSize: 14
                font.weight: Font.Medium
            }
        }

        MouseArea {
            id: actionMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.actionClicked()
        }
    }
}
