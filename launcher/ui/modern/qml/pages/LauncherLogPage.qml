import QtQuick
import QtQuick.Layouts
import PrismModern

// The launcher's own logs (classic ViewLogWindow): live log + older log files.
PageScaffold {
    id: page
    title: qsTr("Launcher log")
    subtitle: qsTr("What the launcher itself has been doing. Useful when reporting problems.")
    property string instanceId: ""
    property string initialTab: ""
    property string initialPage: ""
    property var importUrls: []
    function openTab(key) {}

    LogFilesView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.bottomMargin: Theme.spacingXl
        mode: "launcher"
        uploadName: qsTr("Launcher Log")
    }
}
