import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qaterial 1.0 as Qaterial


/*
 * Logger card on Dashboard.
 * States: Online-Healthy / Online-Alarm / Offline (dimmed).
 */
Qaterial.Card {
    id: card

    property int loggerId: -1
    property string loggerName: ""
    property string host: ""
    property int port: 5020
    property bool online: false
    property bool polling: false
    property bool rtuConnected: false
    property bool anyAlarm: false
    property int sensorCount: 0
    property string lastUpdate: ""
    property string lastError: ""

    signal clicked()
    signal deleteRequested()
    signal acknowledgeRequested()

    readonly property bool isAlarm: card.online && card.anyAlarm
    readonly property bool isOffline: !card.online

    padding: 16
    implicitWidth: 280
    implicitHeight: 240
    elevationOnHovered: true
    outlined: card.isAlarm
    borderColor: card.isAlarm ? Qaterial.Style.errorColor : Qaterial.Style.dividersColor()
    backgroundColor: card.isOffline ? Qt.tint(Qaterial.Style.colorTheme.background8, "#30000000")
                                    : Qaterial.Style.colorTheme.background8

    SequentialAnimation on borderColor {
        running: card.isAlarm
        loops: Animation.Infinite
        ColorAnimation {
            to: Qaterial.Style.errorColor
            duration: 600
        }
        ColorAnimation {
            to: Qt.lighter(Qaterial.Style.errorColor, 1.5)
            duration: 600
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 16

        Rectangle {
            visible: card.isAlarm
            Layout.fillWidth: true
            Layout.preferredHeight: 4
            radius: 4
            color: Qaterial.Style.errorColor
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Qaterial.LabelBody1 {
                    text: card.loggerName
                    color: card.isOffline ? Qaterial.Style.colorTheme.disabledText : Qaterial.Style.colorTheme.primaryText
                    font.family: "Inter"
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Qaterial.LabelCaption {
                    text: card.host + ":" + card.port
                    color: card.isOffline ? Qaterial.Style.colorTheme.disabledText : Qaterial.Style.colorTheme.secondaryText
                    font.family: "JetBrains Mono"
                }
            }

            StatusPill {
                visible: card.isAlarm
                label: "ALARM"
                bgColor: "#FFDAD6"
                textColor: "#93000A"
                dotColor: Qaterial.Style.errorColor
                borderColor: Qaterial.Style.errorColor
            }
            StatusPill {
                visible: !card.isAlarm && card.online
                label: "ONLINE"
                bgColor: "#00390A"
                textColor: "#78DC77"
                dotColor: "#78DC77"
                borderColor: "#78DC77"
            }
            StatusPill {
                visible: card.isOffline
                label: "OFFLINE"
                bgColor: Qaterial.Style.colorTheme.surface
                textColor: Qaterial.Style.colorTheme.secondaryText
                dotColor: Qaterial.Style.colorTheme.disabledText
                borderColor: Qaterial.Style.dividersColor()
            }

            Qaterial.RawMaterialButton {
                flat: true
                text: ""
                display: AbstractButton.IconOnly
                icon.source: Qaterial.Icons.close
                icon.width: 18
                icon.height: 18
                ToolTip.visible: hovered
                ToolTip.text: "Remove logger"
                onClicked: card.deleteRequested()
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: 4 + 2
            visible: card.online

            Repeater {
                model: card.isAlarm
                    ? ["Online", "Polling", "RTU Connected"]
                    : [card.polling ? "Polling" : "Idle",
                       card.rtuConnected ? "RTU Connected" : "RTU Offline"]
                delegate: Rectangle {
                    radius: 9999
                    color: Qaterial.Style.colorTheme.surface
                    height: 22
                    width: chipLbl.implicitWidth + 16
                    Qaterial.LabelCaption {
                        id: chipLbl
                        anchors.centerIn: parent
                        text: modelData
                        color: Qaterial.Style.colorTheme.secondaryText
                        font.family: "JetBrains Mono"
                    }
                }
            }
        }

        Rectangle {
            visible: (card.isAlarm && card.lastError !== "") || card.isOffline
            Layout.fillWidth: true
            radius: 8
            color: card.isAlarm ? "#FFDAD6" : Qaterial.Style.colorTheme.surface
            border.color: card.isAlarm ? Qaterial.Style.errorColor : Qaterial.Style.dividersColor()
            border.width: 1
            implicitHeight: errRow.implicitHeight + 16
            RowLayout {
                id: errRow
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8
                Qaterial.Icon {
                    Layout.alignment: Qt.AlignTop
                    icon: Qaterial.Icons.alertCircle
                    size: 18
                    color: card.isAlarm ? "#93000A" : Qaterial.Style.colorTheme.disabledText
                }
                Qaterial.LabelBody2 {
                    text: card.isAlarm
                        ? (card.lastError !== "" ? card.lastError : "Active alarm")
                        : (card.lastError !== "" ? card.lastError : "Connection Timeout")
                    color: card.isAlarm ? "#93000A" : Qaterial.Style.colorTheme.secondaryText
                    font.family: "Inter"
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: stats.implicitHeight + 16
            color: "transparent"

            Rectangle {
                anchors.top: parent.top
                width: parent.width
                height: 1
                color: Qaterial.Style.dividersColor()
            }
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: Qaterial.Style.dividersColor()
            }

            RowLayout {
                id: stats
                anchors.fill: parent
                anchors.topMargin: 8
                anchors.bottomMargin: 8
                spacing: 16

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Qaterial.LabelCaption {
                        text: "Sensors"
                        color: Qaterial.Style.colorTheme.disabledText
                        font.family: "JetBrains Mono"
                    }
                    Qaterial.LabelBody1 {
                        text: card.sensorCount
                        color: card.isOffline ? Qaterial.Style.colorTheme.disabledText : Qaterial.Style.colorTheme.primaryText
                        font.family: "Inter"
                        font.weight: Font.DemiBold
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Qaterial.LabelCaption {
                        text: "Last Update"
                        color: Qaterial.Style.colorTheme.disabledText
                        font.family: "JetBrains Mono"
                    }
                    Qaterial.LabelCaption {
                        text: card.lastUpdate !== "" ? card.lastUpdate : "—"
                        color: card.isOffline ? Qaterial.Style.colorTheme.disabledText : Qaterial.Style.colorTheme.primaryText
                        font.family: "JetBrains Mono"
                    }
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }

        RowLayout {
            Layout.fillWidth: true
            visible: !card.isOffline
            Item {
                Layout.fillWidth: true
            }
            Qaterial.RawMaterialButton {
                outlined: true
                visible: card.isAlarm
                text: "Acknowledge"
                foregroundColor: Qaterial.Style.colorTheme.secondaryText
                onClicked: card.acknowledgeRequested()
            }
            Qaterial.Button {
                text: "Details"
                onClicked: card.clicked()
            }
        }
    }
}
