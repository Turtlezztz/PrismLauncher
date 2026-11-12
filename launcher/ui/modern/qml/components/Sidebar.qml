import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

Rectangle {
    id: root
    property bool collapsed: width < 120
    property int topInset: 0   // height of the integrated macOS title bar (traffic lights)
    implicitWidth: App.setting("ModernSidebarCollapsed") === true ? 68 : 224
    color: Theme.sidebar
    Behavior on implicitWidth { NumberAnimation { duration: Theme.dur; easing.type: Theme.easing } }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        anchors.topMargin: root.topInset > 0 ? root.topInset + 10 : 12
        spacing: 4

        // brand
        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 14
            Layout.leftMargin: 4
            spacing: 10
            Image {
                source: "qrc:/qt/qml/PrismModern/qml/assets/logo.svg"
                sourceSize: Qt.size(64, 64)
                Layout.preferredWidth: 28; Layout.preferredHeight: 28
            }
            Text {
                visible: !root.collapsed
                text: App.appName
                color: Theme.text
                font.pixelSize: Theme.fontLg
                font.weight: Font.Bold
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
        }

        PButton {
            Layout.fillWidth: true
            Layout.bottomMargin: 10
            variant: "primary"
            iconName: "plus"
            text: root.collapsed ? "" : qsTr("New instance")
            onClicked: Router.go("NewInstance")
            PToolTip { visible: root.collapsed && parent.hovered; text: qsTr("New instance") }
        }

        SidebarItem { iconName: "library"; text: qsTr("Library"); page: "Library"; collapsed: root.collapsed }
        SidebarItem { iconName: "compass"; text: qsTr("Discover"); page: "Discover"; collapsed: root.collapsed }
        SidebarItem { iconName: "users"; text: qsTr("Accounts"); page: "Accounts"; collapsed: root.collapsed }
        SidebarItem { iconName: "settings"; text: qsTr("Settings"); page: "Settings"; collapsed: root.collapsed }

        Item { Layout.fillHeight: true }

        // running instances indicator
        Rectangle {
            Layout.fillWidth: true
            visible: App.runningCount > 0
            implicitHeight: 34
            radius: Theme.radius
            color: Theme.soft(Theme.success)
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 10
                spacing: 8
                Rectangle {
                    width: 8; height: 8; radius: 4; color: Theme.success
                    SequentialAnimation on opacity {
                        running: !Theme.reduceMotion && App.runningCount > 0; loops: Animation.Infinite
                        NumberAnimation { to: 0.35; duration: 900; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1; duration: 900; easing.type: Easing.InOutSine }
                    }
                }
                Text {
                    visible: !root.collapsed
                    text: qsTr("%1 running").arg(App.runningCount)
                    color: Theme.success; font.pixelSize: Theme.fontSm; font.weight: Font.DemiBold
                    Layout.fillWidth: true
                }
            }
        }

        AccountSwitcher { collapsed: root.collapsed }
        SidebarItem { iconName: "folder"; text: qsTr("Folders"); collapsed: root.collapsed; onClicked: foldersMenu.popup(this, width + 6, 0) }
        SidebarItem { iconName: "info"; text: qsTr("Help & About"); collapsed: root.collapsed; onClicked: helpMenu.popup(this, width + 6, 0) }
        SidebarItem {
            iconName: root.collapsed ? "chevron-right" : "chevron-left"
            text: qsTr("Collapse")
            collapsed: root.collapsed
            onClicked: App.setSetting("ModernSidebarCollapsed", !root.collapsed)
        }
    }

    Connections {
        target: App
        function onSettingChanged(key, value) {
            if (key === "ModernSidebarCollapsed") root.implicitWidth = value === true || value === "true" ? 68 : 224
        }
    }

    PMenu {
        id: foldersMenu
        PMenuItem { text: qsTr("Launcher root"); iconName: "folder-open"; onTriggered: App.openFolder("root") }
        PMenuItem { text: qsTr("Instances"); iconName: "folder-open"; onTriggered: App.openFolder("instances") }
        PMenuItem { text: qsTr("Central mods"); iconName: "puzzle"; onTriggered: App.openFolder("centralMods") }
        PMenuItem { text: qsTr("Skins"); iconName: "shirt"; onTriggered: App.openFolder("skins") }
        PMenuItem { text: qsTr("Java"); iconName: "coffee"; onTriggered: App.openFolder("java") }
        PMenuItem { text: qsTr("Logs"); iconName: "file-text"; onTriggered: App.openFolder("logs") }
        PMenuItem { text: qsTr("Instance icons"); iconName: "image"; onTriggered: App.openFolder("icons") }
        PMenuSeparator {}
        PMenuItem { text: qsTr("Icon themes"); iconName: "palette"; onTriggered: App.openFolder("iconThemes") }
        PMenuItem { text: qsTr("Widget themes"); iconName: "palette"; onTriggered: App.openFolder("widgetThemes") }
        PMenuItem { text: qsTr("Cat packs"); iconName: "image"; onTriggered: App.openFolder("catPacks") }
        PMenuItem { text: qsTr("Templates"); iconName: "layers"; onTriggered: App.openFolder("templates") }
    }
    PMenu {
        id: helpMenu
        PMenuItem { text: qsTr("About %1").arg(App.appName); iconName: "info"; onTriggered: Router.go("About") }
        PMenuItem { text: qsTr("News"); iconName: "newspaper"; onTriggered: Router.go("News") }
        PMenuItem { text: qsTr("Launcher log"); iconName: "terminal"; onTriggered: Router.go("LauncherLog") }
        PMenuSeparator {}
        PMenuItem { text: qsTr("Help / Wiki"); iconName: "book"; onTriggered: App.openUrl("https://prismlauncher.org/wiki/") }
        PMenuItem { text: qsTr("Report a bug"); iconName: "bug"; onTriggered: App.openUrl("https://github.com/PrismLauncher/PrismLauncher/issues") }
        PMenuItem { text: qsTr("Discord"); iconName: "discord"; onTriggered: App.openUrl("https://prismlauncher.org/discord") }
        PMenuItem { text: qsTr("Matrix"); iconName: "discord"; onTriggered: App.openUrl("https://prismlauncher.org/matrix") }
        PMenuItem { text: qsTr("Reddit"); iconName: "discord"; onTriggered: App.openUrl("https://prismlauncher.org/reddit") }
        PMenuSeparator {}
        PMenuItem { text: qsTr("Switch to classic interface"); iconName: "rotate-ccw"; onTriggered: {
            Dialogs.confirm({ title: qsTr("Switch to classic interface?"), text: qsTr("The launcher will restart with the classic interface. You can come back from Settings → Appearance in the classic UI by unchecking “Use classic interface”."), confirmText: qsTr("Restart") }, function(ok) {
                if (ok) { App.useClassicUi(true); App.restart() }
            })
        } }
    }
}
