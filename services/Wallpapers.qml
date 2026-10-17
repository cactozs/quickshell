pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

// Wallpaper library for the wallpaper manager: a recursive scan of
// ~/Pictures/Wallpapers and the favorites list persisted in
// wallpaper-favorites.json. Applying goes through `awww img <file>`, the same
// route as dropping a file on the desktop: the /usr/local/bin/awww shim runs
// matugen, which sets the wallpaper (transition in its config) and rewrites
// style/Colors.json, so the whole shell recolors.
Singleton {
    id: root

    // Local config: change to another picture folder if needed.
    readonly property string rootDir: Quickshell.env("HOME") + "/Pictures/Wallpapers"

    // [{ path, name, folder }], folder is relative to rootDir ("" at the top).
    property var entries: []

    Component.onCompleted: root.reload()

    function reload(): void {
        if (!scan.running)
            scan.running = true;
    }

    function parse(text: string): void {
        const out = [];
        const lines = text.split("\n");
        for (let i = 0; i < lines.length; i++) {
            const path = lines[i];
            if (path === "" || !path.startsWith(root.rootDir + "/"))
                continue;
            const rel = path.slice(root.rootDir.length + 1);
            const slash = rel.lastIndexOf("/");
            out.push({
                path: path,
                name: slash === -1 ? rel : rel.slice(slash + 1),
                folder: slash === -1 ? "" : rel.slice(0, slash)
            });
        }
        out.sort((a, b) => a.folder.localeCompare(b.folder) || a.name.localeCompare(b.name));
        root.entries = out;
    }

    function isFavorite(path: string): bool {
        return (favAdapter.favorites ?? []).indexOf(path) !== -1;
    }

    function toggleFavorite(path: string): void {
        const favs = (favAdapter.favorites ?? []).slice();
        const at = favs.indexOf(path);
        if (at !== -1)
            favs.splice(at, 1);
        else
            favs.push(path);
        favAdapter.favorites = favs;
    }

    function apply(path: string): void {
        Quickshell.execDetached(["awww", "img", path]);
    }

    function randomPath(): string {
        if (root.entries.length === 0)
            return "";
        return root.entries[Math.floor(Math.random() * root.entries.length)].path;
    }

    Process {
        id: scan

        command: ["find", root.rootDir, "-type", "f",
            "(", "-iname", "*.jpg", "-o", "-iname", "*.jpeg",
            "-o", "-iname", "*.png", "-o", "-iname", "*.webp", ")"]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.parse(text)
        }
    }

    FileView {
        id: favFile

        path: Qt.resolvedUrl("../wallpaper-favorites.json")
        printErrors: false
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: favAdapter

            property var favorites: []
        }
    }
}
