import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "../.."
import "../common"
import components

/*
 * BaseDialog — Thống nhất UI cho các màn hình Modal dạng Shadcn.
 * Bao gồm: nền tối Overlay, tự động căn giữa, bo góc, Header (có nút Close) và vùng Footer tùy biến.
 */
Popup {
    id: root

    property string title: "Dialog Title"
    property int preferredWidth: 450
    property bool isDark: true

    default property alias dialogBody: contentContainer.data
    property alias dialogFooter: footerContainer.data
    property bool showFooter: true
    property int footerPreferredHeight: 64

    readonly property int headerHeight: 56
    readonly property int footerHeight: showFooter ? footerPreferredHeight : 0
    readonly property int chromeHeight: headerHeight + footerHeight
    readonly property int maxDialogHeight: parent ? Math.floor(parent.height * 0.9) : 600
    readonly property int maxBodyHeight: Math.max(120, maxDialogHeight - chromeHeight)
    readonly property int bodyContentHeight: contentContainer.implicitHeight
    readonly property int bodyViewportHeight: Math.min(Math.max(bodyContentHeight, 0), maxBodyHeight)

    signal cancelled()

    parent: Overlay.overlay
    modal: true
    focus: true
    padding: 0
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    x: Math.round((parent.width - width) / 2)
    y: Math.round((parent.height - height) / 2)
    width: Math.min(preferredWidth, parent.width - 32)
    height: chromeHeight + bodyViewportHeight

    Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.6) }
    onClosed: cancelled()

    enter: Transition {
        ParallelAnimation {
            NumberAnimation {
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: UiMotion.durationDialog
                easing.type: UiMotion.easingOut
            }
            NumberAnimation {
                target: dialogCard
                property: "scale"
                from: 0.96
                to: 1.0
                duration: UiMotion.durationDialog
                easing.type: UiMotion.easingOut
            }
        }
    }

    exit: Transition {
        ParallelAnimation {
            NumberAnimation {
                property: "opacity"
                from: 1.0
                to: 0.0
                duration: UiMotion.durationFast
                easing.type: UiMotion.easingIn
            }
            NumberAnimation {
                target: dialogCard
                property: "scale"
                from: 1.0
                to: 0.96
                duration: UiMotion.durationFast
                easing.type: UiMotion.easingIn
            }
        }
    }

    background: Rectangle {
        id: dialogCard
        radius: 12
        color: Colors.surface(root.isDark)
        border.width: 1
        border.color: Colors.border(root.isDark)
        transformOrigin: Item.Center
    }

    contentItem: Item {
        clip: true

        ColumnLayout {
            id: mainCol
            anchors.fill: parent
            spacing: 0

            // ── Header ───────────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                color: "transparent"
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width; height: 1
                    color: Colors.divider(root.isDark)
                }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 24; anchors.rightMargin: 24
                    UiLabel {
        textType: UiLabel.Body2
                        text: root.title
                        Layout.fillWidth: true
                        color: Colors.textPrimary(root.isDark)
                        font.family: "Roboto"
                        font.pixelSize: 20
                        font.weight: Font.DemiBold
                    }
                    Rectangle {
                        width: 32; height: 32; radius: 6
                        color: "transparent"
                        HoverHighlight {
                            anchors.fill: parent
                            cornerRadius: 6
                            hovered: closeMouse.containsMouse
                            isDark: root.isDark
                        }
                        UiIcon { anchors.centerIn: parent; name: "close"; size: 20; iconColor: Colors.textSecondary(root.isDark) }
                        MouseArea {
                            id: closeMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.close()
                        }
                    }
                }
            }

            // ── Body (Scrollable) ────────────────────────────────────────────
            Flickable {
                Layout.fillWidth: true
                Layout.preferredHeight: root.bodyViewportHeight
                Layout.minimumHeight: 0
                contentHeight: contentContainer.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: contentContainer
                    width: parent.width
                    spacing: 0
                }
            }

            // ── Footer ───────────────────────────────────────────────────────
            Rectangle {
                visible: root.showFooter
                Layout.fillWidth: true
                Layout.preferredHeight: root.footerHeight
                color: "transparent"
                Rectangle {
                    anchors.top: parent.top
                    width: parent.width; height: 1
                    color: Colors.divider(root.isDark)
                    visible: root.showFooter
                }
                RowLayout {
                    id: footerContainer
                    anchors.fill: parent
                    anchors.leftMargin: 24; anchors.rightMargin: 24
                    spacing: 12
                }
            }
        }
    }
}
