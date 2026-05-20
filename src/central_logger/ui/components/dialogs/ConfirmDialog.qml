import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "../.."
import "../common"
import components

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

    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: bodyText.implicitHeight + 48

        UiLabel {
        textType: UiLabel.Body2
            id: bodyText
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 24
            anchors.rightMargin: 24
            text: dialog.message
            color: dialog.isDark ? "#d4d4d8" : "#3f3f46"
            font.family: "Inter"
            font.pixelSize: 14
            wrapMode: Text.WordWrap
            lineHeight: 1.5
        }
    }

    dialogFooter: [
        Item { Layout.fillWidth: true },
        DialogButton {
            text: dialog.cancelText
            isDark: dialog.isDark
            variant: "secondary"
            onClicked: dialog.close()
        },
        DialogButton {
            text: dialog.confirmText
            isDark: dialog.isDark
            variant: dialog.destructive ? "destructive" : "primary"
            onClicked: {
                dialog.close()
                dialog.confirmed()
            }
        }
    ]
}
