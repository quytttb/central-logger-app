import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qaterial 1.0 as Qaterial

ColumnLayout {
    id: root
    property string label: ""
    property string value: ""
    property bool isDark: true

    readonly property alias text: input.text

    Layout.fillWidth: true
    spacing: 8

    Qaterial.LabelBody2 {
        text: root.label
        color: root.isDark ? "#fafafa" : "#18181b"
        font.family: "Roboto"
        font.pixelSize: 14
        font.weight: Font.Medium
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 40
        radius: 6
        color: root.isDark ? "#18181b" : "#fafafa"
        border.width: 1
        border.color: root.isDark ? "#27272a" : "#d4d4d8"

        TextField {
            id: input
            anchors.fill: parent
            anchors.margins: 4
            text: root.value
            font.family: "Roboto"
            font.pixelSize: 14
            color: root.isDark ? "#fafafa" : "#18181b"
            background: null
            verticalAlignment: TextInput.AlignVCenter
            leftPadding: 8
            onTextChanged: root.value = text
        }
    }
}
