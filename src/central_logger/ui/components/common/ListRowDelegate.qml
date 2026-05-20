import QtQuick
import QtQuick.Controls

import "../.."
import "."

/*
 * List/table row shell — hover highlight + bottom divider + optional click.
 */
Rectangle {
    id: root

    property bool isDark: true
    property bool clickable: false
    property int verticalPadding: 0

    default property alias content: contentSlot.data

    signal clicked()

    color: "transparent"
    implicitHeight: contentSlot.childrenRect.height + root.verticalPadding * 2

    HoverHighlight {
        hovered: rowMouse.containsMouse
        isDark: root.isDark
    }

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: Colors.divider(root.isDark)
    }

    Item {
        id: contentSlot
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: root.verticalPadding
    }

    MouseArea {
        id: rowMouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.clickable
        cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (root.clickable) root.clicked()
    }
}
