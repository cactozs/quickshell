pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

// Per-app launch counts for the launcher. Stored as
// { "<desktop id>": <count> } in launcher-usage.json; missing keys count
// as 0, so a fresh install sorts exactly like before (alphabetically).
Singleton {
    id: root

    function launchKey(entry: DesktopEntry): string {
        return entry.id || entry.name;
    }

    function launchCount(entry: DesktopEntry): int {
        return usageAdapter.counts[root.launchKey(entry)] ?? 0;
    }

    function recordLaunch(entry: DesktopEntry): void {
        const key = root.launchKey(entry);
        usageAdapter.counts = Object.assign({}, usageAdapter.counts, {
            [key]: root.launchCount(entry) + 1
        });
    }

    FileView {
        id: usageFile

        path: Qt.resolvedUrl("../launcher-usage.json")
        printErrors: false
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: usageAdapter

            property var counts: ({})
        }
    }
}
