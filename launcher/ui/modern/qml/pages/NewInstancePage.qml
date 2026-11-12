import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// New instance (classic NewInstanceDialog): sources on the left, the chosen source in the middle, the create bar below.
// Router props: initialPage / initialTab = source key, importUrls = URLs from drag & drop / the OS, searchTerm.
PageScaffold {
    id: page
    title: qsTr("New instance")
    subtitle: qsTr("Start fresh, import a pack or install one from a modpack platform")
    property string instanceId: ""
    property string initialTab: ""
    property string initialPage: ""
    property var importUrls: []
    property string searchTerm: ""
    property string current: ""
    function openTab(key) { select(key) }

    Component.onCompleted: {
        Router.section = "NewInstance"
        var start = initialPage.length ? initialPage : initialTab.length ? initialTab : (App.setting("ModernNewInstanceSource") || "vanilla")
        if (!sourceKeys().includes(start)) start = "vanilla"
        select(start)
        if (searchTerm.length) Qt.callLater(function() { var p = paneFor(current); if (p && p.browser) { p.browser.searchTerm = searchTerm; p.browser.search() } })
        if (importUrls && importUrls.length) Qt.callLater(function() { urlHandler.processUrls(page.importUrls) })
    }

    NIController { id: ctl }

    readonly property var sources: [
        { key: "vanilla", text: qsTr("Custom"), hint: qsTr("Vanilla or modded"), section: qsTr("Create") },
        { key: "import", text: qsTr("Import"), hint: qsTr("Zip, mrpack or link") },
        { key: "modrinth", text: "Modrinth", hint: qsTr("Modpacks"), section: qsTr("Modpacks") },
        { key: "curseforge", text: "CurseForge", hint: qsTr("Modpacks"), flame: true },
        { key: "ftb", text: "Feed The Beast", hint: qsTr("Modpacks") },
        { key: "atlauncher", text: "ATLauncher", hint: qsTr("Modpacks") },
        { key: "technic", text: "Technic", hint: qsTr("Modpacks") },
        { key: "legacyftb", text: qsTr("FTB Legacy"), hint: qsTr("Classic FTB packs"), section: qsTr("More") },
        { key: "ftbapp", text: qsTr("FTB App"), hint: qsTr("Import installed packs") }
    ].filter(s => !s.flame || ctl.flameSupported)
    function sourceKeys() { return sources.map(s => s.key) }

    function select(key) {
        if (key === current) return
        // keep the search text when moving between modpack platforms (classic behaviour)
        var prev = paneFor(current)
        var term = prev && prev.browser ? prev.browser.searchTerm : ""
        current = key
        var idx = sourceKeys().indexOf(key)
        visited[idx] = true
        visitedChanged()
        App.setSetting("ModernNewInstanceSource", key)
        if (term.length && !term.startsWith("#")) Qt.callLater(function() { var p = paneFor(key); if (p && p.browser && !p.browser.searchTerm.length) p.browser.searchTerm = term })
    }
    property var visited: ({})
    function paneFor(key) {
        var idx = sourceKeys().indexOf(key)
        if (idx < 0) return null
        var l = stackRep.itemAt(idx)
        return l ? l.item : null
    }

    // ---- URL handling (drag & drop, curseforge:// / modrinth:// / prismlauncher:// links) ----
    NIImportSource {
        id: urlHandler
        onPackRequested: (source, extra) => {
            page.select("import")
            Qt.callLater(function() {
                var p = page.paneFor("import")
                if (!p) return
                p.source.setExtraInfo(extra)
                p.source.text = source
            })
        }
        onModrinthPackRequested: packId => {
            page.select("modrinth")
            Qt.callLater(function() { var p = page.paneFor("modrinth"); if (p) { p.browser.searchTerm = "#" + packId; p.browser.search() } })
        }
        onResourceRequested: (path, type, typeName) => {
            var comp = Qt.createComponent(Qt.resolvedUrl("../dialogs/NiImportResourceDialog.qml"))
            var dlg = comp.createObject(page, { filePath: path, typeName: typeName })
            dlg.chosen.connect(function(id) {
                var err = urlHandler.installResource(path, type, id)
                if (err.length) Toasts.error(err)
                else if (id.length) Toasts.success(qsTr("Added %1 to “%2”").arg(typeName.toLowerCase()).arg(App.instances.get(id).name))
            })
            dlg.closed.connect(function() { dlg.destroy(500) })
            dlg.open()
        }
        onDownloadConfirmationRequested: (url, host) => {
            Dialogs.confirm({ title: qsTr("Install modpack"), text: qsTr("Do you want to download and import a modpack from <b>%1</b>?<br><br>%2").arg(host).arg(url), confirmText: qsTr("Download") },
                            function(ok) { urlHandler.confirmDownload(url, ok) })
        }
        onTaskStarted: task => NiInteraction.track(task, {})
        onError: message => Dialogs.message({ title: qsTr("Can't import"), text: message, kind: "error" })
    }

    DropArea {
        // dropping anywhere on the page imports, like the classic main window
        parent: page
        anchors.fill: parent
        z: -1
        onDropped: ev => { if (ev.hasUrls) urlHandler.processUrls(ev.urls) }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Theme.spacingLg

        // ---- sources ----
        ColumnLayout {
            Layout.preferredWidth: 200
            Layout.maximumWidth: 200
            Layout.fillWidth: false
            Layout.fillHeight: true
            spacing: 2
            Repeater {
                model: page.sources
                delegate: ColumnLayout {
                    id: srcItem
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        visible: !!srcItem.modelData.section
                        text: (srcItem.modelData.section || "").toUpperCase()
                        color: Theme.textSubtle; font.pixelSize: Theme.fontXs; font.weight: Font.DemiBold; font.letterSpacing: 0.8
                        Layout.topMargin: srcItem.index === 0 ? 0 : Theme.spacing
                        Layout.bottomMargin: 2
                        Layout.leftMargin: 10
                    }
                    AbstractButton {
                        id: btn
                        readonly property bool isCurrent: page.current === srcItem.modelData.key
                        Layout.fillWidth: true
                        implicitHeight: 46
                        hoverEnabled: true
                        onClicked: page.select(srcItem.modelData.key)
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        background: Rectangle {
                            radius: Theme.radius
                            color: btn.isCurrent ? Theme.accentSoft : btn.hovered ? Theme.surfaceHover : "transparent"
                            Behavior on color { ColorAnimation { duration: Theme.durFast } }
                        }
                        contentItem: RowLayout {
                            spacing: 10
                            NiPlatformBadge { platform: srcItem.modelData.key; size: 30; Layout.leftMargin: 8 }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Text { text: srcItem.modelData.text; color: btn.isCurrent ? Theme.text : Theme.textMuted; font.pixelSize: Theme.fontMd; font.weight: btn.isCurrent ? Font.DemiBold : Font.Medium; elide: Text.ElideRight; Layout.fillWidth: true }
                                Text { text: srcItem.modelData.hint; color: Theme.textSubtle; font.pixelSize: Theme.fontXs + 1; elide: Text.ElideRight; Layout.fillWidth: true }
                            }
                        }
                    }
                }
            }
            Item { Layout.fillHeight: true }
        }

        Rectangle { Layout.fillHeight: true; width: 1; color: Theme.border }

        // ---- current source ----
        StackLayout {
            id: stack
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: page.sourceKeys().indexOf(page.current)
            Repeater {
                id: stackRep
                model: page.sources
                delegate: Loader {
                    id: loader
                    required property var modelData
                    required property int index
                    active: !!page.visited[index]
                    asynchronous: false
                    opacity: StackLayout.isCurrentItem ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.dur; easing.type: Theme.easing } }
                    sourceComponent: modelData.key === "vanilla" ? vanillaComp : modelData.key === "import" ? importComp : browserComp
                    readonly property bool isActive: page.current === modelData.key
                    Component { id: vanillaComp; NiVanillaPane { controller: ctl; active: loader.isActive } }
                    Component { id: importComp; NiImportPane { controller: ctl; active: loader.isActive } }
                    Component { id: browserComp; NiPackBrowserPane { controller: ctl; platform: loader.modelData.key; active: loader.isActive } }
                }
            }
        }
    }

    NiCreateBar {
        Layout.fillWidth: true
        Layout.bottomMargin: Theme.spacingXl
        controller: ctl
    }
}
