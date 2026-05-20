import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "../.."
import components

/*
 * Dialog footer button — secondary (cancel), primary, or destructive.
 */
Rectangle {
    id: root

    property string text: ""
    property string iconName: ""
    property bool isDark: true
    property string variant: "secondary"  // secondary | primary | destructive

    signal clicked()

    implicitWidth: actionRow.implicitWidth + 32
    implicitHeight: 36
    radius: 6

    readonly property color _labelColor: (root.variant === "primary" || root.variant === "destructive")
        ? "#ffffff"
        : Colors.textBody(root.isDark)

    property color _fill: {
        if (variant === "primary") {
            if (btnMouse.pressed) return Colors.primaryPressed(isDark)
            if (btnMouse.containsMouse) return Colors.primaryHover(isDark)
            return Colors.primary(isDark)
        }
        if (variant === "destructive") {
            if (btnMouse.pressed) return Colors.destructivePressed(isDark)
            if (btnMouse.containsMouse) return Colors.destructiveHover(isDark)
            return Colors.destructive(isDark)
        }
        if (btnMouse.pressed) return Colors.buttonSecondaryPressed(isDark)
        if (btnMouse.containsMouse) return Colors.buttonSecondaryHover(isDark)
        return Colors.buttonSecondary(isDark)
    }

    color: _fill
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
            iconColor: root._labelColor
        }

        UiLabel {
            textType: UiLabel.Body2
            text: root.text
            color: root._labelColor
            font.family: "Inter"
            font.pixelSize: 14
            font.weight: Font.Medium
        }
    }

    MouseArea {
        id: btnMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
