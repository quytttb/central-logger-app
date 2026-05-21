import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "../../"
import "../../components/common"
import "../../components/cards"
import components

PanelCard {
    id: root
    property var detail: ({})

    title: "Sensor Monitoring"
    titleFontFamily: "Roboto"
    headerNote: (detail.catalogError && detail.catalogError.length > 0) ? detail.catalogError : ""
    subtitle: (detail.sensorList ? detail.sensorList.length : 0) + " Total Sensors"
    clipBody: true

    readonly property int rowPad: 24
    readonly property int hMargin: rowPad * 2
    readonly property int colSpacing: 8
    readonly property bool compactRow: width < 400
    readonly property bool showIdCol: !compactRow && width >= 520
    readonly property bool showUnitCol: !compactRow && width >= 640
    readonly property int colId: 52
    readonly property int colValue: width >= 480 ? 88 : 72
    readonly property int colUnit: 72
    readonly property int colStatus: width >= 480 ? 104 : 88
    readonly property int nameMinWidth: 80
    readonly property int rowInnerWidth: compactRow ? width - hMargin : (
        (showIdCol ? colId : 0) + colSpacing + nameMinWidth + colSpacing
        + colValue + colSpacing + (showUnitCol ? colUnit + colSpacing : 0) + colStatus
    )
    readonly property bool stretchColumns: !compactRow && rowInnerWidth + hMargin <= width + 1
    readonly property int tableScrollWidth: compactRow ? width : (
        stretchColumns ? width : Math.max(width, rowInnerWidth + hMargin)
    )
    readonly property bool useHorizontalScroll: !compactRow && !stretchColumns
    readonly property int flexMaxWidth: 100000
    readonly property int headerRowWidth: stretchColumns ? (width - hMargin) : rowInnerWidth

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            visible: !root.compactRow
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? 40 : 0
            color: Colors.surfaceSubtle(root.isDark)
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: Colors.border(root.isDark)
            }
            RowLayout {
                x: root.rowPad
                width: root.headerRowWidth
                height: parent.height
                spacing: root.colSpacing
                TableHeaderCell {
                    visible: root.showIdCol
                    text: "ID"
                    rowHeight: 40
                    Layout.preferredWidth: root.colId
                    Layout.maximumWidth: root.colId
                    isDark: root.isDark
                }
                TableHeaderCell {
                    text: "SENSOR NAME"
                    rowHeight: 40
                    Layout.fillWidth: true
                    Layout.minimumWidth: root.nameMinWidth
                    isDark: root.isDark
                }
                TableHeaderCell {
                    text: "VALUE"
                    rowHeight: 40
                    Layout.fillWidth: root.stretchColumns
                    Layout.preferredWidth: root.stretchColumns ? 56 : root.colValue
                    Layout.maximumWidth: root.stretchColumns ? root.flexMaxWidth : root.colValue
                    Layout.minimumWidth: root.stretchColumns ? 56 : 0
                    isDark: root.isDark
                }
                TableHeaderCell {
                    visible: root.showUnitCol
                    text: "UNIT"
                    rowHeight: 40
                    Layout.fillWidth: root.stretchColumns
                    Layout.preferredWidth: root.stretchColumns ? 48 : root.colUnit
                    Layout.maximumWidth: root.stretchColumns ? root.flexMaxWidth : root.colUnit
                    Layout.minimumWidth: root.stretchColumns ? 48 : 0
                    isDark: root.isDark
                }
                TableHeaderCell {
                    text: "STATUS"
                    rowHeight: 40
                    Layout.fillWidth: root.stretchColumns
                    Layout.preferredWidth: root.stretchColumns ? 72 : root.colStatus
                    Layout.maximumWidth: root.stretchColumns ? root.flexMaxWidth : root.colStatus
                    Layout.minimumWidth: root.stretchColumns ? 72 : 0
                    isDark: root.isDark
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Flickable {
                id: hFlick
                anchors.fill: parent
                contentWidth: root.tableScrollWidth
                contentHeight: height
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: root.useHorizontalScroll
                    ? Flickable.HorizontalFlick
                    : Flickable.AutoFlickDirection
                interactive: root.useHorizontalScroll

                ScrollBar.horizontal: ScrollBar {
                    policy: root.useHorizontalScroll ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                }

                ListView {
                    id: sensorListView
                    width: root.tableScrollWidth
                    height: parent.height
                    clip: true
                    reuseItems: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: detail.sensorList
                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }

                    delegate: ListRowDelegate {
                        width: sensorListView.width
                        height: root.compactRow ? 64 : 48
                        isDark: root.isDark

                        readonly property string stype: (modelData.sensor_type || "").toUpperCase()
                        readonly property bool isDigital: stype === "DI" || stype === "DO"
                        readonly property string dstatus: modelData.display_status || ""
                        readonly property bool hasValue: modelData.value !== null && modelData.value !== undefined

                        function _valueText() {
                            if (!hasValue) return "—"
                            if (isDigital)
                                return modelData.value >= 0.5 ? "ON" : "OFF"
                            return String(modelData.value)
                        }

                        function _unitText() {
                            if (isDigital) return "—"
                            if (hasValue && modelData.unit && modelData.unit.length > 0)
                                return modelData.unit
                            return "—"
                        }

                        function _metaLine() {
                            var parts = []
                            parts.push("#" + modelData.sensor_id)
                            parts.push(_valueText())
                            var u = _unitText()
                            if (u !== "—")
                                parts.push(u)
                            return parts.join(" · ")
                        }

                        ColumnLayout {
                            visible: root.compactRow
                            anchors.fill: parent
                            anchors.leftMargin: root.rowPad
                            anchors.rightMargin: root.rowPad
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                UiLabel {
                                    textType: UiLabel.Body2
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 40
                                    text: modelData.name || modelData.type || ("Sensor " + modelData.sensor_id)
                                    font.family: "Roboto"
                                    font.pixelSize: 14
                                    font.weight: Font.Medium
                                    color: SensorPalette.colorForSensorId(
                                        modelData.sensor_id,
                                        SensorPalette.orderedSensorIds(root.detail.sensorList)
                                    )
                                    elide: Text.ElideRight
                                }
                                SensorStatusBadge {
                                    status: dstatus
                                    alarmType: modelData.alarm_type || ""
                                    isDark: root.isDark
                                }
                            }
                            UiLabel {
                                textType: UiLabel.Caption
                                Layout.fillWidth: true
                                text: _metaLine()
                                color: Colors.textMuted(root.isDark)
                                font.family: "Roboto Mono"
                                font.pixelSize: 11
                                elide: Text.ElideRight
                            }
                        }

                        RowLayout {
                            visible: !root.compactRow
                            x: root.rowPad
                            width: root.stretchColumns ? (parent.width - root.hMargin) : root.rowInnerWidth
                            height: 48
                            spacing: root.colSpacing

                            UiLabel {
                                textType: UiLabel.Caption
                                visible: root.showIdCol
                                Layout.preferredWidth: root.colId
                                Layout.maximumWidth: root.colId
                                text: String(modelData.sensor_id)
                                color: Colors.textSecondary(root.isDark)
                                font.family: "Roboto Mono"
                                font.pixelSize: 12
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.minimumWidth: root.nameMinWidth
                                spacing: 2
                                UiLabel {
                                    textType: UiLabel.Body2
                                    Layout.fillWidth: true
                                    text: modelData.name || modelData.type || ("Sensor " + modelData.sensor_id)
                                    font.family: "Roboto"
                                    font.pixelSize: 14
                                    font.weight: Font.Medium
                                    color: SensorPalette.colorForSensorId(
                                        modelData.sensor_id,
                                        SensorPalette.orderedSensorIds(root.detail.sensorList)
                                    )
                                    elide: Text.ElideRight
                                }
                                UiLabel {
                                    textType: UiLabel.Caption
                                    visible: modelData.sensor_type && modelData.sensor_type.length > 0
                                    Layout.fillWidth: true
                                    text: modelData.sensor_type
                                    color: Colors.textMuted(root.isDark)
                                    font.family: "Roboto"
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }
                            }
                            UiLabel {
                                textType: UiLabel.Body2
                                Layout.fillWidth: root.stretchColumns
                                Layout.preferredWidth: root.stretchColumns ? 56 : root.colValue
                                Layout.maximumWidth: root.stretchColumns ? root.flexMaxWidth : root.colValue
                                Layout.minimumWidth: root.stretchColumns ? 56 : 0
                                text: _valueText()
                                horizontalAlignment: Text.AlignLeft
                                color: (dstatus === "ALARM" || modelData.alarm)
                                    ? Colors.destructiveHover(root.isDark)
                                    : (isDigital && hasValue && modelData.value >= 0.5
                                        ? Colors.badgeText(root.isDark, "blue")
                                        : Colors.textPrimary(root.isDark))
                                font.family: "Roboto"
                                font.pixelSize: 14
                                font.weight: (dstatus === "ALARM" || modelData.alarm) ? Font.Bold : Font.Normal
                                elide: Text.ElideRight
                            }
                            UiLabel {
                                textType: UiLabel.Caption
                                visible: root.showUnitCol
                                Layout.fillWidth: root.stretchColumns
                                Layout.preferredWidth: root.stretchColumns ? 48 : root.colUnit
                                Layout.maximumWidth: root.stretchColumns ? root.flexMaxWidth : root.colUnit
                                Layout.minimumWidth: root.stretchColumns ? 48 : 0
                                text: _unitText()
                                horizontalAlignment: Text.AlignLeft
                                color: Colors.textMuted(root.isDark)
                                font.family: "Roboto"
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }
                            Item {
                                Layout.fillWidth: root.stretchColumns
                                Layout.preferredWidth: root.stretchColumns ? 72 : root.colStatus
                                Layout.maximumWidth: root.stretchColumns ? root.flexMaxWidth : root.colStatus
                                Layout.minimumWidth: root.stretchColumns ? 72 : 0
                                Layout.preferredHeight: 48
                                SensorStatusBadge {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    status: dstatus
                                    alarmType: modelData.alarm_type || ""
                                    isDark: root.isDark
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
