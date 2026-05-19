import QtQuick
import Quickshell
import Quickshell.Io

// Holds the list of desktop-entry IDs pinned to the bar center, and
// persists them to ~/.config/quickshell/pinned.json so the row survives
// shell restarts.
QtObject {
    id: root

    property var ids: []

    readonly property string configDir: Quickshell.env("HOME") + "/.config/quickshell"
    readonly property string filePath: configDir + "/pinned.json"

    function isPinned(id) { return !!id && ids.indexOf(id) !== -1; }

    function pin(id) {
        if (!id || isPinned(id)) return;
        ids = ids.concat([id]);
        save();
    }

    function unpin(id) {
        var idx = ids.indexOf(id);
        if (idx === -1) return;
        var copy = ids.slice();
        copy.splice(idx, 1);
        ids = copy;
        save();
    }

    function move(fromIdx, toIdx) {
        if (fromIdx === toIdx) return;
        if (fromIdx < 0 || fromIdx >= ids.length) return;
        if (toIdx < 0 || toIdx >= ids.length) return;
        var copy = ids.slice();
        var item = copy.splice(fromIdx, 1)[0];
        copy.splice(toIdx, 0, item);
        ids = copy;
        save();
    }

    function entryById(id) {
        if (!id) return null;
        var all = DesktopEntries.applications.values;
        for (var i = 0; i < all.length; ++i) {
            if (all[i].id === id) return all[i];
        }
        return null;
    }

    function save() {
        var json = JSON.stringify(ids);
        // Single-quote-safe shell encoding: close, escaped quote, reopen.
        var safe = json.replace(/'/g, "'\\''");
        saver.command = ["sh", "-c",
            "mkdir -p '" + configDir + "' && printf %s '" + safe + "' > '" + filePath + "'"];
        saver.running = true;
    }

    Component.onCompleted: loader.running = true

    property Process loader: Process {
        command: ["sh", "-c", "cat '" + root.filePath + "' 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var t = text.trim();
                if (!t) return;
                try {
                    var parsed = JSON.parse(t);
                    if (Array.isArray(parsed)) root.ids = parsed;
                } catch (e) {
                    console.warn("PinnedApps: failed to parse", root.filePath, e);
                }
            }
        }
    }

    property Process saver: Process {}
}
