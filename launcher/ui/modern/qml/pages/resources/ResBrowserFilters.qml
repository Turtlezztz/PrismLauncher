import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// Filter sidebar of the mod browser (classic ModFilterWidget).
Item {
    id: root
    property var model: null    // ResSearchModel
    clip: true

    function toggleIn(list, value) {
        var out = list.slice()
        var i = out.indexOf(value)
        if (i >= 0) out.splice(i, 1); else out.push(value)
        return out
    }

    component GroupTitle: Text {
        color: Theme.textSubtle
        font.pixelSize: Theme.fontXs
        font.weight: Font.DemiBold
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 0.6
        Layout.topMargin: Theme.spacingSm
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentHeight: col.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        ScrollBar.vertical: PScrollBar {}

        ColumnLayout {
            id: col
            width: flick.width - 8
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                Text { text: qsTr("Filters"); color: Theme.text; font.pixelSize: Theme.fontLg; font.weight: Font.DemiBold; Layout.fillWidth: true }
                PButton { size: "sm"; variant: "ghost"; text: qsTr("Reset"); visible: root.model.activeFilterCount > 0; onClicked: root.model.resetFilters() }
            }

            GroupTitle { text: qsTr("Minecraft version") }
            PComboBox {
                Layout.fillWidth: true
                model: [qsTr("Any version")].concat(root.model.mcVersionOptions)
                currentIndex: root.model.mcVersions.length ? Math.max(0, root.model.mcVersionOptions.indexOf(root.model.mcVersions[0]) + 1) : 0
                onActivated: (i) => root.model.mcVersions = i === 0 ? [] : [root.model.mcVersionOptions[i - 1]]
            }
            PCheckBox {
                text: qsTr("Show snapshots")
                checked: root.model.showSnapshots
                onToggled: root.model.showSnapshots = checked
            }

            GroupTitle { text: qsTr("Loaders") }
            Flow {
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: root.model.loaderOptions
                    delegate: ResChip {
                        required property var modelData
                        text: modelData.text
                        checked: root.model.loaders.indexOf(modelData.value) >= 0
                        onClicked: root.model.loaders = root.toggleIn(root.model.loaders, modelData.value)
                    }
                }
            }

            GroupTitle { text: qsTr("Environment") }
            SegmentedControl {
                Layout.fillWidth: true
                options: [ { value: "", text: qsTr("Any") }, { value: "client", text: qsTr("Client") }, { value: "server", text: qsTr("Server") } ]
                value: root.model.side
                onActivated: v => root.model.side = v
            }

            GroupTitle { text: qsTr("Release type") }
            Flow {
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: [ { value: "release", text: qsTr("Release") }, { value: "beta", text: qsTr("Beta") }, { value: "alpha", text: qsTr("Alpha") } ]
                    delegate: ResChip {
                        required property var modelData
                        text: modelData.text
                        checked: root.model.releaseTypes.indexOf(modelData.value) >= 0
                        onClicked: root.model.releaseTypes = root.toggleIn(root.model.releaseTypes, modelData.value)
                    }
                }
            }

            GroupTitle { text: qsTr("Other") }
            PSwitch { text: qsTr("Open source only"); Layout.fillWidth: true; checked: root.model.openSourceOnly; onToggled: root.model.openSourceOnly = checked }
            PSwitch { text: qsTr("Hide installed"); Layout.fillWidth: true; checked: root.model.hideInstalled; onToggled: root.model.hideInstalled = checked }

            GroupTitle { text: qsTr("Categories"); visible: root.model.categoryOptions.length > 0 }
            Flow {
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: root.model.categoryOptions
                    delegate: ResChip {
                        required property var modelData
                        text: modelData.name
                        checked: root.model.categories.indexOf(modelData.id) >= 0
                        onClicked: root.model.categories = root.toggleIn(root.model.categories, modelData.id)
                    }
                }
            }
            Item { Layout.preferredHeight: Theme.spacing }
        }
    }
}
