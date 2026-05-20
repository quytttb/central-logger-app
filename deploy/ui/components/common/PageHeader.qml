import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "../.."
import "."
import components

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
    property string iconName: ""

    signal actionClicked()

    spacing: 16

    ColumnLayout {
        spacing: 4
        Layout.fillWidth: root.actionText.length === 0

        UiLabel {
        textType: UiLabel.Headline5
            text: root.title
            color: Colors.textPrimary(root.isDark)
            font.family: root.titleFontFamily
            font.pixelSize: 24
            font.weight: Font.Bold
        }
        UiLabel {
        textType: UiLabel.Body2
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
            UiIcon {
                visible: root.iconName.length > 0
                name: root.iconName
                size: 16
                iconColor: "#ffffff"
            }
            UiLabel {
        textType: UiLabel.Body2
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
