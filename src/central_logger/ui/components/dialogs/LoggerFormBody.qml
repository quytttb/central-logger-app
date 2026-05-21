import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "../.."
import "../common"
import components

Item {
    id: root

    required property var form
    readonly property int gridColumns: width > 900 ? 3 : 1

    implicitWidth: grid.implicitWidth
    implicitHeight: grid.implicitHeight

    function fieldSnapshot() {
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

    function loadFromDetail(d) {
        var src = d || {}
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
            if (root.form.mode === "add" && !(nameField.value || "").trim())
                nameField.setValue(fields.station_name)
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

    GridLayout {
        id: grid
        width: parent.width
        columns: root.gridColumns
        columnSpacing: 32
        rowSpacing: 20

        ColumnLayout {
            Layout.fillWidth: true
            Layout.column: 0
            Layout.row: 0
            spacing: 20

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12
                FormSectionLabel { text: "BASIC" }
                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 12
                    rowSpacing: 12
                    LoggerFormField {
                        id: nameField
                        label: "Name *"
                        isDark: root.form.isDark
                    }
                    LoggerFormField {
                        id: noteField
                        label: "Note (optional)"
                        isDark: root.form.isDark
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12
                FormSectionLabel { text: "CENTRAL — MODBUS" }
                LoggerFormField {
                    id: hostField
                    label: "Host IP *"
                    isDark: root.form.isDark
                    Layout.fillWidth: true
                }
                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 12
                    rowSpacing: 12
                    LoggerFormField { id: portField; label: "Modbus Port"; isDark: root.form.isDark }
                    LoggerFormField { id: unitField; label: "Unit ID"; isDark: root.form.isDark }
                    LoggerFormField { id: timeoutField; label: "Modbus timeout (s)"; isDark: root.form.isDark }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12
                FormSectionLabel { text: "CENTRAL — REST API" }
                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 12
                    rowSpacing: 12
                    LoggerFormField { id: apiPortField; label: "API Port"; isDark: root.form.isDark }
                    LoggerFormField {
                        id: tokenField
                        label: "API Token"
                        isDark: root.form.isDark
                        isPassword: true
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Rectangle {
                        Layout.preferredWidth: scanQrRow.implicitWidth + 24
                        Layout.preferredHeight: 32
                        radius: 6
                        opacity: root.form.qrScanEnabled ? 1.0 : 0.45
                        color: scanQrMouse.containsMouse && root.form.qrScanEnabled
                            ? Colors.buttonSecondaryHover(root.form.isDark)
                            : Colors.surfaceMuted(root.form.isDark)
                        border.width: 1
                        border.color: Colors.borderMuted(root.form.isDark)
                        RowLayout {
                            id: scanQrRow
                            anchors.centerIn: parent
                            spacing: 6
                            UiIcon {
                                name: "qrCode"
                                size: 14
                                iconColor: Colors.textMuted(root.form.isDark)
                            }
                            UiLabel {
                                textType: UiLabel.Caption
                                text: "Scan QR…"
                                color: Colors.textMuted(root.form.isDark)
                                font.family: "Inter"
                                font.pixelSize: 12
                                font.weight: Font.Medium
                            }
                        }
                        MouseArea {
                            id: scanQrMouse
                            anchors.fill: parent
                            hoverEnabled: root.form.qrScanEnabled
                            cursorShape: root.form.qrScanEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                if (root.form.qrScanEnabled)
                                    root.form.importQrFromFile()
                                else if (typeof window !== "undefined" && window && window.notify)
                                    window.notify("QR scan unavailable (see README — ZBar DLL on Windows)", "warning")
                            }
                        }
                    }
                    UiLabel {
                        textType: UiLabel.Caption
                        Layout.fillWidth: true
                        text: root.form.qrScanEnabled
                            ? "Import pairing QR from data-logger (PNG/JPG)"
                            : "QR scan unavailable — enter API token manually"
                        color: Colors.textMuted(root.form.isDark)
                        font.family: "Inter"
                        font.pixelSize: 11
                        wrapMode: Text.WordWrap
                    }
                }
                LoggerFormField {
                    id: apiBaseUrlField
                    label: "API Base URL (optional)"
                    isDark: root.form.isDark
                    Layout.fillWidth: true
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    radius: 6
                    color: connectMouse.containsMouse
                        ? Colors.primaryHover(root.form.isDark)
                        : Colors.primary(root.form.isDark)
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        UiIcon { name: "link"; size: 16; iconColor: "#ffffff" }
                        UiLabel {
                            textType: UiLabel.Body2
                            text: "Connect & Load Config"
                            color: "#ffffff"
                            font.family: "Inter"
                            font.pixelSize: 13
                            font.weight: Font.Medium
                        }
                    }
                    MouseArea {
                        id: connectMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.form.connectAndLoadConfig()
                    }
                }
            }
        }

        Rectangle {
            visible: root.gridColumns === 3
            Layout.column: 1
            Layout.row: 0
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            color: Colors.border(root.form.isDark)
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.column: root.gridColumns === 3 ? 2 : 0
            Layout.row: root.gridColumns === 3 ? 0 : 1
            spacing: 20
            enabled: root.form.deviceEditable
            opacity: root.form.deviceEditable ? 1.0 : 0.6

            Behavior on opacity {
                NumberAnimation { duration: 200 }
            }

            FormSectionLabel { text: "DEVICE — REST (Firmware)" }

            Rectangle {
                visible: !root.form.deviceEditable
                Layout.fillWidth: true
                implicitHeight: hintCol.implicitHeight + 24
                radius: 8
                color: Colors.surfaceMuted(root.form.isDark)
                border.width: 1
                border.color: Colors.border(root.form.isDark)
                ColumnLayout {
                    id: hintCol
                    anchors.centerIn: parent
                    width: parent.width - 32
                    spacing: 6
                    UiIcon {
                        Layout.alignment: Qt.AlignHCenter
                        name: "informationOutline"
                        size: 24
                        iconColor: Colors.textMuted(root.form.isDark)
                    }
                    UiLabel {
                        textType: UiLabel.Caption
                        Layout.fillWidth: true
                        text: root.form.mode === "add"
                            ? "Click Connect & Load Config on the left to load station, poll interval, and Modbus TCP settings from the edge device."
                            : "Click Connect & Load Config to refresh device settings from the edge."
                        color: Colors.textMuted(root.form.isDark)
                        font.family: "Inter"
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            ColumnLayout {
                visible: root.form.deviceEditable
                Layout.fillWidth: true
                spacing: 12

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 12
                    rowSpacing: 12
                    LoggerFormField {
                        id: stationCodeField
                        label: "Station code"
                        isDark: root.form.isDark
                        inputEnabled: root.form.deviceEditable
                    }
                    LoggerFormField {
                        id: stationNameField
                        label: "Station name"
                        isDark: root.form.isDark
                        inputEnabled: root.form.deviceEditable
                    }
                    LoggerFormField {
                        id: bindField
                        label: "Modbus TCP bind"
                        isDark: root.form.isDark
                        inputEnabled: root.form.deviceEditable
                    }
                    LoggerFormField {
                        id: unitIdDeviceField
                        label: "Modbus TCP unit ID (edge)"
                        isDark: root.form.isDark
                        inputEnabled: root.form.deviceEditable
                    }
                }
                LoggerFormField {
                    id: pollDeviceField
                    label: "Device poll interval (s)"
                    isDark: root.form.isDark
                    Layout.fillWidth: true
                    inputEnabled: root.form.deviceEditable
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    CheckBox { id: modbusTcpEnabledCheck }
                    UiLabel {
                        textType: UiLabel.Body2
                        text: "Modbus TCP server enabled"
                        color: Colors.textPrimary(root.form.isDark)
                        font.family: "Inter"
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.form.deviceEditable)
                                    modbusTcpEnabledCheck.toggle()
                            }
                        }
                    }
                }
            }
        }
    }
}
