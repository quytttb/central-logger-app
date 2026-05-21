import QtQuick
import QtQuick.Layouts

import "../.."
import "../common"
import components

RowLayout {
    id: root

    required property var form
    required property var body

    spacing: 12
    implicitHeight: Math.max(probeLabel.implicitHeight, 36)

    UiLabel {
        id: probeLabel
        textType: UiLabel.Body2
        Layout.fillWidth: true
        Layout.minimumWidth: 120
        visible: form.probeStatus.length > 0
        text: form.probeStatus
        color: form.probeStatusColor
        font.family: "Inter"
        font.pixelSize: 14
        wrapMode: Text.WordWrap
        maximumLineCount: 2
        elide: Text.ElideRight
    }

    Item { Layout.fillWidth: true }

    DialogButton {
        text: "Cancel"
        isDark: form.isDark
        variant: "secondary"
        onClicked: form.close()
    }
    DialogButton {
        text: form.mode === "add" ? "Add Logger" : "Save Changes"
        iconName: form.mode === "add" ? "plus" : "save"
        isDark: form.isDark
        variant: "primary"
        onClicked: root.submit()
    }

    function submit() {
        if (form.mode === "add") {
            var snap = body.fieldSnapshot()
            var name = (snap.name || "").trim()
            var host = (snap.host || "").trim()
            if (!name || !host) {
                if (typeof window !== "undefined" && window && window.notify)
                    window.notify("Name and Host are required", "error")
                return
            }
            form.close()
            form.addRequested({
                name: name,
                host: host,
                port: parseInt(snap.port) || 5020,
                unitId: parseInt(snap.unit) || 1,
                pollIntervalS: parseInt(snap.pollDevice) || 2,
                timeoutS: parseFloat(snap.timeout) || 2.0,
                note: (snap.note || "").trim(),
                apiPort: parseInt(snap.apiPort) || 8080,
                apiToken: snap.token || "",
                apiBaseUrl: (snap.apiBaseUrl || "").trim()
            })
        } else {
            var patch = form.buildEditPatch()
            if (!patch.connection.name || !patch.connection.host) {
                if (typeof window !== "undefined" && window && window.notify)
                    window.notify("Name and Host are required", "error")
                return
            }
            form.close()
            form.saved(patch)
        }
    }
}
