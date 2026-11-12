import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// Live Minecraft log of the running / last launch (classic LogPage).
Item {
    id: tab
    property string instanceId
    property InstanceBridge bridge

    LogViewModel { id: logModel; mode: "console"; instanceId: tab.instanceId }
    LogUploadDialog { id: uploader; log: logModel }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacing

        LogToolbar {
            Layout.fillWidth: true
            panel: panel
            log: logModel
            PButton {
                size: "sm"; iconName: "copy"; text: qsTr("Copy"); enabled: logModel.hasSource && logModel.count > 0
                onClicked: { logModel.copyAll(); Toasts.success(qsTr("Log copied to the clipboard")) }
            }
            PButton {
                size: "sm"; iconName: "upload"; text: qsTr("Upload"); busy: logModel.uploading
                enabled: logModel.hasSource && logModel.count > 0 && !logModel.uploading
                onClicked: uploader.ask(qsTr("Minecraft Log"))
            }
            PButton {
                size: "sm"; iconName: "trash-2"; text: qsTr("Clear"); enabled: logModel.hasSource && logModel.count > 0
                onClicked: logModel.clear()
            }
        }

        LogViewPanel {
            id: panel
            Layout.fillWidth: true
            Layout.fillHeight: true
            log: logModel
            emptyTitle: tab.bridge && tab.bridge.launching ? qsTr("Starting…") : qsTr("No log yet")
            emptyText: tab.bridge && tab.bridge.launching ? qsTr("Minecraft's output will appear here as soon as the game starts.")
                                                          : qsTr("Launch the instance to see Minecraft's output here.")
        }
    }
}
