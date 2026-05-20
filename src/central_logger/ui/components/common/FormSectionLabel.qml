import QtQuick
import QtQuick.Layouts

import "../.."
import components

UiLabel {
    textType: UiLabel.Caption
    Layout.fillWidth: true
    property bool isDark: true
    color: Colors.textMuted(isDark)
    font.family: "Inter"
    font.pixelSize: 11
    font.weight: Font.DemiBold
    font.letterSpacing: 1.2
}
