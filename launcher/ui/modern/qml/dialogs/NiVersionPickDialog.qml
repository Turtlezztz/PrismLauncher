import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// Choose a version from an NIVersionModel (ATLauncher loader version prompt). answered("") when cancelled.
PDialog {
    id: dlg
    property var req: ({})
    readonly property NIVersionModel versions: req.model || null
    property string selected: ""
    property string result: ""
    signal answered(string version)

    title: req.title || qsTr("Choose version")
    subtitle: req.text || ""
    iconName: "layers"
    maxWidth: 460
    closePolicy: Popup.CloseOnEscape
    onOpened: { result = ""; selected = req.current || "" }
    onClosed: answered(result)

    NiVersionList {
        Layout.fillWidth: true
        Layout.preferredHeight: 320
        model: dlg.versions
        selectedVersion: dlg.selected
        onPicked: (row, version) => dlg.selected = version
        onActivatedVersion: (row, version) => { dlg.result = version; dlg.close() }
    }
    buttons: [
        PButton { text: qsTr("Use recommended"); onClicked: dlg.close() },
        PButton { text: qsTr("Select"); variant: "primary"; enabled: dlg.selected.length > 0; onClicked: { dlg.result = dlg.selected; dlg.close() } }
    ]
}
