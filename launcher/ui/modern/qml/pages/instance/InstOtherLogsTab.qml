import QtQuick
import QtQuick.Layouts
import PrismModern

// Log files of the instance (logs/, crash reports, ...) - classic OtherLogsPage.
Item {
    id: tab
    property string instanceId
    property InstanceBridge bridge
    LogFilesView {
        anchors.fill: parent
        mode: "files"
        instanceId: tab.instanceId
        uploadName: qsTr("Other Logs")
    }
}
