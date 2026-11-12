import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// Data packs of a single world (classic WorldListPage → "Data Packs" dialog with a DataPackPage).
Popup {
    id: dlg
    property string instanceId
    property string folder: ""
    property string worldName: ""

    function openFor(path, name) { folder = path; worldName = name; open() }

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(1100, parent ? parent.width - 64 : 900)
    height: parent ? parent.height - 64 : 600
    modal: true
    focus: true
    padding: 0
    closePolicy: Popup.CloseOnEscape
    Overlay.modal: Rectangle { color: Theme.overlay }
    enter: Transition { ParallelAnimation {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.dur; easing.type: Theme.easing }
        NumberAnimation { property: "scale"; from: 0.97; to: 1; duration: Theme.durSlow; easing.type: Theme.easingEmph } } }
    exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.durFast } }
    background: Rectangle { color: Theme.bg; radius: Theme.radiusXl; border.color: Theme.borderStrong }

    contentItem: ColumnLayout {
        spacing: Theme.spacingLg
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Theme.spacingXl
            Layout.bottomMargin: 0
            spacing: Theme.spacing
            Rectangle { width: 36; height: 36; radius: 10; color: Theme.accentSoft; Icon { anchors.centerIn: parent; name: "database"; color: Theme.accent; size: 18 } }
            Text { Layout.fillWidth: true; text: qsTr("Data packs for “%1”").arg(dlg.worldName); color: Theme.text; font.pixelSize: Theme.fontLg + 2; font.weight: Font.DemiBold; elide: Text.ElideRight }
            IconButton { iconName: "x"; tip: qsTr("Close"); onClicked: dlg.close() }
        }
        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: Theme.spacingXl
            Layout.rightMargin: Theme.spacingXl
            Layout.bottomMargin: Theme.spacingXl
            active: dlg.opened && dlg.folder.length > 0
            sourceComponent: ResFolderView {
                instanceId: dlg.instanceId
                kind: "folderdatapacks"
                folderPath: dlg.folder
                singular: qsTr("data pack")
                plural: qsTr("data packs")
                emptyIcon: "database"
                compact: true
                nameFilters: [qsTr("Data packs (*.zip)"), qsTr("All files (*)")]
            }
        }
    }
}
