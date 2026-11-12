import QtQuick
import QtQuick.Layouts
import PrismModern

// STUB — to be implemented (see ui/modern/README.md for ownership).
PDialog {
    id: dlg
    property string instanceId
    title: "ExportInstance"
    Text { text: qsTr("Not implemented yet."); color: Theme.textMuted; Layout.fillWidth: true }
    buttons: [ PButton { text: qsTr("Close"); onClicked: dlg.close() } ]
}
