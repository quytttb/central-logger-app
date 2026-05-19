import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qaterial 1.0 as Qaterial

import "../.."
import "../common"

/*
 * Shadcn-style stat card for Dashboard overview.
 * Shows: title, icon, large value, optional trend text.
 */
Rectangle {
    id: card

    property string title: ""
    property string value: "0"
    property string trend: ""
    property string trendColor: ""
    property string iconSource: ""
    property bool isDark: Qaterial.Style.theme === Qaterial.Style.Theme.Dark

    implicitHeight: 140
    radius: 12
    color: isDark ? "#09090b" : "#ffffff"

    HoverHighlight {
        anchors.fill: parent
        cornerRadius: 12
        hovered: cardMouse.containsMouse
        isDark: card.isDark
        z: 0
    }

    // Overlay border
    Rectangle {
        anchors.fill: parent
        radius: 12
        color: "transparent"
        border.width: 1
        border.color: cardMouse.containsMouse
            ? (isDark ? "#52525b" : "#d4d4d8")
            : (isDark ? "#27272a" : "#e4e4e7")
        z: 10
        Behavior on border.color {
            ColorAnimation {
                duration: UiMotion.durationFast
                easing.type: UiMotion.easingOut
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 20
            spacing: 8

            Qaterial.LabelBody2 {
                text: card.title
                color: isDark ? "#a1a1aa" : "#71717a"
                font.family: "Roboto"
                font.pixelSize: 14
                font.weight: Font.Medium
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                maximumLineCount: 1
                elide: Text.ElideRight
            }

            Qaterial.Icon {
                visible: card.iconSource !== ""
                icon: card.iconSource
                size: 16
                color: isDark ? "#71717a" : "#a1a1aa"
                Layout.alignment: Qt.AlignVCenter
            }
        }

        Qaterial.LabelHeadline3 {
            text: card.value
            color: isDark ? "#fafafa" : "#18181b"
            font.family: "Roboto"
            font.pixelSize: 30
            font.weight: Font.Bold
            Layout.topMargin: 4
        }

        // Giữ chiều cao cố định cho dòng trend để 3 card căn đều title/value
        // (card "Total Loggers" không có trend vẫn chiếm cùng không gian).
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 20
            Layout.topMargin: 4

            Qaterial.LabelCaption {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                visible: card.trend !== ""
                text: card.trend
                font.family: "Roboto"
                font.pixelSize: 12
                font.weight: Font.Medium
                color: {
                    if (card.trendColor === "green") return isDark ? "#4ade80" : "#16a34a"
                    if (card.trendColor === "amber") return isDark ? "#fbbf24" : "#d97706"
                    if (card.trendColor === "red")   return isDark ? "#f87171" : "#dc2626"
                    return isDark ? "#a1a1aa" : "#71717a"
                }
            }
        }
    }

    MouseArea {
        id: cardMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        z: 5
    }
}
