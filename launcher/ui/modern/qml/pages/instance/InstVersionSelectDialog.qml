import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// Version picker for any metadata component (classic VersionSelectDialog), or for detected Java installs (uid "java").
//   dlg.pick({ uid, title, current, parentVersion, extraRecommended, emptyText, javaMajor }, function(version) { ... })
PDialog {
    id: dlg
    property var callback: null
    property bool javaMode: false
    maxWidth: 620
    iconName: javaMode ? "coffee" : "layers"

    function pick(opts, cb) {
        callback = cb
        javaMode = opts.uid === "java"
        title = opts.title || qsTr("Choose version")
        subtitle = opts.subtitle || ""
        versions.uid = opts.uid
        versions.search = ""
        versions.parentVersion = opts.parentVersion || ""
        versions.javaMajor = opts.javaMajor || 0
        versions.currentVersion = opts.current || ""
        versions.extraRecommended = opts.extraRecommended || ""
        versions.types = opts.types || []
        list.emptyText = opts.emptyText || qsTr("No versions are currently available.")
        list.selected = null
        open()
        versions.load(!!opts.forceReload)
    }

    InstVersionListModel { id: versions }

    InstVersionList {
        id: list
        Layout.fillWidth: true
        Layout.preferredHeight: 420
        versions: versions
        javaMode: dlg.javaMode
        showTypeFilter: !dlg.javaMode
        onPicked: okBtn.clicked()
    }

    buttons: [
        PButton { text: qsTr("Cancel"); onClicked: { dlg.callback = null; dlg.close() } },
        PButton {
            id: okBtn
            text: qsTr("Select"); variant: "primary"
            enabled: list.selected !== null && !!list.selected
            onClicked: {
                var cb = dlg.callback; var sel = list.selected
                dlg.callback = null
                dlg.close()
                if (cb && sel) cb(sel)
            }
        }
    ]
}
