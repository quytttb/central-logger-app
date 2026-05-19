import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qaterial 1.0 as Qaterial

import "../../"
import "../../components/common"
import "../../components/dialogs"

/*
 * Logger Detail page — Shadcn style.
 * 3-column layout: Status sidebar | Sensor table | Trending chart.
 */
Item {
    id: view

    property bool isDark: Qaterial.Style.theme === Qaterial.Style.Theme.Dark
    property int loggerId: -1
    property var loggersModel: null
    property var dashboardController: null

    signal goBack()

    property var detail: ({
        loggerId: -1,
        loggerName: "—",
        host: "",
        port: 0,
        unitId: 0,
        pollIntervalS: 2,
        timeoutS: 2.0,
        enabled: true,
        note: "",
        apiPort: 8080,
        apiBaseUrl: "",
        sensorCount: 0,
        online: false,
        polling: false,
        rtuConnected: false,
        anyAlarm: false,
        currentRevision: -1,
        lastRevision: -1,
        statusText: "",
        sensorList: [],
        configForm: {
            station_code: "—",
            station_name: "",
            poll_interval: 0,
            modbus_tcp_bind: "",
            modbus_tcp_enabled: false,
            modbus_tcp_unit_id: 1
        },
        cloudForm: { apiToken: "", apiPort: 8080 },
        rawConfig: {}
    })

    function _findModelRow() {
        if (!loggersModel) return null
        for (var i = 0; i < loggersModel.count(); ++i) {
            var it = loggersModel.itemAt(i)
            if (it && it.loggerId === loggerId) return it
        }
        return null
    }

    function _rebuildDetail() {
        var row = _findModelRow()
        if (!row) {
            detail = Object.assign({}, detail, { loggerId: loggerId, loggerName: "Logger #" + loggerId })
            return
        }
        var sensors = detail.sensorList || []
        detail = {
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
            rawConfig: detail.rawConfig
        }
    }

    function _applySensorsPayload(payload) {
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
        detail = Object.assign({}, detail, {
            sensorList: list,
            sensorCount: list.length,
            polling: payload.polling,
            rtuConnected: payload.rtu_connected,
            anyAlarm: payload.any_alarm
        })
    }

    function _hydrateLatest() {
        if (!dashboardController || loggerId < 0) return
        var json = dashboardController.latestReadings(loggerId)
        if (!json) return
        try {
            var payload = JSON.parse(json)
            if (payload && payload.sensors) _applySensorsPayload(payload)
        } catch (e) {
            console.warn("latestReadings parse error", e)
        }
    }

    function _hydrateDetailFromDb() {
        if (!dashboardController || loggerId < 0) return
        try {
            var db = JSON.parse(dashboardController.getLoggerFormData(loggerId) || "{}")
            if (!db.loggerId) return
            detail = Object.assign({}, detail, {
                timeoutS: db.timeoutS !== undefined ? db.timeoutS : detail.timeoutS,
                note: db.note !== undefined ? db.note : detail.note,
                apiPort: db.apiPort !== undefined ? db.apiPort : detail.apiPort,
                apiBaseUrl: db.apiBaseUrl !== undefined ? db.apiBaseUrl : detail.apiBaseUrl,
                lastRevision: db.lastRevision !== undefined ? db.lastRevision : -1,
                cloudForm: Object.assign({}, detail.cloudForm || {}, {
                    apiToken: db.apiToken !== undefined ? db.apiToken : (detail.cloudForm ? detail.cloudForm.apiToken : ""),
                    apiPort: db.apiPort !== undefined ? db.apiPort : (detail.cloudForm ? detail.cloudForm.apiPort : 8080)
                })
            })
        } catch (e) {
            console.warn("getLoggerFormData parse error", e)
        }
    }

    function _openEditDialog() {
        _rebuildDetail()
        _hydrateDetailFromDb()
        if (dashboardController && loggerId >= 0)
            dashboardController.fetchConfig(loggerId)
        editDialog.loadFromDetail(detail)
        editDialog.open()
    }

    function _effectiveConfigRevision() {
        if (detail.currentRevision !== undefined && detail.currentRevision >= 0)
            return detail.currentRevision
        if (detail.lastRevision !== undefined && detail.lastRevision >= 0)
            return detail.lastRevision
        return -1
    }

    Timer {
        id: readingsPollTimer
        interval: {
            var pi = view.detail.configForm ? view.detail.configForm.poll_interval : 0
            if (pi > 0) return pi * 1000
            if (view.detail.pollIntervalS > 0) return view.detail.pollIntervalS * 1000
            return 2000
        }
        repeat: true
        running: view.loggerId >= 0 && view.dashboardController !== null
        onTriggered: {
            if (view.dashboardController && view.loggerId >= 0)
                view.dashboardController.fetchReadings(view.loggerId)
        }
    }

    onLoggerIdChanged: {
        _rebuildDetail()
        _hydrateLatest()
        readingsPollTimer.restart()
        if (dashboardController && loggerId >= 0) {
            dashboardController.fetchConfig(loggerId)
            dashboardController.fetchReadings(loggerId)
        }
    }

    Component.onCompleted: {
        _rebuildDetail()
        _hydrateLatest()
    }

    Connections {
        target: view.dashboardController
        ignoreUnknownSignals: true
        function onSensorsUpdated(id, jsonStr) {
            if (id !== view.loggerId) return
            try {
                var payload = JSON.parse(jsonStr)
                view._applySensorsPayload(payload)
            } catch (e) {
                console.warn("sensorsUpdated parse error", e)
            }
        }
        function onSnapshotApplied(id, ok, info) {
            if (id === view.loggerId) view._rebuildDetail()
        }
        function onConfigFetched(id, ok, payloadJson) {
            if (id !== view.loggerId) return
            if (!ok) {
                try {
                    var errP = JSON.parse(payloadJson)
                    var msg = (errP.errors && errP.errors.length > 0)
                        ? errP.errors[0].message
                        : (errP.message || "Không tải được danh sách cảm biến (REST)")
                    view.detail = Object.assign({}, view.detail, { catalogError: msg })
                } catch (e) {
                    view.detail = Object.assign({}, view.detail, {
                        catalogError: "Không tải được danh sách cảm biến (REST)"
                    })
                }
                return
            }
            try {
                var p = JSON.parse(payloadJson)
                var cfg = p.config || {}
                view.detail = Object.assign({}, view.detail, {
                    catalogError: "",
                    currentRevision: p.revision !== null && p.revision !== undefined ? p.revision : -1,
                    lastRevision: p.revision !== null && p.revision !== undefined ? p.revision : view.detail.lastRevision,
                    configForm: {
                        station_code: cfg.station_code || "—",
                        station_name: cfg.station_name || "",
                        poll_interval: cfg.poll_interval || 0,
                        modbus_tcp_bind: cfg.modbus_tcp_bind || "",
                        modbus_tcp_enabled: !!cfg.modbus_tcp_enabled,
                        modbus_tcp_unit_id: cfg.modbus_tcp_unit_id !== undefined
                            ? cfg.modbus_tcp_unit_id
                            : 1
                    },
                    cloudForm: {
                        apiToken: p.api_token !== undefined ? p.api_token : (view.detail.cloudForm ? view.detail.cloudForm.apiToken : ""),
                        apiPort: p.api_port !== undefined ? p.api_port : (view.detail.cloudForm ? view.detail.cloudForm.apiPort : 8080)
                    },
                    apiPort: p.api_port !== undefined ? p.api_port : view.detail.apiPort,
                    apiBaseUrl: p.api_base_url !== undefined ? p.api_base_url : view.detail.apiBaseUrl,
                    rawConfig: cfg
                })
                if (editDialog.opened)
                    editDialog.loadFromDetail(view.detail)
                if (view.dashboardController) {
                    view.dashboardController.refreshSensorList(view.loggerId)
                    view.dashboardController.fetchReadings(view.loggerId)
                }
            } catch (e) {
                console.warn("configFetched parse error", e)
            }
        }
        function onReportDownloaded(id, ok, message) {
            if (id !== view.loggerId) return
            if (typeof window !== "undefined" && window && window.notify)
                window.notify(message || (ok ? "Report saved" : "Download failed"), ok ? "success" : "error")
        }
        function onReadingsError(id, message) {
            if (id !== view.loggerId) return
            if (typeof window !== "undefined" && window && window.notify)
                window.notify(message || "Could not load sensor readings", "warning")
        }
    }

    Connections {
        target: view.loggersModel
        ignoreUnknownSignals: true
        function onDataChanged() { view._rebuildDetail() }
    }

    Flickable {
        anchors.fill: parent
        contentHeight: mainCol.implicitHeight + 32
        clip: true

        ColumnLayout {
            id: mainCol
            width: parent.width
            spacing: 0

            // ── Sticky Header ────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 72
                color: view.isDark ? Qt.rgba(0.035,0.035,0.043,0.9) : Qt.rgba(0.98,0.98,0.98,0.9)

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width; height: 1
                    color: view.isDark ? Qt.rgba(1,1,1,0.05) : Qt.rgba(0,0,0,0.06)
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 24; anchors.rightMargin: 24
                    spacing: 16

                    // Back button
                    Rectangle {
                        width: 36; height: 36; radius: 6
                        color: "transparent"
                        HoverHighlight {
                            anchors.fill: parent
                            cornerRadius: 6
                            hovered: backMouse.containsMouse
                            isDark: view.isDark
                        }
                        Qaterial.Icon { anchors.centerIn: parent; icon: Qaterial.Icons.arrowLeft; size: 20; color: view.isDark ? "#a1a1aa" : "#52525b" }
                        MouseArea { id: backMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: view.goBack() }
                    }

                    // Title
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 2
                        Qaterial.LabelHeadline5 {
                            text: detail.loggerName
                            color: view.isDark ? "#fafafa" : "#18181b"
                            font.family: "Inter"; font.pixelSize: 24; font.weight: Font.Bold
                        }
                        Qaterial.LabelBody2 {
                            text: detail.host + ":" + detail.port
                            color: view.isDark ? "#a1a1aa" : "#71717a"
                            font.family: "Inter"; font.pixelSize: 14
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Edit button
                    Rectangle {
                        width: 36; height: 36; radius: 6
                        color: "transparent"
                        HoverHighlight {
                            anchors.fill: parent
                            cornerRadius: 6
                            hovered: editMouse.containsMouse
                            isDark: view.isDark
                        }
                        Qaterial.Icon { anchors.centerIn: parent; icon: Qaterial.Icons.pencil; size: 20; color: view.isDark ? "#a1a1aa" : "#52525b" }
                        MouseArea {
                            id: editMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: _openEditDialog()
                        }
                        ToolTip.visible: editMouse.containsMouse; ToolTip.text: "Edit Logger"
                    }

                    // Delete button
                    Rectangle {
                        width: 36; height: 36; radius: 6
                        color: "transparent"
                        Rectangle {
                            anchors.fill: parent
                            radius: 6
                            color: view.isDark ? "#450505" : "#fef2f2"
                            opacity: delMouse.containsMouse ? 1.0 : 0.0
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: UiMotion.durationFast
                                    easing.type: UiMotion.easingOut
                                }
                            }
                        }
                        Qaterial.Icon { anchors.centerIn: parent; icon: Qaterial.Icons.trashCan; size: 20; color: delMouse.containsMouse ? "#ef4444" : (view.isDark ? "#a1a1aa" : "#52525b") }
                        MouseArea { id: delMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: deleteDialog.open() }
                        ToolTip.visible: delMouse.containsMouse; ToolTip.text: "Delete Logger"
                    }
                }
            }

            // ── Overview + 3-column grid ─────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 24
                Layout.rightMargin: 24
                Layout.topMargin: 24
                spacing: 24

                LoggerOverviewGrid {
                    Layout.fillWidth: true
                    isDark: view.isDark
                    detail: view.detail
                }

                GridLayout {
                    id: contentGrid
                    Layout.fillWidth: true
                    columns: view.width > 1100 ? 3 : (view.width > 700 ? 2 : 1)
                    columnSpacing: 24
                    rowSpacing: 24

                    // ──── LEFT: Status + Hardware ─────────────────────────────
                    LoggerStatusSidebar {
                        Layout.preferredWidth: 7
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        isDark: view.isDark
                        detail: view.detail
                        loggerId: view.loggerId
                        dashboardController: view.dashboardController
                    }

                    // ──── CENTER: Sensor Monitoring Table ─────────────────────
                    SensorMonitoringTable {
                        Layout.preferredWidth: 10
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: 520
                        isDark: view.isDark
                        detail: view.detail
                    }

                    // ──── RIGHT: Trending History Chart ───────────────────────
                    SensorTrendingChart {
                        id: trendChart
                        Layout.preferredWidth: 10
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: 520
                        isDark: view.isDark
                        loggerId: view.loggerId
                        dashboardController: view.dashboardController
                        sensorList: view.detail.sensorList
                    }
                }
            }
        }
    }

    // ── Dialogs ──────────────────────────────────────────────────────────────
    EditConfigDialog {
        id: editDialog
        isDark: view.isDark
        config: view.detail
        dashboardController: view.dashboardController
        onSaved: function(patch) {
            if (!view.dashboardController || view.loggerId < 0) return

            var conn = patch.connection || {}
            if (conn.name && conn.host) {
                view.dashboardController.updateLoggerConnection(
                    view.loggerId,
                    conn.name,
                    conn.host,
                    conn.port || 5020,
                    conn.unitId || 1,
                    conn.pollIntervalS || 2,
                    conn.timeoutS || 2.0,
                    conn.note || ""
                )
                view._rebuildDetail()
            }

            var cloudPatch = patch.cloud || {}
            if (Object.keys(cloudPatch).length > 0) {
                view.dashboardController.updateLoggerApi(
                    view.loggerId,
                    cloudPatch.apiToken !== undefined ? cloudPatch.apiToken : (view.detail.cloudForm ? view.detail.cloudForm.apiToken : ""),
                    cloudPatch.apiPort !== undefined ? cloudPatch.apiPort : (view.detail.apiPort || 8080),
                    cloudPatch.apiBaseUrl !== undefined ? cloudPatch.apiBaseUrl : (view.detail.apiBaseUrl || "")
                )
            }

            var configPatch = patch.config || {}
            if (Object.keys(configPatch).length > 0) {
                if (!view.detail.online) {
                    if (typeof window !== "undefined" && window && window.notify)
                        window.notify("Central settings saved. Device config skipped (logger offline).", "warning")
                } else {
                    var rev = view._effectiveConfigRevision()
                    if (rev >= 0) {
                        view.dashboardController.applyConfig(
                            view.loggerId,
                            rev,
                            JSON.stringify(configPatch)
                        )
                    } else if (typeof window !== "undefined" && window && window.notify) {
                        window.notify(
                            "Central settings saved. Device settings could not sync (check API token/port and reload).",
                            "warning"
                        )
                    }
                }
            }
        }
    }

    Connections {
        target: view.dashboardController
        ignoreUnknownSignals: true
        function onConfigApplied(id, ok, payloadJson) {
            if (id !== view.loggerId) return
            try {
                var p = JSON.parse(payloadJson)
                if (ok) {
                    view.detail = Object.assign({}, view.detail, {
                        currentRevision: p.applied_revision !== null && p.applied_revision !== undefined ? p.applied_revision : view.detail.currentRevision
                    })
                    if (view.dashboardController) view.dashboardController.fetchConfig(view.loggerId)
                } else {
                    console.warn("applyConfig failed:", p.message || p.errors)
                }
            } catch (e) {
                console.warn("configApplied parse error", e)
            }
        }
    }

    ConfirmDialog {
        id: deleteDialog
        isDark: view.isDark
        title: "Delete Logger"
        message: "Are you sure you want to delete <b>" + detail.loggerName + "</b>? This action cannot be undone. All historical data and current configurations will be permanently removed."
        confirmText: "Delete Logger"
        destructive: true
        onConfirmed: {
            if (view.dashboardController && view.loggerId >= 0) {
                view.dashboardController.removeLogger(view.loggerId)
            }
            view.goBack()
        }
    }
}
