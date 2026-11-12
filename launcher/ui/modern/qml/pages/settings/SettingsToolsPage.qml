import QtQuick
import QtQuick.Layouts
import PrismModern

// Classic ExternalToolsPage: profilers, JSON editor and world tools.
SetPageBase {
    id: page
    title: qsTr("External tools")
    subtitle: qsTr("Profilers, editors and tools that can be opened from the launcher.")

    function checkProfiler(id, path, name) {
        var err = SettingsBackend.checkProfiler(id, path)
        if (err.length) Dialogs.message({ title: qsTr("Error"), text: qsTr("Error while checking %1 install:").arg(name) + "<br>" + err, kind: "error" })
        else Toasts.success(qsTr("%1 setup seems to be OK").arg(name))
    }

    SetSection {
        title: qsTr("Profilers"); iconName: "zap"
        SetRow {
            stacked: true
            label: "JProfiler"
            description: qsTr("Folder of your JProfiler installation. <a href=\"https://www.ej-technologies.com/products/jprofiler/overview.html\">Get JProfiler</a>")
            keywords: "profiler jprofiler"
            RowLayout {
                width: parent.width
                spacing: 8
                SetPathField {
                    id: jprof
                    Layout.fillWidth: true
                    key: "JProfilerPath"; dialogTitle: qsTr("JProfiler Folder"); showOpen: false
                    validate: p => { var e = SettingsBackend.checkProfiler("jprofiler", p); return e.length ? qsTr("Error while checking JProfiler install:") + "<br>" + e : "" }
                }
                PButton { text: qsTr("Check"); onClicked: page.checkProfiler("jprofiler", page.store.getString("JProfilerPath"), "JProfiler") }
            }
        }
        SetRow {
            stacked: true
            label: "VisualVM"
            description: qsTr("Path to the VisualVM executable. <a href=\"https://visualvm.github.io/\">Get VisualVM</a>")
            keywords: "profiler visualvm jvisualvm"
            RowLayout {
                width: parent.width
                spacing: 8
                SetPathField {
                    Layout.fillWidth: true
                    key: "JVisualVMPath"; file: true; dialogTitle: qsTr("VisualVM Executable")
                    validate: p => { var e = SettingsBackend.checkProfiler("jvisualvm", p); return e.length ? qsTr("Error while checking VisualVM install:") + "<br>" + e : "" }
                }
                PButton { text: qsTr("Check"); onClicked: page.checkProfiler("jvisualvm", page.store.getString("JVisualVMPath"), "VisualVM") }
            }
        }
    }

    SetSection {
        title: qsTr("Editors"); iconName: "pencil"
        SetRow {
            stacked: true
            label: qsTr("Text editor")
            description: qsTr("Used to edit JSON and other text files. Leave empty to use the system default.")
            keywords: "json editor text"
            RowLayout {
                width: parent.width
                spacing: 8
                SetText { id: editorField; key: "JsonEditor"; Layout.fillWidth: true; placeholderText: qsTr("System default")
                    onEditingFinished: { var r = SettingsBackend.resolveJsonEditor(text); if (r !== text) page.store.set("JsonEditor", r) } }
                PButton {
                    text: qsTr("Browse"); iconName: "file-text"
                    onClicked: {
                        var cur = page.store.getString("JsonEditor")
                        var p = SettingsBackend.browseFile(qsTr("Text Editor"), cur.length ? cur : SettingsBackend.defaultApplicationsDir(), "")
                        if (!p.length) return
                        p = SettingsBackend.normalizePath(p)
                        if (SettingsBackend.isExecutableFile(p)) page.store.set("JsonEditor", p)
                        else Dialogs.message({ title: qsTr("Invalid"), text: qsTr("The file chosen does not seem to be an executable"), kind: "warning" })
                    }
                }
            }
        }
    }

    SetSection {
        id: tools
        title: qsTr("World tools"); iconName: "map"
        description: qsTr("Programs that can open a world from the Worlds tab. ${WORLD_PATH} is replaced with the world's folder.")
        property var entries: []
        function load() {
            var m = page.store ? page.store.getJson("WorldTools", {}) : {}
            var l = []
            for (var k in m) l.push({ name: k, command: String(m[k]) })
            entries = l
        }
        function commit() {
            var m = {}
            for (var i = 0; i < entries.length; i++) {
                var n = entries[i].name.trim(), c = entries[i].command.trim()
                if (n.length && c.length) m[n] = c
            }
            page.store.setJson("WorldTools", m)
        }
        Component.onCompleted: load()
        Connections { target: page.store; function onDiscarded() { tools.load() } function onSaved() { tools.load() } }
        headerActions: [
            PButton { text: qsTr("Add"); size: "sm"; iconName: "plus"; onClicked: { var l = tools.entries.slice(); l.push({ name: "", command: "" }); tools.entries = l } }
        ]
        Item {
            width: parent.width; height: 60
            visible: tools.entries.length === 0
            Text { anchors.centerIn: parent; text: qsTr("No world tools configured."); color: Theme.textMuted; font.pixelSize: Theme.fontMd }
        }
        Column {
            width: parent.width
            topPadding: 8; bottomPadding: 12
            spacing: 8
            Repeater {
                model: tools.entries.length
                delegate: RowLayout {
                    id: toolRow
                    required property int index
                    width: parent.width
                    spacing: 8
                    PTextField {
                        id: nameField
                        Layout.preferredWidth: 170
                        placeholderText: qsTr("Name")
                        text: tools.entries[toolRow.index] ? tools.entries[toolRow.index].name : ""
                        onTextEdited: { tools.entries[toolRow.index].name = text; tools.commit() }
                    }
                    PTextField {
                        id: cmdField
                        Layout.fillWidth: true
                        font.family: Theme.monoFamily
                        placeholderText: qsTr("Command, e.g. /path/to/tool ${WORLD_PATH}")
                        text: tools.entries[toolRow.index] ? tools.entries[toolRow.index].command : ""
                        onTextEdited: { tools.entries[toolRow.index].command = text; tools.commit() }
                    }
                    IconButton {
                        iconName: "folder-open"; tip: qsTr("Select executable")
                        onClicked: {
                            var p = SettingsBackend.browseFile(qsTr("Select Executable"), "", Qt.platform.os === "windows" ? qsTr("Executables (*.exe *.bat);;All Files (*)") : qsTr("All Files (*)"))
                            if (!p.length) return
                            if (!SettingsBackend.isExecutableFile(p)) { Dialogs.message({ title: qsTr("Invalid command"), text: qsTr("The selected file is not executable"), kind: "warning" }); return }
                            var e = tools.entries[toolRow.index]
                            e.command = SettingsBackend.worldToolCommandFor(p)
                            if (!e.name.trim().length) e.name = p.replace(/^.*[\\/]/, "").replace(/\.[^.]*$/, "")
                            nameField.text = e.name; cmdField.text = e.command
                            tools.commit()
                        }
                    }
                    IconButton {
                        iconName: "trash-2"; tip: qsTr("Remove")
                        onClicked: { var l = tools.entries.slice(); l.splice(toolRow.index, 1); tools.entries = l; tools.commit() }
                    }
                }
            }
        }
    }
}
