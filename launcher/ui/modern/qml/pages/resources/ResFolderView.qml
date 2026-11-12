import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import QtQuick.Layouts
import PrismModern

// Generic view for an instance's external-resource folder (mods, resource packs, shader packs, data packs...).
// Used by InstModsTab / InstResourcePacksTab / ... and the per-world data pack dialog.
Item {
    id: root
    property string instanceId
    property string kind: "mods"            // see ResFolderModel.kind
    property string folderPath: ""          // for kind "folderdatapacks"
    property string singular: qsTr("mod")
    property string plural: qsTr("mods")
    property string emptyIcon: "puzzle"
    property var nameFilters: [qsTr("All files (*)")]
    property bool downloadable: true
    property bool updatable: true
    property bool showConfigs: false
    property bool compact: false
    property alias leadingTools: leading.data
    readonly property alias model: fm
    readonly property alias browser: browser
    readonly property alias updater: updater
    readonly property bool isMods: fm.isMods
    readonly property var info: _info
    property var _info: ({})
    // re-evaluated whenever the selection (or its lock state) changes
    readonly property var selInfo: (fm.selectedCount, fm.totalCount, fm.selectionInfo())

    function refreshInfo() {
        _info = (fm.selectedCount === 1 && fm.currentRow >= 0) ? fm.details(fm.currentRow) : ({})
    }

    ResFolderModel {
        id: fm
        instanceId: root.instanceId
        kind: root.kind
        folderPath: root.folderPath
        onSelectionChanged: root.refreshInfo()
        onCountsChanged: infoTimer.restart()
    }
    // coalesce parse/update bursts before rebuilding the details panel
    Timer { id: infoTimer; interval: 150; onTriggered: root.refreshInfo() }

    // ------------------------------------------------------------------ actions
    function capital(s) { return s.length ? s.charAt(0).toUpperCase() + s.slice(1) : s }

    function withLoader(fn) {
        if (!root.isMods || fm.hasModLoader) { fn(); return }
        Dialogs.confirm({
            title: qsTr("Missing mod loader"),
            text: qsTr("You need to install a compatible mod loader before installing mods. Would you like to do so?"),
            confirmText: qsTr("Open Version page")
        }, function(ok) { if (ok) Shell.instanceRequested(root.instanceId, "version") })
    }
    function whenSafe(title, text, fn) {
        if (!fm.instanceRunning) { fn(); return }
        Dialogs.confirm({ title: title, text: text, confirmText: qsTr("Continue anyway"), danger: true }, function(ok) { if (ok) fn() })
    }

    function openDownload() {
        withLoader(function() { browser.openFor(root.instanceId, fm.resourceType, root.kind === "folderdatapacks" ? root.folderPath : "") })
    }
    function addFiles() { fileDialog.open() }

    function removeSelected() {
        var sel = fm.selectionInfo()
        if (sel.count === 0) return
        var doRemove = function() {
            if (root.isMods) {
                var deps = fm.dependentsOfSelection()
                if (deps.length) {
                    choice.ask({
                        title: qsTr("Mods depend on this"),
                        text: qsTr("The mods you are removing are required by %n other mod(s). Do you want to disable them?", "", deps.length),
                        details: deps, icon: "triangle-alert",
                        choices: [ { text: qsTr("Cancel"), value: "cancel" },
                                   { text: qsTr("Keep them enabled"), value: "keep" },
                                   { text: qsTr("Disable them"), value: "disable", variant: "primary" } ]
                    }, function(v) {
                        if (v === null || v === "cancel") return
                        if (v === "disable") fm.disableDependentsOfSelection()
                        fm.removeSelected()
                    })
                    return
                }
            }
            fm.removeSelected()
        }
        var confirmThen = function() {
            if (sel.count > 1 || sel.anyFolder) {
                Dialogs.confirm({
                    title: qsTr("Remove %1?").arg(sel.count > 1 ? qsTr("%1 %2").arg(sel.count).arg(root.plural) : "“" + sel.firstName + "”"),
                    text: sel.count > 1 ? qsTr("They will be moved to the trash when possible, otherwise deleted permanently.")
                                        : qsTr("The folder “%1” will be moved to the trash when possible, otherwise deleted permanently.").arg(sel.firstFile),
                    confirmText: qsTr("Remove"), danger: true
                }, function(ok) { if (ok) doRemove() })
            } else doRemove()
        }
        whenSafe(qsTr("Instance is running"), qsTr("Removing %1 while the game is running may crash it.").arg(root.plural), confirmThen)
    }

    function checkUpdates(includeDeps, releaseTypes) {
        if (fm.metadataDisabled) {
            Dialogs.message({ title: qsTr("Updates unavailable"), text: qsTr("Updates are unavailable when metadata is disabled (Settings → Mods)."), kind: "error" })
            return
        }
        withLoader(function() {
            whenSafe(qsTr("Instance is running"),
                     qsTr("Updating %1 while the game is running may cause duplicates and crashes; old files may not be deleted while in use.").arg(root.plural),
                     function() { updater.begin(fm, includeDeps, releaseTypes || []) })
        })
    }

    function changeVersion() {
        var d = root.info
        if (!d.hasMetadata) return
        if (fm.metadataDisabled) {
            Dialogs.message({ title: qsTr("Unavailable"), text: qsTr("Changing versions is unavailable when metadata is disabled."), kind: "error" })
            return
        }
        whenSafe(qsTr("Instance is running"),
                 qsTr("Changing the version while the game is running may cause duplicates and crashes."),
                 function() { withLoader(function() { browser.openChangeVersion(root.instanceId, fm.resourceType, d.providerKey, d.projectId, d.name) }) })
    }

    function resetMetadata() {
        var sel = fm.selectionInfo()
        if (sel.count === 0) return
        if (sel.count === 1) { fm.deleteSelectedMetadata(); return }
        Dialogs.confirm({ title: qsTr("Remove metadata?"), text: qsTr("You are about to remove the metadata of %1 %2.").arg(sel.count).arg(root.plural),
                          confirmText: qsTr("Remove metadata"), danger: true }, function(ok) { if (ok) fm.deleteSelectedMetadata() })
    }

    function countsText() {
        if (fm.selectedCount > 1) return qsTr("%1 selected").arg(fm.selectedCount)
        if (fm.filterText.length || fm.stateFilter !== "all") return qsTr("%n result(s)", "", fm.count)
        if (fm.totalCount === fm.enabledCount) return qsTr("%1 installed and enabled").arg(fm.totalCount)
        return qsTr("%1 installed, %2 enabled").arg(fm.totalCount).arg(fm.enabledCount)
    }

    Shortcut { enabled: root.visible; sequences: [StandardKey.Find]; onActivated: search.forceActiveFocus() }

    // ------------------------------------------------------------------ layout
    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacing

        // toolbar
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSm
            Row { id: leading; spacing: Theme.spacingSm; visible: children.length > 0; Layout.alignment: Qt.AlignVCenter }
            SearchField {
                id: search
                Layout.fillWidth: true
                Layout.maximumWidth: 340
                Layout.minimumWidth: 140
                placeholderText: qsTr("Search %1").arg(root.plural)
                onTextChanged: fm.filterText = text
            }
            PComboBox {
                id: stateBox
                Layout.preferredWidth: 130
                textRole: "text"; valueRole: "value"
                model: [ { value: "all", text: qsTr("All") }, { value: "enabled", text: qsTr("Enabled") },
                         { value: "disabled", text: qsTr("Disabled") }, { value: "issues", text: qsTr("With issues") },
                         { value: "nometadata", text: qsTr("No metadata") } ]
                onActivated: fm.stateFilter = currentValue
            }
            PComboBox {
                id: sortBox
                Layout.preferredWidth: 160
                textRole: "text"; valueRole: "value"
                model: root.isMods
                    ? [ { value: "name", text: qsTr("Sort: Name") }, { value: "enabled", text: qsTr("Sort: Enabled") },
                        { value: "version", text: qsTr("Sort: Version") }, { value: "date", text: qsTr("Sort: Last modified") },
                        { value: "provider", text: qsTr("Sort: Provider") }, { value: "size", text: qsTr("Sort: Size") },
                        { value: "side", text: qsTr("Sort: Side") }, { value: "loaders", text: qsTr("Sort: Loaders") },
                        { value: "mcversions", text: qsTr("Sort: MC versions") }, { value: "releasetype", text: qsTr("Sort: Release type") },
                        { value: "requires", text: qsTr("Sort: Requires") }, { value: "requiredby", text: qsTr("Sort: Required by") },
                        { value: "filename", text: qsTr("Sort: File name") } ]
                    : [ { value: "name", text: qsTr("Sort: Name") }, { value: "enabled", text: qsTr("Sort: Enabled") },
                        { value: "version", text: qsTr("Sort: Version") }, { value: "date", text: qsTr("Sort: Last modified") },
                        { value: "provider", text: qsTr("Sort: Provider") }, { value: "size", text: qsTr("Sort: Size") },
                        { value: "packformat", text: qsTr("Sort: Pack format") }, { value: "filename", text: qsTr("Sort: File name") } ]
                onActivated: fm.sortKey = currentValue
            }
            IconButton {
                iconName: fm.sortDescending ? "arrow-down" : "arrow-up"
                tip: fm.sortDescending ? qsTr("Descending") : qsTr("Ascending")
                onClicked: fm.sortDescending = !fm.sortDescending
            }
            Item { Layout.fillWidth: true }
            PButton {
                visible: root.downloadable
                text: root.compact ? qsTr("Download") : qsTr("Download %1").arg(root.plural)
                iconName: "download"
                variant: "primary"
                onClicked: root.openDownload()
            }
            PButton {
                visible: root.updatable
                text: qsTr("Updates")
                iconName: "refresh-cw"
                trailingIconName: "chevron-down"
                enabled: fm.totalCount > 0 && !root.selInfo.allLocked
                onClicked: updateMenu.popup(this, 0, height + 4)
                PMenu {
                    id: updateMenu
                    PMenuItem { text: fm.selectedCount ? qsTr("Check selected for updates") : qsTr("Check for updates"); iconName: "refresh-cw"; onTriggered: root.checkUpdates(false) }
                    PMenuItem { visible: root.isMods; text: qsTr("Release versions only"); iconName: "badge-check"; onTriggered: root.checkUpdates(false, ["release"]) }
                    PMenuItem { visible: root.isMods; text: qsTr("Release and beta"); iconName: "flask"; onTriggered: root.checkUpdates(false, ["release", "beta"]) }
                    PMenuItem { visible: root.isMods; text: qsTr("Release, beta and alpha"); iconName: "bug"; onTriggered: root.checkUpdates(false, ["release", "beta", "alpha"]) }
                    PMenuSeparator { visible: root.isMods }
                    PMenuItem { visible: root.isMods && !fm.dependenciesDisabled; text: qsTr("Verify dependencies"); iconName: "list-checks"; onTriggered: root.checkUpdates(true) }
                    PMenuItem { text: qsTr("Reset update metadata"); iconName: "rotate-ccw"; enabled: fm.selectedCount > 0; onTriggered: root.resetMetadata() }
                }
            }
            IconButton { iconName: "plus"; tip: qsTr("Add from file"); onClicked: root.addFiles() }
            IconButton { iconName: "folder-open"; tip: qsTr("Open folder"); onClicked: fm.openFolder() }
            IconButton {
                iconName: "ellipsis-vertical"; tip: qsTr("More")
                onClicked: moreMenu.popup(this, 0, height + 4)
                PMenu {
                    id: moreMenu
                    PMenuItem { visible: root.showConfigs; text: qsTr("View configs"); iconName: "settings"; onTriggered: fm.openConfigs() }
                    PMenuItem { visible: root.isMods; text: qsTr("Export mod list…"); iconName: "file-down"; enabled: fm.totalCount > 0; onTriggered: exportDialog.open() }
                    PMenuItem { text: qsTr("Select all"); iconName: "list-checks"; shortcutText: "Ctrl+A"; onTriggered: fm.selectAll() }
                    PMenuItem { text: qsTr("Refresh"); iconName: "refresh-cw"; onTriggered: fm.refresh() }
                }
            }
        }

        // body
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.spacing

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.radiusLg
                color: Theme.surface
                border.color: Theme.border
                clip: true

                ListView {
                    id: list
                    anchors.fill: parent
                    anchors.margins: 4
                    model: fm
                    clip: true
                    focus: true
                    activeFocusOnTab: true
                    boundsBehavior: Flickable.StopAtBounds
                    reuseItems: true
                    cacheBuffer: 600
                    ScrollBar.vertical: PScrollBar {}
                    keyNavigationEnabled: false

                    Keys.onPressed: (ev) => {
                        if (ev.key === Qt.Key_Delete || (ev.key === Qt.Key_Backspace && (ev.modifiers & Qt.ControlModifier))) { root.removeSelected(); ev.accepted = true }
                        else if (ev.key === Qt.Key_A && (ev.modifiers & Qt.ControlModifier)) { fm.selectAll(); ev.accepted = true }
                        else if (ev.key === Qt.Key_Plus) { root.addFiles(); ev.accepted = true }
                        else if (ev.key === Qt.Key_Space && fm.selectedCount > 0) { fm.setSelectedEnabled(!root.info.enabled); ev.accepted = true }
                        else if (ev.key === Qt.Key_Down || ev.key === Qt.Key_Up) {
                            var r = Math.max(0, Math.min(fm.count - 1, fm.currentRow + (ev.key === Qt.Key_Down ? 1 : -1)))
                            fm.select(r, (ev.modifiers & Qt.ShiftModifier) ? "range" : "single")
                            list.positionViewAtIndex(r, ListView.Contain)
                            ev.accepted = true
                        } else if (ev.key === Qt.Key_Escape) { fm.clearSelection(); ev.accepted = true }
                    }

                    delegate: ResFolderRow {
                        width: list.width
                        showModColumns: root.isMods
                        wide: list.width > 720
                        anyChecked: fm.selectedCount > 1
                        onClicked: (mods) => {
                            list.forceActiveFocus()
                            fm.select(index, (mods & Qt.ShiftModifier) ? "range" : (mods & (Qt.ControlModifier | Qt.MetaModifier)) ? "toggle" : "single")
                        }
                        onCheckToggled: { list.forceActiveFocus(); fm.select(index, "toggle") }
                        onToggleEnabled: fm.toggleEnabled(index)
                        onContextMenu: {
                            if (!selected) fm.select(index, "single")
                            rowMenu.popup()
                        }
                    }
                }

                EmptyState {
                    anchors.centerIn: parent
                    visible: fm.count === 0 && !fm.loading
                    iconName: fm.totalCount > 0 ? "search" : root.emptyIcon
                    title: fm.totalCount > 0 ? qsTr("No matches") : qsTr("No %1 yet").arg(root.plural)
                    text: fm.totalCount > 0 ? qsTr("Nothing matches the current search or filter.")
                                            : root.downloadable ? qsTr("Download %1 from Modrinth or CurseForge, or drop files here.").arg(root.plural)
                                                                : qsTr("Add %1 from files or drop them here.").arg(root.plural)
                    PButton { visible: fm.totalCount === 0 && root.downloadable; text: qsTr("Browse %1").arg(root.plural); iconName: "compass"; variant: "primary"; onClicked: root.openDownload() }
                    PButton { visible: fm.totalCount === 0; text: qsTr("Add from file"); iconName: "plus"; onClicked: root.addFiles() }
                }
                Spinner { anchors.centerIn: parent; visible: fm.count === 0 && fm.loading; size: 28 }
            }

            ResDetailsPanel {
                id: details
                Layout.fillHeight: true
                Layout.preferredWidth: shown ? Math.min(340, root.width * 0.36) : 0
                shown: root.info.name !== undefined && root.width > 640
                info: root.info
                isMods: root.isMods
                singular: root.singular
                onChangeVersion: root.changeVersion()
                onRemove: root.removeSelected()
                onToggleLock: fm.setSelectedUpdateLock(!root.info.updateLocked)
                onToggleEnabled: fm.setSelectedEnabled(!root.info.enabled)
                onCheckUpdates: root.checkUpdates(false)
                updatesAvailable: root.updatable
            }
        }

        // status / selection bar
        Item {
            Layout.fillWidth: true
            implicitHeight: Math.max(countLabel.implicitHeight, selBar.implicitHeight)

            Text {
                id: countLabel
                anchors.verticalCenter: parent.verticalCenter
                text: root.countsText()
                color: Theme.textSubtle
                font.pixelSize: Theme.fontSm
            }
            Row {
                id: selBar
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingXs
                readonly property var sel: root.selInfo
                opacity: fm.selectedCount > 0 ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
                PButton { size: "sm"; variant: "ghost"; text: qsTr("Enable"); iconName: "toggle-left"; onClicked: fm.setSelectedEnabled(true) }
                PButton { size: "sm"; variant: "ghost"; text: qsTr("Disable"); iconName: "eye-off"; onClicked: fm.setSelectedEnabled(false) }
                PButton { size: "sm"; variant: "ghost"; visible: root.updatable && selBar.sel.canLock; text: qsTr("Lock updates"); iconName: "lock"; onClicked: fm.setSelectedUpdateLock(true) }
                PButton { size: "sm"; variant: "ghost"; visible: root.updatable && selBar.sel.canUnlock; text: qsTr("Unlock updates"); iconName: "lock-open"; onClicked: fm.setSelectedUpdateLock(false) }
                PButton { size: "sm"; variant: "ghost"; visible: selBar.sel.anyHomepage; text: qsTr("Homepage"); iconName: "external-link"; onClicked: fm.viewSelectedHomepages() }
                PButton { size: "sm"; variant: "ghost"; text: qsTr("Remove"); iconName: "trash-2"; onClicked: root.removeSelected() }
                IconButton { size: Theme.controlHeightSm; iconName: "x"; tip: qsTr("Clear selection"); onClicked: fm.clearSelection() }
            }
        }
    }

    // ------------------------------------------------------------------ menus & dialogs
    PMenu {
        id: rowMenu
        readonly property var sel: root.selInfo
        PMenuItem { text: qsTr("Enable"); iconName: "toggle-left"; onTriggered: fm.setSelectedEnabled(true) }
        PMenuItem { text: qsTr("Disable"); iconName: "eye-off"; onTriggered: fm.setSelectedEnabled(false) }
        PMenuSeparator {}
        PMenuItem { visible: root.updatable; text: qsTr("Check for updates"); iconName: "refresh-cw"; enabled: !rowMenu.sel.allLocked; onTriggered: root.checkUpdates(false) }
        PMenuItem { visible: root.updatable; text: qsTr("Change version…"); iconName: "history"; enabled: rowMenu.sel.canChangeVersion; onTriggered: root.changeVersion() }
        PMenuItem { visible: root.updatable && rowMenu.sel.canLock; text: qsTr("Lock updates"); iconName: "lock"; onTriggered: fm.setSelectedUpdateLock(true) }
        PMenuItem { visible: root.updatable && rowMenu.sel.canUnlock; text: qsTr("Unlock updates"); iconName: "lock-open"; onTriggered: fm.setSelectedUpdateLock(false) }
        PMenuItem { visible: root.updatable; text: qsTr("Reset update metadata"); iconName: "rotate-ccw"; onTriggered: root.resetMetadata() }
        PMenuItem { text: qsTr("View homepage"); iconName: "external-link"; enabled: rowMenu.sel.anyHomepage; onTriggered: fm.viewSelectedHomepages() }
        PMenuSeparator {}
        PMenuItem { text: qsTr("Remove"); iconName: "trash-2"; danger: true; shortcutText: "Del"; onTriggered: root.removeSelected() }
    }

    FileDialog {
        id: fileDialog
        title: qsTr("Select %1").arg(root.plural)
        fileMode: FileDialog.OpenFiles
        nameFilters: root.nameFilters
        currentFolder: ResUtil.centralModsDir().length ? ResUtil.localUrl(ResUtil.centralModsDir()) : ""
        onAccepted: fm.installFiles(selectedFiles)
    }

    DropArea {
        id: drop
        anchors.fill: parent
        keys: ["text/uri-list"]
        onDropped: (ev) => { if (ev.hasUrls) { fm.installFiles(ev.urls); ev.accept(Qt.CopyAction) } }
        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusLg
            color: Theme.accentSoft
            border.color: Theme.accent
            border.width: 2
            opacity: drop.containsDrag ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
            EmptyState { anchors.centerIn: parent; iconName: "download"; title: qsTr("Drop to add %1").arg(root.plural) }
        }
    }

    ResChoiceDialog { id: choice }
    ResBrowserDialog { id: browser; onInstalledSomething: fm.refresh() }
    ResUpdateDialog { id: updater }
    Loader {
        id: exportLoader
        active: false
        sourceComponent: ResExportModListDialog { folderModel: fm; onClosed: exportLoader.active = false }
        onLoaded: item.open()
    }
    QtObject {
        id: exportDialog
        function open() { exportLoader.active = true }
    }
}
