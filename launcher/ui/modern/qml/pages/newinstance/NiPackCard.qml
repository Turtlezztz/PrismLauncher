import QtQuick
import QtQuick.Layouts
import PrismModern

// Showcase card for the Discover grid.
Item {
    id: card
    required property int index
    required property string name
    required property string summary
    required property string logo
    required property string subtitle
    property bool selected: false
    signal clicked()

    Rectangle {
        id: bg
        anchors.fill: parent
        anchors.margins: 6
        radius: Theme.radiusLg
        color: hover.hovered ? Theme.surfaceHover : Theme.surface
        border.width: card.selected ? 2 : 1
        border.color: card.selected ? Theme.accent : hover.hovered ? Theme.borderStrong : Theme.border
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
        transform: Translate { y: hover.hovered && !Theme.reduceMotion ? -2 : 0; Behavior on y { NumberAnimation { duration: Theme.dur; easing.type: Theme.easing } } }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                NiPackLogo { size: 56; source: card.logo; name: card.name }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text { text: card.name; color: Theme.text; font.pixelSize: Theme.fontMd + 1; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true; maximumLineCount: 2; wrapMode: Text.Wrap }
                    Text { text: card.subtitle; visible: text.length > 0; color: Theme.textSubtle; font.pixelSize: Theme.fontSm; elide: Text.ElideRight; Layout.fillWidth: true }
                }
            }
            Text {
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: card.summary
                color: Theme.textMuted; font.pixelSize: Theme.fontSm
                wrapMode: Text.Wrap; elide: Text.ElideRight; maximumLineCount: 3
                verticalAlignment: Text.AlignTop
            }
        }
    }
    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: card.clicked() }
}
