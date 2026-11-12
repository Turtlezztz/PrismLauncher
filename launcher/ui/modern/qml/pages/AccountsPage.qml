import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// Classic AccountListPage: accounts with avatar, type, status; default account; refresh, remove, reorder,
// add Microsoft / offline, profile setup and skins.
PageScaffold {
    id: page
    title: qsTr("Accounts")
    subtitle: Accounts.count === 0 ? qsTr("Sign in to play Minecraft") : Accounts.count === 1 ? qsTr("1 account") : qsTr("%1 accounts").arg(Accounts.count)
    property string instanceId: ""
    property string initialTab: ""
    property string initialPage: ""
    property var importUrls: []
    function openTab(key) {}

    Component.onCompleted: {
        Router.section = "Accounts"
        // debug (screenshots): PRISM_MODERN_SETTINGS_PAGE=skins | offline | profile opens that dialog
        var d = SettingsBackend.debugPage
        if (d === "skins" && Accounts.defaultId.length) openDialog("AccSkinsDialog", { accountId: Accounts.defaultId })
        else if (d === "offline") openDialog("AccOfflineDialog")
        else if (d === "profile" && Accounts.defaultId.length) openDialog("AccProfileSetupDialog", { accountId: Accounts.defaultId })
    }

    function openDialog(name, props) {
        var comp = Qt.createComponent(Qt.resolvedUrl("../dialogs/" + name + ".qml"))
        if (comp.status !== Component.Ready) { console.warn(comp.errorString()); Toasts.error(qsTr("Could not open dialog")); return null }
        var dlg = comp.createObject(page, props || {})
        dlg.closed.connect(function() { dlg.destroy(500) })
        dlg.open()
        return dlg
    }
    function addOffline() {
        if (!Accounts.anyValid) {
            Dialogs.message({ title: qsTr("Microsoft account required"), kind: "warning",
                              text: qsTr("You must add a Microsoft account that owns Minecraft before you can add an offline account.<br><br>If you have lost your account you can contact Microsoft for support.") })
            return
        }
        openDialog("AccOfflineDialog")
    }

    headerActions: [
        PButton { text: qsTr("Add offline"); iconName: "user"; onClicked: page.addOffline() },
        PButton { visible: Accounts.msaSupported; text: qsTr("Add Microsoft"); iconName: "plus"; variant: "primary"; onClicked: page.openDialog("AccMsaLoginDialog") }
    ]

    ListView {
        id: list
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.bottomMargin: Theme.spacingLg
        clip: true
        spacing: 10
        model: Accounts
        ScrollBar.vertical: PScrollBar {}
        visible: count > 0

        add: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.dur } }
        displaced: Transition { NumberAnimation { properties: "y"; duration: Theme.dur; easing.type: Theme.easing } }

        footer: Item {
            width: list.width; height: 64
            visible: Accounts.count > 0
            Text {
                anchors.left: parent.left; anchors.leftMargin: 4; anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 8; wrapMode: Text.Wrap
                text: Accounts.defaultId.length ? qsTr("The default account is used to launch instances unless an instance overrides it.")
                                                : qsTr("No default account: you will be asked which account to use when launching.")
                color: Theme.textSubtle; font.pixelSize: Theme.fontSm
            }
        }

        delegate: Rectangle {
            id: card
            required property int index
            required property string accountId
            required property string name
            required property string typeKey
            required property string typeText
            required property string accountState
            required property string statusText
            required property bool isDefault
            required property bool busy
            required property string faceUrl
            required property bool hasProfile
            required property string lastError
            required property bool canManageSkins

            width: list.width - 6
            implicitHeight: 76 + (errText.visible ? errText.implicitHeight + 6 : 0)
            radius: Theme.radiusLg
            color: hov.hovered ? Theme.surfaceHover : Theme.surface
            border.color: isDefault ? Theme.accent : Theme.border
            border.width: isDefault ? 2 : 1
            Behavior on color { ColorAnimation { duration: Theme.durFast } }
            HoverHandler { id: hov }
            TapHandler { acceptedButtons: Qt.RightButton; onTapped: (ev) => { menu.accountId = card.accountId; menu.row = card.index; menu.popup() } }

            readonly property color stateColor: accountState === "online" ? Theme.success : accountState === "working" ? Theme.info
                                               : (accountState === "errored" || accountState === "expired" || accountState === "gone" || accountState === "disabled") ? Theme.danger
                                               : Theme.textSubtle

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16; anchors.rightMargin: 12
                spacing: 14

                // avatar
                Rectangle {
                    width: 46; height: 46; radius: 10
                    color: Theme.surfaceAlt
                    border.color: Theme.border
                    clip: true
                    Image {
                        anchors.fill: parent; anchors.margins: 3
                        visible: card.faceUrl.length > 0
                        source: card.faceUrl
                        smooth: false
                    }
                    Icon { anchors.centerIn: parent; visible: card.faceUrl.length === 0; name: "user"; size: 22; color: Theme.textMuted }
                    Rectangle {
                        anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 2
                        width: 12; height: 12; radius: 6
                        color: card.stateColor
                        border.width: 2; border.color: Theme.surface
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text { text: card.name; color: Theme.text; font.pixelSize: Theme.fontLg; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.maximumWidth: 320 }
                        Badge { visible: card.isDefault; text: qsTr("Default"); tone: "accent"; iconName: "check" }
                        Badge { text: card.typeText; tone: card.typeKey === "msa" ? "info" : "neutral" }
                        Item { Layout.fillWidth: true }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Spinner { visible: card.busy; size: 12 }
                        Text { text: card.statusText; color: card.stateColor; font.pixelSize: Theme.fontSm; font.weight: Font.Medium }
                        Text { visible: !card.hasProfile && card.typeKey === "msa"; text: "· " + qsTr("No Minecraft profile"); color: Theme.warning; font.pixelSize: Theme.fontSm }
                        Item { Layout.fillWidth: true }
                    }
                    Text {
                        id: errText
                        visible: card.lastError.length > 0 && card.accountState !== "online"
                        Layout.fillWidth: true
                        text: card.lastError; wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight
                        color: Theme.textMuted; font.pixelSize: Theme.fontXs + 1
                    }
                }

                PButton {
                    visible: !card.hasProfile && card.typeKey === "msa" && !card.busy
                    text: qsTr("Set up profile"); size: "sm"; variant: "subtle"
                    onClicked: page.openDialog("AccProfileSetupDialog", { accountId: card.accountId })
                }
                PButton {
                    visible: card.canManageSkins
                    text: qsTr("Skins"); iconName: "shirt"; size: "sm"
                    onClicked: page.openDialog("AccSkinsDialog", { accountId: card.accountId })
                }
                PButton {
                    visible: !card.isDefault
                    enabled: !card.busy
                    text: qsTr("Use"); size: "sm"; variant: "subtle"
                    onClicked: Accounts.setDefault(card.accountId)
                    PToolTip { visible: parent.hovered; text: qsTr("Make this the default account") }
                }
                IconButton {
                    visible: card.typeKey !== "offline"
                    enabled: !card.busy
                    iconName: "refresh-cw"; tip: qsTr("Refresh")
                    onClicked: Accounts.refresh(card.accountId)
                }
                IconButton {
                    iconName: "more-vertical"; tip: qsTr("More")
                    onClicked: { menu.accountId = card.accountId; menu.row = card.index; menu.popup(this, 0, height) }
                }
            }
        }
    }

    EmptyState {
        Layout.alignment: Qt.AlignCenter
        Layout.fillHeight: true
        visible: Accounts.count === 0
        iconName: "users"
        title: qsTr("Welcome!")
        text: qsTr("Link your Microsoft account to play Minecraft. You can add offline accounts once a Microsoft account that owns the game is added.")
        PButton { visible: Accounts.msaSupported; text: qsTr("Add Microsoft account"); variant: "primary"; iconName: "log-in"; onClicked: page.openDialog("AccMsaLoginDialog") }
    }

    PMenu {
        id: menu
        property string accountId
        property int row: -1
        readonly property var acc: accountId.length ? Accounts.get(accountId) : ({})
        PMenuItem { text: qsTr("Set as default"); iconName: "check"; enabled: !menu.acc.isDefault && !menu.acc.busy; onTriggered: Accounts.setDefault(menu.accountId) }
        PMenuItem { text: qsTr("No default account"); iconName: "x"; enabled: Accounts.defaultId.length > 0; onTriggered: Accounts.clearDefault() }
        PMenuSeparator {}
        PMenuItem { text: qsTr("Refresh"); iconName: "refresh-cw"; enabled: menu.acc.typeKey !== "offline" && !menu.acc.busy; onTriggered: Accounts.refresh(menu.accountId) }
        PMenuItem { text: qsTr("Manage skins"); iconName: "shirt"; enabled: !!menu.acc.canManageSkins; onTriggered: page.openDialog("AccSkinsDialog", { accountId: menu.accountId }) }
        PMenuItem { visible: menu.acc.typeKey === "msa" && !menu.acc.hasProfile; text: qsTr("Set up profile"); iconName: "user"; onTriggered: page.openDialog("AccProfileSetupDialog", { accountId: menu.accountId }) }
        PMenuSeparator {}
        PMenuItem { text: qsTr("Move up"); iconName: "chevron-down"; enabled: menu.row > 0; onTriggered: Accounts.move(menu.accountId, -1) }
        PMenuItem { text: qsTr("Move down"); iconName: "chevron-down"; enabled: menu.row >= 0 && menu.row < Accounts.count - 1; onTriggered: Accounts.move(menu.accountId, 1) }
        PMenuSeparator {}
        PMenuItem {
            text: qsTr("Remove"); iconName: "trash-2"; danger: true; enabled: !menu.acc.busy
            onTriggered: {
                var id = menu.accountId, n = menu.acc.name
                Dialogs.confirm({ title: qsTr("Remove %1?").arg(n), text: qsTr("Do you really want to remove this account from the launcher?"), confirmText: qsTr("Remove"), danger: true },
                                function(ok) { if (ok) Accounts.remove(id) })
            }
        }
    }
}
