import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// Generic multi-button question asked by core tasks (ModernInteraction::Question). Emits answered(index) once.
PDialog {
    id: dlg
    property var req: ({})
    property int result: -1
    signal answered(int index)

    readonly property string kind: req.kind || "question"
    title: req.title || ""
    iconName: kind === "error" ? "circle-alert" : kind === "warning" ? "triangle-alert" : kind === "info" ? "info" : "circle-alert"
    maxWidth: 520
    closePolicy: Popup.CloseOnEscape
    onOpened: result = req.cancelIndex !== undefined ? req.cancelIndex : -1
    onClosed: answered(result)

    Text {
        Layout.fillWidth: true
        text: dlg.req.text || ""
        visible: text.length > 0
        color: Theme.textMuted; wrapMode: Text.Wrap; font.pixelSize: Theme.fontMd
        textFormat: Text.StyledText
        onLinkActivated: link => App.openUrl(link)
    }
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(itemList.contentHeight + 16, 180)
        visible: (dlg.req.items || []).length > 0
        radius: Theme.radius; color: Theme.surfaceAlt; border.color: Theme.border
        ListView {
            id: itemList
            anchors.fill: parent; anchors.margins: 8
            clip: true
            model: dlg.req.items || []
            delegate: Text { required property string modelData; width: itemList.width; text: modelData; color: Theme.text; font.pixelSize: Theme.fontSm; font.family: Theme.monoFamily; elide: Text.ElideMiddle }
            ScrollBar.vertical: PScrollBar {}
        }
    }
    PCheckBox {
        id: confirm
        Layout.fillWidth: true
        visible: (dlg.req.confirmCheck || "").length > 0
        text: dlg.req.confirmCheck || ""
    }

    buttons: [
        Repeater {
            model: (dlg.req.buttons || []).slice().reverse()
            delegate: PButton {
                required property string modelData
                required property int index
                readonly property int realIndex: (dlg.req.buttons || []).length - 1 - index
                text: modelData
                variant: realIndex === 0 ? (dlg.kind === "warning" && (dlg.req.buttons || []).length > 1 ? "danger" : "primary") : "secondary"
                enabled: realIndex !== 0 || !confirm.visible || confirm.checked
                onClicked: { dlg.result = realIndex; dlg.close() }
            }
        }
    ]
}
