import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Qaterial 1.0 as Qaterial

import CentralLogger.Core 1.0

/*
 * Top application bar: hamburger, logo, title (drag region for frameless move),
 * status pills, and window controls (minimize / maximize / close).
 */
Qaterial.Pane {
    id: bar

    property string title: "Dashboard"
    signal menuRequested()

    padding: 0
    radius: 0
    elevation: 0
    color: Qaterial.Style.colorTheme.background8

    Rectangle {
        anchors.bottom: parent.bottom
        height: 1
        width: parent.width
        color: Qaterial.Style.dividersColor()
    }

    implicitHeight: 64

    readonly property Window hostWindow: Window.window

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 8

        Qaterial.RawMaterialButton {
            flat: true
            text: ""
            display: AbstractButton.IconOnly
            icon.source: Qaterial.Icons.menu
            icon.width: 22
            icon.height: 22
            Layout.rightMargin: 2
            ToolTip.visible: hovered
            ToolTip.text: "Menu"
            onClicked: bar.menuRequested()
        }

        Item {
            Layout.preferredWidth: 158
            Layout.preferredHeight: 50
            Layout.maximumWidth: 158
            Layout.maximumHeight: 50
            Layout.fillWidth: false
            Layout.alignment: Qt.AlignVCenter
            Layout.rightMargin: 2

            Image {
                anchors.fill: parent
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
                sourceSize: Qt.size(316, 100)
                source: Qt.resolvedUrl("../../resources/images/4M Technologies Blue.svg")
            }
        }

        Rectangle {
            width: 1
            height: 28
            Layout.leftMargin: 2
            color: Qaterial.Style.dividersColor()
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Qaterial.LabelHeadline6 {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: bar.title
                elide: Text.ElideRight
                width: parent.width
            }
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                hoverEnabled: true
                cursorShape: Qt.ArrowCursor
                onPressed: function (mouse) {
                    const w = bar.hostWindow
                    if (w && w.startSystemMove)
                        w.startSystemMove()
                    mouse.accepted = true
                }
            }
        }

        StatusPill {
            label: "Online: " + AppState.onlineLoggers + "/" + AppState.totalLoggers
            dotColor: "#78DC77"
            textColor: "#78DC77"
            bgColor: "#00390A"
            borderColor: "#78DC77"
        }
        StatusPill {
            label: "Alarms: " + AppState.alarmCount
            dotColor: AppState.alarmCount > 0 ? Qaterial.Style.errorColor : Qaterial.Style.colorTheme.disabledText
            textColor: AppState.alarmCount > 0 ? "#93000A" : Qaterial.Style.colorTheme.secondaryText
            bgColor: AppState.alarmCount > 0 ? "#FFDAD6" : Qaterial.Style.colorTheme.surface
            pulse: AppState.alarmCount > 0
            borderColor: AppState.alarmCount > 0 ? Qaterial.Style.errorColor : Qaterial.Style.dividersColor()
        }

        Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: 28
            color: Qaterial.Style.dividersColor()
            Layout.leftMargin: 8
        }

        Row {
            id: windowChrome
            Layout.alignment: Qt.AlignVCenter
            spacing: 4

            // MDI SVG via Qaterial.Icon: consistent box and centering (no font glyph drift).
            readonly property int chromeBtnW: 42
            readonly property int chromeBtnH: 32
            readonly property int chromeIconSize: 18

            Repeater {
                model: [
                    {
                        action: "min",
                        tip: "Minimize",
                        base: "#e8eaed",
                        hover: "#d1d5db",
                        press: "#c4c9d0",
                        fg: "#374151"
                    },
                    {
                        action: "max",
                        tip: "",
                        base: "#e8eaed",
                        hover: "#d1d5db",
                        press: "#c4c9d0",
                        fg: "#374151"
                    },
                    {
                        action: "close",
                        tip: "Close",
                        base: "#e53935",
                        hover: "#c62828",
                        press: "#b71c1c",
                        fg: "#ffffff"
                    }
                ]

                delegate: Item {
                    id: chromeCell
                    width: windowChrome.chromeBtnW
                    height: windowChrome.chromeBtnH

                    readonly property bool isMaxCell: modelData.action === "max"
                    readonly property bool winMax: bar.hostWindow && bar.hostWindow.visibility === Window.Maximized
                    readonly property url chromeIcon: {
                        if (modelData.action === "min")
                            return Qaterial.Icons.windowMinimize
                        if (modelData.action === "close")
                            return Qaterial.Icons.windowClose
                        if (modelData.action === "max")
                            return winMax ? Qaterial.Icons.windowRestore : Qaterial.Icons.windowMaximize
                        return ""
                    }

                    function _tip() {
                        if (isMaxCell)
                            return winMax ? "Restore" : "Maximize"
                        return modelData.tip
                    }

                    Rectangle {
                        id: chromeBg
                        anchors.fill: parent
                        radius: 6
                        color: chromeMouse.pressed ? modelData.press
                             : chromeMouse.containsMouse ? modelData.hover
                             : modelData.base
                    }

                    Qaterial.Icon {
                        anchors.centerIn: parent
                        icon: chromeCell.chromeIcon
                        size: windowChrome.chromeIconSize
                        color: modelData.fg
                    }

                    MouseArea {
                        id: chromeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const w = bar.hostWindow
                            if (!w)
                                return
                            if (modelData.action === "min") {
                                w.showMinimized()
                            } else if (modelData.action === "max") {
                                if (w.visibility === Window.Maximized)
                                    w.visibility = Window.Windowed
                                else
                                    w.visibility = Window.Maximized
                            } else {
                                w.close()
                            }
                        }
                    }

                    ToolTip.visible: chromeMouse.containsMouse
                    ToolTip.text: chromeCell._tip()
                }
            }
        }
    }
}
