import QtQuick
import PrismModern

// Draft of pending global-settings edits. Controls read through get*/ and write through set();
// nothing reaches the settings file until save(). Keys are the classic setting ids.
QtObject {
    id: store

    property var pending: ({})
    property int rev: 0                       // bump to re-evaluate bindings that read the store
    readonly property bool dirty: Object.keys(pending).length > 0
    readonly property int dirtyCount: Object.keys(pending).length

    // search index: [{ page, label, description, item }]
    property var rows: []
    signal saved()
    signal discarded()

    function _same(a, b) { return JSON.stringify(a) === JSON.stringify(b) }

    function raw(key) { rev; return pending.hasOwnProperty(key) ? pending[key] : App.setting(key) }
    function get(key) { return raw(key) }
    function getBool(key) { var v = raw(key); return v === true || v === "true" || v === 1 }
    function getInt(key) { var v = parseInt(raw(key)); return isNaN(v) ? 0 : v }
    function getString(key) { var v = raw(key); return v === undefined || v === null ? "" : String(v) }
    function getList(key) {
        var v = raw(key)
        if (v === undefined || v === null || v === "") return []
        if (typeof v === "string") return [v]
        return Array.prototype.slice.call(v)
    }
    function getJson(key, fallback) {
        try { var o = JSON.parse(getString(key)); return o === null ? fallback : o } catch (e) { return fallback }
    }
    function isPending(key) { rev; return pending.hasOwnProperty(key) }

    function set(key, value) {
        var p = Object.assign({}, pending)
        var current = App.setting(key)
        // compare loosely so "true"/true and "12"/12 from the ini file count as unchanged
        if (_same(current, value) || String(current) === String(value)) delete p[key]
        else p[key] = value
        pending = p
        rev++
    }
    function setJson(key, obj) { set(key, JSON.stringify(obj)) }

    function changed(prefix) {
        for (var k in pending) if (k.indexOf(prefix) === 0) return true
        return false
    }

    // like APIPage::applySettings: add the trailing slash and upgrade non-local http:// to https://
    function _normalizeUrl(url) {
        url = url.trim()
        if (!url.length) return url
        var m = url.match(/^(https?):\/\/([^\/:?#]+)(.*)$/)
        if (!m) return url
        var scheme = m[1], host = m[2], rest = m[3]
        var local = host === "localhost" || host === "127.0.0.1" || host === "[::1]"
        if (scheme === "http" && !local) scheme = "https"
        var path = rest.replace(/[?#].*$/, "")
        var tail = rest.substring(path.length)
        var portMatch = path.match(/^(:\d+)(.*)$/)
        var port = portMatch ? portMatch[1] : ""
        path = portMatch ? portMatch[2] : path
        if (!path.endsWith("/")) path += "/"
        return scheme + "://" + host + port + path + tail
    }

    function save() {
        var p = Object.assign({}, pending)
        var keys = Object.keys(p)
        if (!keys.length) return
        // normalisations done by the classic pages on apply
        var urlKeys = ["MetaURLOverride", "ResourceURLOverride", "LegacyFMLLibsURLOverride"]
        for (var u = 0; u < urlKeys.length; u++) if (p.hasOwnProperty(urlKeys[u])) p[urlKeys[u]] = _normalizeUrl(String(p[urlKeys[u]]))
        if (p.hasOwnProperty("JvmArgs")) p["JvmArgs"] = String(p["JvmArgs"]).replace(/\n/g, " ")
        if (p.hasOwnProperty("MinMemAlloc") || p.hasOwnProperty("MaxMemAlloc")) {
            var mn = parseInt(p.hasOwnProperty("MinMemAlloc") ? p["MinMemAlloc"] : App.setting("MinMemAlloc"))
            var mx = parseInt(p.hasOwnProperty("MaxMemAlloc") ? p["MaxMemAlloc"] : App.setting("MaxMemAlloc"))
            if (mn > mx) { p["MinMemAlloc"] = mx; p["MaxMemAlloc"] = mn; keys = Object.keys(p) }
        }
        for (var i = 0; i < keys.length; i++) App.setSetting(keys[i], p[keys[i]])
        var proxy = keys.some(function(k) { return k.indexOf("Proxy") === 0 })
        pending = ({})
        rev++
        if (proxy) {
            SettingsBackend.applyProxy(App.setting("ProxyType"), App.setting("ProxyAddr"), parseInt(App.setting("ProxyPort")) || 0,
                                       App.setting("ProxyUser"), App.setting("ProxyPass"))
        }
        if (keys.indexOf("JvmArgs") >= 0) {
            var w = SettingsBackend.jvmArgsWarning(App.setting("JvmArgs"))
            if (w.length) Dialogs.message({ title: qsTr("JVM arguments warning"), text: w, kind: "warning" })
        }
        if (keys.indexOf("UseSystemLocale") >= 0) SettingsBackend.setUseSystemLocale(App.setting("UseSystemLocale") === true || App.setting("UseSystemLocale") === "true")
        if (keys.indexOf("PinnedJavaPaths") >= 0) {
            var bad = []
            var pins = {}
            try { pins = JSON.parse(App.setting("PinnedJavaPaths")) || {} } catch (e) {}
            for (var major in pins) if (!SettingsBackend.executableResolves(pins[major])) bad.push(qsTr("Java %1: %2").arg(major).arg(pins[major]))
            if (bad.length) Dialogs.message({ title: qsTr("Pinned Java installations"), kind: "warning",
                text: qsTr("The following pinned Java paths could not be found on your system. They were saved anyway, but instances needing those versions will fall back to the usual detection.") + "<br><br>" + bad.join("<br>") })
        }
        SettingsBackend.notifyApplied()
        saved()
    }
    function discard() { pending = ({}); rev++; discarded() }

    function register(entry) { var r = rows.slice(); r.push(entry); rows = r }
    function unregister(item) { rows = rows.filter(function(e) { return e.item !== item }) }
}
