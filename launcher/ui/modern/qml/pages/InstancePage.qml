import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// Per-instance view (classic InstanceWindow + instance pages).
//   Router.push("Instance", { instanceId: id, initialTab: "version" })
// Tab keys follow the classic page ids: console (log), version, mods, resourcepacks, texturepacks, shaderpacks,
// datapacks, worlds, servers, screenshots, notes, settings, gameoptions, logs, managed_pack.
Item {
    id: page
    property string instanceId: ""
    property string initialTab: ""
    property string initialPage: ""
    property var importUrls: []
    property string currentTab: ""
    property var visited: ({})

    // classic ids that map to another tab
    readonly property var aliases: ({ log: "console", coremods: "mods", nilmods: "mods", "instance-settings": "settings", modpack: "managed_pack" })

    function openTab(key) {
        key = aliases[key] || key
        for (var i = 0; i < tabs.length; i++) {
            if (tabs[i].key === key) {
                var v = Object.assign({}, visited); v[key] = true; visited = v
                currentTab = key
                return
            }
        }
    }

    InstanceBridge { id: bridge; instanceId: page.instanceId }
    ManagedPackBridge { id: packInfo; instanceId: page.instanceId }

    Component.onCompleted: {
        if (!instanceId.length) {
            // debug: PRISM_MODERN_PAGE=Instance PRISM_MODERN_INSTANCE=<id> PRISM_MODERN_TAB=<key>
            instanceId = bridge.environment("PRISM_MODERN_INSTANCE")
            if (!initialTab.length) initialTab = bridge.environment("PRISM_MODERN_TAB")
        }
        Router.section = "Library"
        openTab(initialTab.length ? initialTab : (bridge.running || bridge.launching || bridge.hasLog ? "console" : "version"))
    }

    // the instance was deleted (or replaced by a modpack update)
    Connections {
        target: bridge
        function onGone() { goneCheck.restart() }
    }
    Timer {
        id: goneCheck; interval: 400
        onTriggered: {
            if (App.instanceExists(page.instanceId)) { bridge.instanceId = ""; bridge.instanceId = page.instanceId }
            else if (page.StackView.view) Router.back()
        }
    }

    readonly property var tabs: {
        var t = [
            { key: "console", text: qsTr("Console"), icon: "terminal", file: "InstConsoleTab.qml", own: true },
            { key: "version", text: qsTr("Version"), icon: "layers", file: "InstVersionTab.qml", own: true },
        ]
        if (packInfo.supported)
            t.push({ key: "managed_pack", text: qsTr("Modpack"), icon: "package", file: "InstManagedPackTab.qml", own: true })
        t.push({ key: "mods", text: qsTr("Mods"), icon: "puzzle", file: "InstModsTab.qml" })
        if (bridge.usesTexturePacks)
            t.push({ key: "texturepacks", text: qsTr("Texture packs"), icon: "image", file: "InstTexturePacksTab.qml" })
        else
            t.push({ key: "resourcepacks", text: qsTr("Resource packs"), icon: "image", file: "InstResourcePacksTab.qml" })
        t.push({ key: "shaderpacks", text: qsTr("Shaders"), icon: "sparkles", file: "InstShaderPacksTab.qml" },
               { key: "datapacks", text: qsTr("Data packs"), icon: "box", file: "InstDataPacksTab.qml" },
               { key: "worlds", text: qsTr("Worlds"), icon: "map", file: "InstWorldsTab.qml" },
               { key: "servers", text: qsTr("Servers"), icon: "server", file: "InstServersTab.qml" },
               { key: "screenshots", text: qsTr("Screenshots"), icon: "camera", file: "InstScreenshotsTab.qml" },
               { key: "notes", text: qsTr("Notes"), icon: "sticky-note", file: "InstNotesTab.qml", own: true },
               { key: "settings", text: qsTr("Settings"), icon: "settings", file: "InstSettingsTab.qml", own: true },
               { key: "gameoptions", text: qsTr("Game options"), icon: "sliders-horizontal", file: "InstGameOptionsTab.qml", own: true },
               { key: "logs", text: qsTr("Other logs"), icon: "file-text", file: "InstOtherLogsTab.qml", own: true })
        return t
    }

    Shortcut { sequence: "Ctrl+K"; enabled: bridge.running; onActivated: bridge.kill() }
    Shortcut { sequence: "F2"; onActivated: header.rename() }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        InstHeader {
            id: header
            Layout.fillWidth: true
            Layout.leftMargin: Theme.spacingXxl
            Layout.rightMargin: Theme.spacingXxl
            Layout.topMargin: Theme.spacingXl
            bridge: bridge
            showBack: page.StackView.view ? page.StackView.index > 0 : false
            onOpenTabRequested: (key) => page.openTab(key)
        }

        // tabs (scroll horizontally when the window is narrow)
        Item {
            Layout.fillWidth: true
            Layout.topMargin: Theme.spacingLg
            Layout.leftMargin: Theme.spacingXxl - 4
            Layout.rightMargin: Theme.spacingXxl - 4
            implicitHeight: 40
            Flickable {
                id: tabFlick
                anchors.fill: parent
                contentWidth: tabBar.implicitWidth + 8
                contentHeight: height
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.HorizontalFlick
                interactive: contentWidth > width
                Rectangle {
                    x: 0; y: 0
                    width: tabBar.implicitWidth + 8; height: 40
                    radius: Theme.radius + 2
                    color: Theme.surfaceAlt
                    border.color: Theme.border
                }
                PTabBar {
                    id: tabBar
                    x: 4; y: 2
                    height: 36
                    model: page.tabs
                    currentKey: page.currentTab
                    onActivated: (key) => page.openTab(key)
                }
                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse
                    onWheel: (ev) => { tabFlick.flick(ev.angleDelta.y * 6, 0) }
                }
            }
            // fade hint on the right edge when tabs overflow
            Rectangle {
                anchors.right: parent.right; width: 32; height: parent.height
                visible: tabFlick.contentWidth > tabFlick.width && !tabFlick.atXEnd
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 1; color: Theme.bg }
                }
            }
        }

        // tab content: each tab is created on first visit and kept alive afterwards
        Item {
            id: content
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: Theme.spacingLg
            Layout.leftMargin: Theme.spacingXxl
            Layout.rightMargin: Theme.spacingXxl
            Layout.bottomMargin: Theme.spacingXl

            Repeater {
                model: page.tabs
                delegate: Item {
                    id: slot
                    required property var modelData
                    readonly property bool current: page.currentTab === modelData.key
                    readonly property url url: Qt.resolvedUrl("instance/" + modelData.file)
                    readonly property bool exists: bridge.resourceExists(url)
                    width: content.width
                    height: content.height
                    visible: opacity > 0
                    opacity: current ? 1 : 0
                    y: current ? 0 : 8
                    Behavior on opacity { NumberAnimation { duration: Theme.dur; easing.type: Theme.easing } }
                    Behavior on y { NumberAnimation { duration: Theme.durSlow; easing.type: Theme.easingEmph } }

                    Loader {
                        id: loader
                        anchors.fill: parent
                        active: slot.exists && !!page.visited[slot.modelData.key] && page.instanceId.length > 0
                        asynchronous: false
                        Component.onCompleted: load()
                        onActiveChanged: load()
                        function load() {
                            if (!active || status !== Loader.Null) return
                            var props = { instanceId: page.instanceId }
                            if (slot.modelData.own) props.bridge = bridge
                            setSource(slot.url, props)
                        }
                    }
                    EmptyState {
                        anchors.centerIn: parent
                        visible: !slot.exists
                        iconName: slot.modelData.icon
                        title: slot.modelData.text
                        text: qsTr("This section is not available yet.")
                    }
                }
            }
        }
    }
}
