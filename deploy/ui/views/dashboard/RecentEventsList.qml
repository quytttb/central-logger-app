import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import CentralLogger.Core 1.0

import "../../"
import "../../components/common"
import "../../components/cards"
import components

PanelCard {
    id: root

    property var dashboardController: null
    property RecentEventsModel eventsModel: null

    signal selectLogger(int loggerId)

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
        id: eventsList
        anchors.fill: parent
        clip: true
        model: root.eventsModel

        delegate: ListRowDelegate {
            id: eventRow
            width: eventsList.width
            isDark: root.isDark
            verticalPadding: 12
            clickable: eventRow._resolvedLoggerId() >= 0

            required property string type
            required property string logger
            required property string message
            required property string level
            required property string time
            required property var loggerId

            function _resolvedLoggerId() {
                if (loggerId === null || loggerId === undefined)
                    return -1
                var id = Number(loggerId)
                return (id >= 0 && isFinite(id)) ? id : -1
            }

            onClicked: root.selectLogger(eventRow._resolvedLoggerId())

            ColumnLayout {
                width: parent.width
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 24
                anchors.rightMargin: 24
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
                    UiLabel {
                        textType: UiLabel.Caption
                        text: time
                        color: Colors.textMuted(root.isDark)
                        font.family: "Inter"
                        font.pixelSize: 12
                    }
                }

                UiLabel {
                    textType: UiLabel.Body2
                    text: message
                    color: Colors.textBody(root.isDark)
                    font.family: "Inter"
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }

                UiLabel {
                    textType: UiLabel.Caption
                    text: logger
                    color: Colors.textSecondary(root.isDark)
                    font.family: "Inter"
                    font.pixelSize: 12
                }
            }
        }

        Item {
            anchors.centerIn: parent
            width: parent.width
            height: 80
            visible: eventsList.count === 0
            z: 1
            UiLabel {
                textType: UiLabel.Body2
                anchors.centerIn: parent
                text: "No recent events"
                color: Colors.textMuted(root.isDark)
                font.family: "Inter"
                font.pixelSize: 14
            }
        }
    }
}
