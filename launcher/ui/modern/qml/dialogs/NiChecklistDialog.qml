import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// Pick items from a list (optional mods of a modpack). answered(list) with the checked items, or null when cancelled.
PDialog {
    id: dlg
    property var req: ({})
    property var result: null
    signal answered(var items)

    title: req.title || qsTr("Select optional mods")
    subtitle: req.text || ""
    iconName: "puzzle"
    maxWidth: 560
    closePolicy: Popup.CloseOnEscape
    onOpened: {
        result = null
        checks.clear()
        var pre = req.checked || []
        for (var i = 0; i < (req.items || []).length; i++) {
            var it = req.items[i]
            checks.append({ item: it, picked: pre.indexOf(it) >= 0 })
        }
    }
    onClosed: answered(result)

    ListModel { id: checks }

    RowLayout {
        Layout.fillWidth: true
        Text { text: qsTr("%1 optional files").arg(checks.count); color: Theme.textMuted; font.pixelSize: Theme.fontSm; Layout.fillWidth: true }
        PButton { size: "sm"; variant: "ghost"; text: qsTr("Select all"); onClicked: { for (var i = 0; i < checks.count; i++) checks.setProperty(i, "picked", true) } }
        PButton { size: "sm"; variant: "ghost"; text: qsTr("Clear"); onClicked: { for (var i = 0; i < checks.count; i++) checks.setProperty(i, "picked", false) } }
    }
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(list.contentHeight + 12, 340)
        radius: Theme.radius; color: Theme.surfaceAlt; border.color: Theme.border
        ListView {
            id: list
            anchors.fill: parent; anchors.margins: 6
            clip: true
            model: checks
            delegate: PCheckBox {
                required property int index
                required property string item
                required property bool picked
                width: list.width
                text: item
                checkable: false
                checkState: picked ? Qt.Checked : Qt.Unchecked
                onClicked: checks.setProperty(index, "picked", !picked)
            }
            ScrollBar.vertical: PScrollBar {}
        }
    }
    buttons: [
        PButton { text: qsTr("Cancel"); onClicked: dlg.close() },
        PButton {
            text: qsTr("Continue"); variant: "primary"
            onClicked: {
                var out = []
                for (var i = 0; i < checks.count; i++) if (checks.get(i).picked) out.push(checks.get(i).item)
                dlg.result = out
                dlg.close()
            }
        }
    ]
}
