import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// Search + view toggles shared by the log views. Extra buttons go in the default slot (right side).
//   LogToolbar { panel: logPanel; log: logModel }
RowLayout {
    id: bar
    property LogViewPanel panel
    property LogViewModel log
    property bool showFollow: true
    property alias searchField: search
    default property alias extra: extraRow.data
    spacing: Theme.spacingSm

    SearchField {
        id: search
        Layout.preferredWidth: 260
        Layout.minimumWidth: 160
        placeholderText: qsTr("Find in log")
        onTextChanged: if (bar.panel) bar.panel.searchText = text
        Keys.onReturnPressed: (event) => bar.panel.findNext((event.modifiers & Qt.ShiftModifier) !== 0)
        Keys.onEnterPressed: (event) => bar.panel.findNext((event.modifiers & Qt.ShiftModifier) !== 0)
        Keys.onUpPressed: bar.panel.findNext(true)
        Keys.onDownPressed: bar.panel.findNext(false)
    }
    Text {
        visible: search.text.length > 0
        text: bar.panel && bar.panel.matches ? qsTr("%1 found").arg(bar.panel.matches) : qsTr("No matches")
        color: Theme.textSubtle; font.pixelSize: Theme.fontSm
    }
    IconButton { visible: search.text.length > 0; iconName: "chevron-down"; rotation: 180; tip: qsTr("Previous match (Shift+Enter)"); onClicked: bar.panel.findNext(true) }
    IconButton { visible: search.text.length > 0; iconName: "chevron-down"; tip: qsTr("Next match (Enter)"); onClicked: bar.panel.findNext(false) }

    Item { Layout.fillWidth: true }

    IconButton {
        iconName: "wrap-text"; active: bar.log && bar.log.wrap; tip: qsTr("Wrap lines")
        onClicked: bar.log.wrap = !bar.log.wrap
    }
    IconButton {
        iconName: "palette"; active: bar.log && bar.log.colorLines; tip: qsTr("Color lines by level")
        onClicked: bar.log.colorLines = !bar.log.colorLines
    }
    IconButton {
        visible: bar.showFollow
        iconName: bar.log && bar.log.following ? "pause" : "play"; active: bar.log && !bar.log.following
        tip: bar.log && bar.log.following ? qsTr("Pause log updates") : qsTr("Resume log updates")
        onClicked: bar.log.following = !bar.log.following
    }
    IconButton {
        iconName: "arrow-down-to-line"; active: bar.panel && bar.panel.autoScroll; tip: qsTr("Auto-scroll to new lines")
        onClicked: { bar.panel.autoScroll = !bar.panel.autoScroll; if (bar.panel.autoScroll) bar.panel.scrollToEnd() }
    }
    Rectangle { width: 1; height: 20; color: Theme.border; Layout.leftMargin: 2; Layout.rightMargin: 2 }
    Row { id: extraRow; spacing: Theme.spacingSm; Layout.alignment: Qt.AlignVCenter }

    Shortcut { sequences: [StandardKey.Find]; onActivated: { search.forceActiveFocus(); search.selectAll() } }
    Shortcut { sequences: [StandardKey.FindNext]; onActivated: bar.panel.findNext(false) }
    Shortcut { sequences: [StandardKey.FindPrevious]; onActivated: bar.panel.findNext(true) }
}
