.pragma library

function findModelRow(loggersModel, loggerId) {
    if (!loggersModel) return null
    for (var i = 0; i < loggersModel.count(); ++i) {
        var it = loggersModel.itemAt(i)
        if (it && it.loggerId === loggerId) return it
    }
    return null
}

function rebuildDetail(detail, row, loggerId) {
    if (!row) {
        var copy = {}
        for (var k in detail) copy[k] = detail[k]
        copy.loggerId = loggerId
        copy.loggerName = "Logger #" + loggerId
        return copy
    }
    var sensors = detail.sensorList || []
    return {
        loggerId: row.loggerId,
        loggerName: row.name,
        host: row.host,
        port: row.port,
        unitId: row.unitId,
        pollIntervalS: row.pollIntervalS !== undefined ? row.pollIntervalS : 2,
        timeoutS: row.timeoutS !== undefined ? row.timeoutS : 2.0,
        enabled: row.enabled !== undefined ? row.enabled : true,
        note: row.note || "",
        apiPort: row.apiPort !== undefined ? row.apiPort : 8080,
        apiBaseUrl: row.apiBaseUrl || "",
        sensorCount: row.sensorCount,
        online: row.online,
        polling: row.polling,
        rtuConnected: row.rtuConnected,
        anyAlarm: row.anyAlarm,
        currentRevision: detail.currentRevision !== undefined ? detail.currentRevision : -1,
        lastRevision: detail.lastRevision !== undefined ? detail.lastRevision : -1,
        statusText: row.lastError || (row.online ? "Online" : "Offline"),
        sensorList: sensors,
        configForm: detail.configForm,
        cloudForm: detail.cloudForm,
        rawConfig: detail.rawConfig,
        catalogError: detail.catalogError || ""
    }
}

function applySensorsPayload(detail, payload) {
    var list = []
    for (var i = 0; i < payload.sensors.length; ++i) {
        var s = payload.sensors[i]
        var st = s.sensor_type || ""
        var displayName = (s.name && s.name.length > 0)
            ? s.name
            : (st ? (st + " #" + s.sensor_id) : ("Sensor " + s.sensor_id))
        list.push({
            sensor_id: s.sensor_id,
            name: displayName,
            type: displayName,
            sensor_type: st,
            unit: s.unit || "",
            active: s.active !== undefined ? !!s.active : true,
            timestamp: payload.iso ? payload.iso.substring(11, 19) : "",
            value: s.value,
            valid: s.valid,
            alarm: s.alarm,
            stale: s.stale,
            display_status: s.display_status || "",
            alarm_type: s.alarm_type || "",
            rest_status: s.rest_status || ""
        })
    }
    var out = {}
    for (var k in detail) out[k] = detail[k]
    out.sensorList = list
    out.sensorCount = list.length
    out.polling = payload.polling
    out.rtuConnected = payload.rtu_connected
    out.anyAlarm = payload.any_alarm
    return out
}

function hydrateDetailFromDb(detail, db) {
    if (!db.loggerId) return detail
    var out = {}
    for (var k in detail) out[k] = detail[k]
    out.timeoutS = db.timeoutS !== undefined ? db.timeoutS : detail.timeoutS
    out.note = db.note !== undefined ? db.note : detail.note
    out.apiPort = db.apiPort !== undefined ? db.apiPort : detail.apiPort
    out.apiBaseUrl = db.apiBaseUrl !== undefined ? db.apiBaseUrl : detail.apiBaseUrl
    out.lastRevision = db.lastRevision !== undefined ? db.lastRevision : -1
    var cloud = detail.cloudForm ? detail.cloudForm : {}
    out.cloudForm = {
        apiToken: db.apiToken !== undefined ? db.apiToken : (cloud.apiToken || ""),
        apiPort: db.apiPort !== undefined ? db.apiPort : (cloud.apiPort || 8080)
    }
    return out
}

function effectiveConfigRevision(detail) {
    if (detail.currentRevision !== undefined && detail.currentRevision >= 0)
        return detail.currentRevision
    if (detail.lastRevision !== undefined && detail.lastRevision >= 0)
        return detail.lastRevision
    return -1
}

function parseJsonSafe(jsonStr, fallback) {
    try {
        return JSON.parse(jsonStr || "")
    } catch (e) {
        return fallback
    }
}

function mergeConfigFetched(detail, payloadJson) {
    var p = parseJsonSafe(payloadJson, null)
    if (!p) return { detail: detail, error: "Invalid config response" }
    var cfg = p.config || {}
    var cloud = detail.cloudForm ? detail.cloudForm : {}
    var merged = {}
    for (var k in detail) merged[k] = detail[k]
    merged.catalogError = ""
    merged.currentRevision = p.revision !== null && p.revision !== undefined ? p.revision : -1
    merged.lastRevision = merged.currentRevision >= 0 ? merged.currentRevision : detail.lastRevision
    merged.configForm = {
        station_code: cfg.station_code || "—",
        station_name: cfg.station_name || "",
        poll_interval: cfg.poll_interval || 0,
        modbus_tcp_bind: cfg.modbus_tcp_bind || "",
        modbus_tcp_enabled: !!cfg.modbus_tcp_enabled,
        modbus_tcp_unit_id: cfg.modbus_tcp_unit_id !== undefined ? cfg.modbus_tcp_unit_id : 1
    }
    merged.cloudForm = {
        apiToken: p.api_token !== undefined ? p.api_token : (cloud.apiToken || ""),
        apiPort: p.api_port !== undefined ? p.api_port : (cloud.apiPort || 8080)
    }
    merged.apiPort = p.api_port !== undefined ? p.api_port : detail.apiPort
    merged.apiBaseUrl = p.api_base_url !== undefined ? p.api_base_url : detail.apiBaseUrl
    merged.rawConfig = cfg
    return { detail: merged, error: "" }
}

function configFetchedErrorMessage(payloadJson, defaultMsg) {
    var p = parseJsonSafe(payloadJson, null)
    if (!p) return defaultMsg
    if (p.errors && p.errors.length > 0) return p.errors[0].message
    return p.message || defaultMsg
}

function mergeConfigApplied(detail, payloadJson) {
    var p = parseJsonSafe(payloadJson, null)
    if (!p || !p.ok) return detail
    var merged = {}
    for (var k in detail) merged[k] = detail[k]
    if (p.applied_revision !== null && p.applied_revision !== undefined)
        merged.currentRevision = p.applied_revision
    return merged
}
