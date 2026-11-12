import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// Modal progress for a ResTaskHandle (downloads, metadata, world copies...).
//   ResTaskDialog { id: prog }   prog.track(handle, { successText: "Installed", closeOnSuccess: true }, function(ok) {...})
PDialog {
    id: dlg
    property var handle: null
    property string successText: ""
    property bool closeOnSuccess: true
    property var _cb: null
    readonly property bool finished: handle ? handle.finished : false
    readonly property bool failed: finished && !handle.succeeded

    title: handle ? handle.title : ""
    iconName: failed ? "circle-alert" : finished ? "circle-check" : "download"
    maxWidth: 480
    showClose: finished
    closePolicy: finished ? (Popup.CloseOnEscape | Popup.CloseOnPressOutside) : Popup.NoAutoClose

    function track(h, opts, cb) {
        if (!h) { if (cb) cb(true); return }
        opts = opts || {}
        handle = h
        successText = opts.successText || ""
        closeOnSuccess = opts.closeOnSuccess !== false
        _cb = cb || null
        open()
    }

    Connections {
        target: dlg.handle
        function onDone(ok, error, warnings) {
            if (warnings.length) Toasts.show(warnings.join("\n"), "warning")
            if (ok) {
                if (dlg.successText.length) Toasts.success(dlg.successText)
                if (dlg.closeOnSuccess) dlg.close()
            } else if (!error.length) {
                dlg.close()   // aborted
            }
            var cb = dlg._cb; dlg._cb = null
            if (cb) cb(ok)
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Theme.spacingSm
        Text {
            Layout.fillWidth: true
            text: dlg.failed ? (dlg.handle.error || qsTr("Failed")) : dlg.handle && dlg.handle.status.length ? dlg.handle.status : qsTr("Working…")
            color: dlg.failed ? Theme.danger : Theme.text
            wrapMode: Text.Wrap
            maximumLineCount: dlg.failed ? 12 : 2
            elide: Text.ElideRight
            font.pixelSize: Theme.fontMd
        }
        PProgressBar {
            Layout.fillWidth: true
            visible: !dlg.finished
            indeterminate: !dlg.handle || dlg.handle.progress < 0
            value: dlg.handle && dlg.handle.progress >= 0 ? dlg.handle.progress : 0
        }
        Text {
            Layout.fillWidth: true
            visible: !dlg.finished && text.length > 0
            text: dlg.handle ? dlg.handle.details : ""
            color: Theme.textSubtle
            font.pixelSize: Theme.fontSm
            elide: Text.ElideMiddle
        }
    }

    buttons: [
        PButton {
            visible: !dlg.finished
            enabled: dlg.handle ? dlg.handle.canAbort : false
            text: qsTr("Cancel")
            onClicked: dlg.handle.abort()
        },
        PButton {
            visible: dlg.finished
            text: qsTr("Close")
            variant: "primary"
            onClicked: dlg.close()
        }
    ]
}
