import QtQuick
import QtQuick.Layouts
import PrismModern

// Classic APIPage: paste service, metadata/asset servers, user agent and API keys.
SetPageBase {
    id: page
    title: qsTr("Services & APIs")
    subtitle: qsTr("Advanced: third-party services and API keys. Leave fields empty to use the defaults.")

    readonly property var urlRe: /^https?:\/\/.+/
    function urlError(text) { return text.length > 0 && !urlRe.test(text) }
    readonly property int pasteType: store ? store.getInt("PastebinType") : 3
    function pasteDefault() {
        var types = SettingsBackend.pasteTypes
        for (var i = 0; i < types.length; i++) if (types[i].value === pasteType) return types[i].defaultBase
        return ""
    }

    SetSection {
        title: qsTr("Pastebin service"); iconName: "upload"
        description: qsTr("Used when uploading logs.")
        SetRow {
            label: qsTr("Paste service type"); keywords: "paste log upload mclogs hastebin"
            PComboBox {
                id: pasteCombo
                implicitWidth: 220
                property int lastIndex: currentIndex
                model: SettingsBackend.pasteTypes; textRole: "text"; valueRole: "value"
                currentIndex: {
                    var types = SettingsBackend.pasteTypes
                    for (var i = 0; i < types.length; i++) if (types[i].value === page.pasteType) return i
                    return 0
                }
                onActivated: { page.store.set("PastebinType", currentValue); baseNote.visible = page.store.getString("PastebinCustomAPIBase").length > 0 }
            }
        }
        SetRow {
            stacked: true
            label: qsTr("Base URL"); keywords: "paste url"
            ColumnLayout {
                width: parent.width
                SetText { id: pasteBase; key: "PastebinCustomAPIBase"; Layout.fillWidth: true; placeholderText: page.pasteDefault(); error: page.urlError(text); onTextEdited: baseNote.visible = false }
                Text { id: baseNote; visible: false; Layout.fillWidth: true; wrapMode: Text.Wrap; color: Theme.warning; font.pixelSize: Theme.fontSm
                    text: qsTr("Note: you probably want to change or clear the Base URL after changing the paste service type.") }
            }
        }
    }

    SetSection {
        title: qsTr("Servers"); iconName: "server"
        SetRow { stacked: true; label: qsTr("Metadata server"); description: qsTr("You can set this to a third-party metadata server to use patched libraries or other hacks.")
            keywords: "meta url"
            SetText { key: "MetaURLOverride"; width: parent.width; placeholderText: SettingsBackend.defaults.metaUrl; error: page.urlError(text) } }
        SetRow { stacked: true; label: qsTr("Assets server"); description: qsTr("You can set this to another server if you have problems with downloading assets.")
            keywords: "resource url assets"
            SetText { key: "ResourceURLOverride"; width: parent.width; placeholderText: SettingsBackend.defaults.resourceUrl; error: page.urlError(text) } }
        SetRow { stacked: true; label: qsTr("Legacy FML libraries server"); description: qsTr("For problems downloading legacy FML libraries (Minecraft 1.5.2 and earlier).")
            keywords: "forge fml url"
            SetText { key: "LegacyFMLLibsURLOverride"; width: parent.width; placeholderText: SettingsBackend.defaults.fmlLibsUrl; error: page.urlError(text) } }
        SetRow { stacked: true; label: qsTr("User agent"); description: qsTr("The special string $LAUNCHER_VER will be replaced with the version of the launcher.")
            keywords: "user agent http"
            SetText { key: "UserAgentOverride"; width: parent.width; placeholderText: SettingsBackend.defaults.userAgent } }
    }

    SetSection {
        title: qsTr("API keys"); iconName: "key-round"
        SetRow { stacked: true; label: qsTr("Microsoft authentication client ID")
            description: qsTr("You probably don't need to set this if logging in via Microsoft already works.")
            keywords: "msa client id microsoft azure"
            SetText {
                key: "MSAClientIDOverride"; width: parent.width; placeholderText: qsTr("Use default")
                error: text.length > 0 && !/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.test(text)
            } }
        SetRow { stacked: true; label: qsTr("Modrinth token")
            description: qsTr("Only needed to access private data. Read the <a href=\"https://docs.modrinth.com/api/#authentication\">documentation</a> for more information.")
            keywords: "modrinth api key token"
            SetText { key: "ModrinthToken"; width: parent.width; placeholderText: qsTr("Use none"); echoMode: TextInput.PasswordEchoOnEdit } }
        SetRow { stacked: true; label: qsTr("CurseForge API key")
            description: qsTr("You probably don't need to set this if CurseForge already works.")
            keywords: "curseforge flame api key"
            SetText { key: "FlameKeyOverride"; width: parent.width; placeholderText: qsTr("Use default"); echoMode: TextInput.PasswordEchoOnEdit } }
        SetRow { label: qsTr("Enable fallback to Modrinth for blocked mods")
            description: qsTr("Try to find CurseForge mods that can't be downloaded automatically on Modrinth.")
            keywords: "curseforge blocked modrinth"
            SetSwitch { key: "FallbackMRBlockedMods" } }
        SetRow { stacked: true; label: qsTr("Technic client ID")
            description: qsTr("Only needed to access private data.")
            keywords: "technic api key"
            SetText { key: "TechnicClientID"; width: parent.width; placeholderText: qsTr("Use default") } }
    }
}
