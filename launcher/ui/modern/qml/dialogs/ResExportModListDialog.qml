import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import QtQuick.Layouts
import PrismModern

// Export the (selected or all) mods as a list (classic ExportToModListDialog).
PDialog {
    id: dlg
    property var folderModel: null
    property string format: "html"
    property string customTemplate: "{name} [{version}] by {authors}"
    readonly property var exampleLines: ({
        "html": "<li><a href=\"{url}\">{name}</a> [{version}] by {authors}</li>",
        "markdown": "[{name}]({url}) [{version}] by {authors}",
        "plaintext": "{name} ({url}) [{version}] by {authors}",
        "json": "{\"name\":\"{name}\",\"url\":\"{url}\",\"version\":\"{version}\",\"authors\":\"{authors}\"},",
        "csv": "{name},{url},{version},\"{authors}\""
    })
    readonly property var extensions: ({ "html": "html", "markdown": "md", "plaintext": "txt", "json": "json", "csv": "csv", "custom": "txt" })
    readonly property string output: {
        if (!folderModel) return ""
        if (format === "custom") return folderModel.exportModListCustom(templateArea.text)
        return folderModel.exportModList(format, authorsBox.checked, urlBox.checked, versionBox.checked, fileBox.checked)
    }

    title: qsTr("Export mod list")
    subtitle: folderModel && folderModel.selectedCount > 0 ? qsTr("%n selected mod(s)", "", folderModel.selectedCount) : qsTr("All mods")
    iconName: "file-down"
    maxWidth: 720

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacing
        Text { text: qsTr("Format"); color: Theme.textMuted; font.pixelSize: Theme.fontSm }
        PComboBox {
            Layout.preferredWidth: 180
            textRole: "text"; valueRole: "value"
            model: [ { value: "html", text: "HTML" }, { value: "markdown", text: "Markdown" }, { value: "plaintext", text: qsTr("Plain text") },
                     { value: "json", text: "JSON" }, { value: "csv", text: "CSV" }, { value: "custom", text: qsTr("Custom") } ]
            onActivated: dlg.format = currentValue
        }
        Item { Layout.fillWidth: true }
    }
    Flow {
        Layout.fillWidth: true
        spacing: Theme.spacing
        visible: dlg.format !== "custom"
        PCheckBox { id: authorsBox; text: qsTr("Authors") }
        PCheckBox { id: versionBox; text: qsTr("Version") }
        PCheckBox { id: urlBox; text: qsTr("URL") }
        PCheckBox { id: fileBox; text: qsTr("File name") }
    }
    ColumnLayout {
        Layout.fillWidth: true
        visible: dlg.format === "custom"
        spacing: 4
        Text { text: qsTr("Line template. Placeholders: {name} {mod_id} {url} {version} {authors} {filename}"); color: Theme.textSubtle; font.pixelSize: Theme.fontXs; wrapMode: Text.Wrap; Layout.fillWidth: true }
        PTextArea { id: templateArea; Layout.fillWidth: true; Layout.preferredHeight: 70; monospace: true; text: dlg.customTemplate }
    }
    Text {
        Layout.fillWidth: true
        visible: dlg.format !== "custom"
        text: qsTr("Line format: %1").arg(dlg.exampleLines[dlg.format] || "")
        color: Theme.textSubtle; font.pixelSize: Theme.fontXs; font.family: Theme.monoFamily
        elide: Text.ElideRight
        textFormat: Text.PlainText
    }
    PTextArea {
        Layout.fillWidth: true
        Layout.preferredHeight: 260
        readOnly: true
        monospace: true
        text: dlg.output
    }

    FileDialog {
        id: saveDialog
        title: qsTr("Save mod list")
        fileMode: FileDialog.SaveFile
        defaultSuffix: dlg.extensions[dlg.format]
        selectedFile: ResUtil.localUrl((dlg.folderModel ? dlg.folderModel.instanceName() : "mods") + "." + dlg.extensions[dlg.format])
        onAccepted: {
            var err = ResUtil.saveText(selectedFile, dlg.output)
            if (err.length) Toasts.error(qsTr("Could not save: %1").arg(err))
            else { Toasts.success(qsTr("Mod list saved")); dlg.close() }
        }
    }

    buttons: [
        PButton { text: qsTr("Close"); onClicked: dlg.close() },
        PButton { text: qsTr("Copy"); iconName: "copy"; onClicked: { ResUtil.copyText(dlg.output); Toasts.success(qsTr("Copied to clipboard")) } },
        PButton { text: qsTr("Save…"); iconName: "save"; variant: "primary"; onClicked: saveDialog.open() }
    ]
}
