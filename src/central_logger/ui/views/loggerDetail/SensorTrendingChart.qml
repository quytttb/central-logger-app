import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qaterial 1.0 as Qaterial

import "../../"
import "../../components/charts"
import "../../components/common"

ChartPanel {
    id: root

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
            if (chart) chart.schedulePaint()
            return
        }
        try {
            var raw = dashboardController.pollTrendingChartJson(loggerId)
            var parsed = JSON.parse(raw || "{\"series\":[],\"labels\":[]}")
            var series = parsed.series || []
            seriesLabels = parsed.labels || []
            seriesData = series
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
                chart.schedulePaint()
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
        function onPollTrendingChartJsonChanged(id) {
            if (id === root.loggerId) root.refresh()
        }
    }

    title: "Trending History"
    subtitle: "Per poll · last ~120 readings"

    Item {
        id: chartArea
        anchors.fill: parent

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
                ctx.fillStyle = Colors.textMuted(root.isDark)
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
        }

        ChartTooltipOverlay {
            chart: chart
            isDark: root.isDark
            anchorYAt: function(idx) {
                if (!root.seriesData || root.seriesData.length === 0)
                    return chart.cOY
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
                return anchorY
            }

            ColumnLayout {
                spacing: 3
                Qaterial.LabelCaption {
                    text: chart.hoveredIndex >= 0 && chart.hoveredIndex < root.seriesLabels.length
                        ? root.seriesLabels[chart.hoveredIndex]
                        : ""
                    color: Colors.textSecondary(root.isDark)
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
                            color: Colors.textPrimary(root.isDark)
                            font.pixelSize: 10
                        }
                    }
                }
            }
        }
    }
}
