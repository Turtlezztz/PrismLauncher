import QtQuick
import QtQuick.Layouts
import PrismModern

// Choose a Minecraft profile name for an account without one (classic ProfileSetupDialog).
PDialog {
    id: dlg
    property string accountId: ""
    title: qsTr("Choose your Minecraft name")
    subtitle: qsTr("This account doesn't have a Minecraft profile yet. Pick the name other players will see.")
    iconName: "user"
    maxWidth: 480
    closePolicy: setup.working ? Popup.NoAutoClose : Popup.CloseOnEscape

    ProfileSetup {
        id: setup
        accountId: dlg.accountId
        onFinished: ok => { if (ok) { Toasts.success(qsTr("Profile created")); dlg.close() } }
    }
    onOpened: name.forceActiveFocus()

    PTextField {
        id: name
        Layout.fillWidth: true
        placeholderText: qsTr("Name")
        maximumLength: 16
        rightPadding: 36
        error: setup.nameStatus === "exists" || setup.nameStatus === "error"
        onTextEdited: setup.nameEdited(text)
        onAccepted: setup.submit()
        Item {
            anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
            width: 16; height: 16
            Spinner { anchors.fill: parent; size: 16; visible: setup.nameStatus === "pending" }
            Icon { anchors.centerIn: parent; size: 16; visible: setup.nameStatus === "available"; name: "circle-check"; color: Theme.success }
            Icon { anchors.centerIn: parent; size: 16; visible: setup.nameStatus === "exists" || setup.nameStatus === "error"; name: "circle-alert"; color: Theme.danger }
        }
    }
    Text {
        Layout.fillWidth: true; wrapMode: Text.Wrap
        visible: text.length > 0
        text: setup.message
        color: setup.nameStatus === "available" ? Theme.success : setup.nameStatus === "notset" ? Theme.textMuted : Theme.danger
        font.pixelSize: Theme.fontSm
    }

    buttons: [
        PButton { text: qsTr("Cancel"); enabled: !setup.working; onClicked: dlg.close() },
        PButton { text: qsTr("Create profile"); variant: "primary"; busy: setup.working; enabled: setup.nameStatus === "available" && !setup.working; onClicked: setup.submit() }
    ]
}
