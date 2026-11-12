import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// "Custom" source: Minecraft version (with type filters + search) and an optional mod loader + loader version.
Item {
    id: pane
    property NIController controller: null
    property bool active: false

    NIVanillaSource {
        id: src
        controller: pane.controller
        active: pane.active
    }

    // filter chips: [label, type substring]
    readonly property var typeChips: [
        { key: "release", text: qsTr("Releases") }, { key: "snapshot", text: qsTr("Snapshots") },
        { key: "beta", text: qsTr("Betas") }, { key: "alpha", text: qsTr("Alphas") }, { key: "experiment", text: qsTr("Experiments") }
    ]
    property var enabledTypes: ["release"]
    function toggleType(key) {
        var t = enabledTypes.slice()
        var i = t.indexOf(key)
        if (i >= 0) t.splice(i, 1); else t.push(key)
        enabledTypes = t
        src.versions.typeFilter = t.length ? t : ["\u0000none"]
    }

    readonly property var loaders: [
        { key: "none", text: qsTr("None") }, { key: "neoforge", text: "NeoForge" }, { key: "forge", text: "Forge" },
        { key: "fabric", text: "Fabric" }, { key: "quilt", text: "Quilt" }, { key: "liteloader", text: "LiteLoader" }
    ]

    RowLayout {
        anchors.fill: parent
        spacing: Theme.spacingLg

        // ---------------- Minecraft version ----------------
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 3
            spacing: Theme.spacing

            RowLayout {
                Layout.fillWidth: true
                SectionHeader { Layout.fillWidth: true; title: qsTr("Minecraft version"); description: src.selectedVersion.length ? qsTr("Selected: %1").arg(src.selectedVersion) : "" }
                IconButton { iconName: "refresh-cw"; tip: qsTr("Refresh version list"); onClicked: src.versions.refresh(true) }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingSm
                SearchField {
                    Layout.fillWidth: true
                    placeholderText: qsTr("Search versions")
                    onTextChanged: src.versions.search = text
                }
            }
            Flow {
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: pane.typeChips
                    delegate: NiChip {
                        required property var modelData
                        text: modelData.text
                        checked: pane.enabledTypes.indexOf(modelData.key) >= 0
                        onClicked: pane.toggleType(modelData.key)
                    }
                }
            }
            NiVersionList {
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: src.versions
                selectedVersion: src.selectedVersion
                emptyText: qsTr("No versions match the filters.")
                onPicked: (row, version) => src.selectVersion(row)
            }
        }

        // ---------------- Mod loader ----------------
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 2
            spacing: Theme.spacing

            RowLayout {
                Layout.fillWidth: true
                SectionHeader { Layout.fillWidth: true; title: qsTr("Mod loader"); description: src.loader === "none" ? qsTr("Play vanilla, or pick a loader to run mods.") : qsTr("%1 %2").arg(src.loaderName(src.loader)).arg(src.selectedLoaderVersion) }
                IconButton { iconName: "refresh-cw"; tip: qsTr("Refresh loader versions"); enabled: src.loader !== "none"; onClicked: src.loaderVersions.refresh(true) }
            }
            Flow {
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: pane.loaders
                    delegate: NiChip {
                        required property var modelData
                        text: modelData.text
                        checked: src.loader === modelData.key
                        onClicked: src.loader = modelData.key
                    }
                }
            }
            NiVersionList {
                Layout.fillWidth: true
                Layout.fillHeight: true
                showType: false
                model: src.loader === "none" ? null : src.loaderVersions
                selectedVersion: src.selectedLoaderVersion
                emptyText: src.loaderEmptyText
                onPicked: (row, version) => src.selectLoaderVersion(row)
            }
        }
    }
}
