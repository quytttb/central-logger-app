import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qaterial 1.0 as Qaterial


Rectangle {
    id: root
    property string label: ""
    property var value: ""
    property color statusColor: Qaterial.Style.green

    implicitHeight: 32
    implicitWidth: row.implicitWidth + 24
    radius: 8
    color: Qaterial.Style.colorTheme.surface
    border.color: Qaterial.Style.dividersColor()
    border.width: 1

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 8

        Rectangle {
            width: 10
            height: 10
            radius: 5
            color: root.statusColor
            Layout.alignment: Qt.AlignVCenter
        }
        Qaterial.LabelCaption {
            text: root.label
            color: Qaterial.Style.colorTheme.secondaryText
        }
        Qaterial.LabelCaption {
            text: root.value
            color: Qaterial.Style.colorTheme.primaryText
            font.weight: Font.Bold
        }
    }
}
