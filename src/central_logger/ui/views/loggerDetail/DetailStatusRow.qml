import QtQuick
import QtQuick.Layouts
import Qaterial 1.0 as Qaterial

import "../../components/common"

RowLayout {
    property string label: ""
    property string badgeText: ""
    property string badgeColor: "zinc"
    property bool isDark: true

    Layout.fillWidth: true
    Layout.preferredHeight: 32

    Qaterial.LabelBody2 {
        text: parent.label
        Layout.fillWidth: true
        color: parent.isDark ? "#a1a1aa" : "#71717a"
        font.family: "Roboto"
        font.pixelSize: 14
    }
    Badge {
        text: parent.badgeText
        badgeColor: parent.badgeColor
        isDark: parent.isDark
    }
}
