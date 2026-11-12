import QtQuick
import QtQuick.Layouts
import PrismModern

// Classic ProxyPage.
SetPageBase {
    id: page
    title: qsTr("Proxy")
    subtitle: qsTr("This only applies to the launcher. Minecraft does not accept proxy settings.")

    readonly property string type: store ? (store.getString("ProxyType") || "None") : "None"
    readonly property bool editable: type === "SOCKS5" || type === "HTTP"

    SetSection {
        title: qsTr("Type"); iconName: "network"
        SetRow {
            label: qsTr("Proxy type")
            keywords: "proxy socks http system"
            SegmentedControl {
                id: typeSeg
                function current() { return page.type }
                options: [ { value: "Default", text: qsTr("System") }, { value: "None", text: qsTr("None") }, { value: "SOCKS5", text: "SOCKS5" }, { value: "HTTP", text: "HTTP" } ]
                value: current()
                onActivated: v => { page.store.set("ProxyType", v); value = Qt.binding(current) }
            }
        }
        Text {
            visible: page.type === "Default"
            width: parent.width; bottomPadding: 14
            text: qsTr("Uses your system's default proxy settings.")
            color: Theme.textMuted; font.pixelSize: Theme.fontSm
        }
    }

    SetSection {
        title: qsTr("Address and port"); iconName: "server"
        enabled: page.editable
        opacity: enabled ? 1 : 0.55
        SetRow {
            label: qsTr("Address"); keywords: "proxy host address"
            SetText { key: "ProxyAddr"; implicitWidth: 260; placeholderText: "127.0.0.1" }
        }
        SetRow {
            label: qsTr("Port"); keywords: "proxy port"
            SetSpin { key: "ProxyPort"; from: 0; to: 65535 }
        }
    }

    SetSection {
        title: qsTr("Authentication"); iconName: "key-round"
        enabled: page.editable
        opacity: enabled ? 1 : 0.55
        SetRow {
            label: qsTr("Username"); keywords: "proxy user"
            SetText { key: "ProxyUser"; implicitWidth: 260 }
        }
        SetRow {
            label: qsTr("Password"); keywords: "proxy password"
            SetText { key: "ProxyPass"; implicitWidth: 260; echoMode: TextInput.Password }
        }
        Text {
            width: parent.width; bottomPadding: 14
            wrapMode: Text.Wrap
            text: qsTr("Note: proxy username and password are stored in plain text inside the launcher's configuration file!")
            color: Theme.warning; font.pixelSize: Theme.fontSm
        }
    }
}
