import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// Modpack search filters for Modrinth / CurseForge (classic ModFilterWidget).
Rectangle {
    id: panel
    property NIPackBrowser browser: null
    readonly property bool modrinth: browser && browser.platform === "modrinth"

    // working copy of the filter
    property var mcVersions: []
    property var loaders: []
    property var categories: []
    property var releaseTypes: []
    property bool openSource: false
    property var excludeDisclosures: []
    property bool showSnapshots: false

    function toggle(listName, key) {
        var l = panel[listName].slice()
        var i = l.indexOf(key)
        if (i >= 0) l.splice(i, 1); else l.push(key)
        panel[listName] = l
        apply()
    }
    function apply() {
        browser.setFilter({ mcVersions: mcVersions, loaders: loaders, categories: categories, releaseTypes: releaseTypes,
                            openSource: openSource, excludeDisclosures: excludeDisclosures })
    }
    function reset() {
        mcVersions = []; loaders = []; categories = []; releaseTypes = []; openSource = false; excludeDisclosures = []
        apply()
    }

    readonly property var loaderOptions: modrinth
        ? [ { k: "neoforge", t: "NeoForge" }, { k: "forge", t: "Forge" }, { k: "fabric", t: "Fabric" }, { k: "quilt", t: "Quilt" },
            { k: "liteloader", t: "LiteLoader" }, { k: "babric", t: "Babric" }, { k: "bta", t: "BTA" }, { k: "legacyfabric", t: "Legacy Fabric" },
            { k: "ornithe", t: "Ornithe" }, { k: "rift", t: "Rift" } ]
        : [ { k: "neoforge", t: "NeoForge" }, { k: "forge", t: "Forge" }, { k: "fabric", t: "Fabric" }, { k: "quilt", t: "Quilt" } ]
    readonly property var disclosureOptions: [
        { k: "ai_content", t: qsTr("AI-generated content") }, { k: "ai_content_code", t: qsTr("AI code") }, { k: "ai_content_assets", t: qsTr("AI assets") },
        { k: "ai_content_text", t: qsTr("AI text") }, { k: "ai_content_functionality", t: qsTr("AI functionality") },
        { k: "advertisements", t: qsTr("Advertisements") }, { k: "epilepsy_triggers", t: qsTr("Epilepsy triggers") },
        { k: "system_interactions", t: qsTr("System interactions") }, { k: "telemetry", t: qsTr("Telemetry") },
        { k: "telemetry_opt_in", t: qsTr("Opt-in telemetry") }, { k: "telemetry_opt_out", t: qsTr("Opt-out telemetry") },
        { k: "telemetry_always_active", t: qsTr("Always-on telemetry") }, { k: "derivative_work", t: qsTr("Derivative work") },
        { k: "paid_features", t: qsTr("Paid features") }, { k: "archived", t: qsTr("Archived") }
    ]

    radius: Theme.radiusLg
    color: Theme.surface
    border.color: Theme.border
    clip: true

    NIVersionModel { id: mcList; uid: "net.minecraft"; typeFilter: panel.showSnapshots ? [] : ["release"] }

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.margins: Theme.spacing
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: PScrollBar {}

        ColumnLayout {
            id: col
            width: flick.width - 8
            spacing: Theme.spacing

            RowLayout {
                Layout.fillWidth: true
                Text { text: qsTr("Filters"); color: Theme.text; font.pixelSize: Theme.fontLg; font.weight: Font.DemiBold; Layout.fillWidth: true }
                PButton { size: "sm"; variant: "ghost"; text: qsTr("Reset"); enabled: panel.browser && panel.browser.activeFilterCount > 0; onClicked: panel.reset() }
            }

            // Minecraft versions
            Text { text: qsTr("Minecraft version"); color: Theme.textMuted; font.pixelSize: Theme.fontSm; font.weight: Font.Medium }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 150
                radius: Theme.radius; color: Theme.surfaceAlt; border.color: Theme.border
                ListView {
                    id: mcView
                    anchors.fill: parent; anchors.margins: 4
                    clip: true
                    model: mcList
                    reuseItems: true
                    ScrollBar.vertical: PScrollBar {}
                    delegate: PCheckBox {
                        required property string version
                        width: mcView.width
                        height: 26
                        text: version
                        font.pixelSize: Theme.fontSm
                        checkable: false
                        checkState: panel.mcVersions.indexOf(version) >= 0 ? Qt.Checked : Qt.Unchecked
                        onClicked: {
                            if (panel.modrinth) panel.toggle("mcVersions", version)
                            else { panel.mcVersions = panel.mcVersions.indexOf(version) >= 0 ? [] : [version]; panel.apply() }
                        }
                    }
                }
                Spinner { anchors.centerIn: parent; visible: mcList.loading; size: 18 }
            }
            PSwitch { text: qsTr("Show snapshots"); checked: panel.showSnapshots; onToggled: panel.showSnapshots = checked; Layout.fillWidth: true }

            // loaders
            Text { text: qsTr("Mod loader"); color: Theme.textMuted; font.pixelSize: Theme.fontSm; font.weight: Font.Medium }
            Flow {
                Layout.fillWidth: true; spacing: 6
                Repeater {
                    model: panel.loaderOptions
                    delegate: NiChip { required property var modelData; text: modelData.t; checked: panel.loaders.indexOf(modelData.k) >= 0; onClicked: panel.toggle("loaders", modelData.k) }
                }
            }

            // release type
            Text { text: qsTr("Release type"); color: Theme.textMuted; font.pixelSize: Theme.fontSm; font.weight: Font.Medium }
            Flow {
                Layout.fillWidth: true; spacing: 6
                Repeater {
                    model: [ { k: "Release", t: qsTr("Release") }, { k: "Beta", t: qsTr("Beta") }, { k: "Alpha", t: qsTr("Alpha") } ]
                    delegate: NiChip { required property var modelData; text: modelData.t; checked: panel.releaseTypes.indexOf(modelData.k) >= 0; onClicked: panel.toggle("releaseTypes", modelData.k) }
                }
            }

            // categories
            Text { visible: panel.browser && panel.browser.categories.length > 0; text: qsTr("Categories"); color: Theme.textMuted; font.pixelSize: Theme.fontSm; font.weight: Font.Medium }
            Flow {
                Layout.fillWidth: true; spacing: 6
                Repeater {
                    model: panel.browser ? panel.browser.categories : []
                    delegate: NiChip { required property var modelData; text: modelData.name; checked: panel.categories.indexOf(modelData.id) >= 0; onClicked: panel.toggle("categories", modelData.id) }
                }
            }

            // Modrinth extras
            PSwitch { visible: panel.modrinth; Layout.fillWidth: true; text: qsTr("Open source only"); checked: panel.openSource; onToggled: { panel.openSource = checked; panel.apply() } }
            Text { visible: panel.modrinth; text: qsTr("Hide projects with"); color: Theme.textMuted; font.pixelSize: Theme.fontSm; font.weight: Font.Medium }
            Flow {
                visible: panel.modrinth
                Layout.fillWidth: true; spacing: 6
                Repeater {
                    model: panel.disclosureOptions
                    delegate: NiChip { required property var modelData; text: modelData.t; checked: panel.excludeDisclosures.indexOf(modelData.k) >= 0; onClicked: panel.toggle("excludeDisclosures", modelData.k) }
                }
            }
            Item { height: Theme.spacing }
        }
    }
}
