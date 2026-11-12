import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// Free-form notes for the instance (classic NotesPage). Saved automatically.
Item {
    id: tab
    property string instanceId
    property InstanceBridge bridge
    property bool dirty: false

    function save() {
        if (!dirty || !bridge) return
        bridge.notes = editor.text
        dirty = false
        savedHint.opacity = 1
        hideHint.restart()
    }
    Component.onDestruction: save()

    Timer { id: autosave; interval: 800; onTriggered: tab.save() }
    Timer { id: hideHint; interval: 1600; onTriggered: savedHint.opacity = 0 }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacing
        RowLayout {
            Layout.fillWidth: true
            SectionHeader {
                Layout.fillWidth: true
                title: qsTr("Notes")
                description: qsTr("Anything you want to remember about this instance. Changes are saved automatically.")
            }
            Row {
                id: savedHint
                spacing: 6
                opacity: 0
                Behavior on opacity { NumberAnimation { duration: Theme.dur } }
                Icon { name: "check"; size: 14; color: Theme.success; anchors.verticalCenter: parent.verticalCenter }
                Text { text: qsTr("Saved"); color: Theme.textMuted; font.pixelSize: Theme.fontSm; anchors.verticalCenter: parent.verticalCenter }
            }
        }
        PTextArea {
            id: editor
            Layout.fillWidth: true
            Layout.fillHeight: true
            placeholderText: qsTr("Write your notes here…")
            Component.onCompleted: text = tab.bridge ? tab.bridge.notes : ""
            textArea.onTextChanged: if (textArea.activeFocus) { tab.dirty = true; autosave.restart() }
            textArea.onActiveFocusChanged: if (!textArea.activeFocus) tab.save()
        }
    }
}
