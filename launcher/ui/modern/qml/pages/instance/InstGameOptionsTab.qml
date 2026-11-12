import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// Read-only view of the game's options.txt (classic GameOptionsPage).
Item {
    id: tab
    property string instanceId
    property InstanceBridge bridge
    property var options: []
    property string filter: ""
    property string category: ""
    readonly property var shown: options.filter(function(o) {
        if (category.length && o.category !== category) return false
        if (!filter.length) return true
        var f = filter.toLowerCase()
        return o.key.toLowerCase().indexOf(f) >= 0 || o.value.toLowerCase().indexOf(f) >= 0
    })

    function reload() { options = bridge ? bridge.gameOptions() : [] }
    Component.onCompleted: reload()

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSm
            SearchField { Layout.preferredWidth: 260; placeholderText: qsTr("Filter options"); onTextChanged: tab.filter = text }
            SegmentedControl {
                options: [ { value: "", text: qsTr("All") }, { value: "Other", text: qsTr("General") }, { value: "Controls", text: qsTr("Controls") },
                           { value: "Sound", text: qsTr("Sound") }, { value: "Skin", text: qsTr("Skin") } ]
                value: tab.category
                onActivated: v => tab.category = v
            }
            Item { Layout.fillWidth: true }
            Text { text: qsTr("%1 options").arg(tab.shown.length); color: Theme.textSubtle; font.pixelSize: Theme.fontSm }
            IconButton { iconName: "refresh-cw"; tip: qsTr("Reload"); onClicked: tab.reload() }
            IconButton { iconName: "external-link"; tip: qsTr("Open options.txt"); enabled: tab.options.length > 0; onClicked: App.openPath(tab.bridge.gameOptionsPath()) }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.radiusLg
            color: Theme.surface
            border.color: Theme.border
            clip: true

            ListView {
                id: list
                anchors.fill: parent
                anchors.margins: 1
                model: tab.shown
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: PScrollBar {}
                reuseItems: true
                header: Rectangle {
                    width: list.width; height: 34; color: Theme.surfaceAlt
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16
                        Text { text: qsTr("Option"); color: Theme.textMuted; font.pixelSize: Theme.fontSm; font.weight: Font.DemiBold; Layout.preferredWidth: list.width * 0.45 }
                        Text { text: qsTr("Value"); color: Theme.textMuted; font.pixelSize: Theme.fontSm; font.weight: Font.DemiBold; Layout.fillWidth: true }
                    }
                }
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: list.width
                    height: 32
                    color: index % 2 ? Theme.surfaceAlt : "transparent"
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16
                        Text { text: modelData.key; color: Theme.text; font.pixelSize: Theme.fontMd; elide: Text.ElideRight; Layout.preferredWidth: list.width * 0.45 }
                        Text { text: modelData.value; color: Theme.textMuted; font.family: Theme.monoFamily; font.pixelSize: Theme.fontSm; elide: Text.ElideRight; Layout.fillWidth: true }
                    }
                }
            }
            EmptyState {
                anchors.centerIn: parent
                visible: tab.shown.length === 0
                iconName: "sliders-horizontal"
                title: tab.options.length ? qsTr("No matching options") : qsTr("No game options yet")
                text: tab.options.length ? "" : qsTr("options.txt is created the first time the game is started.")
            }
        }
    }
}
