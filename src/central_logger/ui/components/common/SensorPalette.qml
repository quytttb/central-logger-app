pragma Singleton
import QtQuick

/*
 * Shared sensor colors for SensorMonitoringTable (all sensors) and
 * SensorTrendingChart (analog only). Tailwind ~500–600 hues for light/dark surfaces.
 */
QtObject {
    readonly property var colors: [
        "#3b82f6",  // blue
        "#10b981",  // emerald
        "#f97316",  // orange
        "#ef4444",  // red
        "#8b5cf6",  // violet
        "#eab308",  // amber
        "#06b6d4",  // cyan
        "#ec4899",  // pink
        "#84cc16",  // lime
        "#6366f1",  // indigo
        "#14b8a6",  // teal
        "#f43f5e",  // rose
        "#0ea5e9",  // sky
        "#d946ef",  // fuchsia
        "#64748b"   // slate
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

    function _isDigitalType(sensorType) {
        var st = (sensorType || "").toUpperCase()
        return st === "DI" || st === "DO"
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

    function orderedAnalogSensorIds(sensorList) {
        var ids = []
        if (!sensorList) return ids
        for (var i = 0; i < sensorList.length; ++i) {
            var s = sensorList[i]
            if (!s || _isDigitalType(s.sensor_type))
                continue
            var sid = s.sensor_id
            if (sid !== undefined && sid !== null)
                ids.push(sid)
        }
        return ids
    }
}
