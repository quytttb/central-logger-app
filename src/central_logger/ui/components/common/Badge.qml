import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qaterial 1.0 as Qaterial

/*
 * Shadcn-style status badge — small rounded label.
 * Colors: "green", "blue", "amber", "red", "zinc"
 */
Rectangle {
    id: badge

    property string text: ""
    property string badgeColor: "zinc"   // green | blue | amber | red | zinc
    property bool isDark: Qaterial.Style.theme === Qaterial.Style.Theme.Dark

    implicitHeight: 22
    implicitWidth: lbl.implicitWidth + 16
    radius: 4

    color: {
        if (isDark) {
            switch (badgeColor) {
            case "green": return Qt.rgba(0.22, 0.80, 0.31, 0.10)
            case "blue":  return Qt.rgba(0.23, 0.51, 0.96, 0.10)
            case "amber": return Qt.rgba(0.96, 0.66, 0.02, 0.10)
            case "red":   return Qt.rgba(0.94, 0.27, 0.24, 0.10)
            default:      return "#27272a"
            }
        } else {
            switch (badgeColor) {
            case "green": return "#dcfce7"
            case "blue":  return "#dbeafe"
            case "amber": return "#fef3c7"
            case "red":   return "#fee2e2"
            default:      return "#f4f4f5"
            }
        }
    }

    border.width: 1
    border.color: {
        if (isDark) {
            switch (badgeColor) {
            case "green": return Qt.rgba(0.22, 0.80, 0.31, 0.20)
            case "blue":  return Qt.rgba(0.23, 0.51, 0.96, 0.20)
            case "amber": return Qt.rgba(0.96, 0.66, 0.02, 0.20)
            case "red":   return Qt.rgba(0.94, 0.27, 0.24, 0.20)
            default:      return "#3f3f46"
            }
        } else {
            switch (badgeColor) {
            case "green": return "#bbf7d0"
            case "blue":  return "#bfdbfe"
            case "amber": return "#fde68a"
            case "red":   return "#fecaca"
            default:      return "#e4e4e7"
            }
        }
    }

    Qaterial.LabelCaption {
        id: lbl
        anchors.centerIn: parent
        text: badge.text
        font.family: "Roboto"
        font.pixelSize: 11
        font.weight: Font.Medium
        color: {
            if (badge.isDark) {
                switch (badge.badgeColor) {
                case "green": return "#4ade80"
                case "blue":  return "#60a5fa"
                case "amber": return "#fbbf24"
                case "red":   return "#f87171"
                default:      return "#d4d4d8"
                }
            } else {
                switch (badge.badgeColor) {
                case "green": return "#166534"
                case "blue":  return "#1e40af"
                case "amber": return "#92400e"
                case "red":   return "#991b1b"
                default:      return "#52525b"
                }
            }
        }
    }
}
