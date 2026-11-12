import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import QtQuick.Layouts
import PrismModern

// "Import" source: zip / mrpack / CurseForge zip from a file, URL or curseforge:// link; drag & drop supported.
Item {
    id: pane
    property NIController controller: null
    property bool active: false
    property alias source: src

    NIImportSource {
        id: src
        controller: pane.controller
        active: pane.active
    }

    FileDialog {
        id: fileDialog
        title: qsTr("Choose modpack")
        nameFilters: [qsTr("Supported files (*.zip *.mrpack)"), qsTr("Zip archives (*.zip)"), qsTr("Modrinth packs (*.mrpack)")]
        onAccepted: src.text = src.urlToPath(selectedFile)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacingLg

        SectionHeader {
            Layout.fillWidth: true
            title: qsTr("Import a modpack or instance")
            description: qsTr("Prism / MultiMC instance exports, CurseForge and Modrinth modpacks (.zip, .mrpack), Technic zips, or a link to one.")
        }

        // drop zone
        Rectangle {
            id: zone
            Layout.fillWidth: true
            Layout.preferredHeight: 220
            radius: Theme.radiusLg
            color: drop.containsDrag ? Theme.accentSoft : zoneMa.containsMouse ? Theme.surfaceHover : Theme.surface
            border.width: 2
            border.color: drop.containsDrag ? Theme.accent : Theme.borderStrong
            Behavior on color { ColorAnimation { duration: Theme.durFast } }
            Behavior on border.color { ColorAnimation { duration: Theme.durFast } }
            // dashed look via an inner rectangle
            Rectangle { anchors.fill: parent; anchors.margins: 6; radius: Theme.radiusLg - 4; color: "transparent"; border.color: Theme.border }

            Column {
                anchors.centerIn: parent
                spacing: Theme.spacing
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 56; height: 56; radius: 18; color: Theme.accentSoft
                    scale: drop.containsDrag ? 1.1 : 1
                    Behavior on scale { NumberAnimation { duration: Theme.dur; easing.type: Easing.OutBack } }
                    Icon { anchors.centerIn: parent; name: "upload"; size: 26; color: Theme.accent }
                }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: drop.containsDrag ? qsTr("Drop to import") : qsTr("Drag a modpack file here"); color: Theme.text; font.pixelSize: Theme.fontLg; font.weight: Font.DemiBold }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: qsTr("or click to browse your files"); color: Theme.textMuted; font.pixelSize: Theme.fontMd }
            }
            MouseArea { id: zoneMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: fileDialog.open() }
            DropArea {
                id: drop
                anchors.fill: parent
                onDropped: ev => {
                    if (!ev.hasUrls || ev.urls.length === 0) return
                    src.text = src.urlToPath(ev.urls[0])
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSm
            Text { text: qsTr("File or link"); color: Theme.textMuted; font.pixelSize: Theme.fontSm; font.weight: Font.Medium }
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingSm
                PTextField {
                    id: field
                    Layout.fillWidth: true
                    iconName: "link"
                    placeholderText: qsTr("/path/to/pack.zip, https://… or curseforge://install?…")
                    text: src.text
                    error: src.kind === "invalid"
                    onTextEdited: src.text = text
                }
                PButton { text: qsTr("Browse…"); iconName: "folder-open"; onClicked: fileDialog.open() }
            }
            RowLayout {
                visible: src.hint.length > 0
                spacing: 6
                Spinner { visible: src.resolving; size: 14 }
                Icon {
                    visible: !src.resolving
                    name: src.kind === "invalid" ? "circle-alert" : "circle-check"
                    color: src.kind === "invalid" ? Theme.danger : Theme.success
                    size: 14
                }
                Text { text: src.hint; color: src.kind === "invalid" ? Theme.danger : Theme.textMuted; font.pixelSize: Theme.fontSm; wrapMode: Text.Wrap; Layout.fillWidth: true }
            }
        }

        Card {
            Layout.fillWidth: true
            implicitHeight: tips.implicitHeight + 2 * padding
            ColumnLayout {
                id: tips
                width: parent.width
                spacing: 6
                Text { text: qsTr("Good to know"); color: Theme.text; font.weight: Font.DemiBold; font.pixelSize: Theme.fontMd }
                Text { Layout.fillWidth: true; wrapMode: Text.Wrap; color: Theme.textMuted; font.pixelSize: Theme.fontSm
                    text: qsTr("• You can also drop files onto the launcher window anywhere, or open curseforge:// and modrinth:// links.\n• Dropping a mod, resource pack, shader pack or world adds it to an existing instance instead.\n• Imports from unknown sources may contain mods that are not hosted on Modrinth or CurseForge — you will be warned before they are installed.") }
            }
        }
        Item { Layout.fillHeight: true }
    }
}
