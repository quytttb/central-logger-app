import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qaterial 1.0 as Qaterial

import "../.."

ColumnLayout {
    id: root

    property string label: ""
    property string value: ""
    property bool isDark: true
    property string fontFamily: "Roboto"
    property int labelPixelSize: 14
    property int inputPixelSize: 14
    property int inputHeight: 40
    property int labelSpacing: 8
    property bool isPassword: false
    property bool inputEnabled: true

    readonly property alias text: input.text

    Layout.fillWidth: true
    spacing: labelSpacing

    function setValue(v) {
        var s = v !== undefined && v !== null ? String(v) : ""
        value = s
        input.text = s
    }

    function clearFocus() {
        input.focus = false
    }

    Qaterial.LabelBody2 {
        text: root.label
        color: Colors.textPrimary(root.isDark)
        font.family: root.fontFamily
        font.pixelSize: root.labelPixelSize
        font.weight: Font.Medium
        opacity: root.inputEnabled ? 1.0 : 0.5
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: root.inputHeight
        radius: 6
        color: Colors.surfaceMuted(root.isDark)
        border.width: 1
        border.color: Colors.border(root.isDark)
        opacity: root.inputEnabled ? 1.0 : 0.5

        TextInput {
            id: input
            anchors.fill: parent
            anchors.margins: 4
            leftPadding: 8
            text: root.value
            font.family: root.fontFamily
            font.pixelSize: root.inputPixelSize
            color: Colors.textPrimary(root.isDark)
            verticalAlignment: TextInput.AlignVCenter
            echoMode: root.isPassword ? TextInput.Password : TextInput.Normal
            selectByMouse: true
            clip: true
            readOnly: !root.inputEnabled
            cursorVisible: root.inputEnabled && input.activeFocus
            onTextChanged: if (root.inputEnabled) root.value = text
        }
    }
}
