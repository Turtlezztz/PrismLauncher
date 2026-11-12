import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// ATLauncher optional mods (with dependencies / groups handled by the classic model) + share codes.
PDialog {
    id: dlg
    property var req: ({})
    readonly property NIAtlOptionalMods mods: req.model || null
    property bool result: false
    signal answered(bool accepted)

    title: req.title || qsTr("Select optional mods")
    subtitle: qsTr("Mods marked as recommended by the pack author are preselected.")
    iconName: "puzzle"
    maxWidth: 640
    closePolicy: Popup.CloseOnEscape
    onOpened: result = false
    onClosed: answered(result)

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacingSm
        PTextField { id: code; Layout.fillWidth: true; placeholderText: qsTr("Share code"); iconName: "key-round" }
        PButton { text: qsTr("Use share code"); enabled: code.text.trim().length > 0; onClicked: dlg.mods.useShareCode(code.text.trim()) }
    }
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(list.contentHeight + 12, 360)
        radius: Theme.radius; color: Theme.surfaceAlt; border.color: Theme.border
        ListView {
            id: list
            anchors.fill: parent; anchors.margins: 6
            clip: true
            model: dlg.mods
            delegate: Rectangle {
                id: row
                required property int index
                required property string name
                required property string description
                required property bool checked
                required property string modColor
                width: list.width
                height: Math.max(40, col.implicitHeight + 12)
                radius: Theme.radiusSm
                color: ma.containsMouse ? Theme.surfaceHover : "transparent"
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                    spacing: 10
                    PCheckBox { checkable: false; checkState: row.checked ? Qt.Checked : Qt.Unchecked; onClicked: dlg.mods.toggle(row.index) }
                    ColumnLayout {
                        id: col
                        Layout.fillWidth: true; spacing: 1
                        Text { text: row.name; color: row.modColor.length ? row.modColor : Theme.text; font.pixelSize: Theme.fontMd; font.weight: Font.Medium; Layout.fillWidth: true; elide: Text.ElideRight }
                        Text { visible: text.length > 0; text: row.description; color: Theme.textMuted; font.pixelSize: Theme.fontSm; Layout.fillWidth: true; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight }
                    }
                }
                MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; z: -1; onClicked: dlg.mods.toggle(row.index) }
            }
            ScrollBar.vertical: PScrollBar {}
        }
    }
    RowLayout {
        Layout.fillWidth: true
        PButton { size: "sm"; variant: "ghost"; text: qsTr("Select recommended"); onClicked: dlg.mods.selectRecommended() }
        PButton { size: "sm"; variant: "ghost"; text: qsTr("Clear all"); onClicked: dlg.mods.clearAll() }
    }
    buttons: [
        PButton { text: qsTr("Cancel install"); onClicked: dlg.close() },
        PButton { text: qsTr("Install"); variant: "primary"; onClicked: { dlg.result = true; dlg.close() } }
    ]
}
