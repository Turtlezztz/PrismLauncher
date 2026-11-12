import QtQuick
import PrismModern

// Empty / loading / error state for a modpack results view.
EmptyState {
    id: root
    property NIPackBrowser browser: null
    property Item view: null
    readonly property bool empty: view ? view.count === 0 : true
    visible: browser !== null && empty
    width: Math.min(340, parent ? parent.width - 32 : 340)
    iconName: browser && browser.errorText.length ? "circle-alert" : browser && browser.loading ? "download" : "search"
    title: !browser ? "" : browser.loading ? qsTr("Loading modpacks…") : browser.errorText.length ? qsTr("Couldn't load modpacks") : browser.searchTerm.length ? qsTr("No results") : qsTr("Nothing here yet")
    text: !browser || browser.loading ? "" : browser.errorText.length ? browser.errorText
          : browser.searchTerm.length ? qsTr("No modpack matches “%1”.").arg(browser.searchTerm)
          : browser.platform === "ftbapp" ? qsTr("No FTB app instances were found. Choose the folder where the FTB app keeps its instances.")
          : browser.platform === "legacyftb" && browser.legacyTab === "private" ? qsTr("Add a private pack with its pack code.")
          : qsTr("Try another search.")
    Spinner { visible: root.browser && root.browser.loading; size: 20 }
}
