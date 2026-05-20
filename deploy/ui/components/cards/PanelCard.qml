import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "../.."
import "../common"
import components

/*
 * Shadcn-style panel — radius 12, zinc border, optional titled header.
 */
Rectangle {
    id: root

    property bool isDark: true
    property string title: ""
    property string subtitle: ""
    property string headerNote: ""
    property bool showHeader: title.length > 0
    property bool hoverable: false
    property string titleFontFamily: "Inter"
    property int bodyMargins: 0
    property bool clipBody: false
    property bool sizeBodyToContent: false

    default property alias content: bodySlot.data

    radius: 12
    color: Colors.surface(isDark)
    clip: clipBody

    HoverHighlight {
        anchors.fill: parent
        cornerRadius: 12
        hovered: root.hoverable && cardMouse.containsMouse
        isDark: root.isDark
        visible: root.hoverable
        z: 0
    }

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: "transparent"
        border.width: 1
        border.color: root.hoverable && cardMouse.containsMouse
            ? Colors.borderHover(root.isDark)
            : Colors.border(root.isDark)
        z: 10
        Behavior on border.color {
            ColorAnimation {
                duration: UiMotion.durationFast
                easing.type: UiMotion.easingOut
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            visible: root.showHeader
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? 56 : 0
            color: "transparent"

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: Colors.divider(root.isDark)
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 24
                anchors.rightMargin: 24

                UiLabel {
        textType: UiLabel.Body1
                    text: root.title
                    color: Colors.textPrimary(root.isDark)
                    font.family: root.titleFontFamily
                    font.pixelSize: 18
                    font.weight: Font.Medium
                    Layout.fillWidth: true
                }

                UiLabel {
        textType: UiLabel.Caption
                    visible: root.headerNote.length > 0
                    text: root.headerNote
                    color: "#f97316"
                    font.family: root.titleFontFamily
                    font.pixelSize: 11
                }

                UiLabel {
        textType: UiLabel.Caption
                    visible: root.subtitle.length > 0
                    text: root.subtitle
                    color: Colors.textSecondary(root.isDark)
                    font.family: root.titleFontFamily
                    font.pixelSize: 12
                }
            }
        }

        Item {
            id: bodySlot
            Layout.fillWidth: true
            Layout.fillHeight: !root.sizeBodyToContent
            Layout.preferredHeight: root.sizeBodyToContent ? childrenRect.height : 0
            Layout.margins: root.bodyMargins
        }
    }

    MouseArea {
        id: cardMouse
        anchors.fill: parent
        hoverEnabled: root.hoverable
        acceptedButtons: Qt.NoButton
        z: 5
    }
}
