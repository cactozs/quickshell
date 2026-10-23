pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

// Pinned clipboard entries. cliphist owns the history and `cliphist wipe`
// clears it as a whole, so a pin is a decoded snapshot copied into the shell
// data directory plus a small JSON index of its preview. Pins therefore
// survive a wipe, a cache purge and a reboot; the index and the snapshots are
// still disposable.
Singleton {
    id: root

    readonly property string dir: Quickshell.dataPath("clipboard")
    readonly property var pins: adapter.pins ?? []

    Process {
        id: mkdir

        command: ["mkdir", "-p", root.dir]
        Component.onCompleted: running = true
    }

    FileView {
        id: file

        path: Qt.resolvedUrl(root.dir + "/pins.json")
        blockLoading: true
        printErrors: false

        Component.onCompleted: text()
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: adapter

            property var pins: []
        }
    }

    // One snapshot at a time: the entry is only recorded once cliphist has
    // actually decoded into the file.
    Process {
        id: snapshot

        property var entry: null
        property string path: ""

        onExited: (code, status) => {
            if (code !== 0 || snapshot.entry === null)
                return;
            adapter.pins = [{
                preview: snapshot.entry.preview,
                binary: snapshot.entry.binary,
                line: snapshot.entry.line,
                file: snapshot.path
            }, ...(adapter.pins ?? [])];
            snapshot.entry = null;
        }
    }

    function has(line: string): bool {
        return root.pins.some(p => p.line === line);
    }

    function add(entry: var): void {
        if (!entry || root.has(entry.line))
            return;
        const name = "pin-" + Date.now() + (entry.binary ? ".bin" : ".txt");
        snapshot.path = root.dir + "/" + name;
        snapshot.entry = entry;
        snapshot.command = ["sh", "-c",
            "printf '%s\\n' \"$1\" | cliphist decode > \"$2\"",
            "sh", entry.line, snapshot.path];
        snapshot.running = true;
    }

    function remove(pin: var): void {
        adapter.pins = root.pins.filter(p => p.file !== pin.file);
        Quickshell.execDetached(["rm", "-f", pin.file]);
    }

    function copy(pin: var): void {
        Quickshell.execDetached(["sh", "-c", "wl-copy < \"$1\"", "sh", pin.file]);
    }
}
