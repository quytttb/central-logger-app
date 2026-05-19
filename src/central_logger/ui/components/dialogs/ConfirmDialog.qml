import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qaterial 1.0 as Qaterial

import "../.."

/*
 * Shadcn-style confirmation dialog — modal overlay.
 */
BaseDialog {
    id: dialog
    
    preferredWidth: 450
    title: "Confirm"

    property string message: ""
    property string confirmText: "Confirm"
    property string cancelText: "Cancel"
    property bool destructive: false

    signal confirmed()

    // ── Body ─────────────────────────────────────────────────────────────────
    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: bodyText.implicitHeight + 48

        Qaterial.LabelBody2 {
            id: bodyText
            anchors.left: parent.left; anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 24; anchors.rightMargin: 24
            text: dialog.message
            color: dialog.isDark ? "#d4d4d8" : "#3f3f46"
            font.family: "Inter"
            font.pixelSize: 14
            wrapMode: Text.WordWrap
            lineHeight: 1.5
        }
    }

    // ── Footer ───────────────────────────────────────────────────────────────
    dialogFooter: [
        Item { Layout.fillWidth: true },
        
        // Cancel
        Rectangle {
            Layout.preferredWidth: cancelLabel.implicitWidth + 32
            Layout.preferredHeight: 36
            radius: 6
            property color cancelFill: cancelMouse.pressed ? (dialog.isDark ? "#3f3f46" : "#d4d4d8")
                 : cancelMouse.containsMouse ? (dialog.isDark ? "#27272a" : "#e4e4e7")
                 : (dialog.isDark ? "#27272a" : "#f4f4f5")
            color: cancelFill
            Behavior on color {
                ColorAnimation {
                    duration: UiMotion.durationFast
                    easing.type: UiMotion.easingOut
                }
            }
            
            Qaterial.LabelBody2 {
                id: cancelLabel
                anchors.centerIn: parent
                text: dialog.cancelText
                color: dialog.isDark ? "#fafafa" : "#3f3f46"
                font.family: "Inter"; font.pixelSize: 14; font.weight: Font.Medium
            }
            MouseArea {
                id: cancelMouse; anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: dialog.close()
            }
        },

        // Confirm
        Rectangle {
            Layout.preferredWidth: confirmLabel.implicitWidth + 32
            Layout.preferredHeight: 36
            radius: 6
            property color confirmFill: {
                if (dialog.destructive) {
                    return confirmMouse.pressed ? "#b91c1c"
                         : confirmMouse.containsMouse ? "#ef4444"
                         : "#dc2626"
                }
                return confirmMouse.pressed ? "#1d4ed8"
                     : confirmMouse.containsMouse ? "#3b82f6"
                     : "#2563eb"
            }
            color: confirmFill
            Behavior on color {
                ColorAnimation {
                    duration: UiMotion.durationFast
                    easing.type: UiMotion.easingOut
                }
            }
            
            Qaterial.LabelBody2 {
                id: confirmLabel
                anchors.centerIn: parent
                text: dialog.confirmText
                color: "#ffffff"
                font.family: "Inter"; font.pixelSize: 14; font.weight: Font.Medium
            }
            MouseArea {
                id: confirmMouse; anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { dialog.close(); dialog.confirmed() }
            }
        }
    ]
}
