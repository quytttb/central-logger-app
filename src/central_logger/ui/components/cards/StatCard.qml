import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qaterial 1.0 as Qaterial

import "../.."
import "."

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
    property string iconSource: ""

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

            Qaterial.LabelBody2 {
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

            Qaterial.Icon {
                visible: card.iconSource !== ""
                icon: card.iconSource
                size: 16
                color: Colors.textMuted(card.isDark)
                Layout.alignment: Qt.AlignVCenter
            }
        }

        Qaterial.LabelHeadline3 {
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

            Qaterial.LabelCaption {
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
