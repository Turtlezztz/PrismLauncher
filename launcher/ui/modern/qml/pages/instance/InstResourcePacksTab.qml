import QtQuick
import PrismModern

// Instance → Resource packs (classic ResourcePackPage).
Item {
    id: tab
    property string instanceId

    ResFolderView {
        anchors.fill: parent
        instanceId: tab.instanceId
        kind: "resourcepacks"
        singular: qsTr("resource pack")
        plural: qsTr("resource packs")
        emptyIcon: "paintbrush"
        nameFilters: [qsTr("Resource packs (*.zip)"), qsTr("All files (*)")]
    }
}
