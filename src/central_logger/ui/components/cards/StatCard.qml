import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "../.."
import "."
import components

/*
 * Shadcn-style stat card for Dashboard overview.
 * Composes PanelCard chrome with stat-specific body.
 */
PanelCard {
    id: card

    showHeader: false
    property string statTitle: ""
    property string value: "0"
    property string trend: ""
    property string trendColor: ""
    property string iconName: ""

    hoverable: true
    implicitHeight: 140
    bodyMargins: 24

    ColumnLayout {
        anchors.fill: parent
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 20
            spacing: 8

            UiLabel {
        textType: UiLabel.Body2
                text: card.statTitle
                color: Colors.textSecondary(card.isDark)
                font.family: "Roboto"
                font.pixelSize: 14
                font.weight: Font.Medium
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                maximumLineCount: 1
                elide: Text.ElideRight
            }

            UiIcon {
                visible: card.iconName !== ""
                name: card.iconName
                size: 16
                iconColor: Colors.textMuted(card.isDark)
                Layout.alignment: Qt.AlignVCenter
            }
        }

        UiLabel {
        textType: UiLabel.Headline3
            text: card.value
            color: Colors.textPrimary(card.isDark)
            font.family: "Roboto"
            font.pixelSize: 30
            font.weight: Font.Bold
            Layout.topMargin: 4
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 20
            Layout.topMargin: 4

            UiLabel {
        textType: UiLabel.Caption
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                visible: card.trend !== ""
                text: card.trend
                font.family: "Roboto"
                font.pixelSize: 12
                font.weight: Font.Medium
                color: Colors.trendText(card.isDark, card.trendColor)
            }
        }
    }
}
