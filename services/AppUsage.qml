pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

// Per-app launch counts and favorites for the launcher. Stored in
// launcher-usage.json; missing keys count as 0 / not favorite, so a
// fresh install sorts exactly like before (alphabetically).
Singleton {
    id: root

    function launchKey(entry: DesktopEntry): string {
        return entry.id || entry.name;
    }

    function launchCount(entry: DesktopEntry): int {
        return usageAdapter.counts[root.launchKey(entry)] ?? 0;
    }

    function isFavorite(entry: DesktopEntry): bool {
        return (usageAdapter.favorites ?? []).indexOf(root.launchKey(entry)) !== -1;
    }

    function toggleFavorite(entry: DesktopEntry): void {
        const key = root.launchKey(entry);
        const favs = (usageAdapter.favorites ?? []).slice();
        const at = favs.indexOf(key);
        if (at !== -1)
            favs.splice(at, 1);
        else
            favs.push(key);
        usageAdapter.favorites = favs;
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
            property var favorites: ([])
        }
    }
}
