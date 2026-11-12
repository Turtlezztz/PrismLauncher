import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// Per-instance settings (classic InstanceSettingsPage = MinecraftSettingsWidget + JavaSettingsWidget).
// Every section mirrors one of the classic "override" group boxes; changes apply immediately.
Item {
    id: tab
    property string instanceId
    property InstanceBridge bridge

    InstSettingsBridge { id: s; instanceId: tab.instanceId }
    InstVersionSelectDialog { id: javaPicker }

    // value helpers (re-evaluated whenever any setting changes)
    function v(key) { return s.revision, s.get(key) }
    function b(key) { return s.revision, !!s.get(key) }

    Connections {
        target: s
        function onJavaTestFinished(kind, title, text) { Dialogs.message({ title: title, text: text.replace(/\n/g, "<br>"), kind: kind === "success" ? "info" : kind }) }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentHeight: col.implicitHeight + Theme.spacingXl
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: PScrollBar {}

        ColumnLayout {
            id: col
            width: Math.min(flick.width - 16, 920)
            spacing: Theme.spacingLg

            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: qsTr("Settings here override the global settings for this instance only.")
                    color: Theme.textMuted; font.pixelSize: Theme.fontMd; wrapMode: Text.Wrap
                }
                PButton { size: "sm"; variant: "ghost"; iconName: "external-link"; text: qsTr("Global settings"); onClicked: Router.go("Settings", { initialPage: "minecraft-settings" }) }
            }

            // ================= Java =================
            SectionHeader { title: qsTr("Java"); Layout.topMargin: Theme.spacingSm }

            InstSettingsSection {
                settings: s
                title: qsTr("Java installation"); iconName: "coffee"
                description: qsTr("Which Java runtime starts the game.")
                gateKey: "OverrideJavaLocation"; keys: ["JavaPath", "IgnoreJavaCompatibility"]
                FormRow {
                    label: qsTr("Java executable"); stacked: true
                    RowLayout {
                        width: parent.width
                        spacing: Theme.spacingSm
                        PTextField {
                            id: javaPath
                            Layout.fillWidth: true
                            font.family: Theme.monoFamily
                            text: tab.v("JavaPath") || ""
                            placeholderText: qsTr("Path to java")
                            onEditingFinished: s.set("JavaPath", text)
                        }
                        PButton { text: qsTr("Detect"); iconName: "search"; onClicked: javaPicker.pick({ uid: "java", title: qsTr("Select a Java version"), current: "" }, function(j) { s.set("JavaPath", j.path) }) }
                        PButton { text: qsTr("Browse"); iconName: "folder-open"; onClicked: { var p = s.browseJava(javaPath.text); if (p.length) s.set("JavaPath", p) } }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.spacingSm
                    spacing: Theme.spacingSm
                    PButton {
                        text: s.javaTesting ? qsTr("Testing…") : qsTr("Test settings"); iconName: "zap"; busy: s.javaTesting; enabled: !s.javaTesting
                        onClicked: s.testJava(javaPath.text, tab.v("JvmArgs") || "", minMem.value, maxMem.value, permGen.value)
                    }
                    PButton { visible: s.javaDownloaderEnabled; text: qsTr("Download Java…"); iconName: "download"; onClicked: s.openJavaInstaller() }
                    Item { Layout.fillWidth: true }
                }
                FormRow {
                    label: qsTr("Skip Java compatibility checks")
                    description: qsTr("Don't check whether this instance is compatible with the selected Java version.")
                    PSwitch { checked: tab.b("IgnoreJavaCompatibility"); onToggled: s.set("IgnoreJavaCompatibility", checked) }
                }
            }

            InstSettingsSection {
                settings: s
                title: qsTr("Memory"); iconName: "cpu"
                description: qsTr("Your computer has %1 GiB of memory.").arg((s.totalRamMiB / 1024).toFixed(1))
                gateKey: "OverrideMemory"; keys: ["MinMemAlloc", "MaxMemAlloc", "PermGen", "LowMemWarning"]
                FormRow {
                    label: qsTr("Minimum memory (-Xms)"); description: qsTr("The amount of memory Minecraft is started with.")
                    PSpinBox { id: minMem; from: 8; to: 1048576; stepSize: 128; suffix: "MiB"; value: tab.v("MinMemAlloc") || 512; onValueModified: s.set("MinMemAlloc", value) }
                }
                FormRow {
                    label: qsTr("Maximum memory (-Xmx)"); description: qsTr("The maximum amount of memory Minecraft is allowed to use.")
                    PSpinBox { id: maxMem; from: 8; to: 1048576; stepSize: 128; suffix: "MiB"; value: tab.v("MaxMemAlloc") || 1024; onValueModified: s.set("MaxMemAlloc", value) }
                }
                PSlider {
                    Layout.fillWidth: true
                    from: 512; to: Math.max(1024, s.totalRamMiB); stepSize: 256
                    value: maxMem.value
                    onMoved: { maxMem.value = Math.round(value / 256) * 256; s.set("MaxMemAlloc", maxMem.value) }
                }
                Text {
                    Layout.fillWidth: true
                    readonly property string notice: maxMem.value >= s.totalRamMiB ? qsTr("Your maximum memory allocation exceeds your system memory capacity.")
                                                   : maxMem.value * 10 > s.totalRamMiB * 9 ? qsTr("Your maximum memory allocation is close to your system memory capacity.")
                                                   : maxMem.value < minMem.value ? qsTr("Your maximum memory allocation is below the minimum memory allocation.") : ""
                    visible: notice.length > 0
                    text: notice
                    color: maxMem.value >= s.totalRamMiB ? Theme.danger : Theme.warning
                    font.pixelSize: Theme.fontSm; wrapMode: Text.Wrap
                }
                FormRow {
                    label: qsTr("PermGen size (-XX:PermSize)"); description: qsTr("Memory for loaded Java classes. Only used by Java 7 and older.")
                    PSpinBox { id: permGen; from: 4; to: 1048576; stepSize: 8; suffix: "MiB"; value: tab.v("PermGen") || 128; onValueModified: s.set("PermGen", value) }
                }
                FormRow {
                    label: qsTr("Warn when there is not enough free memory")
                    PSwitch { checked: tab.b("LowMemWarning"); onToggled: s.set("LowMemWarning", checked) }
                }
            }

            InstSettingsSection {
                settings: s
                title: qsTr("Java arguments"); iconName: "terminal"
                description: qsTr("Extra arguments passed to the Java virtual machine.")
                gateKey: "OverrideJavaArgs"; keys: ["JvmArgs"]
                PTextArea {
                    id: jvmArgs
                    Layout.fillWidth: true
                    Layout.preferredHeight: 90
                    monospace: true
                    placeholderText: "-XX:+UseG1GC"
                    Component.onCompleted: text = tab.v("JvmArgs") || ""
                    Connections { target: s; function onInstanceIdChanged() { jvmArgs.text = tab.v("JvmArgs") || "" } }
                    textArea.onActiveFocusChanged: if (!textArea.activeFocus) s.set("JvmArgs", jvmArgs.text.replace(/\n/g, " "))
                }
                Text {
                    Layout.fillWidth: true; Layout.topMargin: 6
                    readonly property string problem: s.jvmArgsProblem(jvmArgs.text)
                    visible: problem.length > 0
                    text: problem; color: Theme.warning; font.pixelSize: Theme.fontSm; wrapMode: Text.Wrap
                }
            }

            // ================= Game =================
            SectionHeader { title: qsTr("Game"); Layout.topMargin: Theme.spacingSm }

            InstSettingsSection {
                settings: s
                title: qsTr("Game window"); iconName: "monitor"
                gateKey: "OverrideWindow"; keys: ["LaunchMaximized", "MinecraftWinWidth", "MinecraftWinHeight", "CloseAfterLaunch", "QuitAfterGameStop"]
                FormRow {
                    label: qsTr("Start Minecraft maximized")
                    description: tab.b("LaunchMaximized") && !s.legacy ? qsTr("The maximized option may not be fully supported on this Minecraft version.")
                                                                      : qsTr("The game only supports a resolution; maximized approximates the display size.")
                    PSwitch { checked: tab.b("LaunchMaximized"); onToggled: s.set("LaunchMaximized", checked) }
                }
                FormRow {
                    label: qsTr("Window size"); enabled: !tab.b("LaunchMaximized")
                    Row {
                        spacing: Theme.spacingSm
                        PSpinBox { width: 120; from: 1; to: 65536; value: tab.v("MinecraftWinWidth") || 854; onValueModified: s.set("MinecraftWinWidth", value) }
                        Text { text: "×"; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                        PSpinBox { width: 120; from: 1; to: 65536; value: tab.v("MinecraftWinHeight") || 480; onValueModified: s.set("MinecraftWinHeight", value) }
                    }
                }
                FormRow {
                    label: qsTr("When the game window opens, hide the launcher")
                    PSwitch { checked: tab.b("CloseAfterLaunch"); onToggled: s.set("CloseAfterLaunch", checked) }
                }
                FormRow {
                    label: qsTr("When the game window closes, quit the launcher")
                    PSwitch { checked: tab.b("QuitAfterGameStop"); onToggled: s.set("QuitAfterGameStop", checked) }
                }
            }

            InstSettingsSection {
                settings: s
                title: qsTr("Console"); iconName: "terminal"
                description: qsTr("When to show this instance's console.")
                gateKey: "OverrideConsole"; keys: ["ShowConsole", "AutoCloseConsole", "ShowConsoleOnError"]
                FormRow { label: qsTr("When the game is launched, show the console"); PSwitch { checked: tab.b("ShowConsole"); onToggled: s.set("ShowConsole", checked) } }
                FormRow { label: qsTr("When the game crashes, show the console"); PSwitch { checked: tab.b("ShowConsoleOnError"); onToggled: s.set("ShowConsoleOnError", checked) } }
                FormRow { label: qsTr("When the game quits, hide the console"); PSwitch { checked: tab.b("AutoCloseConsole"); onToggled: s.set("AutoCloseConsole", checked) } }
            }

            InstSettingsSection {
                settings: s
                title: qsTr("Game time"); iconName: "clock"
                gateKey: "OverrideGameTime"; keys: ["ShowGameTime", "RecordGameTime", "CountGameTime"]
                FormRow { label: qsTr("Show time playing this instance"); PSwitch { checked: tab.b("ShowGameTime"); onToggled: s.set("ShowGameTime", checked) } }
                FormRow { label: qsTr("Record time playing this instance"); PSwitch { checked: tab.b("RecordGameTime"); onToggled: s.set("RecordGameTime", checked) } }
                FormRow { label: qsTr("Count time playing this instance into total time played"); PSwitch { checked: tab.b("CountGameTime"); onToggled: s.set("CountGameTime", checked) } }
            }

            InstSettingsSection {
                settings: s
                title: qsTr("Minecraft version"); iconName: "refresh-cw"
                description: qsTr("Always update this instance to the latest Minecraft version.")
                switchKey: "UseLatestMinecraftVersion"; switchText: qsTr("Auto-update")
                FormRow {
                    label: qsTr("Update to")
                    SegmentedControl {
                        options: [ { value: "release", text: qsTr("Latest release") }, { value: "any", text: qsTr("Any latest version") } ]
                        value: (s.revision, s.get("UseLatestMinecraftVersionType") === "release" ? "release" : "any")
                        onActivated: val => s.set("UseLatestMinecraftVersionType", val)
                    }
                }
            }

            // ================= Launch =================
            SectionHeader { title: qsTr("Launch"); Layout.topMargin: Theme.spacingSm }

            InstSettingsSection {
                id: accountSection
                settings: s
                title: qsTr("Account"); iconName: "user"
                description: qsTr("Always launch this instance with a specific account.")
                switchKey: "UseAccountForInstance"; switchText: qsTr("Use a specific account")
                readonly property var accounts: tab.bridge ? tab.bridge.accounts : []
                onToggled: on => {
                    if (on && accounts.length && !(tab.v("InstanceAccountId") || "").length) s.set("InstanceAccountId", accounts[0].id)
                    if (!on) s.reset("InstanceAccountId")
                }
                FormRow {
                    label: qsTr("Account")
                    PComboBox {
                        width: 260
                        model: accountSection.accounts
                        textRole: "name"; valueRole: "id"
                        displayText: accountSection.accounts.length ? currentText : qsTr("No accounts")
                        currentIndex: { var id = tab.v("InstanceAccountId"); for (var i = 0; i < accountSection.accounts.length; i++) if (accountSection.accounts[i].id === id) return i; return -1 }
                        onActivated: i => s.set("InstanceAccountId", accountSection.accounts[i].id)
                    }
                }
            }

            InstSettingsSection {
                id: joinSection
                settings: s
                title: qsTr("Auto-join"); iconName: "log-in"
                description: qsTr("Join a server or world directly when the game starts.")
                switchKey: "JoinServerOnLaunch"; switchText: qsTr("Enable")
                readonly property bool worldMode: s.revision, (tab.v("JoinWorldOnLaunch") || "").length > 0 && !(tab.v("JoinServerOnLaunchAddress") || "").length && tab.bridge.supportsQuickPlayWorld
                property var worlds: []
                Component.onCompleted: if (tab.bridge && tab.bridge.supportsQuickPlayWorld) worlds = tab.bridge.worlds()
                onToggled: on => { if (!on) { s.reset("JoinServerOnLaunchAddress"); s.reset("JoinWorldOnLaunch") } }
                FormRow {
                    visible: tab.bridge && tab.bridge.supportsQuickPlayWorld
                    label: qsTr("Join")
                    SegmentedControl {
                        id: joinKind
                        property string mode: joinSection.worldMode ? "world" : "server"
                        options: [ { value: "server", text: qsTr("Server") }, { value: "world", text: qsTr("Singleplayer world") } ]
                        value: mode
                        onActivated: val => { mode = val; if (val === "server") s.reset("JoinWorldOnLaunch"); else s.reset("JoinServerOnLaunchAddress") }
                    }
                }
                FormRow {
                    visible: joinKind.mode === "server"
                    label: qsTr("Server address")
                    PTextField {
                        width: 280
                        placeholderText: "play.example.com:25565"
                        text: tab.v("JoinServerOnLaunchAddress") || ""
                        onEditingFinished: { s.set("JoinServerOnLaunchAddress", text.trim()); s.reset("JoinWorldOnLaunch") }
                    }
                }
                FormRow {
                    visible: joinKind.mode === "world"
                    label: qsTr("World")
                    PComboBox {
                        width: 280
                        model: joinSection.worlds
                        displayText: joinSection.worlds.length ? currentText : qsTr("No worlds yet")
                        currentIndex: joinSection.worlds.indexOf(tab.v("JoinWorldOnLaunch") || "")
                        onActivated: i => { s.set("JoinWorldOnLaunch", joinSection.worlds[i]); s.reset("JoinServerOnLaunchAddress") }
                    }
                }
            }

            InstSettingsSection {
                settings: s
                title: qsTr("Custom commands"); iconName: "terminal"
                description: qsTr("Run commands before and after the game. Available variables: $INST_NAME, $INST_ID, $INST_DIR, $INST_MC_DIR, $INST_JAVA, $INST_JAVA_ARGS.")
                gateKey: "OverrideCommands"; keys: ["PreLoadCommand", "PreLaunchCommand", "WrapperCommand", "PostExitCommand"]
                Repeater {
                    model: [
                        { key: "PreLoadCommand", label: qsTr("Pre-load command"), help: qsTr("Runs before the instance's metadata is loaded.") },
                        { key: "PreLaunchCommand", label: qsTr("Pre-launch command"), help: qsTr("Runs before the instance launches.") },
                        { key: "WrapperCommand", label: qsTr("Wrapper command"), help: qsTr("Launch the game through a wrapper program (like 'optirun' on Linux).") },
                        { key: "PostExitCommand", label: qsTr("Post-exit command"), help: qsTr("Runs after the game exits.") }
                    ]
                    delegate: FormRow {
                        required property var modelData
                        label: modelData.label; description: modelData.help; stacked: true
                        PTextField {
                            width: parent.width
                            font.family: Theme.monoFamily
                            text: tab.v(modelData.key) || ""
                            onEditingFinished: s.set(modelData.key, text)
                        }
                    }
                }
            }

            InstSettingsSection {
                id: envSection
                settings: s
                title: qsTr("Environment variables"); iconName: "list"
                description: qsTr("Extra environment variables for the game process.")
                gateKey: "OverrideEnv"; keys: ["Env"]
                property var rows: []
                function load() { rows = s.envVars() }
                function save() { s.setEnvVars(rows) }
                Component.onCompleted: load()
                onToggled: load()
                Repeater {
                    model: envSection.rows.length
                    delegate: RowLayout {
                        required property int index
                        Layout.fillWidth: true
                        Layout.bottomMargin: 6
                        spacing: Theme.spacingSm
                        PTextField {
                            Layout.preferredWidth: 220; font.family: Theme.monoFamily; placeholderText: qsTr("NAME")
                            text: envSection.rows[index].name
                            onEditingFinished: { var r = envSection.rows; r[index].name = text; envSection.rows = r; envSection.save() }
                        }
                        Text { text: "="; color: Theme.textMuted }
                        PTextField {
                            Layout.fillWidth: true; font.family: Theme.monoFamily; placeholderText: qsTr("value")
                            text: envSection.rows[index].value
                            onEditingFinished: { var r = envSection.rows; r[index].value = text; envSection.rows = r; envSection.save() }
                        }
                        IconButton { iconName: "x"; tip: qsTr("Remove"); onClicked: { var r = envSection.rows.slice(); r.splice(index, 1); envSection.rows = r; envSection.save() } }
                    }
                }
                PButton {
                    size: "sm"; iconName: "plus"; text: qsTr("Add variable")
                    onClicked: { var r = envSection.rows.slice(); r.push({ name: "", value: "" }); envSection.rows = r }
                }
            }

            InstSettingsSection {
                id: loaderSection
                settings: s
                title: qsTr("Mod download loaders"); iconName: "hammer"
                description: qsTr("Which mod loaders to look for when downloading mods for this instance.")
                switchKey: "OverrideModDownloadLoaders"; switchText: qsTr("Override")
                property var loaders: []
                Component.onCompleted: loaders = s.modLoaders()
                Connections { target: s; function onRevisionChanged() { loaderSection.loaders = s.modLoaders() } }
                onToggled: on => { s.setModLoaderOverride(on); loaders = s.modLoaders() }
                Flow {
                    Layout.fillWidth: true
                    spacing: Theme.spacing
                    Repeater {
                        model: loaderSection.loaders
                        delegate: PCheckBox {
                            required property var modelData
                            text: modelData.name
                            checked: modelData.checked
                            onToggled: {
                                var keys = []
                                for (var i = 0; i < loaderSection.loaders.length; i++) {
                                    var l = loaderSection.loaders[i]
                                    if (l.key === modelData.key ? checked : l.checked) keys.push(l.key)
                                }
                                s.setModLoaders(keys)
                            }
                        }
                    }
                }
            }

            InstSettingsSection {
                settings: s
                title: qsTr("Global data packs"); iconName: "box"
                description: qsTr("Install data packs across all worlds, if an applicable mod is installed.")
                switchKey: "GlobalDataPacksEnabled"; switchText: qsTr("Enable")
                onToggled: on => { if (!on) s.reset("GlobalDataPacksPath") }
                FormRow {
                    label: qsTr("Folder"); stacked: true
                    RowLayout {
                        width: parent.width
                        PTextField {
                            id: dpPath
                            Layout.fillWidth: true
                            placeholderText: "datapacks"
                            text: tab.v("GlobalDataPacksPath") || ""
                            onEditingFinished: s.set("GlobalDataPacksPath", text.replace(/\\/g, "/"))
                        }
                        PButton { text: qsTr("Browse"); iconName: "folder-open"; onClicked: { var p = s.browseDataPacksFolder(); if (p.length) s.set("GlobalDataPacksPath", p) } }
                    }
                }
            }

            // ================= Advanced =================
            SectionHeader { title: qsTr("Advanced"); Layout.topMargin: Theme.spacingSm }

            InstSettingsSection {
                visible: s.isLinux
                settings: s
                title: qsTr("Performance"); iconName: "zap"
                gateKey: "OverridePerformance"; keys: ["EnableFeralGamemode", "EnableMangoHud", "UseDiscreteGpu", "UseZink"]
                FormRow {
                    label: qsTr("Enable Feral GameMode"); enabled: s.gameModeAvailable
                    description: s.gameModeAvailable ? qsTr("Potentially improves gaming performance.") : qsTr("Feral Interactive's GameMode could not be found on your system.")
                    PSwitch { checked: tab.b("EnableFeralGamemode"); onToggled: s.set("EnableFeralGamemode", checked) }
                }
                FormRow {
                    label: qsTr("Enable MangoHud"); enabled: s.mangoHudAvailable
                    description: s.mangoHudAvailable ? qsTr("Advanced performance overlay.") : qsTr("MangoHud could not be found on your system.")
                    PSwitch { checked: tab.b("EnableMangoHud"); onToggled: s.set("EnableMangoHud", checked) }
                }
                FormRow {
                    label: qsTr("Use discrete GPU"); description: qsTr("Use the discrete GPU instead of the primary GPU.")
                    PSwitch { checked: tab.b("UseDiscreteGpu"); onToggled: s.set("UseDiscreteGpu", checked) }
                }
                FormRow {
                    label: qsTr("Use Zink"); description: qsTr("OpenGL on top of Vulkan via Mesa. If no suitable Vulkan driver is found, software rendering is used.")
                    PSwitch { checked: tab.b("UseZink"); onToggled: s.set("UseZink", checked) }
                }
            }

            InstSettingsSection {
                settings: s
                title: qsTr("Native libraries"); iconName: "wrench"
                description: qsTr("Use libraries installed on your system instead of the bundled ones.")
                gateKey: "OverrideNativeWorkarounds"; keys: ["UseNativeGLFW", "CustomGLFWPath", "UseNativeOpenAL", "CustomOpenALPath", "UseNativeSDL", "CustomSDLPath"]
                Repeater {
                    model: [ { lib: "glfw", name: "GLFW", use: "UseNativeGLFW", path: "CustomGLFWPath" },
                             { lib: "openal", name: "OpenAL", use: "UseNativeOpenAL", path: "CustomOpenALPath" },
                             { lib: "sdl", name: "SDL", use: "UseNativeSDL", path: "CustomSDLPath" } ]
                    delegate: ColumnLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 0
                        FormRow {
                            label: qsTr("Use system installation of %1").arg(modelData.name)
                            PSwitch { checked: tab.b(modelData.use); onToggled: s.set(modelData.use, checked) }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.bottomMargin: 8
                            enabled: tab.b(modelData.use)
                            PTextField {
                                id: libPath
                                Layout.fillWidth: true
                                font.family: Theme.monoFamily
                                placeholderText: s.nativeLibraryPlaceholder(modelData.lib)
                                text: tab.v(modelData.path) || ""
                                onEditingFinished: s.set(modelData.path, text.trim())
                            }
                            PButton { text: qsTr("Browse"); onClicked: { var p = s.browseFile(qsTr("Select %1 library").arg(modelData.name), libPath.text); if (p.length) s.set(modelData.path, p) } }
                        }
                    }
                }
            }

            InstSettingsSection {
                settings: s
                title: qsTr("Legacy tweaks"); iconName: "history"
                gateKey: "OverrideLegacySettings"; keys: ["OnlineFixes"]
                FormRow {
                    label: qsTr("Enable online fixes (experimental)")
                    description: qsTr("Emulates old online services which no longer exist. Currently fixes skins and online mode.")
                    PSwitch { checked: tab.b("OnlineFixes"); onToggled: s.set("OnlineFixes", checked) }
                }
            }

            Item { Layout.preferredHeight: Theme.spacingXl }
        }
    }
}
