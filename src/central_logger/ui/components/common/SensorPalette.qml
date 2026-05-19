pragma Singleton
import QtQuick

/*
 * Shared sensor line colors for SensorMonitoringTable + SensorTrendingChart.
 * Index order must match backend top-sensors sort (by reading count).
 */
QtObject {
    readonly property var colors: [
        "#3b82f6",
        "#10b981",
        "#f97316",
        "#ef4444",
        "#8b5cf6",
        "#eab308"
    ]

    function colorForIndex(index) {
        if (index < 0) return "#71717a"
        return colors[index % colors.length]
    }

    function indexForSensorId(sensorId, orderedIds) {
        if (!orderedIds || orderedIds.length === 0)
            return typeof sensorId === "number" ? sensorId : 0
        for (var i = 0; i < orderedIds.length; ++i) {
            if (orderedIds[i] === sensorId)
                return i
        }
        return typeof sensorId === "number" ? sensorId : 0
    }

    function colorForSensorId(sensorId, orderedIds) {
        return colorForIndex(indexForSensorId(sensorId, orderedIds))
    }

    function orderedSensorIds(sensorList) {
        var ids = []
        if (!sensorList) return ids
        for (var i = 0; i < sensorList.length; ++i) {
            var sid = sensorList[i].sensor_id
            if (sid !== undefined && sid !== null)
                ids.push(sid)
        }
        return ids
    }
}
