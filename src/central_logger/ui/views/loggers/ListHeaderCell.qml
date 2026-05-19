import QtQuick
import Qaterial 1.0 as Qaterial

Item {
    id: root

    property string text: ""
    property int alignment: Text.AlignLeft
    property bool isDark: true

    implicitHeight: 44

    Qaterial.LabelCaption {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: root.alignment === Text.AlignRight ? undefined : parent.left
        anchors.right: root.alignment === Text.AlignRight ? parent.right : undefined
        text: root.text
        color: root.isDark ? "#a1a1aa" : "#71717a"
        font.family: "Roboto"
        font.pixelSize: 11
        font.weight: Font.Medium
        font.letterSpacing: 0.8
    }
}
