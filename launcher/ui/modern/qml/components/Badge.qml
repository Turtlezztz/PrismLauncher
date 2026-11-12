import QtQuick
import PrismModern

// Small pill label. tone: neutral | accent | success | warning | danger | info
Rectangle {
    id: badge
    property string text: ""
    property string tone: "neutral"
    property string iconName: ""
    readonly property color _c: tone === "accent" ? Theme.accent : tone === "success" ? Theme.success : tone === "warning" ? Theme.warning
                              : tone === "danger" ? Theme.danger : tone === "info" ? Theme.info : Theme.textMuted
    implicitHeight: 20
    implicitWidth: row.implicitWidth + 14
    radius: height / 2
    color: tone === "neutral" ? Theme.surfaceHover : Theme.soft(_c)
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4
        Icon { visible: badge.iconName.length > 0; name: badge.iconName; size: 11; color: badge._c; anchors.verticalCenter: parent.verticalCenter }
        Text { text: badge.text; color: badge._c; font.pixelSize: Theme.fontXs; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
    }
}
