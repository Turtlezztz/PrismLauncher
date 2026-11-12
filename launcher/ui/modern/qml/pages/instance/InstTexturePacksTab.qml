import QtQuick
import PrismModern

// Instance → Texture packs (classic TexturePackPage, for Minecraft ≤ 1.6).
Item {
    id: tab
    property string instanceId

    ResFolderView {
        anchors.fill: parent
        instanceId: tab.instanceId
        kind: "texturepacks"
        singular: qsTr("texture pack")
        plural: qsTr("texture packs")
        emptyIcon: "image"
        nameFilters: [qsTr("Texture packs (*.zip)"), qsTr("All files (*)")]
    }
}
