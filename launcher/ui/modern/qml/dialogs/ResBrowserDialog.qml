import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// Large modal browser to search Modrinth / CurseForge for mods and packs, pick versions, review and install.
// (classic ResourceDownloadDialog + ResourcePage/ModPage + ModFilterWidget)
//   browser.openFor(instanceId, "mod")
//   browser.openChangeVersion(instanceId, "mod", "modrinth", projectId, name)
Popup {
    id: dlg
    property string instanceId: ""
    property string resourceType: "mod"
    property string targetFolder: ""
    property bool changeVersionMode: false
    property string changeVersionName: ""
    property bool filtersOpen: true
    signal installedSomething()
    readonly property alias searchModel: sm

    readonly property var typeInfo: ({
        "mod": { plural: qsTr("mods"), singular: qsTr("mod"), icon: "puzzle" },
        "resourcepack": { plural: qsTr("resource packs"), singular: qsTr("resource pack"), icon: "paintbrush" },
        "texturepack": { plural: qsTr("texture packs"), singular: qsTr("texture pack"), icon: "image" },
        "shaderpack": { plural: qsTr("shader packs"), singular: qsTr("shader pack"), icon: "sparkles" },
        "datapack": { plural: qsTr("data packs"), singular: qsTr("data pack"), icon: "database" }
    })[resourceType] || { plural: qsTr("resources"), singular: qsTr("resource"), icon: "package" }

    function openFor(id, type, folder) {
        changeVersionMode = false
        instanceId = id; resourceType = type; targetFolder = folder || ""
        open()
        searchField.text = ""
        sm.searchText = ""
        Qt.callLater(function() { sm.search(); searchField.forceActiveFocus() })
    }
    function openChangeVersion(id, type, provider, projectId, name) {
        changeVersionMode = true
        changeVersionName = name || ""
        instanceId = id; resourceType = type; targetFolder = ""
        open()
        Qt.callLater(function() { sm.openProject(provider, projectId) })
    }
    function requestClose() {
        if (sm.selectedCount > 0 && !changeVersionMode) {
            Dialogs.confirm({ title: qsTr("Discard selection?"), text: qsTr("You have %n selected item(s). Close the browser anyway?", "", sm.selectedCount),
                              confirmText: qsTr("Close"), danger: true }, function(ok) { if (ok) { sm.clearSelection(); dlg.close() } })
        } else {
            sm.clearSelection()
            dlg.close()
        }
    }
    function reviewAndInstall() {
        if (sm.selectedCount === 0) return
        var h = sm.prepareReview()
        if (h) progress.track(h, { closeOnSuccess: true })
    }

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(1320, parent ? parent.width - 48 : 1000)
    height: parent ? parent.height - 48 : 700
    modal: true
    focus: true
    padding: 0
    closePolicy: Popup.NoAutoClose
    Overlay.modal: Rectangle { color: Theme.overlay }
    enter: Transition { ParallelAnimation {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.dur; easing.type: Theme.easing }
        NumberAnimation { property: "scale"; from: 0.97; to: 1; duration: Theme.durSlow; easing.type: Theme.easingEmph } } }
    exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.durFast } }
    background: Rectangle { color: Theme.bg; radius: Theme.radiusXl; border.color: Theme.borderStrong }

    ResSearchModel {
        id: sm
        instanceId: dlg.instanceId
        resourceType: dlg.resourceType
        targetFolder: dlg.targetFolder
        onNotice: (msg, kind) => Toasts.show(msg, kind)
        onReviewReady: review.openWith(sm.reviewItems())
    }
    Timer { id: searchDebounce; interval: 350; onTriggered: { sm.searchText = searchField.text; sm.search() } }
    Timer { id: filterDebounce; interval: 300; onTriggered: if (dlg.opened && !dlg.changeVersionMode) sm.search() }
    Connections { target: sm; function onFilterChanged() { filterDebounce.restart() } }

    Shortcut { enabled: dlg.opened; sequence: "Escape"; onActivated: dlg.requestClose() }
    Shortcut { enabled: dlg.opened && sm.selectedCount > 0; sequences: ["Ctrl+Return", "Ctrl+Enter"]; onActivated: dlg.reviewAndInstall() }

    contentItem: ColumnLayout {
        spacing: 0

        // ---------------- header
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Theme.spacingXl
            Layout.bottomMargin: Theme.spacingLg
            spacing: Theme.spacing
            Rectangle {
                width: 36; height: 36; radius: 10; color: Theme.accentSoft
                Icon { anchors.centerIn: parent; name: dlg.changeVersionMode ? "history" : dlg.typeInfo.icon; color: Theme.accent; size: 18 }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    text: dlg.changeVersionMode ? qsTr("Change version of “%1”").arg(dlg.changeVersionName) : qsTr("Download %1").arg(dlg.typeInfo.plural)
                    color: Theme.text; font.pixelSize: Theme.fontLg + 2; font.weight: Font.DemiBold
                    elide: Text.ElideRight; Layout.fillWidth: true
                }
                Text {
                    text: ResUtil.instanceName(dlg.instanceId) + (sm.instanceMcVersion.length ? " · Minecraft " + sm.instanceMcVersion : "")
                    color: Theme.textMuted; font.pixelSize: Theme.fontSm
                    elide: Text.ElideRight; Layout.fillWidth: true
                }
            }
            SegmentedControl {
                visible: !dlg.changeVersionMode && sm.providers.length > 1
                options: sm.providers.map(p => ({ value: p, text: p === "modrinth" ? "Modrinth" : "CurseForge" }))
                value: sm.provider
                onActivated: v => sm.provider = v
            }
            IconButton { iconName: "x"; tip: qsTr("Close"); onClicked: dlg.requestClose() }
        }

        // ---------------- body
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: Theme.spacingXl
            Layout.rightMargin: Theme.spacingXl
            spacing: Theme.spacingLg

            // filters
            ResBrowserFilters {
                Layout.fillHeight: true
                Layout.preferredWidth: dlg.filtersOpen && sm.supportsFilters && !dlg.changeVersionMode && dlg.width > 980 ? 230 : 0
                visible: Layout.preferredWidth > 0
                model: sm
            }

            // results
            ColumnLayout {
                visible: !dlg.changeVersionMode
                Layout.fillHeight: true
                Layout.fillWidth: true
                Layout.preferredWidth: 420
                spacing: Theme.spacing

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingSm
                    IconButton {
                        visible: sm.supportsFilters && dlg.width > 980
                        iconName: "filter"; active: dlg.filtersOpen
                        tip: dlg.filtersOpen ? qsTr("Hide filters") : qsTr("Show filters")
                        onClicked: dlg.filtersOpen = !dlg.filtersOpen
                    }
                    SearchField {
                        id: searchField
                        Layout.fillWidth: true
                        placeholderText: qsTr("Search %1…").arg(dlg.typeInfo.plural)
                        onTextEdited: searchDebounce.restart()
                        onAccepted: { searchDebounce.stop(); sm.searchText = text; sm.search() }
                    }
                    PComboBox {
                        id: sortBox
                        Layout.preferredWidth: 150
                        model: sm.sortOptions
                        textRole: "text"; valueRole: "value"
                        onActivated: { sm.sortIndex = currentValue; sm.search() }
                        Connections { target: sm; function onProviderChanged() { sortBox.currentIndex = 0 } }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    visible: sm.activeFilterCount > 0 && !(dlg.filtersOpen && dlg.width > 980)
                    implicitHeight: 28; radius: 14
                    color: Theme.accentSoft
                    Text { anchors.centerIn: parent; text: qsTr("%n filter(s) active", "", sm.activeFilterCount); color: Theme.accent; font.pixelSize: Theme.fontSm }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Theme.radiusLg
                    color: Theme.surface
                    border.color: Theme.border
                    clip: true

                    ListView {
                        id: results
                        anchors.fill: parent
                        anchors.margins: 4
                        model: sm
                        clip: true
                        spacing: 2
                        boundsBehavior: Flickable.StopAtBounds
                        reuseItems: true
                        cacheBuffer: 800
                        ScrollBar.vertical: PScrollBar {}
                        currentIndex: sm.currentRow
                        onContentYChanged: if (contentHeight > 0 && contentY + height > contentHeight - 400 && sm.canFetchMoreResults && !sm.searching) sm.fetchMoreResults()
                        onCountChanged: if (contentHeight <= height && sm.canFetchMoreResults && !sm.searching) Qt.callLater(sm.fetchMoreResults)
                        add: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.dur } }

                        delegate: ResSearchRow {
                            width: results.width
                            current: index === sm.currentRow
                            onClicked: sm.currentRow = index
                            onToggle: sm.toggleRow(index)
                        }
                        footer: Item {
                            width: results.width
                            height: sm.searching && results.count > 0 ? 48 : 0
                            Spinner { anchors.centerIn: parent; visible: parent.height > 0; size: 20 }
                        }
                    }
                    Spinner { anchors.centerIn: parent; size: 28; visible: sm.searching && results.count === 0 }
                    EmptyState {
                        anchors.centerIn: parent
                        width: parent.width - 48
                        visible: !sm.searching && results.count === 0
                        iconName: sm.error.length ? "wifi" : "search"
                        title: sm.error.length ? qsTr("Couldn't load results") : qsTr("Nothing found")
                        text: sm.error.length ? sm.error : qsTr("Try a different search or loosen the filters.")
                        PButton { text: qsTr("Retry"); iconName: "refresh-cw"; visible: sm.error.length > 0; onClicked: sm.search() }
                    }
                }
            }

            // details
            ResProjectDetails {
                Layout.fillHeight: true
                Layout.fillWidth: true
                Layout.preferredWidth: dlg.changeVersionMode ? 900 : 520
                model: sm
                changeVersionMode: dlg.changeVersionMode
                singular: dlg.typeInfo.singular
                onInstallNow: dlg.reviewAndInstall()
            }
        }

        // ---------------- footer
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Theme.spacingXl
            Layout.topMargin: Theme.spacingLg
            spacing: Theme.spacing

            Flow {
                Layout.fillWidth: true
                spacing: 6
                clip: true
                Layout.maximumHeight: 64
                Text {
                    visible: sm.selectedCount === 0
                    text: dlg.changeVersionMode ? qsTr("Pick a version, then install it.") : qsTr("Select %1 to download. Tip: Ctrl+Enter reviews your selection.").arg(dlg.typeInfo.plural)
                    color: Theme.textSubtle; font.pixelSize: Theme.fontSm
                    height: 26; verticalAlignment: Text.AlignVCenter
                }
                Repeater {
                    model: sm.selectedItems
                    delegate: Rectangle {
                        required property var modelData
                        height: 26
                        width: chipRow.implicitWidth + 16
                        radius: 13
                        color: Theme.accentSoft
                        border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35)
                        Row {
                            id: chipRow
                            anchors.centerIn: parent
                            spacing: 4
                            Text { text: modelData.name; color: Theme.accent; font.pixelSize: Theme.fontSm; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
                            IconButton { size: 18; iconSize: 12; iconName: "x"; iconColor: Theme.accent; onClicked: sm.deselect(modelData.key); anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }
            }
            PButton { text: qsTr("Cancel"); onClicked: dlg.requestClose() }
            PButton {
                variant: "primary"
                iconName: "download"
                enabled: sm.selectedCount > 0
                text: sm.selectedCount > 0 ? qsTr("Review & install (%1)").arg(sm.selectedCount) : qsTr("Review & install")
                onClicked: dlg.reviewAndInstall()
            }
        }
    }

    ResTaskDialog { id: progress }
    ResReviewDialog {
        id: review
        plural: dlg.typeInfo.plural
        onConfirmed: (excluded) => {
            var h = sm.install(excluded)
            progress.track(h, { successText: qsTr("Installed %1").arg(dlg.typeInfo.plural) }, function(ok) {
                dlg.installedSomething()
                if (ok) dlg.close()
            })
        }
        onCancelled: sm.cancelReview()
    }
}
