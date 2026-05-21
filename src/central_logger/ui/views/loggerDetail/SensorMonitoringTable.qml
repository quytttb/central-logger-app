import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import CentralLogger.Core 1.0

import "../../"
import "../../components/common"
import "../../components/cards"
import components

PanelCard {
    id: sensorPanel
    property var detail: ({})

    bodyMargins: 16
    readonly property int cellPadH: 12

    title: "Sensor Monitoring"
    titleFontFamily: "Roboto"
    headerNote: (detail.catalogError && detail.catalogError.length > 0) ? detail.catalogError : ""
    subtitle: (detail.sensorList ? detail.sensorList.length : 0) + " Total Sensors"
    clipBody: true

    readonly property bool compactRow: width < 400
    readonly property bool showIdCol: !compactRow && width >= 520
    readonly property bool showUnitCol: !compactRow && width >= 640

    function _valueText(sensor) {
        var stype = (sensor.sensor_type || "").toUpperCase()
        var isDigital = stype === "DI" || stype === "DO"
        var hasValue = sensor.value !== null && sensor.value !== undefined
        if (!hasValue) return "—"
        if (isDigital)
            return sensor.value >= 0.5 ? "ON" : "OFF"
        return String(sensor.value)
    }

    function _unitText(sensor) {
        var stype = (sensor.sensor_type || "").toUpperCase()
        var isDigital = stype === "DI" || stype === "DO"
        if (isDigital) return "—"
        if (sensor.value !== null && sensor.value !== undefined
                && sensor.unit && sensor.unit.length > 0)
            return sensor.unit
        return "—"
    }

    function _modelColumnVisible(modelCol) {
        if (compactRow)
            return modelCol === 1 || modelCol === 4
        if (modelCol === 0) return showIdCol
        if (modelCol === 3) return showUnitCol
        return modelCol === 1 || modelCol === 2 || modelCol === 4
    }

    function _columnKind(modelCol) {
        switch (modelCol) {
        case 0: return "id"
        case 1: return "name"
        case 2: return "value"
        case 3: return "unit"
        case 4: return "status"
        default: return ""
        }
    }

    function _headerTextForModelColumn(modelCol) {
        if (!_modelColumnVisible(modelCol))
            return ""
        switch (modelCol) {
        case 0: return "ID"
        case 1: return compactRow ? "SENSOR" : "SENSOR NAME"
        case 2: return "VALUE"
        case 3: return "UNIT"
        case 4: return "STATUS"
        default: return ""
        }
    }

    function columnWidthForModelColumn(modelCol) {
        if (!_modelColumnVisible(modelCol))
            return 0
        var w = sensorTableView.width
        if (compactRow) {
            if (modelCol === 1) return Math.max(80, w * 0.62)
            if (modelCol === 4) return Math.max(72, w * 0.38)
            return 0
        }
        if (modelCol === 0) return 52
        if (modelCol === 4) return Math.max(88, w * 0.14)
        var visible = []
        for (var c = 0; c < 5; ++c) {
            if (_modelColumnVisible(c))
                visible.push(c)
        }
        var n = visible.length
        var flexCols = n - (showIdCol ? 1 : 0) - 1
        return Math.max(56, (w - (showIdCol ? 52 : 0) - 88) / Math.max(1, flexCols))
    }

    function syncSensorModel() {
        sensorModel.setSensors(detail.sensorList || [])
    }

    function refreshTableLayout() {
        if (sensorTableView)
            sensorTableView.forceLayout()
    }

    Timer {
        id: layoutRefreshTimer
        interval: 0
        repeat: false
        onTriggered: sensorPanel.refreshTableLayout()
    }

    onDetailChanged: syncSensorModel()
    onWidthChanged: layoutRefreshTimer.restart()
    onIsDarkChanged: layoutRefreshTimer.restart()

    Component.onCompleted: {
        syncSensorModel()
        layoutRefreshTimer.start()
    }

    SensorMonitoringTableModel {
        id: sensorModel
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            color: Colors.surfaceSubtle(sensorPanel.isDark)
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: Colors.border(sensorPanel.isDark)
            }
            HorizontalHeaderView {
                anchors.fill: parent
                syncView: sensorTableView
                clip: true
                // Custom delegate sets text; syncView model has no "display" role.
                textRole: ""
                delegate: TableHeaderCell {
                    required property int column
                    implicitHeight: 40
                    visible: sensorPanel._modelColumnVisible(column)
                    text: sensorPanel._headerTextForModelColumn(column)
                    rowHeight: 40
                    padH: sensorPanel.cellPadH
                    isDark: sensorPanel.isDark
                }
            }
        }

        TableView {
            id: sensorTableView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            reuseItems: true
            rowSpacing: 0
            boundsBehavior: Flickable.StopAtBounds
            model: sensorModel
            rowHeightProvider: function() { return sensorPanel.compactRow ? 64 : 48 }

            columnWidthProvider: function(column) {
                return sensorPanel.columnWidthForModelColumn(column)
            }

            delegate: Rectangle {
                required property int row
                required property int column

                implicitHeight: sensorPanel.compactRow ? 64 : 48
                visible: sensor !== null && sensorPanel._modelColumnVisible(column)
                color: row % 2 === 0
                    ? Colors.surface(sensorPanel.isDark)
                    : Colors.surfaceSubtle(sensorPanel.isDark)

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: Colors.divider(sensorPanel.isDark)
                }

                readonly property var sensor: {
                    var list = sensorPanel.detail.sensorList
                    if (!list || row < 0 || row >= list.length)
                        return null
                    return list[row]
                }
                readonly property string colKind: sensorPanel._columnKind(column)
                readonly property string dstatus: sensor ? (sensor.display_status || "") : ""
                readonly property string stype: sensor ? (sensor.sensor_type || "").toUpperCase() : ""
                readonly property bool isDigital: stype === "DI" || stype === "DO"
                readonly property bool hasValue: sensor
                    && sensor.value !== null && sensor.value !== undefined
                readonly property string valueText: sensor ? sensorPanel._valueText(sensor) : "—"
                readonly property string unitText: sensor ? sensorPanel._unitText(sensor) : "—"
                readonly property string sensorId: sensor ? String(sensor.sensor_id) : ""
                readonly property string name: sensor
                    ? (sensor.name || sensor.type || ("Sensor " + sensor.sensor_id))
                    : ""

                UiLabel {
                    visible: colKind === "id"
                    anchors.fill: parent
                    anchors.leftMargin: sensorPanel.cellPadH
                    anchors.rightMargin: sensorPanel.cellPadH
                    verticalAlignment: Text.AlignVCenter
                    textType: UiLabel.Caption
                    text: sensorId
                    color: Colors.textSecondary(sensorPanel.isDark)
                    font.family: "Roboto Mono"
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }

                ColumnLayout {
                    visible: colKind === "name" && !sensorPanel.compactRow
                    anchors.fill: parent
                    anchors.leftMargin: sensorPanel.cellPadH
                    anchors.rightMargin: sensorPanel.cellPadH
                    spacing: 2
                    UiLabel {
                        textType: UiLabel.Body2
                        Layout.fillWidth: true
                        text: name
                        font.family: "Roboto"
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        color: SensorPalette.colorForSensorId(
                            sensor.sensor_id,
                            SensorPalette.orderedSensorIds(sensorPanel.detail.sensorList)
                        )
                        elide: Text.ElideRight
                    }
                    UiLabel {
                        visible: stype.length > 0
                        textType: UiLabel.Caption
                        Layout.fillWidth: true
                        text: stype
                        color: Colors.textMuted(sensorPanel.isDark)
                        font.family: "Roboto"
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                }

                UiLabel {
                    visible: colKind === "value"
                    anchors.fill: parent
                    anchors.leftMargin: sensorPanel.cellPadH
                    anchors.rightMargin: sensorPanel.cellPadH
                    verticalAlignment: Text.AlignVCenter
                    textType: UiLabel.Body2
                    text: valueText
                    color: (dstatus === "ALARM" || (sensor && sensor.alarm))
                        ? Colors.destructiveHover(sensorPanel.isDark)
                        : (isDigital && hasValue && sensor.value >= 0.5
                            ? Colors.badgeText(sensorPanel.isDark, "blue")
                            : Colors.textPrimary(sensorPanel.isDark))
                    font.family: "Roboto"
                    font.pixelSize: 14
                    font.weight: (dstatus === "ALARM" || (sensor && sensor.alarm))
                        ? Font.Bold : Font.Normal
                    elide: Text.ElideRight
                }

                UiLabel {
                    visible: colKind === "unit"
                    anchors.fill: parent
                    anchors.leftMargin: sensorPanel.cellPadH
                    anchors.rightMargin: sensorPanel.cellPadH
                    verticalAlignment: Text.AlignVCenter
                    textType: UiLabel.Caption
                    text: unitText
                    color: Colors.textMuted(sensorPanel.isDark)
                    font.family: "Roboto"
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }

                SensorStatusBadge {
                    visible: colKind === "status"
                    anchors.left: parent.left
                    anchors.leftMargin: sensorPanel.cellPadH
                    anchors.verticalCenter: parent.verticalCenter
                    status: dstatus
                    alarmType: sensor ? (sensor.alarm_type || "") : ""
                    isDark: sensorPanel.isDark
                }

                ColumnLayout {
                    visible: colKind === "name" && sensorPanel.compactRow
                    anchors.fill: parent
                    anchors.leftMargin: sensorPanel.cellPadH
                    anchors.rightMargin: sensorPanel.cellPadH
                    spacing: 4
                    UiLabel {
                        textType: UiLabel.Body2
                        Layout.fillWidth: true
                        text: name
                        font.family: "Roboto"
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        color: SensorPalette.colorForSensorId(
                            sensor.sensor_id,
                            SensorPalette.orderedSensorIds(sensorPanel.detail.sensorList)
                        )
                        elide: Text.ElideRight
                    }
                    UiLabel {
                        textType: UiLabel.Caption
                        Layout.fillWidth: true
                        text: "#" + sensorId + " · " + valueText
                            + (unitText !== "—" ? (" · " + unitText) : "")
                        color: Colors.textMuted(sensorPanel.isDark)
                        font.family: "Roboto Mono"
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                }
            }

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }
            ScrollBar.horizontal: ScrollBar {
                policy: ScrollBar.AsNeeded
            }
        }
    }
}
