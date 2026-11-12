import QtQuick
import QtQuick.Controls.Basic
import PrismModern

// Styled ComboBox. Works with string arrays or models with textRole/valueRole.
ComboBox {
    id: control
    implicitHeight: Theme.controlHeight
    implicitWidth: 200
    font.pixelSize: Theme.fontMd
    hoverEnabled: true
    leftPadding: 12
    rightPadding: 32

    delegate: ItemDelegate {
        id: d
        required property var model
        required property int index
        width: ListView.view ? ListView.view.width : control.width
        height: 32
        hoverEnabled: true
        highlighted: control.highlightedIndex === index
        contentItem: Text {
            text: control.textRole ? (Array.isArray(control.model) ? d.model[control.textRole] : d.model[control.textRole]) : d.model.modelData
            color: control.currentIndex === d.index ? Theme.accent : Theme.text
            font.pixelSize: Theme.fontMd
            font.weight: control.currentIndex === d.index ? Font.DemiBold : Font.Normal
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: Theme.radiusSm
            color: d.highlighted ? Theme.surfaceHover : "transparent"
        }
    }
    indicator: Icon {
        x: control.width - width - 10
        y: (control.height - height) / 2
        name: "chevron-down"; size: 14; color: Theme.textMuted
        rotation: control.popup.visible ? 180 : 0
        Behavior on rotation { NumberAnimation { duration: Theme.dur; easing.type: Theme.easing } }
    }
    contentItem: Text {
        text: control.displayText
        font: control.font
        color: control.enabled ? Theme.text : Theme.textDisabled
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    background: Rectangle {
        radius: Theme.radius
        color: control.hovered ? Theme.surfaceHover : Theme.input
        border.width: control.visualFocus || control.popup.visible ? 2 : 1
        border.color: control.visualFocus || control.popup.visible ? Theme.accent : Theme.border
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
    }
    popup: Popup {
        y: control.height + 4
        width: control.width
        implicitHeight: Math.min(contentItem.implicitHeight + 8, 320)
        padding: 4
        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: control.popup.visible ? control.delegateModel : null
            currentIndex: control.highlightedIndex
            ScrollBar.vertical: PScrollBar {}
        }
        background: Rectangle { color: Theme.elevated; radius: Theme.radius; border.color: Theme.borderStrong }
        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durFast }
            NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: Theme.dur; easing.type: Theme.easing }
        }
        exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.durFast } }
    }
}
