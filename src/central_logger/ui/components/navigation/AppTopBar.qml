import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Qaterial 1.0 as Qaterial

import "../.."
import "../common"

/*
 * Shadcn-style top header bar.
 * Contains: hamburger toggle, search bar, light/dark toggle, window chrome.
 */
Rectangle {
    id: bar

    property bool isDark: Qaterial.Style.theme === Qaterial.Style.Theme.Dark
    property alias searchText: searchField.text
    signal menuToggled()
    signal themeChanged(bool dark)
    signal searchChanged(string query)

    implicitHeight: 64
    color: isDark ? "#09090b" : "#ffffff"

    // Bottom border
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: bar.isDark ? "#27272a" : "#e4e4e7"
    }

    readonly property Window hostWindow: Window.window

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 16

        // ── Hamburger ────────────────────────────────────────────────────────
        Rectangle {
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36
            radius: 6
            color: "transparent"

            HoverHighlight {
                anchors.fill: parent
                cornerRadius: 6
                hovered: hamMouse.containsMouse
                isDark: bar.isDark
            }

            Qaterial.Icon {
                anchors.centerIn: parent
                icon: Qaterial.Icons.menu
                size: 20
                color: bar.isDark ? "#a1a1aa" : "#52525b"
            }
            MouseArea {
                id: hamMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: bar.menuToggled()
            }
        }

        // ── Search bar ──────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.maximumWidth: 400
            Layout.preferredHeight: 36
            radius: 6
            color: bar.isDark ? "#18181b" : "#fafafa"
            border.width: 1
            border.color: searchField.activeFocus
                ? (bar.isDark ? "#3b82f6" : "#2563eb")
                : (bar.isDark ? "#27272a" : "#e4e4e7")

            Behavior on border.color {
                ColorAnimation {
                    duration: UiMotion.durationFast
                    easing.type: UiMotion.easingOut
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8

                Qaterial.Icon {
                    icon: Qaterial.Icons.magnify
                    size: 16
                    color: bar.isDark ? "#71717a" : "#a1a1aa"
                    Layout.alignment: Qt.AlignVCenter
                }

                TextInput {
                    id: searchField
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: "Roboto"
                    font.pixelSize: 14
                    color: bar.isDark ? "#fafafa" : "#18181b"
                    selectByMouse: true
                    clip: true
                    
                    onTextChanged: bar.searchChanged(text)

                    Qaterial.LabelBody2 {
                        text: "Search loggers or sites..."
                        color: bar.isDark ? "#71717a" : "#a1a1aa"
                        visible: searchField.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        font.family: "Roboto"
                        font.pixelSize: 14
                    }
                }

                Item {
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                    Layout.alignment: Qt.AlignVCenter
                    visible: searchField.text !== "" || searchField.activeFocus
                    
                    Qaterial.Icon {
                        anchors.centerIn: parent
                        icon: Qaterial.Icons.closeCircle
                        size: 16
                        color: closeSearchMouse.containsMouse 
                            ? (bar.isDark ? "#fafafa" : "#18181b") 
                            : (bar.isDark ? "#71717a" : "#a1a1aa")
                    }

                    MouseArea {
                        id: closeSearchMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            searchField.text = ""
                            searchField.focus = false
                        }
                    }
                }
            }
        }

        Item { Layout.fillWidth: true }

        // ── Light / Dark toggle ─────────────────────────────────────────────
        Rectangle {
            Layout.preferredHeight: 32
            Layout.preferredWidth: lightDarkRow.implicitWidth + 8
            radius: 8
            color: bar.isDark ? "#18181b" : "#f4f4f5"
            border.width: 1
            border.color: bar.isDark ? "#27272a" : "#e4e4e7"

            RowLayout {
                id: lightDarkRow
                anchors.centerIn: parent
                spacing: 2

                // Light button
                Rectangle {
                    Layout.preferredWidth: lightRow.implicitWidth + 16
                    Layout.preferredHeight: 24
                    radius: 6
                    color: !bar.isDark ? "#ffffff" : "transparent"
                    border.width: !bar.isDark ? 1 : 0
                    border.color: "#e4e4e7"

                    RowLayout {
                        id: lightRow
                        anchors.centerIn: parent
                        spacing: 4
                        Qaterial.Icon {
                            icon: Qaterial.Icons.whiteBalanceSunny
                            size: 12
                            color: !bar.isDark ? "#18181b" : "#71717a"
                        }
                        Qaterial.LabelCaption {
                            text: "Light"
                            font.family: "Roboto"
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: !bar.isDark ? "#18181b" : "#71717a"
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: bar.themeChanged(false)
                    }
                }

                // Dark button
                Rectangle {
                    Layout.preferredWidth: darkRow.implicitWidth + 16
                    Layout.preferredHeight: 24
                    radius: 6
                    color: bar.isDark ? "#27272a" : "transparent"
                    border.width: bar.isDark ? 1 : 0
                    border.color: "#3f3f46"

                    RowLayout {
                        id: darkRow
                        anchors.centerIn: parent
                        spacing: 4
                        Qaterial.Icon {
                            icon: Qaterial.Icons.weatherNight
                            size: 12
                            color: bar.isDark ? "#fafafa" : "#71717a"
                        }
                        Qaterial.LabelCaption {
                            text: "Dark"
                            font.family: "Roboto"
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: bar.isDark ? "#fafafa" : "#71717a"
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: bar.themeChanged(true)
                    }
                }
            }
        }

        // ── Separator ───────────────────────────────────────────────────────
        Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: 24
            color: bar.isDark ? "#27272a" : "#e4e4e7"
        }

        // ── Window chrome (Minimize + Close) ────────────────────────────────
        Row {
            spacing: 4
            Layout.alignment: Qt.AlignVCenter

            // Minimize
            Rectangle {
                width: 32; height: 28; radius: 6
                color: minMouse.pressed
                    ? (bar.isDark ? "#3f3f46" : "#d4d4d8")
                    : "transparent"

                HoverHighlight {
                    anchors.fill: parent
                    cornerRadius: 6
                    visible: !minMouse.pressed
                    hovered: minMouse.containsMouse
                    isDark: bar.isDark
                }

                Qaterial.Icon {
                    anchors.centerIn: parent
                    icon: Qaterial.Icons.windowMinimize
                    size: 16
                    color: bar.isDark ? "#a1a1aa" : "#52525b"
                }
                MouseArea {
                    id: minMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { var w = bar.hostWindow; if (w) w.showMinimized() }
                }
                ToolTip.visible: minMouse.containsMouse
                ToolTip.text: "Minimize"
            }

            // Close
            Rectangle {
                width: 32; height: 28; radius: 6
                color: closeMouse.pressed ? "#b91c1c" : "transparent"

                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    visible: !closeMouse.pressed
                    color: closeMouse.containsMouse
                        ? (bar.isDark ? Qt.rgba(0.45, 0.05, 0.05, 0.5) : "#fef2f2")
                        : "transparent"
                    Behavior on color {
                        ColorAnimation {
                            duration: UiMotion.durationFast
                            easing.type: UiMotion.easingOut
                        }
                    }
                }

                Qaterial.Icon {
                    anchors.centerIn: parent
                    icon: Qaterial.Icons.windowClose
                    size: 16
                    color: closeMouse.containsMouse
                        ? (bar.isDark ? "#fca5a5" : "#ef4444")
                        : (bar.isDark ? "#a1a1aa" : "#52525b")
                }
                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { var w = bar.hostWindow; if (w) w.close() }
                }
                ToolTip.visible: closeMouse.containsMouse
                ToolTip.text: "Close"
            }
        }
    }

    // ── Drag region (title bar area, between search and toggles) ────────────
    MouseArea {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 60
        anchors.rightMargin: 250
        z: -1
        acceptedButtons: Qt.LeftButton
        onPressed: function (mouse) {
            var w = bar.hostWindow
            if (w && w.startSystemMove)
                w.startSystemMove()
            mouse.accepted = true
        }
    }
}
