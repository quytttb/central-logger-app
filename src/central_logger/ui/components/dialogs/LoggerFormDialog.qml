import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import "../.."
import "../common"
import "../../logic/LoggerFormLogic.js" as FormLogic
import components

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

    readonly property color probeStatusColor: Colors.probeStatusText(dialog.isDark, probeStatusKind)

    signal addRequested(var formData)
    signal saved(var patch)

    title: mode === "add" ? "Add Edge Logger" : "Edit Logger"

    // Device fields: sau Connect & Load (Add) hoặc Edit khi online.
    readonly property bool deviceEditable: configLoaded
        || (mode === "edit" && !!detail.online)
    readonly property bool qrScanEnabled: !dashboardController || dashboardController.qrScanAvailable()

    readonly property alias nameField: centralCol.nameField
    readonly property alias noteField: centralCol.noteField
    readonly property alias hostField: centralCol.hostField
    readonly property alias portField: centralCol.portField
    readonly property alias unitField: centralCol.unitField
    readonly property alias timeoutField: centralCol.timeoutField
    readonly property alias apiPortField: centralCol.apiPortField
    readonly property alias tokenField: centralCol.tokenField
    readonly property alias apiBaseUrlField: centralCol.apiBaseUrlField
    readonly property alias stationCodeField: deviceCol.stationCodeField
    readonly property alias stationNameField: deviceCol.stationNameField
    readonly property alias bindField: deviceCol.bindField
    readonly property alias unitIdDeviceField: deviceCol.unitIdDeviceField
    readonly property alias pollDeviceField: deviceCol.pollDeviceField
    readonly property alias modbusTcpEnabledCheck: deviceCol.modbusTcpEnabledCheck

    function openQrFileDialog() {
        qrFileDialog.open()
    }

    function humanizeProbeError(raw) {
        return FormLogic.humanizeProbeError(raw)
    }

    function _fieldSnapshot() {
        return {
            name: nameField.value,
            note: noteField.value,
            host: hostField.value,
            port: portField.value,
            unit: unitField.value,
            timeout: timeoutField.value,
            apiPort: apiPortField.value,
            token: tokenField.value,
            apiBaseUrl: apiBaseUrlField.value,
            stationCode: stationCodeField.value,
            stationName: stationNameField.value,
            bind: bindField.value,
            pollDevice: pollDeviceField.value,
            unitIdDevice: unitIdDeviceField.value,
            modbusTcpEnabled: modbusTcpEnabledCheck.checked
        }
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
        return FormLogic.connectionSnapshotFromFields(_fieldSnapshot())
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
        var src = d || {}
        if (dialog.mode === "add")
            detail = src
        nameField.setValue(src.loggerName || "")
        noteField.setValue(src.note || "")
        hostField.setValue(src.host || "")
        portField.setValue(src.port !== undefined ? String(src.port) : "5020")
        unitField.setValue(src.unitId !== undefined ? String(src.unitId) : "1")
        timeoutField.setValue(src.timeoutS !== undefined ? String(src.timeoutS) : "2.0")
        apiPortField.setValue(src.apiPort !== undefined ? String(src.apiPort) : "8080")
        tokenField.setValue(src.cloudForm ? (src.cloudForm.apiToken || "") : "")
        apiBaseUrlField.setValue(src.apiBaseUrl || "")

        var cf = src.configForm || {}
        var raw = src.rawConfig || {}
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
            var result = FormLogic.parseProbeSuccess(jsonStr, snap)
            if (!result.ok) {
                configLoaded = false
                setProbeError(result.error)
                return
            }
            detail = result.detail
            probedRevision = result.revision
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

    function _buildEditPatch() {
        return FormLogic.buildEditPatch(dialog.mode, detail, detail.online, _fieldSnapshot())
    }

    onOpened: {
        probeStatus = ""
        probeStatusKind = "idle"
        probedRevision = -1
        if (mode === "edit") {
            loadFromDetail(detail)
        } else {
            configLoaded = false
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
                UiLabel {
        textType: UiLabel.Caption
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

            LoggerFormCentralColumn {
                id: centralCol
                dialog: dialog
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                color: Colors.border(dialog.isDark)
            }

            LoggerFormDeviceColumn {
                id: deviceCol
                dialog: dialog
            }
        }
    }

    dialogFooter: [
        Item { Layout.fillWidth: true },
        DialogButton {
            text: "Cancel"
            isDark: dialog.isDark
            variant: "secondary"
            onClicked: dialog.close()
        },
        DialogButton {
            text: dialog.mode === "add" ? "Add Logger" : "Save Changes"
            iconName: dialog.mode === "add" ? "plus" : "save"
            isDark: dialog.isDark
            variant: "primary"
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
            // Edit mode: LoggerDetailView owns config fetch and refreshes the form via loadFromDetail.
            if (dialog.mode === "edit") return
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
                var snap = dialog.connectionSnapshotFromFields()
                var parsed = FormLogic.parseConfigFetched(id, payloadJson, snap)
                dialog.detail = parsed
                dialog.loadFromDetail(parsed)
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

}
