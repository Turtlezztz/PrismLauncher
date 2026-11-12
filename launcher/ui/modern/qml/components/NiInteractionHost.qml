import QtQuick
import PrismModern

// Global host (placed once in Main.qml) for:
//  - questions that core tasks ask while importing / installing (NiInteraction.requested, answered with respond())
//  - background tasks shown in a TaskProgressDialog (NiInteraction.track(bridge, opts)) that survive page changes
Item {
    id: host

    Timer { interval: 300; running: true; onTriggered: { var s = String(App.setting("ModernNewInstanceSource")); if (s === "dlg:q") { question.req = { title: "Easy There!", text: "The modpack you are installing includes mods which are not hosted on Modrinth or CurseForge.<br><br><b>Malicious mods are often distributed through links.</b>", kind: "warning", items: ["mods/foo.jar", "mods/bar-1.2.jar"], buttons: ["Install anyway", "Cancel"], cancelIndex: 1, confirmCheck: "I trust this modpack and wish to proceed regardless" }; question.open() } else if (s === "dlg:c") { checklist.req = { title: "Select optional mods", text: "This modpack has optional mods.", items: ["mods/a.jar", "mods/b.jar", "resourcepacks/c.zip"], checked: ["mods/a.jar"] }; checklist.open() } else if (s === "dlg:url") Router.go("NewInstance", { importUrls: ["modrinth://modpack/fabulously-optimized"] }); else if (s.startsWith("dlg:")) InstanceActions.open(s.substr(4), "Vanilla 1.21") } } // TMPDLG
    Connections {
        target: NiInteraction
        function onRequested(id, kind, data) {
            var dlg = kind === "question" ? question
                    : kind === "checklist" ? checklist
                    : kind === "blockedMods" ? blocked
                    : kind === "atlOptionalMods" ? atlMods
                    : kind === "chooseVersion" ? versionPick : null
            if (!dlg) { NiInteraction.respond(id, null); return }
            dlg.reqId = id
            dlg.req = data
            dlg.open()
        }
        function onNotified(title, text, kind) {
            Toasts.show(title.length ? title + ": " + text : text, kind === "error" ? "error" : kind === "warning" ? "warning" : "info")
        }
        function onTrackRequested(task, opts) {
            var dlg = progressComp.createObject(host, { task: task, opts: opts || {} })
            dlg.closed.connect(function() { dlg.destroy(500) })
            dlg.open()
        }
    }

    NiQuestionDialog { id: question; property int reqId: -1; onAnswered: index => NiInteraction.respond(reqId, index) }
    NiChecklistDialog { id: checklist; property int reqId: -1; onAnswered: items => NiInteraction.respond(reqId, items) }
    NiBlockedModsDialog { id: blocked; property int reqId: -1; onAnswered: proceed => NiInteraction.respond(reqId, proceed) }
    NiAtlOptionalModsDialog { id: atlMods; property int reqId: -1; onAnswered: accepted => NiInteraction.respond(reqId, accepted) }
    NiVersionPickDialog { id: versionPick; property int reqId: -1; onAnswered: version => NiInteraction.respond(reqId, version) }

    Component {
        id: progressComp
        TaskProgressDialog {
            property var opts: ({})
            onSucceeded: {
                if (opts.successText) Toasts.success(opts.successText)
                if (opts.openInstance && task.resultId.length) {
                    Router.section = "Library"
                    Router.go("Library")
                    Router.push("Instance", { instanceId: task.resultId })
                }
            }
            onFailed: reason => { if (opts.failToast) Toasts.error(reason) }
        }
    }
}
