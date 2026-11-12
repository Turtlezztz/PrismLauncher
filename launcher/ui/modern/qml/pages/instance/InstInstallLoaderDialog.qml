import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// Install / change a mod loader (classic InstallLoaderDialog), including the "second loader" conflict handling.
//   dlg.openFor(componentsModel, minecraftVersion, "net.fabricmc.fabric-loader")
PDialog {
    id: dlg
    property ComponentListModel components
    property string minecraftVersion: ""
    property string loaderUid: "net.neoforged"
    property var pendingConflicts: []
    property var pendingVersion: null
    title: qsTr("Install mod loader")
    subtitle: minecraftVersion.length ? qsTr("For Minecraft %1").arg(minecraftVersion) : ""
    iconName: "hammer"
    maxWidth: 640

    readonly property var loaders: [
        { value: "net.neoforged", text: "NeoForge", oldest: "" },
        { value: "net.minecraftforge", text: "Forge", oldest: "" },
        { value: "net.fabricmc.fabric-loader", text: "Fabric", oldest: "1.14" },
        { value: "org.quiltmc.quilt-loader", text: "Quilt", oldest: "1.14" },
        { value: "com.mumfrey.liteloader", text: "LiteLoader", oldest: "" }
    ]
    function loaderInfo(uid) { for (var i = 0; i < loaders.length; i++) if (loaders[i].value === uid) return loaders[i]; return loaders[0] }

    function openFor(model, mc, uid) {
        components = model
        minecraftVersion = mc
        open()
        select(uid && uid.length ? uid : "net.neoforged")
    }
    function select(uid) {
        loaderUid = uid
        var info = loaderInfo(uid)
        versions.uid = uid
        versions.search = ""
        versions.parentVersion = minecraftVersion
        versions.blockAll = info.oldest.length > 0 && minecraftVersion.length > 0 && versions.versionLess(minecraftVersion, info.oldest)
        var comp = components ? components.get(uid) : ({})
        versions.currentVersion = comp && comp.version ? comp.version : ""
        list.selected = null
        versions.load(false)
        if (!versions.loading) Qt.callLater(list.preselect)
    }

    function install() {
        if (!list.selected) return
        pendingVersion = list.selected.descriptor
        pendingConflicts = components.loaderConflicts(loaderUid)
        nextConflict()
    }
    function nextConflict() {
        if (pendingConflicts.length === 0) {
            components.installLoader(loaderUid, pendingVersion)
            Toasts.success(qsTr("Installing %1 %2").arg(loaderInfo(loaderUid).text).arg(pendingVersion))
            close()
            return
        }
        conflict.item = pendingConflicts[0]
        conflict.open()
    }

    InstVersionListModel { id: versions }

    RowLayout {
        Layout.fillWidth: true
        SegmentedControl {
            options: dlg.loaders.map(function(l) { return { value: l.value, text: l.text } })
            value: dlg.loaderUid
            onActivated: v => dlg.select(v)
        }
        Item { Layout.fillWidth: true }
    }

    InstVersionList {
        id: list
        Layout.fillWidth: true
        Layout.preferredHeight: 380
        versions: versions
        showTypeFilter: false
        emptyText: versions.blockAll ? qsTr("%1 is not available for Minecraft %2.").arg(dlg.loaderInfo(dlg.loaderUid).text).arg(dlg.minecraftVersion)
                                     : qsTr("No versions are currently available for Minecraft %1.").arg(dlg.minecraftVersion)
        onPicked: dlg.install()
    }

    buttons: [
        PButton { text: qsTr("Cancel"); onClicked: dlg.close() },
        PButton { text: qsTr("Install"); variant: "primary"; iconName: "download"; enabled: !!list.selected; onClicked: dlg.install() }
    ]

    // conflict with an already installed loader
    PDialog {
        id: conflict
        property var item: ({})
        title: qsTr("Installing a second loader")
        iconName: "triangle-alert"
        maxWidth: 500
        closePolicy: Popup.CloseOnEscape
        onClosed: if (dlg.pendingVersion && conflict.choice === "") dlg.pendingConflicts = []
        property string choice: ""
        onAboutToShow: choice = ""
        function choose(c) {
            choice = c
            if (c === "cancel") { dlg.pendingConflicts = []; close(); return }
            if (c !== "keep") dlg.components.resolveConflict(item.uid, c)
            close()
            var rest = dlg.pendingConflicts.slice(1)
            dlg.pendingConflicts = rest
            Qt.callLater(dlg.nextConflict)
        }
        Text {
            Layout.fillWidth: true; wrapMode: Text.Wrap; color: Theme.textMuted; font.pixelSize: Theme.fontMd
            text: qsTr("%1 is known to conflict with %2, which is enabled on this instance. Having both enabled at the same time will likely break the instance.\n\nWhat would you like to do with %2?")
                    .arg(dlg.loaderInfo(dlg.loaderUid).text + " " + (dlg.pendingVersion || ""))
                    .arg((conflict.item.name || "") + " " + (conflict.item.version || ""))
        }
        buttons: [
            PButton { text: qsTr("Cancel"); onClicked: conflict.choose("cancel") },
            PButton { text: qsTr("Keep it"); onClicked: conflict.choose("keep") },
            PButton { visible: !!conflict.item.canDisable; text: qsTr("Disable it"); onClicked: conflict.choose("disable") },
            PButton { visible: !!conflict.item.canRemove; text: qsTr("Uninstall it"); variant: "danger"; onClicked: conflict.choose("remove") }
        ]
    }
}
