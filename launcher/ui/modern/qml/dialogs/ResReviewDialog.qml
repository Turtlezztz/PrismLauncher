import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// Review the selected downloads (incl. resolved dependencies) before installing (classic ReviewMessageBox).
PDialog {
    id: dlg
    property string plural: qsTr("mods")
    property var items: []
    property var excluded: ({})
    property bool _confirmed: false
    signal confirmed(var excludedKeys)
    signal cancelled()

    title: qsTr("Confirm %1 to download").arg(plural)
    subtitle: qsTr("Only checked items will be installed.")
    iconName: "list-checks"
    maxWidth: 640

    function openWith(list) {
        items = list
        var ex = {}
        for (var i = 0; i < list.length; ++i) if (!list[i].enabled) ex[list[i].key] = true
        excluded = ex
        _confirmed = false
        open()
    }
    function setIncluded(key, on) {
        var ex = Object.assign({}, excluded)
        if (on) delete ex[key]; else ex[key] = true
        excluded = ex
    }
    function includedCount() {
        var n = 0
        for (var i = 0; i < items.length; ++i) if (!excluded[items[i].key]) n++
        return n
    }
    onClosed: if (!_confirmed) cancelled()

    ListView {
        id: list
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, 420)
        clip: true
        spacing: 4
        model: dlg.items
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: PScrollBar {}
        delegate: Rectangle {
            id: item
            required property var modelData
            readonly property bool included: !dlg.excluded[modelData.key]
            width: list.width
            height: rowLay.implicitHeight + 16
            radius: Theme.radius
            color: Theme.surfaceAlt
            opacity: included ? 1 : 0.6
            Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
            RowLayout {
                id: rowLay
                anchors.fill: parent; anchors.margins: 8
                spacing: 10
                PCheckBox { checked: item.included; onToggled: dlg.setIncluded(item.modelData.key, checked) }
                Rectangle {
                    Layout.preferredWidth: 32; Layout.preferredHeight: 32
                    radius: Theme.radiusSm; color: Theme.surface; clip: true
                    Image { anchors.fill: parent; source: item.modelData.logo; sourceSize: Qt.size(64, 64); asynchronous: true; fillMode: Image.PreserveAspectCrop }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    RowLayout {
                        spacing: 6
                        Text { text: item.modelData.name; color: Theme.text; font.pixelSize: Theme.fontMd; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.maximumWidth: 260 }
                        Badge { text: item.modelData.provider; tone: item.modelData.provider === "Modrinth" ? "success" : "warning" }
                        Badge { visible: item.modelData.dependency; text: qsTr("Dependency"); tone: "info" }
                        Badge { visible: item.modelData.versionType.length > 0 && item.modelData.versionType !== "Release"; text: item.modelData.versionType; tone: "warning" }
                    }
                    Text { text: item.modelData.fileName; color: Theme.textSubtle; font.pixelSize: Theme.fontXs; elide: Text.ElideMiddle; Layout.fillWidth: true }
                    Text {
                        visible: item.modelData.requiredBy.length > 0
                        text: qsTr("Required by: %1").arg(item.modelData.requiredBy.join(", "))
                        color: Theme.textMuted; font.pixelSize: Theme.fontXs; wrapMode: Text.Wrap; Layout.fillWidth: true
                    }
                    Text {
                        visible: item.modelData.maybeInstalled
                        text: qsTr("Might already be installed – unchecked by default.")
                        color: Theme.warning; font.pixelSize: Theme.fontXs; Layout.fillWidth: true
                    }
                }
            }
        }
    }

    buttons: [
        PButton { text: qsTr("Back"); onClicked: dlg.close() },
        PButton {
            text: qsTr("Install %1").arg(dlg.includedCount())
            variant: "primary"; iconName: "download"
            enabled: dlg.includedCount() > 0
            onClicked: {
                dlg._confirmed = true
                dlg.close()
                dlg.confirmed(Object.keys(dlg.excluded))
            }
        }
    ]
}
