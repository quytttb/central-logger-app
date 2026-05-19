import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qaterial 1.0 as Qaterial

import "../.."
import "../common"

/*
 * Shadcn-style sidebar navigation.
 * Fixed panel with collapsible width. Includes logo, section headers, nav items.
 */
Rectangle {
    id: sidebar

    property string currentView: "dashboard"
    property bool isOpen: true
    property bool isDark: Qaterial.Style.theme === Qaterial.Style.Theme.Dark

    /** Logo SVG viewBox ~186×80 — giữ height 40, width theo tỷ lệ để không bị co trong ô vuông. */
    readonly property real logoAspect: 186 / 80
    readonly property int logoHeight: 40
    readonly property int logoWidthExpanded: Math.round(logoHeight * logoAspect)

    signal navigate(string view)

    color: isDark ? "#09090b" : "#ffffff"

    // Right border
    Rectangle {
        anchors.right: parent.right
        width: 1
        height: parent.height
        color: isDark ? "#27272a" : "#e4e4e7"
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Logo header (một layout, animate vị trí/width — tránh nháy khi collapse) ──
        Item {
            id: logoHeader
            Layout.fillWidth: true
            Layout.preferredHeight: 64
            clip: true

            readonly property int brandInsetLeft: 24
            readonly property int titleGap: 4

            property real logoSlotW: sidebar.isOpen
                ? sidebar.logoWidthExpanded
                : Math.min(width - 16, sidebar.logoWidthExpanded)
            property real logoSlotX: sidebar.isOpen
                ? brandInsetLeft
                : Math.max(0, (width - logoSlotW) / 2)

            Behavior on logoSlotW {
                NumberAnimation {
                    duration: UiMotion.durationNormal
                    easing.type: UiMotion.easingOut
                }
            }
            Behavior on logoSlotX {
                NumberAnimation {
                    duration: UiMotion.durationNormal
                    easing.type: UiMotion.easingOut
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: sidebar.isDark ? "#27272a" : "#e4e4e7"
            }

            Item {
                x: logoHeader.logoSlotX
                y: (logoHeader.height - sidebar.logoHeight) / 2
                width: logoHeader.logoSlotW
                height: sidebar.logoHeight

                Image {
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                    sourceSize: Qt.size(372, 160)
                    source: logoUrl
                }
            }

            ColumnLayout {
                x: logoHeader.logoSlotX + logoHeader.logoSlotW + logoHeader.titleGap
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0
                opacity: sidebar.isOpen ? 1.0 : 0.0
                visible: opacity > 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: UiMotion.durationNormal
                        easing.type: UiMotion.easingOut
                    }
                }

                Qaterial.LabelBody2 {
                    text: "Central"
                    color: sidebar.isDark ? "#fafafa" : "#18181b"
                    font.family: "Roboto"
                    font.pixelSize: 16
                    font.weight: Font.Bold
                    lineHeight: 1.1
                }
                Qaterial.LabelCaption {
                    text: "Logger"
                    color: sidebar.isDark ? "#d4d4d8" : "#52525b"
                    font.family: "Roboto"
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    lineHeight: 1.1
                    Layout.topMargin: -2
                }
            }
        }

        // ── Navigation ──────────────────────────────────────────────────────
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: navCol.implicitHeight
            clip: true

            ColumnLayout {
                id: navCol
                width: parent.width
                spacing: 2

                Item { Layout.preferredHeight: 16 }

                // Section: Overview
                Qaterial.LabelCaption {
                    text: "OVERVIEW"
                    opacity: sidebar.isOpen ? 1.0 : 0.0
                    visible: opacity > 0
                    color: sidebar.isDark ? "#71717a" : "#a1a1aa"
                    font.family: "Roboto"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.2
                    Layout.leftMargin: 20
                    Layout.bottomMargin: 4
                    Behavior on opacity {
                        NumberAnimation {
                            duration: UiMotion.durationNormal
                            easing.type: UiMotion.easingOut
                        }
                    }
                }

                NavItem {
                    viewName: "dashboard"
                    label: "Dashboard"
                    iconSource: Qaterial.Icons.viewDashboard
                    currentView: sidebar.currentView
                    isOpen: sidebar.isOpen
                    isDark: sidebar.isDark
                    onClicked: sidebar.navigate("dashboard")
                }

                Item { Layout.preferredHeight: 12 }

                // Section: Edge Network
                Qaterial.LabelCaption {
                    text: "EDGE NETWORK"
                    opacity: sidebar.isOpen ? 1.0 : 0.0
                    visible: opacity > 0
                    color: sidebar.isDark ? "#71717a" : "#a1a1aa"
                    font.family: "Roboto"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.2
                    Layout.leftMargin: 20
                    Layout.bottomMargin: 4
                    Behavior on opacity {
                        NumberAnimation {
                            duration: UiMotion.durationNormal
                            easing.type: UiMotion.easingOut
                        }
                    }
                }

                NavItem {
                    viewName: "loggers"
                    label: "Loggers"
                    iconSource: Qaterial.Icons.server
                    currentView: sidebar.currentView
                    isOpen: sidebar.isOpen
                    isDark: sidebar.isDark
                    onClicked: sidebar.navigate("loggers")
                }

                Item { Layout.preferredHeight: 12 }

                // Section: Configuration
                Qaterial.LabelCaption {
                    text: "CONFIGURATION"
                    opacity: sidebar.isOpen ? 1.0 : 0.0
                    visible: opacity > 0
                    color: sidebar.isDark ? "#71717a" : "#a1a1aa"
                    font.family: "Roboto"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.2
                    Layout.leftMargin: 20
                    Layout.bottomMargin: 4
                    Behavior on opacity {
                        NumberAnimation {
                            duration: UiMotion.durationNormal
                            easing.type: UiMotion.easingOut
                        }
                    }
                }

                NavItem {
                    viewName: "settings"
                    label: "Settings"
                    iconSource: Qaterial.Icons.cog
                    currentView: sidebar.currentView
                    isOpen: sidebar.isOpen
                    isDark: sidebar.isDark
                    onClicked: sidebar.navigate("settings")
                }
            }
        }

        // ── Footer ──────────────────────────────────────────────────────────
        Qaterial.LabelCaption {
            text: "© 2026 4M Technologies"
            color: sidebar.isDark ? "#52525b" : "#a1a1aa"
            font.family: "Roboto"
            font.pixelSize: 11
            opacity: sidebar.isOpen ? 0.8 : 0.0
            visible: opacity > 0
            Layout.leftMargin: 20
            Layout.bottomMargin: 16
            Behavior on opacity {
                NumberAnimation {
                    duration: UiMotion.durationNormal
                    easing.type: UiMotion.easingOut
                }
            }
        }
    }

    // ── NavItem sub-component ────────────────────────────────────────────────
    component NavItem: Item {
        id: navItem

        property string viewName: ""
        property string label: ""
        property url iconSource: ""
        property string currentView: ""
        property bool isOpen: true
        property bool isDark: true

        signal clicked()

        readonly property bool isActive: viewName === currentView

        Layout.fillWidth: true
        Layout.preferredHeight: 36
        Layout.leftMargin: 12
        Layout.rightMargin: 12

        Rectangle {
            anchors.fill: parent
            radius: 6
            color: navItem.isActive
                ? (navItem.isDark ? "#2563eb" : "#eff6ff")
                : "transparent"

            HoverHighlight {
                anchors.fill: parent
                cornerRadius: 6
                visible: !navItem.isActive
                hovered: navMouse.containsMouse
                isDark: navItem.isDark
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: navItem.isOpen ? 12 : 0

            Item {
                Layout.fillWidth: !navItem.isOpen
                Layout.preferredWidth: navItem.isOpen ? 0 : 1
                Layout.maximumWidth: navItem.isOpen ? 0 : -1
            }

            Item {
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
                Layout.alignment: Qt.AlignVCenter

                Qaterial.Icon {
                    anchors.centerIn: parent
                    icon: navItem.iconSource
                    size: 16
                    color: navItem.isActive
                        ? (navItem.isDark ? "#ffffff" : "#1d4ed8")
                        : (navItem.isDark ? "#a1a1aa" : "#52525b")
                }
            }

            Qaterial.LabelBody2 {
                text: navItem.label
                opacity: navItem.isOpen ? 1.0 : 0.0
                visible: opacity > 0
                color: navItem.isActive
                    ? (navItem.isDark ? "#ffffff" : "#1d4ed8")
                    : (navItem.isDark ? "#a1a1aa" : "#52525b")
                font.family: "Roboto"
                font.pixelSize: 14
                font.weight: Font.Medium
                Layout.fillWidth: navItem.isOpen
                Layout.preferredWidth: navItem.isOpen ? -1 : 0
                Layout.maximumWidth: navItem.isOpen ? -1 : 0
                elide: Text.ElideRight
                Behavior on opacity {
                    NumberAnimation {
                        duration: UiMotion.durationNormal
                        easing.type: UiMotion.easingOut
                    }
                }
            }

            Item {
                Layout.fillWidth: !navItem.isOpen
                Layout.preferredWidth: navItem.isOpen ? 0 : 1
                Layout.maximumWidth: navItem.isOpen ? 0 : -1
            }
        }

        MouseArea {
            id: navMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: navItem.clicked()
        }
    }
}
