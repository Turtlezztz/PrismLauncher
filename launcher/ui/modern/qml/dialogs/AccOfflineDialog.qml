import QtQuick
import QtQuick.Layouts
import PrismModern

// Add an offline account (classic ChooseOfflineNameDialog).
PDialog {
    id: dlg
    title: qsTr("Add offline account")
    subtitle: qsTr("Offline accounts can only play singleplayer and on offline-mode servers.")
    iconName: "user"
    maxWidth: 460

    readonly property bool valid: allowInvalid.checked ? name.text.length > 0 : Accounts.isValidOfflineName(name.text)

    onOpened: { name.text = ""; allowInvalid.checked = false; name.forceActiveFocus() }

    function submit() {
        if (!valid) return
        var err = Accounts.addOffline(name.text)
        if (err.length) { Dialogs.message({ title: qsTr("Error"), text: err, kind: "error" }); return }
        Toasts.success(qsTr("Added %1").arg(name.text))
        close()
    }

    Text { text: qsTr("Username"); color: Theme.text; font.pixelSize: Theme.fontMd; font.weight: Font.Medium }
    PTextField {
        id: name
        Layout.fillWidth: true
        iconName: "user"
        placeholderText: qsTr("Steve")
        maximumLength: allowInvalid.checked ? 32767 : 16
        error: text.length > 0 && !dlg.valid
        onAccepted: dlg.submit()
    }
    Text {
        Layout.fillWidth: true; wrapMode: Text.Wrap
        text: allowInvalid.checked ? qsTr("Invalid names may cause issues in game.") : qsTr("3–16 characters: letters, numbers and underscores.")
        color: name.text.length > 0 && !dlg.valid ? Theme.danger : Theme.textMuted
        font.pixelSize: Theme.fontSm
    }
    PCheckBox { id: allowInvalid; text: qsTr("Allow invalid usernames") }

    buttons: [
        PButton { text: qsTr("Cancel"); onClicked: dlg.close() },
        PButton { text: qsTr("Add account"); variant: "primary"; enabled: dlg.valid; onClicked: dlg.submit() }
    ]
}
