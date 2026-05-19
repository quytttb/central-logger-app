import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qaterial 1.0 as Qaterial

import "../../"
import "../../components/common"

Rectangle {
    id: root
    property bool isDark: true
    property var dashboardController: null
    property var events: []

    function refresh() {
        if (!dashboardController) return
        try {
            var raw = dashboardController.getRecentEvents(20)
            events = JSON.parse(raw || "[]")
        } catch (e) {
            console.warn("recent events parse error", e)
            events = []
        }
    }

    Connections {
        target: root.dashboardController
        ignoreUnknownSignals: true
        function onEventsChanged() { root.refresh() }
    }
    Component.onCompleted: refresh()

    radius: 12
    color: isDark ? "#09090b" : "#ffffff"

    // Overlay border
    Rectangle {
        anchors.fill: parent
        radius: 12
        color: "transparent"
        border.width: 1
        border.color: root.isDark ? "#27272a" : "#e4e4e7"
        z: 10
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Header
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            color: "transparent"

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width; height: 1
                color: root.isDark ? "#27272a" : "#f4f4f5"
            }

            Qaterial.LabelBody1 {
                anchors.left: parent.left
                anchors.leftMargin: 24
                anchors.verticalCenter: parent.verticalCenter
                text: "Recent Events"
                color: root.isDark ? "#fafafa" : "#18181b"
                font.family: "Inter"
                font.pixelSize: 18
                font.weight: Font.Medium
            }
        }

        // Events list
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: root.events
            delegate: Rectangle {
                width: ListView.view.width
                height: eventCol.implicitHeight + 24
                color: "transparent"

                HoverHighlight {
                    hovered: evtMouse.containsMouse
                    isDark: root.isDark
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width; height: 1
                    color: root.isDark ? "#27272a" : "#f4f4f5"
                }

                ColumnLayout {
                    id: eventCol
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        Badge {
                            text: modelData.type
                            badgeColor: {
                                if (modelData.level === "critical") return "red"
                                if (modelData.level === "warning") return "amber"
                                if (modelData.level === "error") return "zinc"
                                if (modelData.level === "info") return "blue"
                                return "zinc"
                            }
                            isDark: root.isDark
                        }
                        Item { Layout.fillWidth: true }
                        Qaterial.LabelCaption {
                            text: modelData.time
                            color: root.isDark ? "#71717a" : "#a1a1aa"
                            font.family: "Inter"
                            font.pixelSize: 12
                        }
                    }

                    Qaterial.LabelBody2 {
                        text: modelData.message
                        color: root.isDark ? "#e4e4e7" : "#27272a"
                        font.family: "Inter"
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                    }
                    Qaterial.LabelCaption {
                        text: modelData.logger
                        color: root.isDark ? "#a1a1aa" : "#71717a"
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
}
