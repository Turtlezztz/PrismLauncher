import QtQuick
import QtQuick.Layouts
import PrismModern

// Compact list row for a modpack (NIPackListModel roles).
Rectangle {
    id: row
    required property int index
    required property string name
    required property string summary
    required property string logo
    required property string subtitle
    property bool selected: false
    signal clicked()

    height: 72
    radius: Theme.radius
    color: selected ? Theme.accentSoft : hover.hovered ? Theme.surfaceHover : "transparent"
    border.color: selected ? Theme.accent : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.durFast } }
    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: row.clicked() }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10; anchors.rightMargin: 10
        spacing: 12
        NiPackLogo { size: 48; source: row.logo; name: row.name }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Text { text: row.name; color: row.selected ? Theme.accent : Theme.text; font.pixelSize: Theme.fontMd + 1; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
            Text { text: row.subtitle; visible: text.length > 0; color: Theme.textSubtle; font.pixelSize: Theme.fontXs + 1; elide: Text.ElideRight; Layout.fillWidth: true }
            Text {
                text: row.summary; visible: text.length > 0
                color: Theme.textMuted; font.pixelSize: Theme.fontSm
                wrapMode: Text.Wrap; maximumLineCount: row.subtitle.length ? 1 : 2; elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
    }
}
