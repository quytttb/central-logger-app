import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "../.."
import "../common"
import "../../logic/LoggerFormLogic.js" as FormLogic
import components

/*
 * Unified Add / Edit logger form — responsive GridLayout body.
 * mode "add"  : Central editable; Device after Connect & Load.
 * mode "edit" : Central always editable; Device after successful probe.
 */
Dialog {
    id: dialog

    property bool isDark: true
    property string mode: "add"  // "add" | "edit"
    property var detail: ({})
    property var dashboardController: null
    property bool configLoaded: false
    property string probeStatus: ""
    property string probeStatusKind: "idle"  // idle | loading | success | error

    readonly property color probeStatusColor: Colors.probeStatusText(dialog.isDark, probeStatusKind)
    readonly property bool deviceEditable: configLoaded
    readonly property bool qrScanEnabled: !dashboardController || dashboardController.qrScanAvailable()

    signal addRequested(var formData)
    signal saved(var patch)

    title: mode === "add" ? "Add Edge Logger" : "Edit Logger"
    modal: true
    focus: true
    padding: 0
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(940, parent ? parent.width - 32 : 940)
    height: Math.min(
        headerItem.height + footerItem.implicitHeight + bodyFlick.contentHeight + 2,
        parent ? Math.floor(parent.height * 0.9) : 720
    )

    Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.6) }

    enter: Transition {
        ParallelAnimation {
            NumberAnimation {
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: UiMotion.durationDialog
                easing.type: UiMotion.easingOut
            }
            NumberAnimation {
                target: dialogCard
                property: "scale"
                from: 0.96
                to: 1.0
                duration: UiMotion.durationDialog
                easing.type: UiMotion.easingOut
            }
        }
    }

    exit: Transition {
        ParallelAnimation {
            NumberAnimation {
                property: "opacity"
                from: 1.0
                to: 0.0
                duration: UiMotion.durationFast
                easing.type: UiMotion.easingIn
            }
            NumberAnimation {
                target: dialogCard
                property: "scale"
                from: 1.0
                to: 0.96
                duration: UiMotion.durationFast
                easing.type: UiMotion.easingIn
            }
        }
    }

    background: Rectangle {
        id: dialogCard
        radius: 12
        color: Colors.surface(dialog.isDark)
        border.width: 1
        border.color: Colors.border(dialog.isDark)
        transformOrigin: Item.Center
    }

    header: Item {
        id: headerItem
        implicitHeight: 56
        implicitWidth: dialog.width

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Colors.divider(dialog.isDark)
        }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 24
            anchors.rightMargin: 24
            UiLabel {
                textType: UiLabel.Body2
                text: dialog.title
                Layout.fillWidth: true
                color: Colors.textPrimary(dialog.isDark)
                font.family: "Roboto"
                font.pixelSize: 20
                font.weight: Font.DemiBold
            }
            Rectangle {
                width: 32
                height: 32
                radius: 6
                color: "transparent"
                HoverHighlight {
                    anchors.fill: parent
                    cornerRadius: 6
                    hovered: closeMouse.containsMouse
                    isDark: dialog.isDark
                }
                UiIcon {
                    anchors.centerIn: parent
                    name: "close"
                    size: 20
                    iconColor: Colors.textSecondary(dialog.isDark)
                }
                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: dialog.close()
                }
            }
        }
    }

    contentItem: Flickable {
        id: bodyFlick
        implicitWidth: dialog.width
        implicitHeight: Math.min(
            formBody.implicitHeight + 40,
            dialog.parent ? Math.floor(dialog.parent.height * 0.9) - headerItem.height - footerItem.implicitHeight - 8 : 600
        )
        contentWidth: width
        contentHeight: formBody.implicitHeight + 40
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        LoggerFormBody {
            id: formBody
            width: bodyFlick.width - 48
            x: 24
            y: 20
            form: dialog
        }
    }

    footer: Item {
        id: footerItem
        implicitWidth: dialog.width
        implicitHeight: footerPad.implicitHeight + 24

        Rectangle {
            anchors.top: parent.top
            width: parent.width
            height: 1
            color: Colors.divider(dialog.isDark)
        }
        LoggerFormFooter {
            id: footerPad
            anchors.fill: parent
            anchors.leftMargin: 24
            anchors.rightMargin: 24
            anchors.topMargin: 12
            anchors.bottomMargin: 12
            form: dialog
            body: formBody
        }
    }

    function humanizeProbeError(raw) {
        return FormLogic.humanizeProbeError(raw)
    }

    function connectionSnapshotFromFields() {
        return FormLogic.connectionSnapshotFromFields(formBody.fieldSnapshot())
    }

    function setProbeLoading() {
        probeStatusKind = "loading"
        probeStatus = "Connecting…"
    }

    function setProbeSuccess() {
        probeStatusKind = "success"
        probeStatus = "Configuration loaded successfully."
    }

    function setProbeError(raw) {
        probeStatusKind = "error"
        probeStatus = humanizeProbeError(raw)
    }

    function loadFromDetail(d) {
        var src = d || {}
        if (dialog.mode === "add")
            detail = src
        formBody.loadFromDetail(src)
        var cf = src.configForm || {}
        var raw = src.rawConfig || {}
        configLoaded = !!(cf.station_code || raw.station_code || cf.poll_interval)
    }

    function loadFromProbeResult(jsonStr) {
        var snap = connectionSnapshotFromFields()
        try {
            var result = FormLogic.parseProbeSuccess(jsonStr, snap)
            if (!result.ok) {
                configLoaded = false
                setProbeError(result.error)
                return
            }
            detail = Object.assign({}, result.detail, {
                loggerId: dialog.detail.loggerId !== undefined ? dialog.detail.loggerId : result.detail.loggerId
            })
            loadFromDetail(detail)
            configLoaded = true
            setProbeSuccess()
        } catch (e) {
            configLoaded = false
            setProbeError("Invalid response")
            console.warn("loadFromProbeResult:", e)
        }
    }

    function connectAndLoadConfig() {
        if (!dashboardController) {
            setProbeError("Controller unavailable")
            return
        }
        setProbeLoading()
        configLoaded = false
        var snap = formBody.fieldSnapshot()
        var h = (snap.host || "").trim()
        var ap = parseInt(snap.apiPort)
        dashboardController.probeEdgeConfig(
            h,
            isNaN(ap) ? 8080 : ap,
            snap.token || "",
            (snap.apiBaseUrl || "").trim()
        )
    }

    function importQrFromFile() {
        if (!dialog.dashboardController) {
            if (typeof window !== "undefined" && window && window.notify)
                window.notify("Dashboard controller not available", "error")
            return
        }
        var raw = dialog.dashboardController.importProvisionFromQrImageWithDialog()
        try {
            var res = JSON.parse(raw || "{}")
            if (res.cancelled)
                return
            if (res.ok && res.fields)
                applyProvisionFields(res.fields)
            else if (typeof window !== "undefined" && window && window.notify)
                window.notify(res.error || "Invalid provisioning QR", "error")
            else
                console.warn("QR import:", res.error)
        } catch (e) {
            if (typeof window !== "undefined" && window && window.notify)
                window.notify("Invalid QR response", "error")
        }
    }

    function applyProvisionFields(fields) {
        formBody.applyProvisionFields(fields)
    }

    function buildEditPatch() {
        return FormLogic.buildEditPatch(dialog.mode, detail, configLoaded, formBody.fieldSnapshot())
    }

    onClosed: {
        probeStatus = ""
        probeStatusKind = "idle"
    }

    onOpened: {
        probeStatus = ""
        probeStatusKind = "idle"
        if (mode === "edit") {
            loadFromDetail(detail)
        } else {
            configLoaded = false
            loadFromDetail({
                loggerName: "",
                note: "",
                host: "",
                port: 5020,
                unitId: 1,
                timeoutS: 2.0,
                apiPort: 8080,
                apiBaseUrl: "",
                cloudForm: { apiToken: "", apiPort: 8080 }
            })
        }
        Qt.callLater(formBody.clearAllFieldFocus)
    }

    Connections {
        target: dialog.dashboardController
        enabled: dialog.dashboardController !== null
        ignoreUnknownSignals: true
        function onEdgeConfigProbed(ok, payloadJson) {
            if (!dialog.opened) return
            if (!ok) {
                dialog.configLoaded = false
                try {
                    var errP = JSON.parse(payloadJson)
                    var errMsg = (errP.errors && errP.errors.length > 0)
                        ? errP.errors[0].message
                        : (errP.message || "Connect failed")
                    dialog.setProbeError(errMsg)
                } catch (e) {
                    dialog.setProbeError("Connect failed")
                }
                return
            }
            dialog.loadFromProbeResult(payloadJson)
        }
    }
}
