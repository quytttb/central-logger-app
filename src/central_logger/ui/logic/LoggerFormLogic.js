.pragma library

function humanizeProbeError(raw) {
    var m = (raw || "").toLowerCase()
    if (m.indexOf("timeout") >= 0 || m.indexOf("timed out") >= 0)
        return "The logger did not respond in time. Check host and API port."
    if (m.indexOf("network") >= 0 || m.indexOf("connection") >= 0)
        return "Could not reach the logger. Check host, API port, and network."
    if (m.indexOf("401") >= 0 || m.indexOf("unauthorized") >= 0 || m.indexOf("token") >= 0)
        return "Invalid or missing API token."
    if (m.indexOf("404") >= 0)
        return "Logger API not available. Update data-logger firmware."
    if (m.indexOf("409") >= 0 || m.indexOf("conflict") >= 0 || m.indexOf("revision") >= 0)
        return "Configuration changed on device. Connect again, then save."
    if ((raw || "").length > 0)
        return "Could not load configuration."
    return "Could not load configuration."
}

function diff(current, original) {
    var out = {}
    for (var key in current) {
        if (current[key] !== original[key]) out[key] = current[key]
    }
    return out
}

function connectionSnapshotFromFields(fields) {
    var ap = parseInt(fields.apiPort)
    var p = parseInt(fields.port)
    var u = parseInt(fields.unit)
    var t = parseFloat(fields.timeout)
    return {
        loggerName: (fields.name || "").trim(),
        note: (fields.note || "").trim(),
        host: (fields.host || "").trim(),
        port: isNaN(p) ? 5020 : p,
        unitId: isNaN(u) ? 1 : u,
        timeoutS: isNaN(t) ? 2.0 : t,
        apiPort: isNaN(ap) ? 8080 : ap,
        apiBaseUrl: (fields.apiBaseUrl || "").trim(),
        cloudForm: {
            apiToken: fields.token || "",
            apiPort: isNaN(ap) ? 8080 : ap
        }
    }
}

function buildEditPatch(mode, detail, online, fields) {
    var d = detail
    var cf = d.configForm || {}
    var raw = d.rawConfig || {}
    var pollDev = parseInt(fields.pollDevice)
    var apiPort = parseInt(fields.apiPort)
    var timeoutVal = parseFloat(fields.timeout)
    var pollDevConn = parseInt(fields.pollDevice)

    var connection = {
        name: (fields.name || "").trim(),
        host: (fields.host || "").trim(),
        port: parseInt(fields.port) || 5020,
        unitId: parseInt(fields.unit) || 1,
        pollIntervalS: isNaN(pollDevConn) ? (d.pollIntervalS || 2) : pollDevConn,
        timeoutS: isNaN(timeoutVal) ? 2.0 : timeoutVal,
        note: (fields.note || "").trim()
    }

    var cloudCurrent = {
        apiToken: fields.token,
        apiPort: isNaN(apiPort) ? (d.cloudForm ? (d.cloudForm.apiPort || 8080) : 8080) : apiPort,
        apiBaseUrl: (fields.apiBaseUrl || "").trim()
    }
    var cloudOriginal = {
        apiToken: d.cloudForm ? (d.cloudForm.apiToken || "") : "",
        apiPort: d.cloudForm ? (d.cloudForm.apiPort || 8080) : 8080,
        apiBaseUrl: d.apiBaseUrl || ""
    }

    var configPatch = {}
    if (mode === "edit" && !!online) {
        var edgeUnitId = parseInt(fields.unitIdDevice)
        var configCurrent = {
            station_code: (fields.stationCode || "").trim(),
            station_name: (fields.stationName || "").trim(),
            modbus_tcp_bind: fields.bind,
            modbus_tcp_enabled: fields.modbusTcpEnabled,
            modbus_tcp_unit_id: isNaN(edgeUnitId) ? (cf.modbus_tcp_unit_id || 1) : edgeUnitId,
            poll_interval: isNaN(pollDev) ? (cf.poll_interval || 0) : pollDev
        }
        var configOriginal = {
            station_code: cf.station_code || raw.station_code || "",
            station_name: cf.station_name || raw.station_name || "",
            modbus_tcp_bind: raw.modbus_tcp_bind || cf.modbus_tcp_bind || "",
            modbus_tcp_enabled: cf.modbus_tcp_enabled !== undefined
                ? !!cf.modbus_tcp_enabled
                : !!raw.modbus_tcp_enabled,
            modbus_tcp_unit_id: cf.modbus_tcp_unit_id !== undefined
                ? cf.modbus_tcp_unit_id
                : (raw.modbus_tcp_unit_id !== undefined ? raw.modbus_tcp_unit_id : 1),
            poll_interval: cf.poll_interval || 0
        }
        configPatch = diff(configCurrent, configOriginal)
    }

    return {
        connection: connection,
        config: configPatch,
        cloud: diff(cloudCurrent, cloudOriginal)
    }
}

function parseProbeSuccess(jsonStr, snap) {
    var p = JSON.parse(jsonStr || "{}")
    if (!p.ok) {
        var errMsg = ""
        if (p.errors && p.errors.length > 0 && p.errors[0].message)
            errMsg = p.errors[0].message
        else if (p.message)
            errMsg = p.message
        return { ok: false, error: errMsg || "Connect failed" }
    }
    var cfg = p.config || {}
    var detail = Object.assign({}, snap, {
        configForm: {
            station_code: cfg.station_code || "",
            station_name: cfg.station_name || "",
            poll_interval: cfg.poll_interval !== undefined ? cfg.poll_interval : 0,
            modbus_tcp_bind: cfg.modbus_tcp_bind || "",
            modbus_tcp_enabled: !!cfg.modbus_tcp_enabled,
            modbus_tcp_unit_id: cfg.modbus_tcp_unit_id !== undefined ? cfg.modbus_tcp_unit_id : 1
        },
        rawConfig: cfg,
        currentRevision: p.revision !== null && p.revision !== undefined ? p.revision : -1
    })
    return { ok: true, detail: detail, revision: detail.currentRevision }
}

function parseConfigFetched(id, payloadJson, snap) {
    var p = JSON.parse(payloadJson)
    var cfg = p.config || {}
    var apiTok = p.api_token !== undefined ? p.api_token : (snap.cloudForm ? snap.cloudForm.apiToken : "")
    var apiP = p.api_port !== undefined ? p.api_port : snap.apiPort
    var detail = Object.assign({}, snap, {
        loggerId: id,
        apiPort: apiP,
        apiBaseUrl: p.api_base_url !== undefined ? p.api_base_url : snap.apiBaseUrl,
        cloudForm: {
            apiToken: apiTok,
            apiPort: apiP
        },
        configForm: {
            station_code: cfg.station_code || "",
            station_name: cfg.station_name || "",
            poll_interval: cfg.poll_interval || 0,
            modbus_tcp_bind: cfg.modbus_tcp_bind || "",
            modbus_tcp_enabled: !!cfg.modbus_tcp_enabled,
            modbus_tcp_unit_id: cfg.modbus_tcp_unit_id !== undefined ? cfg.modbus_tcp_unit_id : 1
        },
        rawConfig: cfg,
        currentRevision: p.revision !== null && p.revision !== undefined ? p.revision : -1
    })
    return detail
}
