import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "../.."
import "../common"
import components

/*
 * Shadcn-style sidebar navigation.
 * Fixed panel with collapsible width. Includes logo, section headers, nav items.
 */
Rectangle {
    id: sidebar

    property string currentView: "dashboard"
    property bool isOpen: true
    property bool isDark: true

    /** Logo SVG viewBox ~186×80 — giữ height 40, width theo tỷ lệ để không bị co trong ô vuông. */
    readonly property real logoAspect: 186 / 80
    readonly property int logoHeight: 40
    readonly property int logoWidthExpanded: Math.round(logoHeight * logoAspect)

    signal navigate(string view)

    color: Colors.surface(isDark)

    // Right border
    Rectangle {
        anchors.right: parent.right
        width: 1
        height: parent.height
        color: Colors.border(isDark)
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
                color: Colors.border(sidebar.isDark)
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

                UiLabel {
        textType: UiLabel.Body2
                    text: "Central"
                    color: Colors.textPrimary(sidebar.isDark)
                    font.family: "Roboto"
                    font.pixelSize: 16
                    font.weight: Font.Bold
                    lineHeight: 1.1
                }
                UiLabel {
        textType: UiLabel.Body2
                    text: "Logger"
                    color: Colors.textBody(sidebar.isDark)
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
                UiLabel {
        textType: UiLabel.Caption
                    text: "OVERVIEW"
                    opacity: sidebar.isOpen ? 1.0 : 0.0
                    visible: opacity > 0
                    color: Colors.textMuted(sidebar.isDark)
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
                    iconName: "viewDashboard"
                    currentView: sidebar.currentView
                    isOpen: sidebar.isOpen
                    isDark: sidebar.isDark
                    onClicked: sidebar.navigate("dashboard")
                }

                Item { Layout.preferredHeight: 12 }

                // Section: Edge Network
                UiLabel {
        textType: UiLabel.Caption
                    text: "EDGE NETWORK"
                    opacity: sidebar.isOpen ? 1.0 : 0.0
                    visible: opacity > 0
                    color: Colors.textMuted(sidebar.isDark)
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
                    iconName: "server"
                    currentView: sidebar.currentView
                    isOpen: sidebar.isOpen
                    isDark: sidebar.isDark
                    onClicked: sidebar.navigate("loggers")
                }

                Item { Layout.preferredHeight: 12 }

                // Section: Configuration
                UiLabel {
        textType: UiLabel.Caption
                    text: "CONFIGURATION"
                    opacity: sidebar.isOpen ? 1.0 : 0.0
                    visible: opacity > 0
                    color: Colors.textMuted(sidebar.isDark)
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
                    iconName: "cog"
                    currentView: sidebar.currentView
                    isOpen: sidebar.isOpen
                    isDark: sidebar.isDark
                    onClicked: sidebar.navigate("settings")
                }
            }
        }

        // ── Footer ──────────────────────────────────────────────────────────
        UiLabel {
        textType: UiLabel.Caption
            text: "© 2026 4M Technologies"
            color: Colors.textMuted(sidebar.isDark)
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
        property string iconName: ""
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
            color: navItem.isActive ? Colors.navActiveBg(navItem.isDark) : "transparent"

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

                UiIcon {
                    anchors.centerIn: parent
                    name: navItem.iconName
                    size: 16
                    iconColor: navItem.isActive ? Colors.navActiveFg(navItem.isDark) : Colors.textSecondary(navItem.isDark)
                }
            }

            UiLabel {
        textType: UiLabel.Body2
                text: navItem.label
                opacity: navItem.isOpen ? 1.0 : 0.0
                visible: opacity > 0
                color: navItem.isActive ? Colors.navActiveFg(navItem.isDark) : Colors.textSecondary(navItem.isDark)
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
