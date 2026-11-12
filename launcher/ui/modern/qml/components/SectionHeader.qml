import QtQuick
import QtQuick.Layouts
import PrismModern

// Section title with optional description; trailing actions in default slot.
RowLayout {
    id: root
    property string title: ""
    property string description: ""
    default property alias actions: trailing.data
    spacing: Theme.spacing
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2
        Text { text: root.title; color: Theme.text; font.pixelSize: Theme.fontLg; font.weight: Font.DemiBold; Layout.fillWidth: true; elide: Text.ElideRight }
        Text { visible: root.description.length > 0; text: root.description; color: Theme.textMuted; font.pixelSize: Theme.fontSm + 1; Layout.fillWidth: true; wrapMode: Text.Wrap }
    }
    Row { id: trailing; spacing: Theme.spacingSm; Layout.alignment: Qt.AlignVCenter }
}
