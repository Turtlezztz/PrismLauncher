import QtQuick
import QtQuick.Layouts
import PrismModern

// Classic LanguagePage. The modern interface is English only.
SetPageBase {
    id: page
    title: qsTr("Language")
    subtitle: qsTr("Interface language and regional formats.")

    SetSection {
        title: qsTr("Language"); iconName: "languages"
        SetRow {
            label: qsTr("Interface language")
            description: qsTr("The new interface is currently available in English only.")
            keywords: "translation locale english"
            RowLayout {
                spacing: 8
                Badge { text: qsTr("English"); tone: "accent"; iconName: "check" }
                PButton {
                    visible: page.store ? (page.store.getString("Language").length > 0 && page.store.getString("Language") !== "en_US") : false
                    size: "sm"; variant: "ghost"
                    text: qsTr("Reset classic dialogs to English")
                    onClicked: page.store.set("Language", "en_US")
                }
            }
        }
        SetRow {
            label: qsTr("Use system regional standards")
            description: qsTr("Format dates and numbers according to your system settings.")
            keywords: "locale format date number"
            SetSwitch { key: "UseSystemLocale" }
        }
        SetRow {
            label: qsTr("Help translate")
            description: qsTr("Don't see your language or the quality is poor? Translations of the classic interface are maintained by the community.")
            PButton { text: qsTr("Open translation site"); iconName: "external-link"; onClicked: App.openUrl(LauncherInfo.links.translations) }
        }
    }
}
