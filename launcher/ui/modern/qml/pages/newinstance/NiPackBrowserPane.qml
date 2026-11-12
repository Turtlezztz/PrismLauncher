import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import QtQuick.Layouts
import PrismModern

// A modpack platform browser: search, sort, filters, infinite scroll, logos, details + version choice.
// Shared by NewInstancePage (list layout) and DiscoverPage (`gridMode: true`, card grid + details drawer).
Item {
    id: pane
    property string platform: ""
    property NIController controller: null
    property bool active: false
    property bool gridMode: false
    property alias browser: b
    property bool showFilters: false
    readonly property bool hasDetails: b.selectedRow >= 0

    NIPackBrowser {
        id: b
        platform: pane.platform
        controller: pane.controller
        active: pane.active
        onError: message => Toasts.error(message)
        onPrivatePackFailed: code => Dialogs.confirm({ title: qsTr("FTB private packs"), text: qsTr("Failed to download pack information for code %1. Should it be removed now?").arg(code), confirmText: qsTr("Remove") },
                                                    function(ok) { if (ok) b.forgetPrivatePackCode(code) })
    }

    FolderDialog {
        id: ftbAppDialog
        title: qsTr("Select FTB app instances directory")
        onAccepted: b.setFtbAppPath(selectedFolder)
    }

    function maybeFetchMore(view) {
        if (b.canLoadMore && view.contentHeight > 0 && view.contentY + view.height > view.contentHeight - 400) b.fetchMore()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacing

        // ---- toolbar ----
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSm
            SearchField {
                id: searchField
                Layout.fillWidth: true
                placeholderText: b.platform === "ftbapp" ? qsTr("Filter installed FTB app packs") : qsTr("Search modpacks")
                text: b.searchTerm
                onTextEdited: b.searchTerm = text
                onAccepted: b.search()
            }
            PComboBox {
                visible: b.sortOptions.length > 0
                implicitWidth: 190
                model: b.sortOptions
                currentIndex: b.sortIndex
                displayText: qsTr("Sort: %1").arg(currentText)
                onActivated: idx => b.sortIndex = idx
            }
            PButton {
                visible: b.supportsFilters
                iconName: "filter"
                text: b.activeFilterCount > 0 ? qsTr("Filters (%1)").arg(b.activeFilterCount) : qsTr("Filters")
                variant: pane.showFilters || b.activeFilterCount > 0 ? "subtle" : "secondary"
                onClicked: pane.showFilters = !pane.showFilters
            }
            IconButton { iconName: "refresh-cw"; tip: qsTr("Refresh"); onClicked: b.refresh() }
        }

        // ---- legacy FTB tabs / FTB app folder ----
        RowLayout {
            Layout.fillWidth: true
            visible: b.platform === "legacyftb"
            spacing: Theme.spacingSm
            PTabBar {
                model: [ { key: "public", text: qsTr("Public") }, { key: "thirdParty", text: qsTr("Third party") }, { key: "private", text: qsTr("Private") } ]
                currentKey: b.legacyTab
                onActivated: key => b.legacyTab = key
            }
            Item { Layout.fillWidth: true }
            PButton {
                visible: b.legacyTab === "private"; size: "sm"; iconName: "plus"; text: qsTr("Add pack code")
                onClicked: Dialogs.prompt({ title: qsTr("Add FTB pack"), text: qsTr("Enter pack code:"), confirmText: qsTr("Add") }, function(v) { if (v && v.length) b.addPrivatePack(v) })
            }
            PButton {
                visible: b.legacyTab === "private"; size: "sm"; iconName: "trash-2"; text: qsTr("Remove"); enabled: b.selectedRow >= 0
                onClicked: {
                    var row = b.selectedRow, name = b.current.name
                    Dialogs.confirm({ title: qsTr("Remove pack"), text: qsTr("Are you sure you want to remove pack %1?").arg(name), confirmText: qsTr("Remove"), danger: true },
                                    function(ok) { if (ok) b.removePrivatePack(row) })
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            visible: b.platform === "ftbapp"
            spacing: Theme.spacingSm
            Icon { name: "folder"; color: Theme.textMuted; size: 15 }
            Text { text: b.ftbAppPath.length ? b.ftbAppPath : qsTr("FTB app instances folder not found"); color: Theme.textMuted; font.pixelSize: Theme.fontSm; elide: Text.ElideMiddle; Layout.fillWidth: true }
            PButton { size: "sm"; text: qsTr("Change folder…"); onClicked: ftbAppDialog.open() }
        }

        PProgressBar {
            Layout.fillWidth: true
            implicitHeight: 3
            indeterminate: true
            opacity: b.loading ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.dur } }
        }

        // ---- content ----
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.spacing

            NiFilterPanel {
                id: filterPanel
                browser: b
                visible: b.supportsFilters && pane.showFilters
                Layout.preferredWidth: 240
                Layout.fillHeight: true
            }

            // list layout (NewInstancePage)
            Rectangle {
                visible: !pane.gridMode
                Layout.preferredWidth: pane.gridMode ? 0 : Math.max(300, (pane.width - (filterPanel.visible ? 252 : 0)) * 0.44)
                Layout.fillHeight: true
                radius: Theme.radiusLg
                color: Theme.surface
                border.color: Theme.border
                clip: true
                ListView {
                    id: list
                    anchors.fill: parent
                    anchors.margins: 6
                    model: pane.gridMode ? null : b.model
                    spacing: 2
                    clip: true
                    reuseItems: true
                    cacheBuffer: 600
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: PScrollBar {}
                    onContentYChanged: pane.maybeFetchMore(list)
                    onCountChanged: Qt.callLater(function() { pane.maybeFetchMore(list) })
                    delegate: NiPackRow {
                        width: list.width
                        selected: index === b.selectedRow
                        onClicked: b.select(index)
                    }
                    footer: Item {
                        width: list.width
                        height: b.loading && list.count > 0 ? 48 : 0
                        Spinner { anchors.centerIn: parent; visible: parent.height > 0; size: 20 }
                    }
                }
                NiBrowserEmpty { anchors.centerIn: parent; browser: b; view: list }
            }

            // grid layout (DiscoverPage)
            Item {
                visible: pane.gridMode
                Layout.fillWidth: true
                Layout.fillHeight: true
                GridView {
                    id: grid
                    anchors.fill: parent
                    anchors.leftMargin: -6; anchors.rightMargin: -6
                    model: pane.gridMode ? b.model : null
                    readonly property int columns: Math.max(1, Math.floor(width / 290))
                    cellWidth: Math.floor(width / columns)
                    cellHeight: 168
                    clip: true
                    reuseItems: true
                    cacheBuffer: 600
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: PScrollBar {}
                    onContentYChanged: pane.maybeFetchMore(grid)
                    onCountChanged: Qt.callLater(function() { pane.maybeFetchMore(grid) })
                    delegate: NiPackCard {
                        width: grid.cellWidth
                        height: grid.cellHeight
                        selected: index === b.selectedRow
                        onClicked: b.select(index)
                    }
                    footer: Item {
                        width: grid.width
                        height: b.loading && grid.count > 0 ? 56 : 0
                        Spinner { anchors.centerIn: parent; visible: parent.height > 0; size: 20 }
                    }
                }
                NiBrowserEmpty { anchors.centerIn: parent; browser: b; view: grid }
            }

            NiPackDetails {
                visible: !pane.gridMode || pane.hasDetails
                browser: b
                Layout.fillWidth: !pane.gridMode
                Layout.preferredWidth: pane.gridMode ? Math.min(460, pane.width * 0.42) : -1
                Layout.fillHeight: true
            }
        }
    }
}
