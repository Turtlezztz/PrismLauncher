import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// One row of ResFolderView (a mod / pack). Model roles come from ResFolderModel.
Rectangle {
    id: row
    required property int index
    required property string name
    required property string version
    required property string author
    required property string provider
    required property string description
    required property string fileName
    required property bool isEnabled
    required property bool selected
    required property string iconSource
    required property bool hasMetadata
    required property bool updateLocked
    required property string issues
    required property string linkTip
    required property bool isFolder
    property bool showModColumns: true
    property bool wide: true
    property bool anyChecked: false

    signal clicked(int modifiers)
    signal checkToggled()
    signal toggleEnabled()
    signal contextMenu()

    height: 56
    radius: Theme.radius
    color: selected ? Theme.accentSoft : hover.hovered ? Theme.surfaceHover : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.durFast } }

    HoverHandler { id: hover }
    TapHandler {
        acceptedModifiers: Qt.KeyboardModifierMask
        onTapped: (ev) => row.clicked(ev.modifiers)
        onDoubleTapped: row.toggleEnabled()
    }
    TapHandler { acceptedButtons: Qt.RightButton; onTapped: row.contextMenu() }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 12
        spacing: 12

        // selection checkbox (shown on hover or while multi-selecting)
        Item {
            Layout.preferredWidth: 20
            Layout.fillHeight: true
            PCheckBox {
                anchors.centerIn: parent
                padding: 0
                checked: row.selected
                opacity: row.selected || row.anyChecked || hover.hovered ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
                onToggled: row.checkToggled()
            }
        }

        Rectangle {
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36
            radius: Theme.radiusSm + 2
            color: Theme.surfaceAlt
            border.color: Theme.border
            opacity: row.isEnabled ? 1 : 0.5
            Image {
                id: img
                anchors.fill: parent
                anchors.margins: 2
                source: row.iconSource
                sourceSize: Qt.size(64, 64)
                fillMode: Image.PreserveAspectFit
                smooth: false
                cache: true
                visible: status === Image.Ready && implicitWidth > 1
            }
            Icon {
                anchors.centerIn: parent
                visible: !img.visible
                name: row.isFolder ? "folder" : row.showModColumns ? "puzzle" : "package"
                size: 18
                color: Theme.textSubtle
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Text {
                    text: row.name
                    color: row.isEnabled ? Theme.text : Theme.textMuted
                    font.pixelSize: Theme.fontMd
                    font.weight: Font.DemiBold
                    font.strikeout: false
                    elide: Text.ElideRight
                    Layout.fillWidth: implicitWidth > width
                    Layout.maximumWidth: implicitWidth
                }
                Icon {
                    visible: row.issues.length > 0
                    name: "triangle-alert"; size: 13; color: Theme.warning
                    HoverHandler { id: issueHover }
                    PToolTip { visible: issueHover.hovered; text: row.issues }
                }
                Icon {
                    visible: row.updateLocked
                    name: "lock"; size: 12; color: Theme.textSubtle
                    HoverHandler { id: lockHover }
                    PToolTip { visible: lockHover.hovered; text: qsTr("Updates are locked") }
                }
                Icon {
                    visible: row.linkTip.length > 0
                    name: "link"; size: 12; color: Theme.info
                    HoverHandler { id: linkHover }
                    PToolTip { visible: linkHover.hovered; text: row.linkTip }
                }
                Badge { visible: !row.isEnabled; text: qsTr("Disabled") }
                Item { Layout.fillWidth: true }
            }
            Text {
                Layout.fillWidth: true
                text: row.description.length ? row.description : row.fileName
                color: Theme.textSubtle
                font.pixelSize: Theme.fontSm
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        Text {
            visible: row.wide
            Layout.preferredWidth: 130
            Layout.minimumWidth: 130
            Layout.maximumWidth: 130
            text: row.version
            color: Theme.textMuted
            font.pixelSize: Theme.fontSm
            elide: Text.ElideRight
        }

        ColumnLayout {
            visible: row.wide
            Layout.preferredWidth: 140
            Layout.minimumWidth: 140
            Layout.maximumWidth: 140
            spacing: 2
            Badge {
                visible: row.provider.length > 0
                text: row.provider
                tone: row.provider === "Modrinth" ? "success" : row.provider === "CurseForge" ? "warning" : "neutral"
            }
            Text {
                visible: row.author.length > 0 || row.provider.length === 0
                Layout.fillWidth: true
                text: row.author.length ? row.author : (row.hasMetadata ? "" : qsTr("Local file"))
                color: Theme.textSubtle
                font.pixelSize: Theme.fontXs
                elide: Text.ElideRight
            }
        }

        PSwitch {
            checked: row.isEnabled
            onToggled: { row.toggleEnabled(); checked = Qt.binding(() => row.isEnabled) }
            PToolTip { visible: parent.hovered; text: row.isEnabled ? qsTr("Disable") : qsTr("Enable") }
        }
    }
}
