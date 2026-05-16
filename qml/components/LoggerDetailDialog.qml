import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qaterial 1.0 as Qaterial


/*
 * Full-screen detail overlay (converted from Dialog).
 * Placed in main.qml as a ColumnLayout child with anchors.fill: parent and z: 10.
 * Call openFor(...) to show; close() or visible = false to dismiss.
 */
Rectangle {
    id: dlg

    property var controllerRef: null

    property int loggerId: -1
    property string loggerName: ""
    property string host: ""
    property int port: 5020
    property int unitId: 1
    property int sensorCount: 0
    property int currentRevision: -1
    property bool busy: false
    property bool online: false
    property bool polling: false
    property bool rtuConnected: false
    property bool anyAlarm: false
    property string statusText: ""
    property bool statusOk: true

    property var sensorList: []

    visible: false
    color: Qaterial.Style.backgroundColor

    // ─── Public API ───────────────────────────────────────────────────────────
    function openFor(id, name, hst, prt, unit, sensors, onl, pol, rtu, alarm) {
        dlg.loggerId      = id
        dlg.loggerName    = name
        dlg.host          = hst
        dlg.port          = prt
        dlg.unitId        = unit
        dlg.sensorCount   = sensors
        dlg.online        = onl  === undefined ? false : onl
        dlg.polling       = pol  === undefined ? false : pol
        dlg.rtuConnected  = rtu  === undefined ? false : rtu
        dlg.anyAlarm      = alarm === undefined ? false : alarm
        dlg.currentRevision = -1
        dlg.statusText    = ""
        dlg.statusOk      = true
        rawConfig.text    = "{}"
        pollIntervalField.text = ""
        loggerSerialField.text = ""
        modbusBindField.text   = ""
        tokenField.text        = ""
        apiPortField.text      = ""
        dlg._loadCachedSensors()
        dlg.visible = true
        if (controllerRef) {
            dlg.busy = true
            controllerRef.checkHealth(id)
            controllerRef.fetchConfig(id)
        }
    }

    function close() { dlg.visible = false }

    // ─── Internal helpers ─────────────────────────────────────────────────────
    function _setStatus(ok, msg)       { dlg.statusOk = ok; dlg.statusText = msg }
    function _hydrateForm(cfg) {
        if (cfg.poll_interval  !== undefined) pollIntervalField.text = String(cfg.poll_interval)
        if (cfg.logger_serial  !== undefined) loggerSerialField.text = String(cfg.logger_serial)
        if (cfg.modbus_tcp_bind !== undefined) modbusBindField.text  = String(cfg.modbus_tcp_bind)
    }
    function _buildConfigPatch() {
        var patch = {}
        if (pollIntervalField.text.trim() !== "") {
            var v = parseInt(pollIntervalField.text)
            if (!isNaN(v)) patch.poll_interval = v
        }
        if (loggerSerialField.text.trim() !== "")  patch.logger_serial   = loggerSerialField.text.trim()
        if (modbusBindField.text.trim()   !== "")  patch.modbus_tcp_bind = modbusBindField.text.trim()
        return patch
    }
    function _loadCachedSensors() {
        if (!dlg.controllerRef) { dlg.sensorList = []; return }
        var raw = dlg.controllerRef.latestReadings(dlg.loggerId)
        if (!raw) { dlg.sensorList = []; return }
        try { dlg.sensorList = (JSON.parse(raw).sensors) || [] }
        catch (e) { dlg.sensorList = [] }
    }
    function _formatValue(v) {
        if (v === undefined || v === null) return "---"
        var n = Number(v)
        if (!isFinite(n)) return "---"
        return n.toFixed(2)
    }
    function _errorText(data) {
        if (!data) return "unknown"
        if (data.errors && data.errors.length > 0) {
            var parts = []
            for (var i = 0; i < data.errors.length; ++i) {
                var e = data.errors[i]
                parts.push((e.field ? e.field + ": " : "") + (e.message || ""))
            }
            return parts.join("; ")
        }
        return data.message || "unknown"
    }

    // ─── Controller signals ───────────────────────────────────────────────────
    Connections {
        target: dlg.controllerRef
        ignoreUnknownSignals: true

        function onHealthChecked(id, ok, revision, message) {
            if (id !== dlg.loggerId) return
            if (ok && revision >= 0) dlg.currentRevision = revision
            dlg._setStatus(ok, ok ? ("Health OK, revision=" + revision)
                                  : ("Health error: " + message))
            if (!ok) dlg.busy = false
        }
        function onConfigFetched(id, ok, payloadJson) {
            if (id !== dlg.loggerId) return
            dlg.busy = false
            try {
                var data = JSON.parse(payloadJson)
                if (ok) {
                    if (data.revision !== undefined && data.revision !== null)
                        dlg.currentRevision = data.revision
                    else if (data.config && data.config.revision !== undefined)
                        dlg.currentRevision = data.config.revision
                    rawConfig.text = JSON.stringify(data.config || {}, null, 2)
                    dlg._hydrateForm(data.config || {})
                    dlg._setStatus(true, "Loaded config, revision=" + dlg.currentRevision)
                } else {
                    dlg._setStatus(false, "Fetch error: " + _errorText(data))
                }
            } catch (e) { dlg._setStatus(false, "Parse error: " + e) }
        }
        function onConfigApplied(id, ok, payloadJson) {
            if (id !== dlg.loggerId) return
            dlg.busy = false
            try {
                var data = JSON.parse(payloadJson)
                if (ok) {
                    if (data.applied_revision !== undefined && data.applied_revision !== null)
                        dlg.currentRevision = data.applied_revision
                    dlg._setStatus(true, "Applied. New revision=" + dlg.currentRevision)
                    if (dlg.controllerRef) dlg.controllerRef.fetchConfig(dlg.loggerId)
                } else {
                    dlg._setStatus(false, "[" + data.http_status + "] " + _errorText(data))
                }
            } catch (e) { dlg._setStatus(false, "Parse error: " + e) }
        }
        function onSensorsUpdated(id, payloadJson) {
            if (id !== dlg.loggerId) return
            try {
                var data = JSON.parse(payloadJson)
                dlg.sensorList    = data.sensors || []
                dlg.polling       = !!data.polling
                dlg.rtuConnected  = !!data.rtu_connected
                dlg.anyAlarm      = !!data.any_alarm
                dlg.online        = true
            } catch (e) { /* ignore */ }
        }
    }

    // ─── Content ──────────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // SubHeader
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: subHeader.implicitHeight + 24 * 2
            color: Qaterial.Style.colorTheme.background8

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width; height: 1
                color: Qaterial.Style.dividersColor()
            }

            ColumnLayout {
                id: subHeader
                anchors.fill: parent
                anchors.margins: 24
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Qaterial.RawMaterialButton {
                        outlined: true
                        display: AbstractButton.TextBesideIcon
                        icon.source: Qaterial.Icons.arrowLeft
                        icon.width: 18
                        icon.height: 18
                        text: "Back to Dashboard"
                        foregroundColor: Qaterial.Style.colorTheme.secondaryText
                        font.family: "JetBrains Mono"
                        font.pixelSize: 13
                        onClicked: dlg.close()
                    }
                    Item { Layout.fillWidth: true }
                    StatusPill {
                        visible: dlg.online && !dlg.anyAlarm
                        label: dlg.polling ? "Online • Polling" : "Online"
                        bgColor: "#00390A"
                        textColor: "#48AB4D"
                        dotColor: "#005313"
                        borderColor: "#78DC77"
                        pulse: dlg.polling
                    }
                    StatusPill {
                        visible: dlg.online && dlg.anyAlarm
                        label: "Online • ALARM"
                        bgColor: "#FFDAD6"
                        textColor: "#93000A"
                        dotColor: Qaterial.Style.errorColor
                        pulse: true
                    }
                    StatusPill {
                        visible: !dlg.online
                        label: "Offline"
                        bgColor: Qaterial.Style.colorTheme.surface
                        textColor: Qaterial.Style.colorTheme.secondaryText
                        dotColor: Qaterial.Style.colorTheme.disabledText
                        borderColor: Qaterial.Style.dividersColor()
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16

                    Qaterial.LabelHeadline3 {
                        text: dlg.loggerName
                        color: Qaterial.Style.colorTheme.primaryText
                        font.family: "Inter"
                        font.pixelSize: 32
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    // Host chip
                    Rectangle {
                        radius: 9999
                        color: Qaterial.Style.colorTheme.surface
                        border.color: Qaterial.Style.dividersColor()
                        border.width: 1
                        implicitHeight: 28
                        implicitWidth: hostLbl.implicitWidth + 24
                        Qaterial.LabelCaption {
                            id: hostLbl
                            anchors.centerIn: parent
                            text: dlg.host + ":" + dlg.port
                            color: Qaterial.Style.colorTheme.secondaryText
                            font.family: "JetBrains Mono"
                            font.pixelSize: 13
                        }
                    }
                    // Unit chip
                    Rectangle {
                        radius: 9999
                        color: Qaterial.Style.colorTheme.surface
                        border.color: Qaterial.Style.dividersColor()
                        border.width: 1
                        implicitHeight: 28
                        implicitWidth: unitLbl.implicitWidth + 24
                        Qaterial.LabelCaption {
                            id: unitLbl
                            anchors.centerIn: parent
                            text: "Unit " + dlg.unitId
                            color: Qaterial.Style.colorTheme.secondaryText
                            font.family: "JetBrains Mono"
                            font.pixelSize: 13
                        }
                    }
                }
            }
        }

        // TabBar
        Qaterial.TabBar {
            id: tabBar
            Layout.fillWidth: true

            Qaterial.TabButton {
                text: "Monitor"
                font.family: "JetBrains Mono"
                font.pixelSize: 13
                font.weight: Font.Bold
            }
            Qaterial.TabButton {
                text: "Remote Config"
                font.family: "JetBrains Mono"
                font.pixelSize: 13
            }
        }

        // Tabs content
        StackLayout {
            id: tabStack
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: tabBar.currentIndex

            // ─── Monitor ─────────────────────────────────────────────────────
            Rectangle {
                color: Qaterial.Style.backgroundColor

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 24
                    spacing: 16

                    Qaterial.LabelBody2 {
                        visible: dlg.sensorList.length === 0
                        text: dlg.online
                            ? "Waiting for first Modbus snapshot..."
                            : "Logger offline — no sensor data available."
                        color: Qaterial.Style.colorTheme.secondaryText
                        font.family: "Inter"
                        font.pixelSize: 14
                        Layout.alignment: Qt.AlignHCenter
                    }

                    GridView {
                        id: sensorGrid
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: dlg.sensorList.length > 0
                        cellWidth: 240
                        cellHeight: 200
                        clip: true
                        model: dlg.sensorList
                        delegate: SensorCard {
                            width: sensorGrid.cellWidth - 8
                            height: sensorGrid.cellHeight - 8
                            sensorType: "ANALOG"
                            title: "Sensor #" + modelData.sensor_id
                            value: dlg._formatValue(modelData.value)
                            unit: ""
                            alarm: !!modelData.alarm
                            stale: !!modelData.stale
                            valid: !!modelData.valid
                            alarmType: "max"
                            lastUpdate: Qt.formatTime(new Date(), "hh:mm:ss")
                        }
                    }
                }
            }

            // ─── Remote Config ────────────────────────────────────────────────
            Rectangle {
                color: Qaterial.Style.backgroundColor

                Qaterial.ScrollView {
                    id: configScroll
                    anchors.fill: parent
                    contentWidth: availableWidth
                    clip: true

                    ColumnLayout {
                        // Fix clipping: center using ScrollView availableWidth
                        x: Math.max(0, (configScroll.availableWidth - width) / 2)
                        width: Math.min(configScroll.availableWidth - 32 * 2, 820)
                        spacing: 24

                        Item { implicitHeight: 24 }

                        // Quick actions row
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Qaterial.RawMaterialButton {
                                text: "Refresh"
                                enabled: !dlg.busy && dlg.controllerRef !== null
                                onClicked: {
                                    dlg.busy = true
                                    dlg.controllerRef.checkHealth(dlg.loggerId)
                                    dlg.controllerRef.fetchConfig(dlg.loggerId)
                                }
                            }
                            Qaterial.RawMaterialButton {
                                text: "Health Check"
                                enabled: !dlg.busy && dlg.controllerRef !== null
                                onClicked: {
                                    dlg.busy = true
                                    dlg.controllerRef.checkHealth(dlg.loggerId)
                                }
                            }
                            Item { Layout.fillWidth: true }
                            Qaterial.BusyIndicator { running: dlg.busy; visible: dlg.busy }
                            StatusPill {
                                visible: dlg.currentRevision >= 0
                                label: "Revision " + dlg.currentRevision
                                bgColor: Qaterial.Style.colorTheme.surface
                                textColor: Qaterial.Style.colorTheme.secondaryText
                                dotColor: Qaterial.Style.primaryColor
                            }
                        }

                        // Cloud Connection Settings card
                        Rectangle {
                            Layout.fillWidth: true
                            radius: 16
                            color: Qaterial.Style.colorTheme.background8
                            border.color: Qaterial.Style.dividersColor()
                            border.width: 1
                            implicitHeight: connForm.implicitHeight + 32 * 2

                            ColumnLayout {
                                id: connForm
                                anchors.fill: parent
                                anchors.margins: 32
                                spacing: 24

                                Qaterial.LabelHeadline6 {
                                    text: "Cloud Connection Settings"
                                    color: Qaterial.Style.colorTheme.primaryText
                                    font.family: "Inter"
                                    font.pixelSize: 20
                                    font.weight: Font.DemiBold
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    Qaterial.LabelCaption {
                                        text: "API Token"
                                        color: Qaterial.Style.colorTheme.secondaryText
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: 13
                                    }
                                    Qaterial.TextField {
                                        id: tokenField
                                        Layout.fillWidth: true
                                        placeholderText: "sk_..."
                                        echoMode: TextInput.Password
                                        font.family: "JetBrains Mono"
                                    }
                                    Qaterial.LabelBody2 {
                                        text: "Bearer token for REST config to Edge device."
                                        color: Qaterial.Style.colorTheme.disabledText
                                        font.family: "Inter"
                                        font.pixelSize: 12
                                    }
                                }

                                GridLayout {
                                    Layout.fillWidth: true
                                    columns: 2
                                    columnSpacing: 24
                                    rowSpacing: 8

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 4
                                        Qaterial.LabelCaption {
                                            text: "API Port"
                                            color: Qaterial.Style.colorTheme.secondaryText
                                            font.family: "JetBrains Mono"
                                            font.pixelSize: 13
                                        }
                                        Qaterial.TextField {
                                            id: apiPortField
                                            Layout.fillWidth: true
                                            placeholderText: "8080"
                                            inputMethodHints: Qt.ImhDigitsOnly
                                            font.family: "JetBrains Mono"
                                        }
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 4
                                        Qaterial.LabelCaption {
                                            text: "Polling Interval (ms)"
                                            color: Qaterial.Style.colorTheme.secondaryText
                                            font.family: "JetBrains Mono"
                                            font.pixelSize: 13
                                        }
                                        Qaterial.TextField {
                                            id: pollIntervalField
                                            Layout.fillWidth: true
                                            placeholderText: "2000"
                                            inputMethodHints: Qt.ImhDigitsOnly
                                            font.family: "JetBrains Mono"
                                        }
                                    }
                                }

                                // Connection status panel
                                Rectangle {
                                    Layout.fillWidth: true
                                    radius: 8
                                    color: dlg.currentRevision >= 0
                                        ? "#00390A"
                                        : Qaterial.Style.colorTheme.surface
                                    border.color: Qaterial.Style.dividersColor()
                                    border.width: 1
                                    implicitHeight: connStatusRow.implicitHeight + 16 * 2

                                    RowLayout {
                                        id: connStatusRow
                                        anchors.fill: parent
                                        anchors.margins: 16
                                        spacing: 8
                                        Item {
                                            Layout.preferredWidth: 22
                                            Layout.preferredHeight: 22
                                            Layout.alignment: Qt.AlignVCenter
                                            Qaterial.Icon {
                                                anchors.centerIn: parent
                                                icon: dlg.currentRevision >= 0 ? Qaterial.Icons.cloudCheck : Qaterial.Icons.alert
                                                size: 18
                                                color: dlg.currentRevision >= 0
                                                    ? "#48AB4D"
                                                    : Qaterial.Style.colorTheme.disabledText
                                            }
                                        }
                                        Qaterial.LabelBody2 {
                                            text: dlg.currentRevision >= 0
                                                ? "Authorized • Synced (revision " + dlg.currentRevision + ")"
                                                : "Not synced — click Refresh to check"
                                            color: dlg.currentRevision >= 0
                                                ? "#48AB4D"
                                                : Qaterial.Style.colorTheme.secondaryText
                                            font.family: "JetBrains Mono"
                                            font.pixelSize: 13
                                        }
                                        Item { Layout.fillWidth: true }
                                    }
                                }
                            }
                        }

                        // Logger Configuration card
                        Rectangle {
                            Layout.fillWidth: true
                            radius: 16
                            color: Qaterial.Style.colorTheme.background8
                            border.color: Qaterial.Style.dividersColor()
                            border.width: 1
                            implicitHeight: advForm.implicitHeight + 32 * 2

                            ColumnLayout {
                                id: advForm
                                anchors.fill: parent
                                anchors.margins: 32
                                spacing: 24

                                Qaterial.LabelHeadline6 {
                                    text: "Logger Configuration (partial update)"
                                    color: Qaterial.Style.colorTheme.primaryText
                                    font.family: "Inter"
                                    font.pixelSize: 20
                                    font.weight: Font.DemiBold
                                }

                                GridLayout {
                                    Layout.fillWidth: true
                                    columns: 2
                                    columnSpacing: 24
                                    rowSpacing: 8

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 4
                                        Qaterial.LabelCaption {
                                            text: "Logger Serial"
                                            color: Qaterial.Style.colorTheme.secondaryText
                                            font.family: "JetBrains Mono"
                                            font.pixelSize: 13
                                        }
                                        Qaterial.TextField {
                                            id: loggerSerialField
                                            Layout.fillWidth: true
                                            placeholderText: "HN_QUY_TEST01"
                                            font.family: "JetBrains Mono"
                                        }
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 4
                                        Qaterial.LabelCaption {
                                            text: "Modbus TCP Bind"
                                            color: Qaterial.Style.colorTheme.secondaryText
                                            font.family: "JetBrains Mono"
                                            font.pixelSize: 13
                                        }
                                        Qaterial.TextField {
                                            id: modbusBindField
                                            Layout.fillWidth: true
                                            placeholderText: "0.0.0.0"
                                            font.family: "JetBrains Mono"
                                        }
                                    }
                                }

                                Qaterial.LabelCaption {
                                    text: "Raw config snapshot (read-only)"
                                    color: Qaterial.Style.colorTheme.secondaryText
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: 13
                                }
                                Qaterial.ScrollView {
                                    id: rawConfigScroll
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 200
                                    clip: true
                                    Qaterial.TextArea {
                                        id: rawConfig
                                        width: rawConfigScroll.availableWidth
                                        wrapMode: TextEdit.WrapAnywhere
                                        text: "{}"
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: 12
                                        selectByMouse: true
                                        Component.onCompleted: Qt.callLater(function () {
                                            if (rawConfig.textArea)
                                                rawConfig.textArea.readOnly = true
                                        })
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Item { Layout.fillWidth: true }
                                    Qaterial.RawMaterialButton {
                                        outlined: true
                                        text: "Cancel"
                                        foregroundColor: Qaterial.Style.colorTheme.secondaryText
                                        onClicked: dlg.close()
                                    }
                                    Qaterial.RawMaterialButton {
                                        outlined: true
                                        text: "Save Token / Port"
                                        enabled: !dlg.busy && dlg.controllerRef !== null
                                                 && (tokenField.text.length > 0
                                                     || apiPortField.text.length > 0)
                                        onClicked: {
                                            dlg.controllerRef.updateLoggerApi(
                                                dlg.loggerId,
                                                tokenField.text,
                                                parseInt(apiPortField.text) || 0)
                                            dlg._setStatus(true, "API token/port saved.")
                                        }
                                    }
                                    Qaterial.Button {
                                        text: "Apply Config"
                                        enabled: !dlg.busy && dlg.controllerRef !== null
                                                 && dlg.currentRevision >= 0
                                        onClicked: {
                                            var patch = dlg._buildConfigPatch()
                                            if (Object.keys(patch).length === 0) {
                                                dlg._setStatus(false, "No fields to submit.")
                                                return
                                            }
                                            dlg.busy = true
                                            dlg.controllerRef.applyConfig(
                                                dlg.loggerId, dlg.currentRevision,
                                                JSON.stringify(patch))
                                        }
                                    }
                                }
                            }
                        }

                        Qaterial.LabelBody2 {
                            Layout.fillWidth: true
                            text: dlg.statusText
                            color: dlg.statusOk ? Qaterial.Style.green : Qaterial.Style.errorColor
                            font.family: "Inter"
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                        }

                        Item { implicitHeight: 24 }
                    }
                }
            }
        }
    }
}
