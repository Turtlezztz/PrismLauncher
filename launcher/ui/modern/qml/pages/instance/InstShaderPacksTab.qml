import QtQuick
import PrismModern

// Instance → Shader packs (classic ShaderPackPage).
Item {
    id: tab
    property string instanceId

    ResFolderView {
        anchors.fill: parent
        instanceId: tab.instanceId
        kind: "shaderpacks"
        singular: qsTr("shader pack")
        plural: qsTr("shader packs")
        emptyIcon: "sparkles"
        nameFilters: [qsTr("Shader packs (*.zip)"), qsTr("All files (*)")]
    }
}
