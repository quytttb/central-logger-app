import QtQuick

import "../.."
import components

Item {
    id: root

    property string text: ""
    property int alignment: Text.AlignLeft
    property bool isDark: true
    property int rowHeight: 44
    property int padH: 0

    implicitHeight: rowHeight

    UiLabel {
        textType: UiLabel.Caption
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: root.alignment === Text.AlignRight ? undefined : parent.left
        anchors.right: root.alignment === Text.AlignRight ? parent.right : undefined
        anchors.leftMargin: root.padH
        anchors.rightMargin: root.padH
        text: root.text
        color: Colors.textSecondary(root.isDark)
        font.family: "Roboto"
        font.pixelSize: 11
        font.weight: Font.Medium
        font.letterSpacing: 0.8
    }
}
