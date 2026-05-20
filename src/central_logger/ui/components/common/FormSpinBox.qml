import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material

import "../.."
import components

/*
 * SpinBox styled like LabeledField — surfaceMuted field, visible step buttons.
 */
SpinBox {
    id: control

    property bool isDark: true

    implicitHeight: 40
    implicitWidth: 160

    Material.theme: control.isDark ? Material.Dark : Material.Light
    Material.accent: Colors.primary(control.isDark)

    background: Rectangle {
        implicitWidth: control.implicitWidth
        implicitHeight: 40
        radius: 6
        color: Colors.surfaceMuted(control.isDark)
        border.width: 1
        border.color: control.activeFocus
            ? Colors.primary(control.isDark)
            : Colors.border(control.isDark)
    }

    contentItem: TextInput {
        z: 2
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        text: control.textFromValue(control.value, control.locale)
        font.family: "Roboto"
        font.pixelSize: 14
        color: Colors.textPrimary(control.isDark)
        selectionColor: Colors.primary(control.isDark)
        selectedTextColor: "#ffffff"
        horizontalAlignment: Qt.AlignLeft
        verticalAlignment: Qt.AlignVCenter
        readOnly: !control.editable
        validator: control.validator
        inputMethodHints: Qt.ImhFormattedNumbersOnly
    }

    up.indicator: Rectangle {
        x: control.mirrored ? 0 : parent.width - width
        height: parent.height
        implicitWidth: 32
        implicitHeight: 40
        radius: 6
        color: control.up.pressed
            ? Colors.buttonSecondaryPressed(control.isDark)
            : (control.up.hovered ? Colors.buttonSecondaryHover(control.isDark) : "transparent")
        Text {
            anchors.centerIn: parent
            text: "+"
            font.pixelSize: 16
            font.weight: Font.Medium
            color: Colors.textSecondary(control.isDark)
        }
    }

    down.indicator: Rectangle {
        x: control.mirrored ? parent.width - width : 0
        height: parent.height
        implicitWidth: 32
        implicitHeight: 40
        radius: 6
        color: control.down.pressed
            ? Colors.buttonSecondaryPressed(control.isDark)
            : (control.down.hovered ? Colors.buttonSecondaryHover(control.isDark) : "transparent")
        Text {
            anchors.centerIn: parent
            text: "\u2212"
            font.pixelSize: 16
            font.weight: Font.Medium
            color: Colors.textSecondary(control.isDark)
        }
    }
}
