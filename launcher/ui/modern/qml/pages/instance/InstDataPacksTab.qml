import QtQuick
import PrismModern

// Instance → Data packs (classic DataPackPage; global data packs folder of the instance).
Item {
    id: tab
    property string instanceId

    ResFolderView {
        anchors.fill: parent
        instanceId: tab.instanceId
        kind: "datapacks"
        singular: qsTr("data pack")
        plural: qsTr("data packs")
        emptyIcon: "database"
        nameFilters: [qsTr("Data packs (*.zip)"), qsTr("All files (*)")]
    }
}
