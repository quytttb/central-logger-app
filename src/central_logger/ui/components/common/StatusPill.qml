import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qaterial 1.0 as Qaterial


/*
 * Pill-shaped status badge (header / card status).
 */
Rectangle {
    id: pill

    property string label: ""
    property color dotColor: Qaterial.Style.green
    property color textColor: Qaterial.Style.green
    property color bgColor: "#94F990"
    property color borderColor: "transparent"
    property bool showDot: true
    property bool pulse: false

    implicitHeight: 26
    implicitWidth: row.implicitWidth + 24
    radius: 9999
    color: bgColor
    border.color: borderColor
    border.width: borderColor === "transparent" ? 0 : 1

    SequentialAnimation on opacity {
        running: pill.pulse
        loops: Animation.Infinite
        NumberAnimation { from: 1.0; to: 0.55; duration: 700; easing.type: Easing.InOutSine }
        NumberAnimation { from: 0.55; to: 1.0; duration: 700; easing.type: Easing.InOutSine }
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Rectangle {
            visible: pill.showDot
            width: 8; height: 8; radius: 4
            color: pill.dotColor
            Layout.alignment: Qt.AlignVCenter
        }

        Qaterial.LabelCaption {
            text: pill.label
            color: pill.textColor
            font.family: "Roboto Mono"
            font.weight: Font.Medium
        }
    }
}
