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
          : browser.searchTerm.length ? qsTr("Nothing matches your search.")
          : browser.platform === "ftbapp" ? qsTr("No FTB app instances found.")
          : browser.platform === "legacyftb" && browser.legacyTab === "private" ? qsTr("Add a private pack with its pack code.")
          : qsTr("Try another search.")
    Spinner { visible: root.browser && root.browser.loading; size: 20 }
}
