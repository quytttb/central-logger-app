import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Qaterial 1.0 as Qaterial

/*
 * Single-row search: rounded container, leading magnify icon, borderless text field.
 */
Rectangle {
    id: root

    property string placeholderText: qsTr("Search…")
    property alias text: field.text
    property int fontPixelSize: 14

    signal queryChanged(string query)

    implicitHeight: 44
    implicitWidth: 280

    radius: height / 2
    color: Qaterial.Style.colorTheme.surface
    border.width: field.activeFocus ? 2 : 1
    border.color: field.activeFocus ? Qaterial.Style.accentColor
                  : Qt.alpha(Qaterial.Style.colorTheme.secondaryText, 0.22)

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 10

        Item {
            Layout.preferredWidth: 24
            Layout.preferredHeight: 24
            Layout.alignment: Qt.AlignVCenter

            Qaterial.Icon {
                anchors.centerIn: parent
                icon: Qaterial.Icons.magnify
                size: 20
                color: field.activeFocus ? Qaterial.Style.accentColor
                       : Qaterial.Style.colorTheme.secondaryText
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.IBeamCursor
                onClicked: field.forceActiveFocus()
            }
        }

        TextField {
            id: field
            Layout.fillWidth: true
            Layout.fillHeight: true
            placeholderText: root.placeholderText
            background: null
            padding: 0
            topInset: 0
            bottomInset: 0
            leftInset: 0
            rightInset: 0
            verticalAlignment: TextInput.AlignVCenter
            font.family: "JetBrains Mono"
            font.pixelSize: root.fontPixelSize
            color: Qaterial.Style.colorTheme.primaryText
            placeholderTextColor: Qaterial.Style.hintTextColor()
            selectionColor: Qaterial.Style.accentColor
            selectedTextColor: Qaterial.Style.shouldReverseForegroundOnAccent
                ? Qaterial.Style.primaryTextColorReversed()
                : Qaterial.Style.primaryTextColor()
            selectByMouse: true
            renderType: Text.NativeRendering

            onTextChanged: root.queryChanged(text.trim().toLowerCase())
        }
    }
}
