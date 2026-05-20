import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material

import "../.."
import components

/*
 * ComboBox styled like LabeledField — follows app isDark, not qtquickcontrols2.conf alone.
 */
ComboBox {
    id: control

    property bool isDark: true

    implicitHeight: 40
    leftPadding: 12
    rightPadding: 12

    Material.theme: control.isDark ? Material.Dark : Material.Light
    Material.accent: Colors.primary(control.isDark)

    background: Rectangle {
        implicitHeight: 40
        width: control.width
        radius: 6
        color: Colors.surfaceMuted(control.isDark)
        border.width: 1
        border.color: control.activeFocus
            ? Colors.primary(control.isDark)
            : Colors.border(control.isDark)
    }

    contentItem: Text {
        leftPadding: 0
        rightPadding: control.indicator.width + 8
        text: control.displayText
        font.family: "Roboto"
        font.pixelSize: 14
        color: Colors.textPrimary(control.isDark)
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    indicator: Text {
        x: control.width - width - 12
        y: (control.height - height) / 2
        text: "\u25BE"
        font.pixelSize: 12
        color: Colors.textSecondary(control.isDark)
    }

    delegate: ItemDelegate {
        width: control.width
        height: 36
        padding: 8

        contentItem: Text {
            text: typeof modelData === "string" ? modelData : control.textAt(index)
            font.family: "Roboto"
            font.pixelSize: 14
            color: Colors.textPrimary(control.isDark)
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }

        background: Rectangle {
            radius: 4
            color: parent.highlighted
                ? Colors.buttonSecondaryHover(control.isDark)
                : "transparent"
        }
    }

    popup: Popup {
        y: control.height + 2
        width: control.width
        implicitHeight: contentItem.implicitHeight + 8
        padding: 4

        background: Rectangle {
            radius: 6
            color: Colors.surface(control.isDark)
            border.width: 1
            border.color: Colors.border(control.isDark)
        }

        contentItem: ListView {
            clip: true
            implicitHeight: Math.min(contentHeight, 280)
            model: control.popup.visible ? control.delegateModel : null
            currentIndex: control.highlightedIndex
            ScrollIndicator.vertical: ScrollIndicator { }
        }
    }
}
