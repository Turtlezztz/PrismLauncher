import QtQuick
import QtQuick.Layouts
import PrismModern

// STUB — to be implemented (see ui/modern/README.md for ownership).
PageScaffold {
    id: page
    title: "NewInstance"
    property string instanceId: ""
    property string initialTab: ""
    property string initialPage: ""
    property var importUrls: []
    function openTab(key) {}
    EmptyState { Layout.alignment: Qt.AlignCenter; iconName: "hammer"; title: qsTr("Coming soon"); text: qsTr("This page is not implemented yet.") }
}
