import QtQuick
import QtQuick.Controls.Basic
import PrismModern

// Context menu for an instance. Set instanceId then popup().
PMenu {
    id: menu
    property string instanceId: ""
    readonly property var info: instanceId.length ? App.instances.get(instanceId) : ({})

    PMenuItem { text: info.running ? qsTr("Stop") : qsTr("Play"); iconName: info.running ? "square" : "play"
        onTriggered: info.running ? App.kill(menu.instanceId) : App.launch(menu.instanceId) }
    PMenuItem { text: qsTr("Play offline"); iconName: "wifi"; enabled: !info.running; onTriggered: App.launch(menu.instanceId, true) }
    PMenuSeparator {}
    PMenuItem { text: qsTr("Edit"); iconName: "sliders-horizontal"; onTriggered: Router.push("Instance", { instanceId: menu.instanceId }) }
    PMenuItem { text: qsTr("Rename"); iconName: "pencil"; onTriggered: {
        var id = menu.instanceId
        Dialogs.prompt({ title: qsTr("Rename instance"), value: info.name, confirmText: qsTr("Rename") }, function(v) { if (v !== null) App.renameInstance(id, v) })
    } }
    PMenuItem { text: qsTr("Change icon"); iconName: "image"; onTriggered: InstanceActions.open("icon", menu.instanceId) }
    PMenuItem { text: qsTr("Change group"); iconName: "layers"; onTriggered: InstanceActions.open("group", menu.instanceId) }
    PMenuItem { text: qsTr("Open folder"); iconName: "folder-open"; onTriggered: App.openInstanceFolder(menu.instanceId) }
    PMenuSeparator {}
    PMenuItem { text: qsTr("Copy"); iconName: "copy"; onTriggered: InstanceActions.open("copy", menu.instanceId) }
    PMenuItem { text: qsTr("Export"); iconName: "upload"; onTriggered: InstanceActions.open("export", menu.instanceId) }
    PMenuItem { text: qsTr("Create shortcut"); iconName: "link"; onTriggered: InstanceActions.open("shortcut", menu.instanceId) }
    PMenuSeparator {}
    PMenuItem { text: qsTr("Delete"); iconName: "trash-2"; danger: true; onTriggered: InstanceActions.confirmDelete(menu.instanceId) }
}
