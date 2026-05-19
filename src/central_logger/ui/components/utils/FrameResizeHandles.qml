import QtQuick
import QtQuick.Window

/*
 * Invisible edge/corner hit targets for frameless windows.
 * Uses Window.startSystemResize (Qt 5.15+) when not maximized.
 *
 * Top edge and top corners are omitted so the custom title bar (AppTopBar)
 * keeps normal clicks; left/right/bottom + bottom corners still resize.
 */
Item {
    id: root

    anchors.fill: parent

    readonly property Window hostWindow: Window.window
    readonly property bool allowResize: hostWindow && hostWindow.visibility !== Window.Maximized
    readonly property int margin: 6

    function _startResize(edges) {
        if (!allowResize || !hostWindow || !hostWindow.startSystemResize)
            return
        hostWindow.startSystemResize(edges)
    }

    MouseArea {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.margin
        enabled: root.allowResize
        hoverEnabled: true
        cursorShape: Qt.SizeHorCursor
        onPressed: function (mouse) {
            if (mouse.button === Qt.LeftButton)
                root._startResize(Qt.LeftEdge)
        }
    }
    MouseArea {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.margin
        enabled: root.allowResize
        hoverEnabled: true
        cursorShape: Qt.SizeHorCursor
        onPressed: function (mouse) {
            if (mouse.button === Qt.LeftButton)
                root._startResize(Qt.RightEdge)
        }
    }
    MouseArea {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.margin * 2
        anchors.rightMargin: root.margin * 2
        height: root.margin
        enabled: root.allowResize
        hoverEnabled: true
        cursorShape: Qt.SizeVerCursor
        onPressed: function (mouse) {
            if (mouse.button === Qt.LeftButton)
                root._startResize(Qt.BottomEdge)
        }
    }

    MouseArea {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        width: root.margin * 2
        height: root.margin * 2
        enabled: root.allowResize
        hoverEnabled: true
        cursorShape: Qt.SizeBDiagCursor
        onPressed: function (mouse) {
            if (mouse.button === Qt.LeftButton)
                root._startResize(Qt.LeftEdge | Qt.BottomEdge)
        }
    }
    MouseArea {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: root.margin * 2
        height: root.margin * 2
        enabled: root.allowResize
        hoverEnabled: true
        cursorShape: Qt.SizeFDiagCursor
        onPressed: function (mouse) {
            if (mouse.button === Qt.LeftButton)
                root._startResize(Qt.RightEdge | Qt.BottomEdge)
        }
    }
}
