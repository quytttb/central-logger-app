import QtQuick
import Qaterial 1.0 as Qaterial

import "../.."

Item {
    id: root

    property string text: ""
    property int alignment: Text.AlignLeft
    property bool isDark: true
    property int rowHeight: 44

    implicitHeight: rowHeight

    Qaterial.LabelCaption {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: root.alignment === Text.AlignRight ? undefined : parent.left
        anchors.right: root.alignment === Text.AlignRight ? parent.right : undefined
        text: root.text
        color: Colors.textSecondary(root.isDark)
        font.family: "Roboto"
        font.pixelSize: 11
        font.weight: Font.Medium
        font.letterSpacing: 0.8
    }
}
