import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// Discover: a showcase of modpacks from every platform, sharing NewInstancePage's browser, details and create bar.
PageScaffold {
    id: page
    title: qsTr("Discover")
    subtitle: qsTr("Find your next adventure — browse modpacks from Modrinth, CurseForge and more")
    property string instanceId: ""
    property string initialTab: ""
    property string initialPage: ""
    property var importUrls: []
    property string platform: ""
    function openTab(key) { platform = key }

    NIController { id: ctl }

    readonly property var platforms: [
        { key: "modrinth", text: "Modrinth" },
        { key: "curseforge", text: "CurseForge", flame: true },
        { key: "ftb", text: "Feed The Beast" },
        { key: "atlauncher", text: "ATLauncher" },
        { key: "technic", text: "Technic" }
    ].filter(p => !p.flame || ctl.flameSupported)
    property var visited: ({})

    Component.onCompleted: {
        Router.section = "Discover"
        var start = initialTab.length ? initialTab : initialPage.length ? initialPage : "modrinth"
        platform = platforms.some(p => p.key === start) ? start : "modrinth"
    }
    onPlatformChanged: {
        var v = Object.assign({}, visited)
        v[platform] = true
        visited = v
        ctl.clear()
    }

    headerActions: [
        PButton {
            text: qsTr("All sources"); iconName: "layers"
            onClicked: Router.go("NewInstance", { initialPage: page.platform })
        }
    ]

    headerExtra: [
        PTabBar {
            model: page.platforms.map(p => ({ key: p.key, text: p.text }))
            currentKey: page.platform
            onActivated: key => page.platform = key
        }
    ]

    StackLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        currentIndex: page.platforms.findIndex(p => p.key === page.platform)
        Repeater {
            model: page.platforms
            delegate: Loader {
                id: loader
                required property var modelData
                active: !!page.visited[modelData.key]
                readonly property bool isActive: page.platform === modelData.key
                opacity: isActive ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.dur; easing.type: Theme.easing } }
                sourceComponent: NiPackBrowserPane {
                    platform: loader.modelData.key
                    controller: ctl
                    active: loader.isActive
                    gridMode: true
                }
            }
        }
    }

    NiCreateBar {
        Layout.fillWidth: true
        Layout.bottomMargin: Theme.spacingXl
        controller: ctl
        visible: ctl.hasTask
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.dur } }
    }
}
