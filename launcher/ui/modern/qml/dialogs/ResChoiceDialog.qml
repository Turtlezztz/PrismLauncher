import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// Multi-choice dialog with an optional detail list and checkbox.
//   choice.ask({ title, text, details: ["a", "b"], icon, checkText, choices: [{ text, value, variant }] }, function(value, checked) {...})
// value is null when dismissed.
PDialog {
    id: dlg
    property string body: ""
    property var details: []
    property var choices: []
    property string checkText: ""
    property var _cb: null
    property var _result: null
    maxWidth: 520

    function ask(opts, cb) {
        title = opts.title || ""
        body = opts.text || ""
        details = opts.details || []
        choices = opts.choices || [{ text: qsTr("OK"), value: true, variant: "primary" }]
        checkText = opts.checkText || ""
        check.checked = !!opts.checked
        iconName = opts.icon || "circle-alert"
        _cb = cb
        _result = null
        open()
    }
    onClosed: { var cb = _cb; _cb = null; if (cb) cb(_result, check.checked) }

    Text {
        Layout.fillWidth: true
        visible: text.length > 0
        text: dlg.body
        color: Theme.textMuted
        wrapMode: Text.Wrap
        font.pixelSize: Theme.fontMd
        textFormat: Text.StyledText
        onLinkActivated: link => App.openUrl(link)
    }
    Rectangle {
        Layout.fillWidth: true
        visible: dlg.details.length > 0
        Layout.preferredHeight: Math.min(detailList.contentHeight + 16, 220)
        radius: Theme.radius
        color: Theme.surfaceAlt
        border.color: Theme.border
        ListView {
            id: detailList
            anchors.fill: parent; anchors.margins: 8
            clip: true
            model: dlg.details
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: PScrollBar {}
            delegate: Text {
                required property var modelData
                width: ListView.view.width
                text: "• " + modelData
                color: Theme.text
                font.pixelSize: Theme.fontSm + 1
                wrapMode: Text.Wrap
                textFormat: Text.StyledText
                topPadding: 2; bottomPadding: 2
                onLinkActivated: link => App.openUrl(link)
            }
        }
    }
    PCheckBox { id: check; visible: dlg.checkText.length > 0; text: dlg.checkText; Layout.fillWidth: true }

    buttons: [
        Repeater {
            model: dlg.choices
            delegate: PButton {
                required property var modelData
                text: modelData.text
                variant: modelData.variant || "secondary"
                onClicked: { dlg._result = modelData.value; dlg.close() }
            }
        }
    ]
}
