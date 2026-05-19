import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import Qaterial 1.0 as Qaterial

import "../.."

/*
 * Unified Add / Edit logger form — 2-column desktop layout.
 * mode "add"  : Left column (Central) editable; Right column (Device) shows hint.
 * mode "edit" : Left editable always; Right editable only when logger online.
 */
BaseDialog {
    id: dialog

    preferredWidth: 940
    property string mode: "add"  // "add" | "edit"
    property var detail: ({})
    property var dashboardController: null
    property bool configLoaded: false
    property string probeStatus: ""
    property string probeStatusKind: "idle"  // idle | loading | success | error
    property int probedRevision: -1

    readonly property color probeStatusColor: {
        if (probeStatusKind === "success")
            return dialog.isDark ? "#86efac" : "#166534"
        if (probeStatusKind === "error")
            return dialog.isDark ? "#fca5a5" : "#dc2626"
        return dialog.isDark ? "#a1a1aa" : "#71717a"
    }

    signal addRequested(var formData)
    signal saved(var patch)

    title: mode === "add" ? "Add Edge Logger" : "Edit Logger"

    // Device fields: sau Connect & Load (Add) hoặc Edit khi online.
    readonly property bool deviceEditable: configLoaded
        || (mode === "edit" && !!detail.online)
    readonly property bool qrScanEnabled: !dashboardController || dashboardController.qrScanAvailable()

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

    function setProbeLoading() {
        probeStatusKind = "loading"
        probeStatus = "Connecting…"
    }

    function setProbeSuccess() {
        probeStatusKind = "success"
        probeStatus = "Configuration loaded successfully."
    }

    function setProbeError(raw) {
        probeStatusKind = "error"
        probeStatus = humanizeProbeError(raw)
    }

    function connectionSnapshotFromFields() {
        var ap = parseInt(apiPortField.value)
        var p = parseInt(portField.value)
        var u = parseInt(unitField.value)
        var t = parseFloat(timeoutField.value)
        return {
            loggerName: (nameField.value || "").trim(),
            note: (noteField.value || "").trim(),
            host: (hostField.value || "").trim(),
            port: isNaN(p) ? 5020 : p,
            unitId: isNaN(u) ? 1 : u,
            timeoutS: isNaN(t) ? 2.0 : t,
            apiPort: isNaN(ap) ? 8080 : ap,
            apiBaseUrl: (apiBaseUrlField.value || "").trim(),
            cloudForm: {
                apiToken: tokenField.value || "",
                apiPort: isNaN(ap) ? 8080 : ap
            }
        }
    }

    function clearAllFieldFocus() {
        nameField.clearFocus()
        noteField.clearFocus()
        hostField.clearFocus()
        portField.clearFocus()
        unitField.clearFocus()
        timeoutField.clearFocus()
        apiPortField.clearFocus()
        tokenField.clearFocus()
        apiBaseUrlField.clearFocus()
        stationCodeField.clearFocus()
        stationNameField.clearFocus()
        bindField.clearFocus()
        pollDeviceField.clearFocus()
        unitIdDeviceField.clearFocus()
    }

    function loadFromDetail(d) {
        detail = d || {}
        nameField.setValue(detail.loggerName || "")
        noteField.setValue(detail.note || "")
        hostField.setValue(detail.host || "")
        portField.setValue(detail.port !== undefined ? String(detail.port) : "5020")
        unitField.setValue(detail.unitId !== undefined ? String(detail.unitId) : "1")
        timeoutField.setValue(detail.timeoutS !== undefined ? String(detail.timeoutS) : "2.0")
        apiPortField.setValue(detail.apiPort !== undefined ? String(detail.apiPort) : "8080")
        tokenField.setValue(detail.cloudForm ? (detail.cloudForm.apiToken || "") : "")
        apiBaseUrlField.setValue(detail.apiBaseUrl || "")

        var cf = detail.configForm || {}
        var raw = detail.rawConfig || {}
        stationCodeField.setValue(cf.station_code || raw.station_code || "")
        stationNameField.setValue(cf.station_name || raw.station_name || "")
        bindField.setValue(raw.modbus_tcp_bind || cf.modbus_tcp_bind || "")
        pollDeviceField.setValue(cf.poll_interval !== undefined ? String(cf.poll_interval) : "")
        modbusTcpEnabledCheck.checked = cf.modbus_tcp_enabled !== undefined
            ? !!cf.modbus_tcp_enabled
            : !!raw.modbus_tcp_enabled
        var edgeUnit = cf.modbus_tcp_unit_id !== undefined ? cf.modbus_tcp_unit_id : raw.modbus_tcp_unit_id
        unitIdDeviceField.setValue(edgeUnit !== undefined ? String(edgeUnit) : "")
        configLoaded = !!(cf.station_code || raw.station_code || cf.poll_interval)
    }

    function loadFromProbeResult(jsonStr) {
        var snap = connectionSnapshotFromFields()
        try {
            var p = JSON.parse(jsonStr || "{}")
            if (!p.ok) {
                configLoaded = false
                var errMsg = ""
                if (p.errors && p.errors.length > 0 && p.errors[0].message)
                    errMsg = p.errors[0].message
                else if (p.message)
                    errMsg = p.message
                setProbeError(errMsg || "Connect failed")
                return
            }
            var cfg = p.config || {}
            detail = Object.assign({}, detail, snap, {
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
            probedRevision = detail.currentRevision
            loadFromDetail(detail)
            configLoaded = true
            setProbeSuccess()
        } catch (e) {
            configLoaded = false
            setProbeError("Invalid response")
            console.warn("loadFromProbeResult:", e)
        }
    }

    function connectAndLoadConfig() {
        if (!dashboardController) {
            setProbeError("Controller unavailable")
            return
        }
        setProbeLoading()
        configLoaded = false
        var lid = detail.loggerId !== undefined ? detail.loggerId : -1
        if (mode === "edit" && lid >= 0) {
            dashboardController.fetchConfig(lid)
            return
        }
        var h = (hostField.value || "").trim()
        var tok = tokenField.value || ""
        var ap = parseInt(apiPortField.value)
        dashboardController.probeEdgeConfig(
            h,
            isNaN(ap) ? 8080 : ap,
            tok,
            (apiBaseUrlField.value || "").trim()
        )
    }

    function applyProvisionFields(fields) {
        if (!fields) return
        if (fields.api_token !== undefined) tokenField.setValue(fields.api_token)
        if (fields.host !== undefined) hostField.setValue(fields.host)
        if (fields.api_port !== undefined) apiPortField.setValue(String(fields.api_port))
        if (fields.modbus_port !== undefined) portField.setValue(String(fields.modbus_port))
        if (fields.modbus_unit_id !== undefined) unitField.setValue(String(fields.modbus_unit_id))
        if (fields.station_code !== undefined) stationCodeField.setValue(fields.station_code)
        if (fields.station_name !== undefined) {
            stationNameField.setValue(fields.station_name)
            if (dialog.mode === "add" && !(nameField.value || "").trim())
                nameField.setValue(fields.station_name)
        }
    }

    function _diff(current, original) {
        var out = {}
        for (var key in current) {
            if (current[key] !== original[key]) out[key] = current[key]
        }
        return out
    }

    function _buildEditPatch() {
        var d = detail
        var cf = d.configForm || {}
        var raw = d.rawConfig || {}
        var pollDev = parseInt(pollDeviceField.value)
        var apiPort = parseInt(apiPortField.value)
        var timeoutVal = parseFloat(timeoutField.value)

        var pollDevConn = parseInt(pollDeviceField.value)
        var connection = {
            name: (nameField.value || "").trim(),
            host: (hostField.value || "").trim(),
            port: parseInt(portField.value) || 5020,
            unitId: parseInt(unitField.value) || 1,
            pollIntervalS: isNaN(pollDevConn) ? (d.pollIntervalS || 2) : pollDevConn,
            timeoutS: isNaN(timeoutVal) ? 2.0 : timeoutVal,
            note: (noteField.value || "").trim()
        }

        var cloudCurrent = {
            apiToken: tokenField.value,
            apiPort: isNaN(apiPort) ? (d.cloudForm ? (d.cloudForm.apiPort || 8080) : 8080) : apiPort,
            apiBaseUrl: (apiBaseUrlField.value || "").trim()
        }
        var cloudOriginal = {
            apiToken: d.cloudForm ? (d.cloudForm.apiToken || "") : "",
            apiPort: d.cloudForm ? (d.cloudForm.apiPort || 8080) : 8080,
            apiBaseUrl: d.apiBaseUrl || ""
        }

        var configPatch = {}
        if (dialog.mode === "edit" && !!d.online) {
            var edgeUnitId = parseInt(unitIdDeviceField.value)
            var configCurrent = {
                station_code: (stationCodeField.value || "").trim(),
                station_name: (stationNameField.value || "").trim(),
                modbus_tcp_bind: bindField.value,
                modbus_tcp_enabled: modbusTcpEnabledCheck.checked,
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
            configPatch = dialog._diff(configCurrent, configOriginal)
        }

        return {
            connection: connection,
            config: configPatch,
            cloud: dialog._diff(cloudCurrent, cloudOriginal)
        }
    }

    onOpened: {
        configLoaded = false
        probeStatus = ""
        probeStatusKind = "idle"
        probedRevision = -1
        if (mode === "edit") loadFromDetail(detail)
        else {
            nameField.setValue("")
            noteField.setValue("")
            hostField.setValue("")
            portField.setValue("5020")
            unitField.setValue("1")
            timeoutField.setValue("2.0")
            apiPortField.setValue("8080")
            tokenField.setValue("")
            apiBaseUrlField.setValue("")
        }
        Qt.callLater(dialog.clearAllFieldFocus)
    }

    // ── Status strip (Edit only) ──────────────────────────────────────────────
    ColumnLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 0
        Layout.rightMargin: 0
        spacing: 0

        Rectangle {
            visible: dialog.mode === "edit"
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? 40 : 0
            color: detail.online
                ? (dialog.isDark ? "#052e16" : "#f0fdf4")
                : (dialog.isDark ? "#422006" : "#fefce8")
            border.width: 0

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 24
                anchors.rightMargin: 24
                spacing: 8
                Rectangle {
                    width: 8; height: 8; radius: 4
                    color: detail.online ? "#22c55e" : "#f59e0b"
                }
                Qaterial.LabelCaption {
                    text: detail.online
                        ? "Online"
                        : "Offline — device settings read-only. Central column still saves."
                    color: detail.online
                        ? (dialog.isDark ? "#86efac" : "#166534")
                        : (dialog.isDark ? "#fde68a" : "#92400e")
                    font.family: "Inter"
                    font.pixelSize: 12
                }
                Item { Layout.fillWidth: true }
            }
        }

        // ── Two-column body ───────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 24
            Layout.rightMargin: 24
            Layout.topMargin: 20
            Layout.bottomMargin: 20
            spacing: 32

            // ── LEFT: Central ─────────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 20

                // -- BASIC --
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    SectionLabel { text: "BASIC" }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 12
                        rowSpacing: 12
                        FormField { id: nameField; label: "Name *"; isDark: dialog.isDark }
                        FormField { id: noteField; label: "Note (optional)"; isDark: dialog.isDark }
                    }
                }

                // -- CENTRAL MODBUS --
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    SectionLabel { text: "CENTRAL — MODBUS" }
                    FormField { id: hostField; label: "Host IP *"; isDark: dialog.isDark; Layout.fillWidth: true }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 12
                        rowSpacing: 12
                        FormField { id: portField; label: "Modbus Port"; isDark: dialog.isDark }
                        FormField { id: unitField; label: "Unit ID"; isDark: dialog.isDark }
                        FormField { id: timeoutField; label: "Modbus timeout (s)"; isDark: dialog.isDark }
                    }
                }

                // -- CENTRAL REST API --
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    SectionLabel { text: "CENTRAL — REST API" }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 12
                        rowSpacing: 12
                        FormField { id: apiPortField; label: "API Port"; isDark: dialog.isDark }
                        FormField { id: tokenField; label: "API Token"; isDark: dialog.isDark; isPassword: true }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Rectangle {
                            Layout.preferredWidth: scanQrLabel.implicitWidth + 24
                            Layout.preferredHeight: 32
                            radius: 6
                            opacity: dialog.qrScanEnabled ? 1.0 : 0.45
                            color: scanQrMouse.containsMouse && dialog.qrScanEnabled
                                ? (dialog.isDark ? "#27272a" : "#e4e4e7")
                                : (dialog.isDark ? "#18181b" : "#f4f4f5")
                            border.width: 1
                            border.color: dialog.isDark ? "#3f3f46" : "#d4d4d8"
                            Qaterial.LabelCaption {
                                id: scanQrLabel
                                anchors.centerIn: parent
                                text: "Scan QR…"
                                color: dialog.isDark ? "#a1a1aa" : "#52525b"
                                font.family: "Inter"
                                font.pixelSize: 12
                                font.weight: Font.Medium
                            }
                            MouseArea {
                                id: scanQrMouse
                                anchors.fill: parent
                                hoverEnabled: dialog.qrScanEnabled
                                cursorShape: dialog.qrScanEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    if (dialog.qrScanEnabled)
                                        qrFileDialog.open()
                                    else if (typeof window !== "undefined" && window && window.notify)
                                        window.notify("QR scan unavailable (see README — ZBar DLL on Windows)", "warning")
                                }
                            }
                        }
                        Qaterial.LabelCaption {
                            Layout.fillWidth: true
                            text: dialog.qrScanEnabled
                                ? "Import pairing QR from data-logger (PNG/JPG)"
                                : "QR scan unavailable — enter API token manually"
                            color: dialog.isDark ? "#71717a" : "#a1a1aa"
                            font.family: "Inter"
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                        }
                    }
                    FormField { id: apiBaseUrlField; label: "API Base URL (optional)"; isDark: dialog.isDark; Layout.fillWidth: true }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        radius: 6
                        color: connectMouse.containsMouse ? "#2563eb" : "#1d4ed8"
                        Qaterial.LabelBody2 {
                            anchors.centerIn: parent
                            text: "Connect & Load Config"
                            color: "#ffffff"
                            font.family: "Inter"
                            font.pixelSize: 13
                            font.weight: Font.Medium
                        }
                        MouseArea {
                            id: connectMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: dialog.connectAndLoadConfig()
                        }
                    }
                    Qaterial.LabelCaption {
                        Layout.fillWidth: true
                        visible: dialog.probeStatus.length > 0
                        text: dialog.probeStatus
                        color: dialog.probeStatusColor
                        font.family: "Inter"
                        font.pixelSize: 11
                        wrapMode: Text.WordWrap
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                color: dialog.isDark ? "#27272a" : "#e4e4e7"
            }

            // ── RIGHT: Device ─────────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 20
                opacity: dialog.deviceEditable ? 1.0 : 0.45

                Behavior on opacity { NumberAnimation { duration: 200 } }

                SectionLabel { text: "DEVICE — REST (Firmware)" }

                Rectangle {
                    visible: !dialog.deviceEditable
                    Layout.fillWidth: true
                    implicitHeight: hintCol.implicitHeight + 24
                    radius: 8
                    color: dialog.isDark ? "#18181b" : "#f4f4f5"
                    border.width: 1
                    border.color: dialog.isDark ? "#27272a" : "#e4e4e7"
                    ColumnLayout {
                        id: hintCol
                        anchors.centerIn: parent
                        width: parent.width - 32
                        spacing: 6
                        Qaterial.Icon {
                            Layout.alignment: Qt.AlignHCenter
                            icon: Qaterial.Icons.informationOutline
                            size: 24
                            color: dialog.isDark ? "#52525b" : "#a1a1aa"
                        }
                        Qaterial.LabelCaption {
                            Layout.fillWidth: true
                            text: dialog.mode === "add"
                                ? "Click Connect & Load Config on the left to load station, poll interval, and Modbus TCP settings from the edge device."
                                : "Click Connect & Load Config on the left to refresh device settings from the edge."
                            color: dialog.isDark ? "#71717a" : "#a1a1aa"
                            font.family: "Inter"
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }

                ColumnLayout {
                    visible: dialog.deviceEditable
                    Layout.fillWidth: true
                    spacing: 12

                    // Offline overlay caption
                    Rectangle {
                        visible: !dialog.deviceEditable
                        Layout.fillWidth: true
                        implicitHeight: offlineHint.implicitHeight + 16
                        radius: 6
                        color: dialog.isDark ? "#1c1917" : "#fafaf9"
                        border.width: 1
                        border.color: dialog.isDark ? "#292524" : "#e7e5e4"
                        Qaterial.LabelCaption {
                            id: offlineHint
                            anchors.centerIn: parent
                            width: parent.width - 24
                            text: "Firmware settings require the logger to be online. Central connection (left column) can still be saved."
                            color: dialog.isDark ? "#78716c" : "#a8a29e"
                            font.family: "Inter"
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 12
                        rowSpacing: 12
                        FormField {
                            id: stationCodeField; label: "Station code"
                            isDark: dialog.isDark
                            inputEnabled: dialog.deviceEditable
                        }
                        FormField {
                            id: stationNameField; label: "Station name"
                            isDark: dialog.isDark
                            inputEnabled: dialog.deviceEditable
                        }
                        FormField {
                            id: bindField; label: "Modbus TCP bind"
                            isDark: dialog.isDark
                            inputEnabled: dialog.deviceEditable
                        }
                        FormField {
                            id: unitIdDeviceField; label: "Modbus TCP unit ID (edge)"
                            isDark: dialog.isDark
                            inputEnabled: dialog.deviceEditable
                        }
                    }
                    FormField {
                        id: pollDeviceField; label: "Device poll interval (s)"
                        isDark: dialog.isDark
                        Layout.fillWidth: true
                        inputEnabled: dialog.deviceEditable
                    }
                    RowLayout {
                        enabled: dialog.deviceEditable
                        Layout.fillWidth: true
                        spacing: 10
                        CheckBox { id: modbusTcpEnabledCheck }
                        Qaterial.LabelBody2 {
                            text: "Modbus TCP server enabled"
                            color: dialog.isDark ? "#fafafa" : "#18181b"
                            font.family: "Inter"; font.pixelSize: 13; font.weight: Font.Medium
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (dialog.deviceEditable) modbusTcpEnabledCheck.toggle()
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }
    }

    dialogFooter: [
        Item { Layout.fillWidth: true },
        Rectangle {
            Layout.preferredWidth: cnLabel.implicitWidth + 32
            Layout.preferredHeight: 36
            radius: 6
            color: cnMouse.containsMouse ? (dialog.isDark ? "#27272a" : "#e4e4e7") : (dialog.isDark ? "#27272a" : "#f4f4f5")
            Qaterial.LabelBody2 {
                id: cnLabel; anchors.centerIn: parent; text: "Cancel"
                color: dialog.isDark ? "#fafafa" : "#3f3f46"
                font.family: "Roboto"; font.pixelSize: 14; font.weight: Font.Medium
            }
            MouseArea {
                id: cnMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: dialog.close()
            }
        },
        Rectangle {
            Layout.preferredWidth: okLabel.implicitWidth + 32
            Layout.preferredHeight: 36
            radius: 6
            color: okMouse.containsMouse ? "#3b82f6" : "#2563eb"
            Qaterial.LabelBody2 {
                id: okLabel; anchors.centerIn: parent
                text: dialog.mode === "add" ? "Add Logger" : "Save Changes"
                color: "#ffffff"
                font.family: "Inter"; font.pixelSize: 14; font.weight: Font.Medium
            }
            MouseArea {
                id: okMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (dialog.mode === "add") {
                        var name = (nameField.value || "").trim()
                        var host = (hostField.value || "").trim()
                        if (!name || !host) {
                            if (typeof window !== "undefined" && window && window.notify)
                                window.notify("Name and Host are required", "error")
                            return
                        }
                        dialog.close()
                        dialog.addRequested({
                            name: name,
                            host: host,
                            port: parseInt(portField.value) || 5020,
                            unitId: parseInt(unitField.value) || 1,
                            pollIntervalS: parseInt(pollDeviceField.value) || 2,
                            timeoutS: parseFloat(timeoutField.value) || 2.0,
                            note: (noteField.value || "").trim(),
                            apiPort: parseInt(apiPortField.value) || 8080,
                            apiToken: tokenField.value || "",
                            apiBaseUrl: (apiBaseUrlField.value || "").trim()
                        })
                    } else {
                        var patch = dialog._buildEditPatch()
                        if (!patch.connection.name || !patch.connection.host) {
                            if (typeof window !== "undefined" && window && window.notify)
                                window.notify("Name and Host are required", "error")
                            return
                        }
                        dialog.close()
                        dialog.saved(patch)
                    }
                }
            }
        }
    ]

    // ── Shared components ─────────────────────────────────────────────────────
    Connections {
        target: dialog.dashboardController
        enabled: dialog.dashboardController !== null
        ignoreUnknownSignals: true
        function onEdgeConfigProbed(ok, payloadJson) {
            if (dialog.mode !== "add") return
            dialog.loadFromProbeResult(payloadJson)
        }
        function onConfigFetched(id, ok, payloadJson) {
            if (dialog.mode !== "edit") return
            var lid = dialog.detail.loggerId !== undefined ? dialog.detail.loggerId : -1
            if (id !== lid) return
            if (!ok) {
                dialog.configLoaded = false
                try {
                    var errP = JSON.parse(payloadJson)
                    var errMsg = (errP.errors && errP.errors.length > 0)
                        ? errP.errors[0].message
                        : (errP.message || "Load failed")
                    dialog.setProbeError(errMsg)
                } catch (e) {
                    dialog.setProbeError("Load failed")
                }
                return
            }
            try {
                var p = JSON.parse(payloadJson)
                var cfg = p.config || {}
                var snap = dialog.connectionSnapshotFromFields()
                var apiTok = p.api_token !== undefined ? p.api_token : (snap.cloudForm ? snap.cloudForm.apiToken : "")
                var apiP = p.api_port !== undefined ? p.api_port : snap.apiPort
                dialog.detail = Object.assign({}, dialog.detail, snap, {
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
                dialog.loadFromDetail(dialog.detail)
                dialog.configLoaded = true
                dialog.setProbeSuccess()
            } catch (e) {
                console.warn("configFetched in form:", e)
                dialog.setProbeError("Invalid response")
            }
        }
    }

    FileDialog {
        id: qrFileDialog
        title: "Select provisioning QR image"
        nameFilters: ["Images (*.png *.jpg *.jpeg *.bmp)"]
        onAccepted: {
            if (!dialog.dashboardController) {
                if (typeof window !== "undefined" && window && window.notify)
                    window.notify("Dashboard controller not available", "error")
                return
            }
            var path = selectedFile.toString()
            if (path.startsWith("file://"))
                path = path.substring(7)
            var raw = dialog.dashboardController.importProvisionFromQrImage(path)
            try {
                var res = JSON.parse(raw || "{}")
                if (res.ok && res.fields)
                    dialog.applyProvisionFields(res.fields)
                else if (typeof window !== "undefined" && window && window.notify)
                    window.notify(res.error || "Invalid provisioning QR", "error")
                else
                    console.warn("QR import:", res.error)
            } catch (e) {
                if (typeof window !== "undefined" && window && window.notify)
                    window.notify("Invalid QR response", "error")
            }
        }
    }

    component SectionLabel: Qaterial.LabelCaption {
        Layout.fillWidth: true
        color: "#71717a"
        font.family: "Inter"
        font.pixelSize: 11
        font.weight: Font.DemiBold
        font.letterSpacing: 1.2
    }

    component FormField: ColumnLayout {
        id: formField
        property string label: ""
        property string fieldValue: ""
        property bool isDark: true
        property bool isPassword: false
        property bool inputEnabled: true

        Layout.fillWidth: true
        spacing: 6

        function setValue(v) {
            var s = v !== undefined && v !== null ? String(v) : ""
            fieldValue = s
            input.text = s
        }

        function clearFocus() {
            input.focus = false
        }

        readonly property alias value: formField.fieldValue

        Qaterial.LabelBody2 {
            text: formField.label
            color: formField.isDark ? "#fafafa" : "#18181b"
            font.family: "Inter"; font.pixelSize: 13; font.weight: Font.Medium
            opacity: formField.inputEnabled ? 1.0 : 0.5
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            radius: 6
            color: formField.isDark ? "#18181b" : "#fafafa"
            border.width: 1
            border.color: formField.isDark ? "#27272a" : "#d4d4d8"
            opacity: formField.inputEnabled ? 1.0 : 0.5
            TextInput {
                id: input
                anchors.fill: parent; anchors.margins: 4
                leftPadding: 8
                text: formField.fieldValue
                font.family: "Inter"; font.pixelSize: 13
                color: formField.isDark ? "#fafafa" : "#18181b"
                verticalAlignment: TextInput.AlignVCenter
                echoMode: formField.isPassword ? TextInput.Password : TextInput.Normal
                selectByMouse: true
                clip: true
                readOnly: !formField.inputEnabled
                cursorVisible: formField.inputEnabled && input.activeFocus
                onTextChanged: if (formField.inputEnabled) formField.fieldValue = text
            }
        }
    }
}
