import QtQuick
import QtQuick.Controls

import "../.."
import components

/*
 * Shadcn-style status badge — small rounded label.
 * Colors: "green", "blue", "amber", "red", "zinc"
 */
Rectangle {
    id: badge

    property string text: ""
    property string badgeColor: "zinc"
    property bool isDark: true

    implicitHeight: 22
    implicitWidth: lbl.implicitWidth + 16
    radius: 4

    color: Colors.badgeFill(isDark, badgeColor)
    border.width: 1
    border.color: Colors.badgeBorder(isDark, badgeColor)

    UiLabel {
        textType: UiLabel.Caption
        id: lbl
        anchors.centerIn: parent
        text: badge.text
        font.family: "Roboto"
        font.pixelSize: 11
        font.weight: Font.Medium
        color: Colors.badgeText(badge.isDark, badge.badgeColor)
    }
}
