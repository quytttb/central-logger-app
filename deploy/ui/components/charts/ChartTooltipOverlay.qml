import QtQuick
import QtQuick.Controls

import "../.."

/*
 * Shared chart hover tooltip — content must attach via root default property (not Rectangle).
 */
Item {
    id: root

    anchors.fill: parent
    enabled: false
    z: 10

    // Children declared inside ChartTooltipOverlay { ... } land in contentSlot.
    default property alias tooltipContent: contentSlot.data

    property var chart
    property bool isDark: true
    property var anchorYAt: function(idx) { return chart ? chart.cOY : 0 }

    property real tooltipX: 0
    property real tooltipY: 8

    readonly property int hoveredIndex: chart ? chart.hoveredIndex : -1
    readonly property bool tooltipVisible: hoveredIndex >= 0

    function updatePosition() {
        if (!chart || chart.hoveredIndex < 0 || tooltipRect.width <= 0)
            return
        var idx = chart.hoveredIndex
        var anchorY = anchorYAt(idx)
        var hx = chart.cOX + idx * chart.cStepX
        tooltipX = Math.min(Math.max(8, hx + 12), width - tooltipRect.width - 8)
        var ty = anchorY - tooltipRect.height - 10
        var oY = chart.cOY
        var chartH = chart.cChartH
        tooltipY = Math.max(oY + 4, Math.min(ty, oY + chartH - tooltipRect.height - 4))
    }

    onWidthChanged: updatePosition()

    Connections {
        target: root.chart
        ignoreUnknownSignals: true
        function onHoveredIndexChanged() { root.updatePosition() }
        function onCChartHChanged() { root.updatePosition() }
        function onCChartWChanged() { root.updatePosition() }
    }

    Rectangle {
        id: tooltipRect
        width: contentSlot.childrenRect.width + 24
        height: contentSlot.childrenRect.height + 16
        radius: 8
        color: Colors.surfaceMuted(root.isDark)
        border.width: 1
        border.color: Colors.border(root.isDark)
        z: 20
        x: root.tooltipX
        y: root.tooltipY
        visible: root.tooltipVisible

        onWidthChanged: root.updatePosition()
        onHeightChanged: root.updatePosition()

        Item {
            id: contentSlot
            anchors.centerIn: parent
            width: childrenRect.width
            height: childrenRect.height
            onChildrenRectChanged: root.updatePosition()
        }
    }
}
