import QtQuick

import "../.."

/*
 * BaseChart — Canvas chart shell.
 * Trục X/Y: số tick tự điều chỉnh theo cChartW / cChartH (độ dày vùng vẽ).
 */
Item {
    id: chartRoot

    property bool isDark: true
    property int minLabelWidthX: 52
    property int minLabelHeightY: 28
    property int yLabelCharWidth: 7
    property int maxYDigits: 4
    property int topPadding: 10
    property int rightPadding: 10
    property int bottomMargin: 30
    property int pointCount: 24

    readonly property int effectiveYAxisLabelsCount: {
        var n = Math.floor(cChartH / minLabelHeightY)
        return Math.max(3, Math.min(8, n))
    }
    readonly property int xTickCount: {
        if (pointCount <= 1) return pointCount
        var fit = Math.floor(cChartW / minLabelWidthX)
        return Math.max(2, Math.min(pointCount, fit))
    }
    readonly property int xTickStep: {
        if (pointCount <= 1) return 1
        return Math.max(1, Math.round((pointCount - 1) / Math.max(1, xTickCount - 1)))
    }
    readonly property real xMargin: Math.max(36, yLabelCharWidth * maxYDigits + 8)
    readonly property int yMargin: bottomMargin

    readonly property real cOX: xMargin
    readonly property real cOY: topPadding
    readonly property real cChartW: Math.max(0, width - xMargin - rightPadding)
    readonly property real cChartH: Math.max(0, height - topPadding - yMargin)
    readonly property real cStepX: pointCount > 1 ? cChartW / (pointCount - 1) : cChartW

    property int hoveredIndex: -1
    property real hoverCrosshairOpacity: hoveredIndex >= 0 ? 1.0 : 0.0

    signal requestPaint()

    property alias canvas: canvasItem

    function xTickIndices() {
        var indices = []
        if (pointCount <= 0) return indices
        if (pointCount === 1) return [0]
        for (var i = 0; i < pointCount; i += xTickStep)
            indices.push(i)
        if (indices.length === 0 || indices[indices.length - 1] !== pointCount - 1)
            indices.push(pointCount - 1)
        return indices
    }

    Behavior on hoverCrosshairOpacity {
        NumberAnimation {
            duration: UiMotion.durationFast
            easing.type: UiMotion.easingOut
        }
    }

    onHoverCrosshairOpacityChanged: canvasItem.requestPaint()
    onPointCountChanged: canvasItem.requestPaint()
    onEffectiveYAxisLabelsCountChanged: canvasItem.requestPaint()

    Rectangle {
        x: chartRoot.cOX
        y: chartRoot.cOY
        width: chartRoot.cChartW
        height: chartRoot.cChartH
        radius: 4
        color: chartRoot.isDark ? "#ffffff" : "#000000"
        opacity: chartRoot.hoveredIndex >= 0
            ? (chartRoot.isDark ? UiMotion.hoverOpacityDark : UiMotion.hoverOpacityLight)
            : 0.0
        z: 0
        Behavior on opacity {
            NumberAnimation {
                duration: UiMotion.durationFast
                easing.type: UiMotion.easingOut
            }
        }
    }

    Canvas {
        id: canvasItem
        anchors.fill: parent
        z: 1

        function drawGrid(ctx) {
            ctx.lineWidth = 1
            ctx.strokeStyle = chartRoot.isDark ? "#27272a" : "#e4e4e7"

            var yCount = chartRoot.effectiveYAxisLabelsCount
            for (var i = 0; i <= yCount; i++) {
                var gy = chartRoot.cOY + chartRoot.cChartH - (i / yCount) * chartRoot.cChartH
                ctx.beginPath()
                ctx.moveTo(chartRoot.cOX, gy)
                ctx.lineTo(chartRoot.cOX + chartRoot.cChartW, gy)
                ctx.stroke()
            }
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Component.onCompleted: requestPaint()
    }

    onCChartWChanged: canvasItem.requestPaint()
    onCChartHChanged: canvasItem.requestPaint()
    onIsDarkChanged: canvasItem.requestPaint()
    onHoveredIndexChanged: canvasItem.requestPaint()

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        z: 2

        onPositionChanged: function(mouse) {
            var inX = mouse.x >= chartRoot.cOX && mouse.x <= chartRoot.cOX + chartRoot.cChartW
            var inY = mouse.y >= chartRoot.cOY && mouse.y <= chartRoot.cOY + chartRoot.cChartH
            if (inX && inY && chartRoot.pointCount > 0) {
                var idx = Math.round((mouse.x - chartRoot.cOX) / Math.max(1, chartRoot.cStepX))
                idx = Math.max(0, Math.min(chartRoot.pointCount - 1, idx))
                if (chartRoot.hoveredIndex !== idx)
                    chartRoot.hoveredIndex = idx
            } else if (chartRoot.hoveredIndex !== -1) {
                chartRoot.hoveredIndex = -1
            }
        }
        onExited: {
            if (chartRoot.hoveredIndex !== -1)
                chartRoot.hoveredIndex = -1
        }
    }
}
