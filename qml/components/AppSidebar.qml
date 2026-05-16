import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qaterial 1.0 as Qaterial


/*
 * Sidebar navigation content (navy dark panel).
 * Placed inside a Qaterial.Drawer in main.qml.
 */
Rectangle {
    id: sidebar

    property int currentTab: 0
    signal selectTab(int index)

    color: "#1B2838"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 84
            Layout.bottomMargin: 6
            radius: 10
            color: "#FFFFFF"
            clip: true

            Image {
                anchors.fill: parent
                anchors.margins: 6
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
                sourceSize: Qt.size(480, 160)
                source: Qt.resolvedUrl("../../resources/images/4M Technologies Blue.svg")
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#1A237E"
        }

        Repeater {
            model: [
                { label: "Dashboard", icon: Qaterial.Icons.viewDashboard },
                { label: "Map View", icon: Qaterial.Icons.map },
                { label: "Global Settings", icon: Qaterial.Icons.cog }
            ]
            delegate: Item {
                id: navItem
                Layout.fillWidth: true
                Layout.preferredHeight: 44

                readonly property bool active: index === sidebar.currentTab

                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: parent.active ? "#1A237E"
                         : (mouse.containsMouse ? Qt.tint("#1B2838", "#20ffffff") : "transparent")
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
                Rectangle {
                    visible: parent.active
                    width: 3
                    height: parent.height - 12
                    radius: 2
                    color: "#B4CAD6"
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 16

                    Qaterial.Icon {
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
                        icon: modelData.icon
                        size: 20
                        color: navItem.active ? "#8690EE" : "#B4CAD6"
                    }
                    Qaterial.LabelBody2 {
                        text: modelData.label
                        color: navItem.active ? "#8690EE" : "#B4CAD6"
                        font.family: "JetBrains Mono"
                        Layout.fillWidth: true
                    }
                }
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: sidebar.selectTab(index)
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }

        Qaterial.LabelCaption {
            text: "© 2026 4M Technologies"
            color: "#B4CAD6"
            opacity: 0.6
        }
    }
}
