import QtQuick
import QtQuick.Layouts
import PrismModern

// Classic MinecraftPage (global MinecraftSettingsWidget): window, console, game time, tweaks, native libraries, performance.
// Custom commands and environment variables live on their own page.
SetPageBase {
    id: page
    title: qsTr("Minecraft")
    subtitle: qsTr("Defaults for every instance. Instances can override these in their own settings.")

    SetSection {
        title: qsTr("Game window"); iconName: "maximize"
        SetRow {
            label: qsTr("Start Minecraft maximized")
            description: page.store && page.store.getBool("LaunchMaximized")
                         ? "<font color='" + Theme.warning + "'>" + qsTr("The maximized option may not be fully supported on all Minecraft versions.") + "</font>"
                         : qsTr("The base game only supports a resolution; maximizing approximates the display size.")
            SetSwitch { key: "LaunchMaximized" }
        }
        SetRow {
            label: qsTr("Window size")
            description: qsTr("Width × height in pixels.")
            keywords: "resolution width height"
            enabled: page.store ? !page.store.getBool("LaunchMaximized") : true
            RowLayout {
                spacing: 8
                SetSpin { key: "MinecraftWinWidth"; from: 1; to: 65536; implicitWidth: 110 }
                Text { text: "×"; color: Theme.textMuted; font.pixelSize: Theme.fontLg }
                SetSpin { key: "MinecraftWinHeight"; from: 1; to: 65536; implicitWidth: 110 }
            }
        }
        SetRow {
            label: qsTr("When the game window opens, hide the launcher")
            keywords: "close launcher"
            SetSwitch { key: "CloseAfterLaunch" }
        }
        SetRow {
            label: qsTr("When the game window closes, quit the launcher")
            keywords: "quit exit"
            SetSwitch { key: "QuitAfterGameStop" }
        }
    }

    SetSection {
        title: qsTr("Console window"); iconName: "terminal"
        SetRow { label: qsTr("When the game is launched, show the console window"); SetSwitch { key: "ShowConsole" } }
        SetRow { label: qsTr("When the game crashes, show the console window"); SetSwitch { key: "ShowConsoleOnError" } }
        SetRow { label: qsTr("When the game quits, hide the console window"); SetSwitch { key: "AutoCloseConsole" } }
    }

    SetSection {
        title: qsTr("Game time"); iconName: "clock"
        SetRow { label: qsTr("Show time spent playing instances"); keywords: "playtime"; SetSwitch { key: "ShowGameTime" } }
        SetRow { label: qsTr("Record time spent playing instances"); keywords: "playtime"; SetSwitch { key: "RecordGameTime" } }
        SetRow { label: qsTr("Show the total time played across instances"); keywords: "playtime total"; SetSwitch { key: "ShowGlobalGameTime" } }
        SetRow { label: qsTr("Always show durations in hours"); keywords: "playtime days"; SetSwitch { key: "ShowGameTimeWithoutDays" } }
    }

    SetSection {
        title: qsTr("Legacy tweaks"); iconName: "history"
        SetRow {
            label: qsTr("Enable online fixes (experimental)")
            description: qsTr("Emulates usages of old online services which are no longer operating. Current fixes include skin and online mode support.")
            keywords: "legacy old skins online"
            SetSwitch { key: "OnlineFixes" }
        }
    }

    SetSection {
        title: qsTr("Native libraries"); iconName: "cpu"
        description: qsTr("Use libraries installed on your system instead of the ones bundled with Minecraft.")
        Repeater {
            model: [
                { use: "UseNativeGLFW", path: "CustomGLFWPath", name: "GLFW", ph: SettingsBackend.defaults.glfw },
                { use: "UseNativeOpenAL", path: "CustomOpenALPath", name: "OpenAL", ph: SettingsBackend.defaults.openal },
                { use: "UseNativeSDL", path: "CustomSDLPath", name: "SDL", ph: SettingsBackend.defaults.sdl }
            ]
            delegate: SetRow {
                id: nativeRow
                required property var modelData
                readonly property bool on: page.store ? page.store.getBool(modelData.use) : false
                stacked: true
                label: qsTr("Use system installation of %1").arg(modelData.name)
                description: qsTr("Optionally point to a specific %1 library file.").arg(modelData.name)
                keywords: "native library " + modelData.name.toLowerCase()
                RowLayout {
                    width: parent.width
                    spacing: 12
                    SetPathField {
                        Layout.fillWidth: true
                        enabled: nativeRow.on
                        key: nativeRow.modelData.path; file: true; showOpen: false
                        placeholder: nativeRow.modelData.ph
                        dialogTitle: qsTr("%1 library file").arg(nativeRow.modelData.name)
                    }
                    SetSwitch { key: nativeRow.modelData.use }
                }
            }
        }
    }

    SetSection {
        visible: SettingsBackend.isLinux
        title: qsTr("Performance"); iconName: "zap"
        SetRow {
            label: qsTr("Enable Feral GameMode")
            description: SettingsBackend.supportsGameMode ? qsTr("Potentially improves gaming performance.") : qsTr("Feral Interactive's GameMode could not be found on your system.")
            enabled: SettingsBackend.supportsGameMode
            SetSwitch { key: "EnableFeralGamemode" }
        }
        SetRow {
            label: qsTr("Enable MangoHud")
            description: SettingsBackend.supportsMangoHud ? qsTr("Advanced performance overlay.") : qsTr("MangoHud could not be found on your system.")
            enabled: SettingsBackend.supportsMangoHud
            SetSwitch { key: "EnableMangoHud" }
        }
        SetRow {
            label: qsTr("Use discrete GPU")
            description: qsTr("Use the discrete GPU instead of the primary GPU.")
            keywords: "graphics card prime"
            SetSwitch { key: "UseDiscreteGpu" }
        }
        SetRow {
            label: qsTr("Use Zink")
            description: qsTr("A Mesa OpenGL driver that implements OpenGL on top of Vulkan. If no suitable Vulkan driver is found, software rendering is used.")
            keywords: "vulkan opengl mesa"
            SetSwitch { key: "UseZink" }
        }
    }

    Text {
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        color: Theme.textSubtle; font.pixelSize: Theme.fontSm
        text: qsTr("Quick play (auto-join a server or world), the account override and mod loader overrides are per-instance settings.")
    }
}
