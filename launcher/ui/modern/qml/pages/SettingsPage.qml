import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// Global settings: sub-navigation + search on the left, the selected settings page on the right.
// Edits are kept in a draft (SetStore) and written with the sticky "Unsaved changes" bar (or when leaving the page,
// like the classic dialog's Close button). Appearance options apply immediately.
Item {
    id: page
    property string instanceId: ""
    property string initialTab: ""
    property string initialPage: ""
    property var importUrls: []
    function openTab(key) { go(keyFor(key)) }

    readonly property var sections: [
        { key: "launcher",   title: qsTr("Launcher"),            icon: "settings",           file: "SettingsLauncherPage" },
        { key: "appearance", title: qsTr("Appearance"),          icon: "palette",            file: "SettingsAppearancePage" },
        { key: "language",   title: qsTr("Language"),            icon: "languages",          file: "SettingsLanguagePage" },
        { key: "minecraft",  title: qsTr("Minecraft"),           icon: "gamepad-2",          file: "SettingsMinecraftPage" },
        { key: "java",       title: qsTr("Java"),                icon: "coffee",             file: "SettingsJavaPage" },
        { key: "commands",   title: qsTr("Commands & environment"), icon: "terminal",        file: "SettingsCommandsPage" },
        { key: "accounts",   title: qsTr("Accounts"),            icon: "users",              file: "" },
        { key: "api",        title: qsTr("Services & APIs"),     icon: "key-round",          file: "SettingsApiPage" },
        { key: "tools",      title: qsTr("External tools"),      icon: "wrench",             file: "SettingsToolsPage" },
        { key: "proxy",      title: qsTr("Proxy"),               icon: "network",            file: "SettingsProxyPage" }
    ]
    property string current: "launcher"
    property var visited: ({ launcher: true })
    readonly property bool searching: search.text.trim().length > 0

    function keyFor(id) {
        var k = String(id || "").toLowerCase().replace(/-settings$/, "")
        var map = { "apis": "api", "external-tools": "tools", "global": "launcher", "custom-commands": "commands", "environment-variables": "commands",
                    "commands": "commands", "minecraft": "minecraft", "appearance": "appearance", "language": "language", "java": "java",
                    "launcher": "launcher", "java-install": "java", "java-pick": "java", "proxy": "proxy", "accounts": "accounts", "api": "api", "tools": "tools", "general": "launcher" }
        return map[k] || "launcher"
    }
    function go(key) {
        if (key === "accounts") { Qt.callLater(function() { Router.go("Accounts") }); return }
        var v = Object.assign({}, visited); v[key] = true; visited = v
        current = key
    }
    function indexOfKey(key) { for (var i = 0; i < sections.length; i++) if (sections[i].key === key) return i; return 0 }
    function pageItem(key) { var l = loaders.itemAt(indexOfKey(key)); return l ? l.item : null }

    SetStore { id: store }
    Timer { id: debugScroll; property int y: 0; property string key; interval: 400; onTriggered: { var p = page.pageItem(key); if (p) p.contentY = y } }

    Component.onCompleted: {
        Router.section = "Settings"
        SettingsBackend.notifyAboutToOpen()
        if (initialPage.length) go(keyFor(initialPage))
        else if (SettingsBackend.debugPage.length) {
            // debug (screenshots): "<page>[@scrollY]" or "search:<text>"
            var d = SettingsBackend.debugPage
            if (d.indexOf("search:") === 0) { search.text = d.substring(7); return }
            var parts = d.split("@")
            go(keyFor(parts[0]))
            if (parts.length > 1) { debugScroll.y = parseInt(parts[1]); debugScroll.key = keyFor(parts[0]); debugScroll.start() }
        }
    }
    Component.onDestruction: if (store.dirty) { store.save(); Toasts.success(qsTr("Settings saved")) }

    Shortcut { sequences: [StandardKey.Save]; enabled: store.dirty; onActivated: { store.save(); Toasts.success(qsTr("Settings saved")) } }
    Shortcut { sequences: [StandardKey.Find]; onActivated: search.forceActiveFocus() }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ------------------------------------------------------------ sub-navigation
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 248
            color: Theme.bg
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingLg
                anchors.topMargin: Theme.spacingXl
                spacing: 2
                Text { text: qsTr("Settings"); color: Theme.text; font.pixelSize: Theme.fontXl + 2; font.weight: Font.Bold; Layout.leftMargin: 4; Layout.bottomMargin: Theme.spacing }
                SearchField {
                    id: search
                    Layout.fillWidth: true
                    Layout.bottomMargin: Theme.spacing
                    placeholderText: qsTr("Search settings")
                    onTextChanged: if (text.length) { var v = Object.assign({}, page.visited); for (var i = 0; i < page.sections.length; i++) v[page.sections[i].key] = true; page.visited = v }
                    Keys.onReturnPressed: if (results.count > 0) results.itemAtIndex(0).activate()
                    Keys.onDownPressed: if (results.count > 0) { results.forceActiveFocus(); results.currentIndex = 0 }
                }
                Repeater {
                    model: page.sections
                    delegate: AbstractButton {
                        id: navItem
                        required property var modelData
                        readonly property bool active: !page.searching && page.current === modelData.key
                        Layout.fillWidth: true
                        implicitHeight: 36
                        hoverEnabled: true
                        onClicked: { search.text = ""; page.go(modelData.key) }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        background: Rectangle {
                            radius: Theme.radius
                            color: navItem.active ? Theme.accentSoft : navItem.down ? Theme.surfacePressed : navItem.hovered ? Theme.surfaceHover : "transparent"
                            Behavior on color { ColorAnimation { duration: Theme.durFast } }
                        }
                        contentItem: RowLayout {
                            spacing: 10
                            Icon { name: navItem.modelData.icon; size: 16; color: navItem.active ? Theme.accent : Theme.textMuted; Layout.leftMargin: 10 }
                            Text {
                                text: navItem.modelData.title; Layout.fillWidth: true; elide: Text.ElideRight
                                color: navItem.active || navItem.hovered ? Theme.text : Theme.textMuted
                                font.pixelSize: Theme.fontMd; font.weight: navItem.active ? Font.DemiBold : Font.Medium
                            }
                            Icon { visible: navItem.modelData.key === "accounts"; name: "chevron-right"; size: 14; color: Theme.textSubtle; Layout.rightMargin: 8 }
                        }
                    }
                }
                Item { Layout.fillHeight: true }
                PButton {
                    Layout.fillWidth: true
                    variant: "ghost"; size: "sm"; iconName: "folder-open"
                    text: qsTr("Open launcher folder")
                    onClicked: App.openFolder("root")
                }
            }
        }
        Rectangle { Layout.fillHeight: true; width: 1; color: Theme.border }

        // ------------------------------------------------------------ content
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            StackLayout {
                id: stack
                anchors.fill: parent
                visible: !page.searching
                currentIndex: page.indexOfKey(page.current)
                Repeater {
                    id: loaders
                    model: page.sections
                    delegate: Loader {
                        id: ld
                        required property var modelData
                        required property int index
                        readonly property bool want: modelData.file.length > 0 && page.visited[modelData.key] === true
                        asynchronous: false
                        onWantChanged: load()
                        Component.onCompleted: load()
                        function load() {
                            if (want && !item && status !== Loader.Loading)
                                setSource(Qt.resolvedUrl("settings/" + modelData.file + ".qml"), { store: store, pageKey: modelData.key })
                        }
                        opacity: StackLayout.isCurrentItem ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.dur; easing.type: Theme.easing } }
                    }
                }
            }

            // ---------------- search results
            ListView {
                id: results
                anchors.fill: parent
                anchors.topMargin: Theme.spacingXl
                visible: page.searching
                clip: true
                keyNavigationEnabled: true
                ScrollBar.vertical: PScrollBar {}
                readonly property string query: search.text.trim().toLowerCase()
                model: {
                    if (!page.searching) return []
                    var words = query.split(/\s+/)
                    var out = []
                    var rows = store.rows
                    for (var i = 0; i < rows.length; i++) {
                        var r = rows[i]
                        if (!r.item || !r.label) continue
                        var hay = (r.label + " " + r.description + " " + r.keywords + " " + r.pageTitle).toLowerCase()
                        var ok = true
                        for (var w = 0; w < words.length; w++) if (hay.indexOf(words[w]) < 0) { ok = false; break }
                        if (ok) out.push(r)
                    }
                    out.sort(function(a, b) { return page.indexOfKey(a.page) - page.indexOfKey(b.page) })
                    return out
                }
                header: Item {
                    width: results.width; height: 56
                    Text {
                        x: Math.max(Theme.spacingXxl, (results.width - 860) / 2)
                        text: results.count ? qsTr("%1 results for “%2”").arg(results.count).arg(search.text.trim()) : ""
                        color: Theme.textMuted; font.pixelSize: Theme.fontMd
                    }
                }
                section.property: "pageTitle"
                section.delegate: Item {
                    required property string section
                    width: results.width; height: 34
                    Text {
                        x: Math.max(Theme.spacingXxl, (results.width - 860) / 2) + 2; anchors.bottom: parent.bottom; anchors.bottomMargin: 6
                        text: section.toUpperCase(); color: Theme.textSubtle; font.pixelSize: Theme.fontXs; font.weight: Font.Bold; font.letterSpacing: 0.6
                    }
                }
                delegate: AbstractButton {
                    id: res
                    required property var modelData
                    required property int index
                    width: Math.min(results.width - 2 * Theme.spacingXxl, 860)
                    x: Math.round((results.width - width) / 2)
                    height: 58
                    hoverEnabled: true
                    function activate() {
                        var target = modelData
                        search.text = ""
                        page.go(target.page)
                        Qt.callLater(function() { var p = page.pageItem(target.page); if (p) p.reveal(target.item) })
                    }
                    onClicked: activate()
                    Keys.onReturnPressed: activate()
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    background: Rectangle {
                        radius: Theme.radius
                        color: res.hovered || res.ListView.isCurrentItem ? Theme.surfaceHover : Theme.surface
                        border.color: Theme.border
                    }
                    contentItem: RowLayout {
                        spacing: 12
                        ColumnLayout {
                            Layout.fillWidth: true; Layout.leftMargin: 14
                            spacing: 2
                            Text { text: res.modelData.label; color: Theme.text; font.pixelSize: Theme.fontMd; font.weight: Font.Medium; elide: Text.ElideRight; Layout.fillWidth: true }
                            Text { text: res.modelData.description.replace(/<[^>]*>/g, ""); visible: text.length; color: Theme.textMuted; font.pixelSize: Theme.fontSm; elide: Text.ElideRight; Layout.fillWidth: true }
                        }
                        Icon { name: "chevron-right"; size: 15; color: Theme.textSubtle; Layout.rightMargin: 12 }
                    }
                }
                spacing: 6
                EmptyState {
                    anchors.centerIn: parent
                    visible: page.searching && results.count === 0
                    iconName: "search"
                    title: qsTr("No settings found")
                    text: qsTr("Nothing matches “%1”.").arg(search.text.trim())
                }
            }

            // ---------------- sticky unsaved changes bar
            Rectangle {
                id: bar
                readonly property bool shown: store.dirty
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width - 2 * Theme.spacingXl, 620)
                height: 56
                y: shown ? parent.height - height - Theme.spacingXl : parent.height + 12
                opacity: shown ? 1 : 0
                visible: opacity > 0
                Behavior on y { NumberAnimation { duration: Theme.durSlow; easing.type: Theme.easingEmph } }
                Behavior on opacity { NumberAnimation { duration: Theme.dur } }
                radius: Theme.radiusLg
                color: Theme.elevated
                border.color: Theme.borderStrong
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 18; anchors.rightMargin: 10
                    spacing: Theme.spacingSm
                    Rectangle { width: 8; height: 8; radius: 4; color: Theme.warning }
                    Text {
                        Layout.fillWidth: true
                        text: store.dirtyCount === 1 ? qsTr("1 unsaved change") : qsTr("%1 unsaved changes").arg(store.dirtyCount)
                        color: Theme.text; font.pixelSize: Theme.fontMd; font.weight: Font.Medium
                    }
                    PButton { text: qsTr("Discard"); variant: "ghost"; onClicked: store.discard() }
                    PButton { text: qsTr("Save"); variant: "primary"; iconName: "check"; onClicked: { store.save(); Toasts.success(qsTr("Settings saved")) } }
                }
            }
        }
    }
}
