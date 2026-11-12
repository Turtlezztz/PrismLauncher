import QtQuick
import QtQuick.Controls.Basic
import PrismModern

ToolTip {
    id: tip
    delay: 450
    timeout: 6000
    padding: 6
    leftPadding: 9; rightPadding: 9
    font.pixelSize: Theme.fontSm
    contentItem: Text { text: tip.text; font: tip.font; color: Theme.text; wrapMode: Text.Wrap }
    background: Rectangle { color: Theme.elevated; radius: Theme.radiusSm; border.color: Theme.borderStrong }
    enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durFast } }
    exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.durFast } }
}
