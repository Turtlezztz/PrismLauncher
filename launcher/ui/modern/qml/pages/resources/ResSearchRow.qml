import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// Search result row of the resource browser.
Rectangle {
    id: row
    required property int index
    required property string name
    required property string summary
    required property string authors
    required property string logo
    required property bool installed
    required property bool selected
    required property bool loading
    property bool current: false
    signal clicked()
    signal toggle()

    height: 76
    radius: Theme.radius
    color: current ? Theme.surfaceHover : hover.hovered ? Qt.rgba(Theme.surfaceHover.r, Theme.surfaceHover.g, Theme.surfaceHover.b, 0.6) : "transparent"
    border.width: selected ? 1 : 0
    border.color: Theme.accent
    Behavior on color { ColorAnimation { duration: Theme.durFast } }

    HoverHandler { id: hover }
    TapHandler { onTapped: row.clicked(); onDoubleTapped: row.toggle() }
    TapHandler { acceptedButtons: Qt.MiddleButton; onTapped: row.toggle() }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 12

        Rectangle {
            Layout.preferredWidth: 48; Layout.preferredHeight: 48
            Layout.alignment: Qt.AlignTop
            radius: Theme.radius
            color: Theme.surfaceAlt
            clip: true
            Image {
                id: logoImg
                anchors.fill: parent
                source: row.logo
                sourceSize: Qt.size(96, 96)
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                opacity: status === Image.Ready ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.dur } }
            }
            Icon { anchors.centerIn: parent; visible: logoImg.status !== Image.Ready; name: "package"; size: 20; color: Theme.textSubtle }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: 2
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Text {
                    text: row.name
                    color: Theme.text
                    font.pixelSize: Theme.fontMd
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    Layout.fillWidth: implicitWidth > width
                    Layout.maximumWidth: implicitWidth
                }
                Badge { visible: row.installed; text: qsTr("Installed"); tone: "success" }
                Item { Layout.fillWidth: true }
            }
            Text {
                visible: row.authors.length > 0
                text: qsTr("by %1").arg(row.authors)
                color: Theme.textSubtle
                font.pixelSize: Theme.fontXs
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Text {
                text: row.summary
                color: Theme.textMuted
                font.pixelSize: Theme.fontSm
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        // select toggle
        AbstractButton {
            id: sel
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 32; implicitHeight: 32
            hoverEnabled: true
            onClicked: row.toggle()
            HoverHandler { cursorShape: Qt.PointingHandCursor }
            PToolTip { visible: sel.hovered; text: row.selected ? qsTr("Deselect") : qsTr("Select for download") }
            background: Rectangle {
                radius: 16
                color: row.selected ? Theme.accent : sel.hovered ? Theme.surfacePressed : Theme.surfaceAlt
                border.color: row.selected ? Theme.accent : Theme.borderStrong
                Behavior on color { ColorAnimation { duration: Theme.durFast } }
            }
            contentItem: Item {
                Spinner { anchors.centerIn: parent; visible: row.loading; size: 14; color: Theme.textMuted }
                Icon {
                    anchors.centerIn: parent
                    visible: !row.loading
                    name: row.selected ? "check" : "plus"
                    size: 16
                    color: row.selected ? Theme.textOnAccent : Theme.textMuted
                    scale: row.selected ? 1 : 0.9
                    Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutBack } }
                }
            }
        }
    }
}
