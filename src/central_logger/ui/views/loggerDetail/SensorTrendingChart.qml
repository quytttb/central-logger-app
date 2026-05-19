import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qaterial 1.0 as Qaterial

import "../../"
import "../../components/charts"
import "../../components/common"

Rectangle {
    id: root

    property bool isDark: true
    property int loggerId: -1
    property var dashboardController: null
    property var sensorList: []

    property var seriesData: []
    property var seriesLabels: []
    property real seriesMin: 0
    property real seriesMax: 1

    readonly property var orderedSensorIds: SensorPalette.orderedSensorIds(sensorList)

    function seriesColor(sensorId) {
        return SensorPalette.colorForSensorId(sensorId, orderedSensorIds)
    }

    function refresh() {
        if (!dashboardController || loggerId < 0) {
            seriesData = []
            seriesLabels = []
            if (chart && chart.canvas) chart.canvas.requestPaint()
            return
        }
        try {
            var raw = dashboardController.getSensorTrendingPollChart(loggerId, 120)
            var parsed = JSON.parse(raw || "{\"series\":[],\"labels\":[]}")
            var series = parsed.series || []
            seriesLabels = parsed.labels || []
            seriesData = series
            // global min/max for shared y-axis
            var mn = Number.POSITIVE_INFINITY, mx = Number.NEGATIVE_INFINITY
            for (var i = 0; i < series.length; ++i) {
                var v = series[i].values || []
                for (var j = 0; j < v.length; ++j) {
                    if (v[j] < mn) mn = v[j]
                    if (v[j] > mx) mx = v[j]
                }
            }
            if (!isFinite(mn) || !isFinite(mx) || mn === mx) { mn = 0; mx = 1 }
            seriesMin = mn
            seriesMax = mx
            if (chart) {
                chart.pointCount = seriesLabels.length > 0 ? seriesLabels.length : 1
                chart.minLabelWidthX = chart.pointCount > 60 ? 48 : 52
                chart.maxYDigits = Math.max(3, String(Math.round(mx)).length + 1)
                if (chart.canvas) chart.canvas.requestPaint()
            }
        } catch (e) {
            console.warn("trending chart parse error", e)
        }
    }

    onLoggerIdChanged: refresh()
    Component.onCompleted: refresh()

    Connections {
        target: root.dashboardController
        ignoreUnknownSignals: true
        function onSensorsUpdated(id, jsonStr) {
            if (id === root.loggerId) root.refresh()
        }
    }

    radius: 12
    color: isDark ? "#09090b" : "#ffffff"

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: "transparent"
        border.width: 1
        border.color: root.isDark ? "#27272a" : "#e4e4e7"
        z: 10
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            color: "transparent"
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: root.isDark ? "#27272a" : "#f4f4f5"
            }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 24
                anchors.rightMargin: 24
                Qaterial.LabelBody1 {
                    text: "Trending History"
                    color: root.isDark ? "#fafafa" : "#18181b"
                    font.family: "Inter"
                    font.pixelSize: 18
                    font.weight: Font.Medium
                    Layout.fillWidth: true
                }
                Qaterial.LabelCaption {
                    text: "Per poll · last ~120 readings"
                    color: root.isDark ? "#a1a1aa" : "#71717a"
                    font.family: "Inter"
                    font.pixelSize: 12
                }
            }
        }

        Item {
            id: chartArea
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 8

            property real tooltipX: 0
            property real tooltipY: 8

            function updateTooltipPosition() {
                var idx = chart.hoveredIndex
                if (idx < 0 || !root.seriesData || root.seriesData.length === 0) return
                var oY = chart.cOY
                var chartH = chart.cChartH
                var rng = Math.max(1e-9, root.seriesMax - root.seriesMin)
                var anchorY = oY + chartH
                for (var i = 0; i < root.seriesData.length; ++i) {
                    var arr = root.seriesData[i].values || []
                    if (idx >= arr.length) continue
                    var norm = (arr[idx] - root.seriesMin) / rng
                    var y = oY + chartH - norm * chartH
                    if (y < anchorY) anchorY = y
                }
                var hx = chart.cOX + idx * chart.cStepX
                tooltipX = Math.min(Math.max(8, hx + 12), width - chartTooltip.width - 8)
                var ty = anchorY - chartTooltip.height - 10
                tooltipY = Math.max(oY + 4, Math.min(ty, oY + chartH - chartTooltip.height - 4))
            }

            BaseChart {
                id: chart
                anchors.fill: parent
                isDark: root.isDark
                pointCount: root.seriesLabels.length > 0 ? root.seriesLabels.length : 1
                minLabelWidthX: pointCount > 60 ? 48 : 52
                maxYDigits: Math.max(3, String(Math.round(root.seriesMax)).length + 1)

                canvas.onPaint: {
                    var ctx = canvas.getContext("2d")
                    ctx.clearRect(0, 0, canvas.width, canvas.height)

                    var chartH = chart.cChartH
                    var oX = chart.cOX
                    var oY = chart.cOY
                    var n = chart.pointCount
                    var stepX = chart.cStepX

                    canvas.drawGrid(ctx)

                    var minV = root.seriesMin
                    var maxV = root.seriesMax
                    var rng = Math.max(1e-9, maxV - minV)
                    var yCount = chart.effectiveYAxisLabelsCount

                    ctx.font = '10px "Inter", sans-serif'
                    ctx.fillStyle = root.isDark ? "#52525b" : "#a1a1aa"
                    for (var g = 0; g <= yCount; g++) {
                        var gy = oY + chartH - (g / yCount) * chartH
                        var lv = minV + (g / yCount) * rng
                        ctx.fillText(lv.toFixed(1), 2, gy + 4)
                    }
                    var labels = root.seriesLabels
                    var xTicks = chart.xTickIndices()
                    ctx.textAlign = "center"
                    for (var ti = 0; ti < xTicks.length; ++ti) {
                        var xl = xTicks[ti]
                        if (xl >= labels.length) continue
                        ctx.fillText(labels[xl], oX + xl * stepX, oY + chartH + 14)
                    }
                    ctx.textAlign = "start"

                    var data = root.seriesData
                    if (!data || data.length === 0) return

                    function drawSeries(arr, color) {
                        ctx.beginPath()
                        var started = false
                        for (var i = 0; i < n && i < arr.length; i++) {
                            var px = oX + i * stepX
                            var norm = (arr[i] - minV) / rng
                            var py = oY + chartH - norm * chartH
                            if (!started) { ctx.moveTo(px, py); started = true }
                            else ctx.lineTo(px, py)
                        }
                        ctx.strokeStyle = color
                        ctx.lineWidth = 2
                        ctx.stroke()
                    }

                    for (var s = 0; s < data.length; ++s) {
                        drawSeries(data[s].values || [], root.seriesColor(data[s].sensorId))
                    }

                    if (chart.hoveredIndex >= 0 && chart.hoveredIndex < n) {
                        var hx = oX + chart.hoveredIndex * stepX
                        ctx.globalAlpha = chart.hoverCrosshairOpacity
                        ctx.strokeStyle = root.isDark ? "rgba(255,255,255,0.2)" : "rgba(0,0,0,0.15)"
                        ctx.lineWidth = 1
                        ctx.setLineDash([4, 3])
                        ctx.beginPath()
                        ctx.moveTo(hx, oY)
                        ctx.lineTo(hx, oY + chartH)
                        ctx.stroke()
                        ctx.setLineDash([])

                        for (var k = 0; k < data.length; ++k) {
                            var arrK = data[k].values || []
                            if (chart.hoveredIndex >= arrK.length) continue
                            var normK = (arrK[chart.hoveredIndex] - minV) / rng
                            var dy = oY + chartH - normK * chartH
                            ctx.fillStyle = root.seriesColor(data[k].sensorId)
                            ctx.beginPath()
                            ctx.arc(hx, dy, 4, 0, Math.PI * 2)
                            ctx.fill()
                        }
                        ctx.globalAlpha = 1.0
                    }
                }

                onHoveredIndexChanged: chartArea.updateTooltipPosition()
                onCChartHChanged: chartArea.updateTooltipPosition()
                onCChartWChanged: chartArea.updateTooltipPosition()
            }

            Rectangle {
                id: chartTooltip
                width: stCol.implicitWidth + 24
                height: stCol.implicitHeight + 16
                radius: 8
                color: root.isDark ? "#18181b" : "#ffffff"
                border.width: 1
                border.color: root.isDark ? "#27272a" : "#e4e4e7"
                z: 20
                x: chartArea.tooltipX
                y: chartArea.tooltipY
                opacity: chart.hoveredIndex >= 0 ? 1.0 : 0.0
                enabled: opacity > 0
                Behavior on opacity { NumberAnimation { duration: UiMotion.durationFast; easing.type: UiMotion.easingOut } }
                Behavior on x { NumberAnimation { duration: UiMotion.durationFast; easing.type: UiMotion.easingOut } }
                Behavior on y { NumberAnimation { duration: UiMotion.durationFast; easing.type: UiMotion.easingOut } }

                onHeightChanged: chartArea.updateTooltipPosition()

                ColumnLayout {
                    id: stCol
                    anchors.centerIn: parent
                    spacing: 3
                    Qaterial.LabelCaption {
                        text: chart.hoveredIndex >= 0 && chart.hoveredIndex < root.seriesLabels.length
                            ? root.seriesLabels[chart.hoveredIndex]
                            : ""
                        color: root.isDark ? "#a1a1aa" : "#71717a"
                        font.family: "Inter"
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }
                    Repeater {
                        model: root.seriesData
                        delegate: Row {
                            spacing: 4
                            Rectangle {
                                width: 6; height: 6; radius: 3
                                color: root.seriesColor(modelData.sensorId)
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Qaterial.LabelCaption {
                                text: (modelData.label || ("S" + modelData.sensorId)) + ": "
                                    + (chart.hoveredIndex >= 0 && modelData.values && chart.hoveredIndex < modelData.values.length
                                        ? Number(modelData.values[chart.hoveredIndex]).toFixed(2)
                                        : "")
                                color: root.isDark ? "#fafafa" : "#18181b"
                                font.pixelSize: 10
                            }
                        }
                    }
                }
            }
        }
    }
}
