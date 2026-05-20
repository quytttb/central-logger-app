import QtQuick
import QtQuick.Layouts
import Qaterial 1.0 as Qaterial

import "../.."

Qaterial.LabelCaption {
    Layout.fillWidth: true
    property bool isDark: true
    color: Colors.textMuted(isDark)
    font.family: "Inter"
    font.pixelSize: 11
    font.weight: Font.DemiBold
    font.letterSpacing: 1.2
}
