import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qaterial 1.0 as Qaterial

import "../../"
import "../../components/charts"

Rectangle {
    id: root

    property bool isDark: true
    property var dashboardController: null
    property var chartData: []
    property real maxReadings: 1
    property int bucketMinutes: 5

    function refresh() {
        if (!dashboardController) return
        try {
            var raw = dashboardController.getIngestionChart24h()
            var parsed = JSON.parse(raw || "{}")
            var data = parsed.buckets || parsed
            if (!Array.isArray(data)) data = []
            bucketMinutes = parsed.bucketMinutes > 0 ? parsed.bucketMinutes : 5
            chartData = data
            var m = 1
            for (var i = 0; i < data.length; ++i)
                if (data[i].readings > m) m = data[i].readings
            maxReadings = m
            if (chart) {
                chart.pointCount = data.length > 0 ? data.length : 24
                if (chart.canvas) chart.canvas.requestPaint()
            }
        } catch (e) {
            console.warn("ingestion chart load error", e)
        }
    }

    Connections {
        target: root.dashboardController
        ignoreUnknownSignals: true
        function onAppStatsChanged() { root.refresh() }
        function onSnapshotApplied(id, ok, info) { root.refresh() }
    }
    Component.onCompleted: refresh()

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
                    text: "Network Traffic"
                    color: root.isDark ? "#fafafa" : "#18181b"
                    font.family: "Inter"
                    font.pixelSize: 18
                    font.weight: Font.Medium
                    Layout.fillWidth: true
                }
                Qaterial.LabelCaption {
                    text: "Readings per 5 min · last 24h"
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
                if (idx < 0)
                    return
                var data = root.chartData
                if (!data || idx >= data.length)
                    return

                var maxVal = Math.max(1, root.maxReadings)
                var oY = chart.cOY
                var chartH = chart.cChartH
                var dlY = oY + chartH - (data[idx].readings / maxVal) * chartH
                var ulY = oY + chartH - (data[idx].activeLoggers / Math.max(1, maxVal)) * chartH
                var anchorY = Math.min(dlY, ulY)

                var hx = chart.cOX + idx * chart.cStepX
                tooltipX = Math.min(Math.max(8, hx + 12), width - chartTooltip.width - 8)

                var ty = anchorY - chartTooltip.height - 10
                tooltipY = Math.max(oY + 4, Math.min(ty, oY + chartH - chartTooltip.height - 4))
            }

            BaseChart {
                id: chart
                anchors.fill: parent
                isDark: root.isDark
                pointCount: root.chartData.length > 0 ? root.chartData.length : 288
                maxYDigits: String(Math.round(root.maxReadings)).length

                canvas.onPaint: {
                    var ctx = canvas.getContext("2d")
                    ctx.clearRect(0, 0, canvas.width, canvas.height)

                    var data = root.chartData
                    if (!data || data.length === 0)
                        return

                    var chartH = chart.cChartH
                    var oX = chart.cOX
                    var oY = chart.cOY
                    var maxVal = Math.max(1, root.maxReadings)
                    var n = data.length
                    var stepX = chart.cStepX
                    var yCount = chart.effectiveYAxisLabelsCount

                    canvas.drawGrid(ctx)

                    ctx.font = '11px "Inter", sans-serif'
                    ctx.fillStyle = root.isDark ? "#71717a" : "#a1a1aa"
                    for (var g = 0; g <= yCount; g++) {
                        var gy = oY + chartH - (g / yCount) * chartH
                        ctx.fillText(String(Math.round(maxVal * g / yCount)), 2, gy + 4)
                    }
                    var xTicks = chart.xTickIndices()
                    ctx.textAlign = "center"
                    for (var ti = 0; ti < xTicks.length; ++ti) {
                        var xl = xTicks[ti]
                        if (xl >= n) continue
                        ctx.fillText(data[xl].hour, oX + xl * stepX, oY + chartH + 16)
                    }
                    ctx.textAlign = "start"

                    function drawArea(key, color, alpha, scale) {
                        var s = scale || maxVal
                        ctx.beginPath()
                        for (var i = 0; i < n; i++) {
                            var px = oX + i * stepX
                            var py = oY + chartH - (data[i][key] / s) * chartH
                            if (i === 0)
                                ctx.moveTo(px, py)
                            else
                                ctx.lineTo(px, py)
                        }
                        ctx.lineTo(oX + (n - 1) * stepX, oY + chartH)
                        ctx.lineTo(oX, oY + chartH)
                        ctx.closePath()
                        ctx.fillStyle = Qt.rgba(Qt.color(color).r, Qt.color(color).g, Qt.color(color).b, alpha)
                        ctx.fill()

                        ctx.beginPath()
                        for (var j = 0; j < n; j++) {
                            var lx = oX + j * stepX
                            var ly = oY + chartH - (data[j][key] / s) * chartH
                            if (j === 0)
                                ctx.moveTo(lx, ly)
                            else
                                ctx.lineTo(lx, ly)
                        }
                        ctx.strokeStyle = color
                        ctx.lineWidth = 2
                        ctx.stroke()
                    }

                    drawArea("readings", "#3b82f6", 0.15, maxVal)
                    drawArea("activeLoggers", "#10b981", 0.15, Math.max(1, maxVal))

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
                        var dlY = oY + chartH - (data[chart.hoveredIndex].readings / maxVal) * chartH
                        var ulY = oY + chartH - (data[chart.hoveredIndex].activeLoggers / Math.max(1, maxVal)) * chartH
                        ctx.fillStyle = "#3b82f6"
                        ctx.beginPath()
                        ctx.arc(hx, dlY, 4, 0, Math.PI * 2)
                        ctx.fill()
                        ctx.fillStyle = "#10b981"
                        ctx.beginPath()
                        ctx.arc(hx, ulY, 4, 0, Math.PI * 2)
                        ctx.fill()
                        ctx.globalAlpha = 1.0
                    }
                }

                onHoveredIndexChanged: chartArea.updateTooltipPosition()
                onCChartHChanged: chartArea.updateTooltipPosition()
                onCChartWChanged: chartArea.updateTooltipPosition()
            }

            Rectangle {
                id: chartTooltip
                width: ttCol.implicitWidth + 24
                height: ttCol.implicitHeight + 16
                radius: 8
                color: root.isDark ? "#18181b" : "#ffffff"
                border.width: 1
                border.color: root.isDark ? "#27272a" : "#e4e4e7"
                z: 20
                x: chartArea.tooltipX
                y: chartArea.tooltipY
                opacity: chart.hoveredIndex >= 0 ? 1.0 : 0.0
                enabled: opacity > 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: UiMotion.durationFast
                        easing.type: UiMotion.easingOut
                    }
                }
                Behavior on x {
                    NumberAnimation {
                        duration: UiMotion.durationFast
                        easing.type: UiMotion.easingOut
                    }
                }
                Behavior on y {
                    NumberAnimation {
                        duration: UiMotion.durationFast
                        easing.type: UiMotion.easingOut
                    }
                }

                onHeightChanged: chartArea.updateTooltipPosition()

                ColumnLayout {
                    id: ttCol
                    anchors.centerIn: parent
                    spacing: 4
                    Qaterial.LabelCaption {
                        text: chart.hoveredIndex >= 0 && chart.hoveredIndex < root.chartData.length ? root.chartData[chart.hoveredIndex].hour : ""
                        color: root.isDark ? "#a1a1aa" : "#71717a"
                        font.family: "Inter"
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }
                    Row {
                        spacing: 6
                        Rectangle {
                            width: 8
                            height: 8
                            radius: 4
                            color: "#3b82f6"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Qaterial.LabelCaption {
                            text: {
                                if (chart.hoveredIndex < 0 || chart.hoveredIndex >= root.chartData.length)
                                    return "Readings: —"
                                var n = root.chartData[chart.hoveredIndex].readings
                                return "Readings: " + n + " / " + root.bucketMinutes + " min"
                            }
                            color: root.isDark ? "#fafafa" : "#18181b"
                            font.family: "Inter"
                            font.pixelSize: 11
                        }
                    }
                    Row {
                        spacing: 6
                        Rectangle {
                            width: 8
                            height: 8
                            radius: 4
                            color: "#10b981"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Qaterial.LabelCaption {
                            text: "Active loggers: " + (chart.hoveredIndex >= 0 && chart.hoveredIndex < root.chartData.length ? root.chartData[chart.hoveredIndex].activeLoggers : "")
                            color: root.isDark ? "#fafafa" : "#18181b"
                            font.family: "Inter"
                            font.pixelSize: 11
                        }
                    }
                }
            }
        }
    }
}
