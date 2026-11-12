import QtQuick
import QtQuick.Layouts
import PrismModern

// Path text field + Browse (+ open) bound to a setting in the settings draft.
//   SetPathField { key: "InstanceDir"; dialogTitle: qsTr("Instance Folder") }        (directory)
//   SetPathField { key: "JsonEditor"; file: true }                                    (file)
// `validate(path)` may return a warning string; when non-empty the user is asked to confirm.
RowLayout {
    id: root
    property var store: null
    property string key: ""
    property string dialogTitle: qsTr("Select folder")
    property bool file: false
    property string fileFilter: ""
    property string placeholder: ""
    property bool showOpen: !file
    property var validate: null
    spacing: Theme.spacingSm
    width: parent ? parent.width : implicitWidth

    function accept(path) {
        if (!store) return
        var w = validate ? validate(path) : ""
        if (w && w.length) {
            Dialogs.confirm({ title: qsTr("Use this path?"), text: w, confirmText: qsTr("Use anyway") }, function(ok) { if (ok) root.store.set(root.key, path) })
        } else {
            store.set(key, path)
        }
    }

    PTextField {
        id: field
        Layout.fillWidth: true
        text: root.store ? root.store.getString(root.key) : ""
        placeholderText: root.placeholder
        onTextEdited: if (root.store) root.store.set(root.key, text)
    }
    PButton {
        text: qsTr("Browse")
        iconName: root.file ? "file-text" : "folder-open"
        onClicked: {
            var cur = field.text
            var p = root.file ? SettingsBackend.browseFile(root.dialogTitle, cur, root.fileFilter) : SettingsBackend.browseDirectory(root.dialogTitle, cur)
            if (p.length) root.accept(SettingsBackend.normalizePath(p))
        }
    }
    IconButton {
        visible: root.showOpen
        iconName: "external-link"; tip: qsTr("Open folder")
        onClicked: App.openPath(field.text)
    }
    Component.onCompleted: if (!store) { var p = parent; while (p && p.isSettingsPage !== true) p = p.parent; if (p) store = Qt.binding(function() { return p.store }) }
}
