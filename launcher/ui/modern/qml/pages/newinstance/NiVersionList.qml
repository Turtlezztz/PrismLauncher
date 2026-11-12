import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import PrismModern

// List of NIVersionModel rows (version, type, release date, recommended) with a selection highlight.
Rectangle {
    id: root
    property NIVersionModel model: null
    property string selectedVersion: ""
    property string emptyText: qsTr("No versions available.")
    property bool showType: true
    signal picked(int row, string version)
    signal activatedVersion(int row, string version)

    radius: Theme.radius
    color: Theme.surface
    border.color: Theme.border
    clip: true

    ListView {
        id: list
        anchors.fill: parent
        anchors.margins: 4
        model: root.model
        spacing: 1
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: PScrollBar {}
        reuseItems: true
        cacheBuffer: 300
        keyNavigationEnabled: true
        currentIndex: -1

        delegate: Rectangle {
            id: row
            required property int index
            required property string version
            required property string type
            required property bool recommended
            required property string time
            readonly property bool current: version === root.selectedVersion
            width: list.width - 8
            height: 34
            radius: Theme.radiusSm
            color: current ? Theme.accentSoft : rowMa.containsMouse ? Theme.surfaceHover : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.durFast } }
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                spacing: 8
                Text {
                    text: row.version
                    color: row.current ? Theme.accent : Theme.text
                    font.pixelSize: Theme.fontMd; font.weight: row.current ? Font.DemiBold : Font.Normal
                    Layout.fillWidth: true; elide: Text.ElideRight
                }
                Badge { visible: row.recommended; text: qsTr("Recommended"); tone: "success"; iconName: "star" }
                Badge {
                    visible: root.showType && row.type.length > 0 && row.type !== "release"
                    text: row.type
                    tone: row.type === "snapshot" ? "info" : row.type.indexOf("experiment") >= 0 ? "danger" : "warning"
                }
                Text { text: row.time; color: Theme.textSubtle; font.pixelSize: Theme.fontSm; Layout.preferredWidth: 80; horizontalAlignment: Text.AlignRight }
            }
            MouseArea {
                id: rowMa
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: { list.currentIndex = row.index; root.picked(row.index, row.version) }
                onDoubleClicked: root.activatedVersion(row.index, row.version)
            }
        }
        Keys.onUpPressed: { if (currentIndex > 0) { currentIndex--; root.picked(currentIndex, root.model.versionAt(currentIndex)) } }
        Keys.onDownPressed: { if (currentIndex < count - 1) { currentIndex++; root.picked(currentIndex, root.model.versionAt(currentIndex)) } }
    }

    // keep the selected row in view when the selection changes from outside (e.g. preselection)
    onSelectedVersionChanged: Qt.callLater(scrollToSelected)
    function scrollToSelected() {
        if (!model) return
        var i = model.indexOf(selectedVersion)
        if (i >= 0) { list.currentIndex = i; list.positionViewAtIndex(i, ListView.Contain) }
    }

    Column {
        anchors.centerIn: parent
        spacing: Theme.spacingSm
        visible: root.model !== null && (root.model.loading || root.model.count === 0)
        Spinner { anchors.horizontalCenter: parent.horizontalCenter; visible: root.model !== null && root.model.loading; size: 22 }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(implicitWidth, root.width - 32)
            text: root.model === null ? "" : root.model.loading ? qsTr("Loading versions…") : root.model.error.length ? root.model.error : root.emptyText
            color: Theme.textMuted; font.pixelSize: Theme.fontSm
            horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
        }
    }
    Column {
        anchors.centerIn: parent
        visible: root.model === null
        Text { text: root.emptyText; color: Theme.textMuted; font.pixelSize: Theme.fontSm }
    }
}
