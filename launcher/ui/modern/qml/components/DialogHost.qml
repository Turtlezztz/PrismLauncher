import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// Renders Dialogs.confirm / prompt / message requests.
Item {
    id: host
    property var _cb: null

    Connections {
        target: Dialogs
        function onConfirmRequested(opts, cb) {
            host._cb = cb
            confirm.title = opts.title || qsTr("Are you sure?")
            confirm.body = opts.text || ""
            confirm.okText = opts.confirmText || qsTr("Confirm")
            confirm.cancelText = opts.cancelText || qsTr("Cancel")
            confirm.danger = !!opts.danger
            confirm.iconName = opts.icon || (opts.danger ? "triangle-alert" : "circle-alert")
            confirm.result = false
            confirm.open()
        }
        function onPromptRequested(opts, cb) {
            host._cb = cb
            prompt.title = opts.title || ""
            prompt.body = opts.text || ""
            prompt.okText = opts.confirmText || qsTr("OK")
            field.text = opts.value || ""
            field.placeholderText = opts.placeholder || ""
            prompt.result = null
            prompt.open()
            field.forceActiveFocus(); field.selectAll()
        }
        function onMessageRequested(opts) {
            message.title = opts.title || ""
            message.body = opts.text || ""
            message.iconName = opts.kind === "error" ? "circle-alert" : opts.kind === "warning" ? "triangle-alert" : "info"
            message.open()
        }
    }

    PDialog {
        id: confirm
        property string body
        property string okText
        property string cancelText
        property bool danger
        property bool result
        maxWidth: 440
        onClosed: { var cb = host._cb; host._cb = null; if (cb) cb(result) }
        Text { text: confirm.body; visible: text.length; color: Theme.textMuted; wrapMode: Text.Wrap; Layout.fillWidth: true; font.pixelSize: Theme.fontMd; textFormat: Text.StyledText; onLinkActivated: link => App.openUrl(link) }
        buttons: [
            PButton { text: confirm.cancelText; onClicked: confirm.close() },
            PButton { text: confirm.okText; variant: confirm.danger ? "danger" : "primary"; onClicked: { confirm.result = true; confirm.close() } }
        ]
    }

    PDialog {
        id: prompt
        property string body
        property string okText
        property var result: null
        maxWidth: 440
        onClosed: { var cb = host._cb; host._cb = null; if (cb) cb(result) }
        Text { text: prompt.body; visible: text.length; color: Theme.textMuted; wrapMode: Text.Wrap; Layout.fillWidth: true }
        PTextField { id: field; Layout.fillWidth: true; onAccepted: { prompt.result = text; prompt.close() } }
        buttons: [
            PButton { text: qsTr("Cancel"); onClicked: prompt.close() },
            PButton { text: prompt.okText; variant: "primary"; onClicked: { prompt.result = field.text; prompt.close() } }
        ]
    }

    PDialog {
        id: message
        property string body
        maxWidth: 480
        Text { text: message.body; color: Theme.textMuted; wrapMode: Text.Wrap; Layout.fillWidth: true; textFormat: Text.StyledText; onLinkActivated: link => App.openUrl(link) }
        buttons: [ PButton { text: qsTr("OK"); variant: "primary"; onClicked: message.close() } ]
    }
}
