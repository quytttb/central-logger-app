import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qaterial 1.0 as Qaterial

import "../.."
import "../common"

/*
 * BaseDialog — Thống nhất UI cho các màn hình Modal dạng Shadcn.
 * Bao gồm: nền tối Overlay, tự động căn giữa, bo góc, Header (có nút Close) và vùng Footer tùy biến.
 */
Popup {
    id: root

    property string title: "Dialog Title"
    property int preferredWidth: 450
    property bool isDark: Qaterial.Style.theme === Qaterial.Style.Theme.Dark

    default property alias dialogBody: contentContainer.data
    property alias dialogFooter: footerContainer.data
    property bool showFooter: true

    signal cancelled()

    parent: Overlay.overlay
    modal: true
    focus: true
    padding: 0
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    x: Math.round((parent.width - width) / 2)
    y: Math.round((parent.height - height) / 2)
    width: Math.min(preferredWidth, parent.width - 32)
    height: Math.min(mainCol.implicitHeight, parent.height * 0.9)

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
        color: root.isDark ? "#09090b" : "#ffffff"
        border.width: 1
        border.color: root.isDark ? "#27272a" : "#e4e4e7"
        transformOrigin: Item.Center
    }

    contentItem: Item {
        clip: true

        ColumnLayout {
            id: mainCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: 0

            // ── Header ───────────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                color: "transparent"
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width; height: 1
                    color: root.isDark ? "#27272a" : "#f4f4f5"
                }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 24; anchors.rightMargin: 24
                    Qaterial.LabelBody1 {
                        text: root.title
                        Layout.fillWidth: true
                        color: root.isDark ? "#fafafa" : "#18181b"
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
                        Qaterial.Icon { anchors.centerIn: parent; icon: Qaterial.Icons.close; size: 20; color: root.isDark ? "#a1a1aa" : "#71717a" }
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
                Layout.fillHeight: true
                Layout.preferredHeight: contentContainer.implicitHeight
                contentHeight: contentContainer.implicitHeight
                clip: true

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
                Layout.preferredHeight: visible ? 64 : 0
                color: "transparent"
                Rectangle {
                    anchors.top: parent.top
                    width: parent.width; height: 1
                    color: root.isDark ? "#27272a" : "#f4f4f5"
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
