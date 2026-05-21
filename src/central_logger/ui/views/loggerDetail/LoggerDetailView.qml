import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "../../"
import "../../components/dialogs"
import "../../logic/LoggerDetailLogic.js" as DetailLogic

Item {
    id: view

    property bool isDark: true
    property int loggerId: -1
    property var loggersModel: null
    property var dashboardController: null

    readonly property bool useRowPanels: width > 950

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
        return DetailLogic.findModelRow(loggersModel, loggerId)
    }

    function _rebuildDetail() {
        detail = DetailLogic.rebuildDetail(detail, _findModelRow(), loggerId)
    }

    function _applySensorsPayload(payload) {
        detail = DetailLogic.applySensorsPayload(detail, payload)
    }

    function _hydrateLatest() {
        if (!dashboardController || loggerId < 0) return
        var json = dashboardController.latestReadings(loggerId)
        if (!json) return
        var payload = DetailLogic.parseJsonSafe(json, null)
        if (payload && payload.sensors) _applySensorsPayload(payload)
    }

    function _hydrateDetailFromDb() {
        if (!dashboardController || loggerId < 0) return
        var db = DetailLogic.parseJsonSafe(
            dashboardController.getLoggerFormData(loggerId),
            {}
        )
        detail = DetailLogic.hydrateDetailFromDb(detail, db)
    }

    function _openEditDialog() {
        _rebuildDetail()
        _hydrateDetailFromDb()
        editDialog.loadFromDetail(view.detail)
        editDialog.open()
    }

    function _effectiveConfigRevision() {
        return DetailLogic.effectiveConfigRevision(detail)
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
        running: view.loggerId >= 0 && view.detail.online && view.dashboardController !== null
        onTriggered: {
            if (view.dashboardController && view.loggerId >= 0)
                view.dashboardController.fetchReadingsIfStale(view.loggerId)
        }
    }

    onLoggerIdChanged: {
        _rebuildDetail()
        _hydrateLatest()
        readingsPollTimer.restart()
        if (dashboardController && loggerId >= 0) {
            dashboardController.fetchConfig(loggerId)
            if (view.detail.online)
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
            var payload = DetailLogic.parseJsonSafe(jsonStr, null)
            if (payload) view._applySensorsPayload(payload)
        }
        function onSnapshotApplied(id, ok, info) {
            if (id === view.loggerId) view._rebuildDetail()
        }
        function onConfigFetched(id, ok, payloadJson) {
            if (id !== view.loggerId) return
            if (!ok) {
                var failMsg = DetailLogic.configFetchedErrorMessage(
                    payloadJson,
                    "Could not load sensor catalog (REST)"
                )
                view.detail = Object.assign({}, view.detail, { catalogError: failMsg })
                return
            }
            var merged = DetailLogic.mergeConfigFetched(view.detail, payloadJson)
            view.detail = merged.detail
            if (editDialog.opened)
                editDialog.loadFromDetail(view.detail)
            if (view.dashboardController) {
                view.dashboardController.refreshSensorList(view.loggerId)
                if (view.detail.online)
                    view.dashboardController.fetchReadings(view.loggerId)
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
        function onConfigApplied(id, ok, payloadJson) {
            if (id !== view.loggerId) return
            if (ok) {
                view.detail = DetailLogic.mergeConfigApplied(view.detail, payloadJson)
                if (view.dashboardController) view.dashboardController.fetchConfig(view.loggerId)
            } else {
                var p = DetailLogic.parseJsonSafe(payloadJson, {})
                console.warn("applyConfig failed:", p.message || p.errors)
            }
        }
    }

    Connections {
        target: view.loggersModel
        ignoreUnknownSignals: true
        function onDataChanged() { view._rebuildDetail() }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        LoggerDetailHeader {
            Layout.fillWidth: true
            isDark: view.isDark
            detail: view.detail
            loggerId: view.loggerId
            dashboardController: view.dashboardController
            onGoBack: view.goBack()
            onEditClicked: _openEditDialog()
            onDeleteClicked: deleteDialog.open()
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            Layout.topMargin: 16
            Layout.bottomMargin: 16
            spacing: 16

            LoggerOverviewGrid {
                Layout.fillWidth: true
                isDark: view.isDark
                detail: view.detail
            }

            Item {
                id: panelsHost
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 280

                Loader {
                    anchors.fill: parent
                    sourceComponent: view.useRowPanels ? rowPanels : columnPanels
                }
            }
        }
    }

    Component {
        id: rowPanels
        RowLayout {
            anchors.fill: parent
            spacing: 16

            SensorMonitoringTable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: panelsHost.width * 0.58
                Layout.minimumWidth: 320
                isDark: view.isDark
                detail: view.detail
            }

            SensorTrendingChart {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: panelsHost.width * 0.42
                Layout.minimumWidth: 280
                isDark: view.isDark
                loggerId: view.loggerId
                dashboardController: view.dashboardController
                sensorList: view.detail.sensorList
            }
        }
    }

    Component {
        id: columnPanels
        ColumnLayout {
            anchors.fill: parent
            spacing: 16

            SensorMonitoringTable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: panelsHost.height * 0.5
                Layout.minimumHeight: 200
                isDark: view.isDark
                detail: view.detail
            }

            SensorTrendingChart {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: panelsHost.height * 0.5
                Layout.minimumHeight: 200
                isDark: view.isDark
                loggerId: view.loggerId
                dashboardController: view.dashboardController
                sensorList: view.detail.sensorList
            }
        }
    }

    LoggerFormDialog {
        id: editDialog
        mode: "edit"
        isDark: view.isDark
        detail: view.detail
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
