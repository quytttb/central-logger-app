import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qaterial 1.0 as Qaterial


/*
 * Sensor card (Monitor tab).
 * Types: ANALOG (default), DI, DO. ALARM from flag.
 */
Qaterial.Card {
    id: card

    property string sensorType: "ANALOG"
    property string title: ""
    property string value: "---"
    property string unit: ""
    property string rawValue: ""
    property bool alarm: false
    property bool stale: false
    property bool valid: true
    property string alarmType: "max"
    property string lastUpdate: ""

    readonly property bool isAnalog: sensorType === "ANALOG"
    readonly property bool isDI: sensorType === "DI"
    readonly property bool isDO: sensorType === "DO"
    readonly property bool isOn: value === "1" || value === "ON"

    padding: 16
    implicitWidth: 220
    implicitHeight: 180
    elevationOnHovered: true
    outlined: card.alarm
    borderColor: card.alarm ? Qaterial.Style.errorColor : Qaterial.Style.dividersColor()
    backgroundColor: Qaterial.Style.colorTheme.background8

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Qaterial.LabelBody2 {
                text: card.title
                color: Qaterial.Style.colorTheme.primaryText
                font.family: "Inter"
                font.weight: Font.DemiBold
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            Item {
                visible: card.alarm
                width: 22
                height: 22
                Qaterial.Icon {
                    anchors.centerIn: parent
                    icon: Qaterial.Icons.alertCircle
                    size: 18
                    color: Qaterial.Style.errorColor
                }
            }
            Rectangle {
                visible: !card.alarm && card.isAnalog
                width: 22
                height: 22
                radius: 11
                color: Qaterial.Style.colorTheme.surface
                Qaterial.Icon {
                    anchors.centerIn: parent
                    icon: Qaterial.Icons.diameterOutline
                    size: 14
                    color: Qaterial.Style.colorTheme.secondaryText
                }
            }
            Rectangle {
                visible: card.isDI
                radius: 4
                color: "#CFE6F2"
                implicitWidth: diLbl.implicitWidth + 12
                implicitHeight: 22
                Qaterial.LabelCaption {
                    id: diLbl
                    anchors.centerIn: parent
                    text: "DI"
                    color: "#526772"
                    font.family: "JetBrains Mono"
                    font.weight: Font.Medium
                }
            }
            Rectangle {
                visible: card.isDO
                radius: 4
                color: Qaterial.Style.primaryColor
                implicitWidth: doLbl.implicitWidth + 12
                implicitHeight: 22
                Qaterial.LabelCaption {
                    id: doLbl
                    anchors.centerIn: parent
                    text: "DO"
                    color: "#FFFFFF"
                    font.family: "JetBrains Mono"
                    font.weight: Font.Medium
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Qaterial.LabelHeadline6 {
                    text: card.value
                    color: card.alarm
                        ? Qaterial.Style.errorColor
                        : (card.isDO && card.isOn ? Qaterial.Style.primaryColor
                                                  : (card.isDI ? Qaterial.Style.colorTheme.secondaryText
                                                              : Qaterial.Style.colorTheme.primaryText))
                    font.family: "Inter"
                    font.pixelSize: card.isAnalog ? 32 : 24
                    font.weight: Font.Bold
                }
                Qaterial.LabelBody2 {
                    text: card.isAnalog
                        ? card.unit
                        : (card.isDI || card.isDO
                            ? (card.isOn ? qsTr("(ON)") : qsTr("(OFF)"))
                            : "")
                    color: card.alarm ? Qaterial.Style.errorColor : Qaterial.Style.colorTheme.secondaryText
                    font.family: "Inter"
                    Layout.alignment: Qt.AlignBottom
                    Layout.bottomMargin: 4
                }
                Item {
                    Layout.fillWidth: true
                }
            }
            Qaterial.LabelCaption {
                visible: card.isAnalog && card.rawValue !== ""
                text: qsTr("Raw: ") + card.rawValue
                color: Qaterial.Style.colorTheme.secondaryText
                font.family: "JetBrains Mono"
            }
            Qaterial.LabelCaption {
                visible: card.stale
                text: qsTr("STALE")
                color: Qaterial.Style.orange
                font.family: "JetBrains Mono"
                font.weight: Font.Bold
            }
        }

        Item {
            Layout.fillHeight: true
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Qaterial.Style.dividersColor()
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            StatusPill {
                visible: card.alarm
                label: card.alarmType === "min"
                    ? qsTr("ALARM (MIN)")
                    : (card.alarmType === "max" ? qsTr("ALARM (MAX)") : qsTr("ALARM"))
                bgColor: "#FFDAD6"
                textColor: "#93000A"
                dotColor: Qaterial.Style.errorColor
                showDot: false
            }
            StatusPill {
                visible: !card.alarm && !card.stale && card.valid
                label: qsTr("OK")
                bgColor: Qaterial.Style.colorTheme.surface
                textColor: Qaterial.Style.colorTheme.primaryText
                dotColor: Qaterial.Style.green
                showDot: false
            }
            StatusPill {
                visible: !card.alarm && card.stale
                label: qsTr("STALE")
                bgColor: Qt.rgba(0.93, 0.42, 0.01, 0.18)
                textColor: Qaterial.Style.orange
                dotColor: Qaterial.Style.orange
                showDot: false
            }
            StatusPill {
                visible: !card.valid && !card.alarm
                label: qsTr("INVALID")
                bgColor: Qaterial.Style.colorTheme.surface
                textColor: Qaterial.Style.colorTheme.disabledText
                dotColor: Qaterial.Style.colorTheme.disabledText
                showDot: false
            }
            Item {
                Layout.fillWidth: true
            }
            Qaterial.LabelCaption {
                text: card.lastUpdate
                color: Qaterial.Style.colorTheme.secondaryText
                font.family: "JetBrains Mono"
            }
        }
    }
}
