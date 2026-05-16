import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qaterial 1.0 as Qaterial


Qaterial.Dialog {
    id: dlg
    title: qsTr("Add Logger")
    modal: true
    standardButtons: Dialog.Ok | Dialog.Cancel
    anchors.centerIn: parent
    width: 480

    signal loggerSubmitted(string name, string host, int port, int unitId, int pollMs,
                           int apiPort, string apiToken)

    function resetFields() {
        nameField.text = ""
        hostField.text = ""
        portField.text = "5020"
        unitField.text = "1"
        pollField.text = "2000"
        apiPortField.text = "8080"
        apiTokenField.text = ""
    }

    onAccepted: dlg.loggerSubmitted(
        nameField.text.trim(),
        hostField.text.trim(),
        parseInt(portField.text) || 5020,
        parseInt(unitField.text) || 1,
        parseInt(pollField.text) || 2000,
        parseInt(apiPortField.text) || 8080,
        apiTokenField.text.trim()
    )

    contentItem: GridLayout {
        columns: 2
        columnSpacing: 16
        rowSpacing: 8

        Qaterial.LabelCaption {
            text: qsTr("Name")
            color: Qaterial.Style.colorTheme.secondaryText
            font.family: "JetBrains Mono"
        }
        Qaterial.TextField {
            id: nameField
            Layout.fillWidth: true
            placeholderText: "Logger A"
            font.family: "Inter"
        }

        Qaterial.LabelCaption {
            text: qsTr("Host")
            color: Qaterial.Style.colorTheme.secondaryText
            font.family: "JetBrains Mono"
        }
        Qaterial.TextField {
            id: hostField
            Layout.fillWidth: true
            placeholderText: "192.168.1.10"
            font.family: "JetBrains Mono"
        }

        Qaterial.LabelCaption {
            text: qsTr("Modbus port")
            color: Qaterial.Style.colorTheme.secondaryText
            font.family: "JetBrains Mono"
        }
        Qaterial.TextField {
            id: portField
            text: "5020"
            inputMethodHints: Qt.ImhDigitsOnly
            Layout.fillWidth: true
            font.family: "JetBrains Mono"
        }

        Qaterial.LabelCaption {
            text: qsTr("Unit ID")
            color: Qaterial.Style.colorTheme.secondaryText
            font.family: "JetBrains Mono"
        }
        Qaterial.TextField {
            id: unitField
            text: "1"
            inputMethodHints: Qt.ImhDigitsOnly
            Layout.fillWidth: true
            font.family: "JetBrains Mono"
        }

        Qaterial.LabelCaption {
            text: qsTr("Poll (ms)")
            color: Qaterial.Style.colorTheme.secondaryText
            font.family: "JetBrains Mono"
        }
        Qaterial.TextField {
            id: pollField
            text: "2000"
            inputMethodHints: Qt.ImhDigitsOnly
            Layout.fillWidth: true
            font.family: "JetBrains Mono"
        }

        Qaterial.LabelCaption {
            text: qsTr("REST port")
            color: Qaterial.Style.colorTheme.secondaryText
            font.family: "JetBrains Mono"
        }
        Qaterial.TextField {
            id: apiPortField
            text: "8080"
            inputMethodHints: Qt.ImhDigitsOnly
            Layout.fillWidth: true
            font.family: "JetBrains Mono"
        }

        Qaterial.LabelCaption {
            text: qsTr("API token")
            color: Qaterial.Style.colorTheme.secondaryText
            font.family: "JetBrains Mono"
        }
        Qaterial.TextField {
            id: apiTokenField
            Layout.fillWidth: true
            placeholderText: qsTr("Bearer token from Pi device")
            echoMode: TextInput.Password
            font.family: "JetBrains Mono"
        }
    }
}
