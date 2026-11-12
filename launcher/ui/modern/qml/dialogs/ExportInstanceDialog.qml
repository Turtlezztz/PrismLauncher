import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import QtQuick.Layouts
import PrismModern

// Export an instance (classic ExportInstanceDialog + ExportPackDialog):
//  - Prism zip (whole instance, pick files to include)
//  - Modrinth .mrpack / CurseForge zip with pack metadata and an include/exclude file tree.
PDialog {
    id: dlg
    property string instanceId
    property string format: "zip"

    title: qsTr("Export instance")
    subtitle: exporter.instanceName
    iconName: "upload"
    maxWidth: 720

    NIExportInstance { id: exporter; instanceId: dlg.instanceId; format: dlg.format; onError: message => Toasts.error(message) }

    readonly property bool pack: format !== "zip"
    readonly property bool valid: format !== "modrinth" || exporter.packVersion.trim().length > 0

    onClosed: exporter.saveSettings()

    FileDialog {
        id: saveDialog
        title: qsTr("Export %1").arg(exporter.instanceName)
        fileMode: FileDialog.SaveFile
        currentFolder: exporter.suggestedFolder()
        nameFilters: dlg.format === "modrinth" ? [qsTr("Modrinth pack (*.mrpack *.zip)")] : dlg.format === "curseforge" ? [qsTr("CurseForge pack (*.zip)")] : [qsTr("Zip (*.zip)")]
        onAccepted: {
            var bridge = exporter.exportTo(selectedFile)
            if (bridge) NiInteraction.track(bridge, { successText: qsTr("Exported “%1”").arg(exporter.instanceName) })
            dlg.close()
        }
    }

    SegmentedControl {
        options: [ { value: "zip", text: qsTr("Prism zip"), icon: "file-archive" }, { value: "modrinth", text: "Modrinth (.mrpack)", icon: "package" },
                   { value: "curseforge", text: qsTr("CurseForge"), icon: "package" } ]
        value: dlg.format
        onActivated: v => dlg.format = v
    }
    Text {
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        color: Theme.textMuted; font.pixelSize: Theme.fontSm
        text: dlg.format === "zip" ? qsTr("A complete copy of the instance that can be imported into Prism Launcher or MultiMC.")
            : dlg.format === "modrinth" ? qsTr("A Modrinth modpack. Mods known to Modrinth are referenced by download link; other files are bundled as overrides.")
            : qsTr("A CurseForge modpack. Mods known to CurseForge are referenced by ID; other files are bundled as overrides.")
    }

    // pack metadata
    GridLayout {
        Layout.fillWidth: true
        visible: dlg.pack
        columns: 2
        columnSpacing: Theme.spacing
        rowSpacing: Theme.spacingSm
        Text { text: qsTr("Name"); color: Theme.textMuted; font.pixelSize: Theme.fontSm }
        PTextField { Layout.fillWidth: true; placeholderText: exporter.instanceName; text: exporter.packName; onTextEdited: exporter.packName = text }
        Text { text: qsTr("Version"); color: Theme.textMuted; font.pixelSize: Theme.fontSm }
        PTextField { Layout.fillWidth: true; placeholderText: qsTr("1.0.0"); text: exporter.packVersion; onTextEdited: exporter.packVersion = text; error: dlg.format === "modrinth" && !text.trim().length }
        Text { visible: dlg.format === "modrinth"; text: qsTr("Summary"); color: Theme.textMuted; font.pixelSize: Theme.fontSm }
        PTextField { visible: dlg.format === "modrinth"; Layout.fillWidth: true; text: exporter.summary; onTextEdited: exporter.summary = text }
        Text { visible: dlg.format === "curseforge"; text: qsTr("Author"); color: Theme.textMuted; font.pixelSize: Theme.fontSm }
        PTextField { visible: dlg.format === "curseforge"; Layout.fillWidth: true; text: exporter.author; onTextEdited: exporter.author = text }
        Text { visible: dlg.format === "curseforge"; text: qsTr("Memory"); color: Theme.textMuted; font.pixelSize: Theme.fontSm }
        RowLayout {
            visible: dlg.format === "curseforge"
            spacing: Theme.spacingSm
            PCheckBox { text: qsTr("Recommended memory"); checked: exporter.recommendedMemoryEnabled; onToggled: exporter.recommendedMemoryEnabled = checked }
            PSpinBox { enabled: exporter.recommendedMemoryEnabled; from: 512; to: 65536; stepSize: 512; suffix: "MiB"; value: exporter.recommendedMemory; onValueModified: exporter.recommendedMemory = value }
        }
    }
    PCheckBox {
        visible: dlg.pack
        text: qsTr("Mark disabled files as optional")
        checked: exporter.optionalFiles
        onToggled: exporter.optionalFiles = checked
    }

    // file tree
    Text { text: qsTr("Files to include"); color: Theme.text; font.weight: Font.DemiBold; font.pixelSize: Theme.fontMd }
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: dlg.pack ? 220 : 320
        radius: Theme.radius
        color: Theme.surfaceAlt
        border.color: Theme.border
        clip: true
        TreeView {
            id: tree
            anchors.fill: parent
            anchors.margins: 4
            model: exporter.files
            rootIndex: exporter.rootIndex
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: PScrollBar {}
            delegate: Item {
                id: node
                required property TreeView treeView
                required property bool isTreeNode
                required property bool expanded
                required property bool hasChildren
                required property int depth
                required property int row
                required property string fileName
                required property int checkValue
                required property bool isDir
                required property string sizeText
                implicitWidth: tree.width
                implicitHeight: 28
                Rectangle { anchors.fill: parent; radius: Theme.radiusSm; color: nodeHover.hovered ? Theme.surfaceHover : "transparent" }
                HoverHandler { id: nodeHover }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 4 + node.depth * 18
                    anchors.rightMargin: 10
                    spacing: 4
                    Item {
                        Layout.preferredWidth: 18; Layout.preferredHeight: 18
                        Icon {
                            anchors.centerIn: parent
                            visible: node.isDir
                            name: "chevron-right"; size: 13; color: Theme.textMuted
                            rotation: node.expanded ? 90 : 0
                            Behavior on rotation { NumberAnimation { duration: Theme.durFast } }
                        }
                        TapHandler { enabled: node.isDir; onTapped: node.treeView.toggleExpanded(node.row) }
                    }
                    PCheckBox {
                        checkable: false
                        checkState: node.checkValue === 2 ? Qt.Checked : node.checkValue === 1 ? Qt.PartiallyChecked : Qt.Unchecked
                        onClicked: exporter.files.toggle(node.treeView.index(node.row, 0))
                    }
                    Icon { name: node.isDir ? "folder" : "file-text"; size: 14; color: node.isDir ? Theme.accent : Theme.textSubtle }
                    Text {
                        Layout.fillWidth: true
                        text: node.fileName
                        color: node.checkValue === 0 ? Theme.textSubtle : Theme.text
                        font.pixelSize: Theme.fontSm
                        font.strikeout: node.checkValue === 0
                        elide: Text.ElideMiddle
                    }
                    Text { text: node.sizeText; color: Theme.textSubtle; font.pixelSize: Theme.fontXs + 1 }
                }
                TapHandler { enabled: node.isDir; onDoubleTapped: node.treeView.toggleExpanded(node.row) }
            }
        }
    }

    buttons: [
        PButton { text: qsTr("Cancel"); onClicked: dlg.close() },
        PButton {
            text: qsTr("Export…"); variant: "primary"; iconName: "upload"
            enabled: dlg.valid
            onClicked: {
                saveDialog.selectedFile = Qt.resolvedUrl(exporter.suggestedFolder() + "/" + exporter.suggestedFileName())
                saveDialog.open()
            }
        }
    ]
}
