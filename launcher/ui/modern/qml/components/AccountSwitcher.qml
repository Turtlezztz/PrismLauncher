import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// Sidebar account switcher: shows the default account, click to switch or manage accounts.
// Also hosts app-wide QML hooks from the settings/accounts area (Java messages, update offers).
AbstractButton {
    id: sw
    property bool collapsed: false
    Layout.fillWidth: true
    implicitHeight: 44
    hoverEnabled: true
    onClicked: menu.popup(sw, sw.width + 6, sw.height - menu.implicitHeight)
    HoverHandler { cursorShape: Qt.PointingHandCursor }

    SetGlobalHooks {}

    background: Rectangle {
        radius: Theme.radius
        color: sw.down ? Theme.surfacePressed : sw.hovered || menu.visible ? Theme.surfaceHover : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
    }
    contentItem: RowLayout {
        spacing: 10
        Item { width: sw.collapsed ? (sw.width - 28) / 2 - 10 : 0 }
        Rectangle {
            Layout.leftMargin: sw.collapsed ? 0 : 6
            width: 28; height: 28; radius: 7
            color: Theme.surfaceAlt
            border.color: Theme.border
            clip: true
            Image { anchors.fill: parent; anchors.margins: 2; visible: Accounts.defaultFaceUrl.length > 0; source: Accounts.defaultFaceUrl; smooth: false }
            Icon { anchors.centerIn: parent; visible: Accounts.defaultFaceUrl.length === 0; name: "user"; size: 15; color: Theme.textMuted }
        }
        ColumnLayout {
            visible: !sw.collapsed
            Layout.fillWidth: true
            spacing: 0
            Text {
                text: Accounts.defaultName.length ? Accounts.defaultName : Accounts.count ? qsTr("No default account") : qsTr("Sign in")
                color: Theme.text; font.pixelSize: Theme.fontMd; font.weight: Font.DemiBold
                elide: Text.ElideRight; Layout.fillWidth: true
            }
            Text {
                text: Accounts.count ? (Accounts.count === 1 ? qsTr("1 account") : qsTr("%1 accounts").arg(Accounts.count)) : qsTr("Add an account")
                color: Theme.textSubtle; font.pixelSize: Theme.fontXs + 1
                elide: Text.ElideRight; Layout.fillWidth: true
            }
        }
        Icon { visible: !sw.collapsed; name: "arrow-up-down"; size: 14; color: Theme.textSubtle; Layout.rightMargin: 6 }
    }
    PToolTip { visible: sw.collapsed && sw.hovered && !menu.visible; text: Accounts.defaultName.length ? Accounts.defaultName : qsTr("Accounts") }

    PMenu {
        id: menu
        implicitWidth: 250
        Instantiator {
            model: Accounts
            onObjectAdded: (index, object) => menu.insertItem(index, object)
            onObjectRemoved: (index, object) => menu.removeItem(object)
            delegate: PMenuItem {
                required property string accountId
                required property string name
                required property bool isDefault
                required property string typeText
                text: name + "  ·  " + typeText
                iconName: isDefault ? "check" : "user"
                onTriggered: Accounts.setDefault(accountId)
            }
        }
        PMenuSeparator { visible: Accounts.count > 0 }
        PMenuItem { text: qsTr("No default account"); iconName: "x"; visible: Accounts.defaultId.length > 0; onTriggered: Accounts.clearDefault() }
        PMenuItem { text: qsTr("Manage accounts…"); iconName: "users"; onTriggered: Router.go("Accounts") }
    }
}
