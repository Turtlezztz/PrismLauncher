import QtQuick
import QtQuick.Layouts
import PrismModern

// Instance → Mods (classic ModFolderPage, plus Core mods / Nil mods when the instance has them).
Item {
    id: tab
    property string instanceId
    property string folderKind: "mods"
    readonly property var folders: ResUtil.modFolders(instanceId)

    ResFolderView {
        anchors.fill: parent
        instanceId: tab.instanceId
        kind: tab.folderKind
        singular: qsTr("mod")
        plural: qsTr("mods")
        emptyIcon: "puzzle"
        showConfigs: true
        downloadable: tab.folderKind === "mods"
        updatable: tab.folderKind === "mods"
        nameFilters: [qsTr("Minecraft mods (*.zip *.jar *.litemod *.disabled)"), qsTr("All files (*)")]
        leadingTools: [
            SegmentedControl {
                visible: tab.folders.length > 1
                options: tab.folders.map(k => ({ value: k, text: k === "mods" ? qsTr("Mods") : k === "coremods" ? qsTr("Core mods") : qsTr("Nil mods") }))
                value: tab.folderKind
                onActivated: v => tab.folderKind = v
            }
        ]
    }
}
