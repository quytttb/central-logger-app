import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qaterial 1.0 as Qaterial
import CentralLogger.Core 1.0

import "../../"
import "../../components/common"
import "../../components/cards"

PanelCard {
    id: root

    property var dashboardController: null
    property RecentEventsModel eventsModel: null

    title: "Recent Events"
    clipBody: true

    Connections {
        target: root.dashboardController
        ignoreUnknownSignals: true
        function onEventsChanged() {
            if (root.eventsModel)
                root.eventsModel.reload(20)
        }
    }

    Component.onCompleted: {
        if (eventsModel)
            eventsModel.reload(20)
    }

    ListView {
        anchors.fill: parent
        clip: true
        model: root.eventsModel
        delegate: Rectangle {
            width: ListView.view.width
            height: eventCol.implicitHeight + 24
            color: "transparent"

            required property string type
            required property string logger
            required property string message
            required property string level
            required property string time

            HoverHighlight {
                hovered: evtMouse.containsMouse
                isDark: root.isDark
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: Colors.divider(root.isDark)
            }

            ColumnLayout {
                id: eventCol
                anchors.fill: parent
                anchors.margins: 16
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    Badge {
                        text: type
                        badgeColor: {
                            if (level === "critical") return "red"
                            if (level === "warning") return "amber"
                            if (level === "error") return "zinc"
                            if (level === "info") return "blue"
                            return "zinc"
                        }
                        isDark: root.isDark
                    }
                    Item { Layout.fillWidth: true }
                    Qaterial.LabelCaption {
                        text: time
                        color: Colors.textMuted(root.isDark)
                        font.family: "Inter"
                        font.pixelSize: 12
                    }
                }

                Qaterial.LabelBody2 {
                    text: message
                    color: Colors.textBody(root.isDark)
                    font.family: "Inter"
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
                Qaterial.LabelCaption {
                    text: logger
                    color: Colors.textSecondary(root.isDark)
                    font.family: "Inter"
                    font.pixelSize: 12
                }
            }

            MouseArea {
                id: evtMouse
                anchors.fill: parent
                hoverEnabled: true
            }
        }
    }
}
