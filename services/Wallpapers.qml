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

    // Source path -> cached preview (see `thumbs`); a path missing from the map
    // (preview not built yet, or no magick) falls back to the original file.
    property var thumbs: ({})

    readonly property string thumbDir: Quickshell.env("HOME") + "/.cache/quickshell/wallpapers"

    function thumbFor(path: string): string {
        return root.thumbs[path] ?? path;
    }

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
        // Unchanged list: keep the array identity, otherwise every menu open
        // rebuilds the grid and re-decodes all previews.
        if (out.length === root.entries.length && out.every((e, i) => e.path === root.entries[i].path))
            return;
        root.entries = out;
        if (!thumbs.running)
            thumbs.running = true;
    }

    // Preview paths as "source\tpreview" lines from `thumbs`.
    function parseThumbs(text: string): void {
        const out = {};
        const lines = text.split("\n");
        for (let i = 0; i < lines.length; i++) {
            const tab = lines[i].indexOf("\t");
            if (tab > 0)
                out[lines[i].slice(0, tab)] = lines[i].slice(tab + 1);
        }
        root.thumbs = out;
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

        command: ["fd", "-H", "-I", "-t", "f", "-e", "jpg", "-e", "jpeg",
            "-e", "png", "-e", "webp", ".", root.rootDir]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.parse(text)
        }
    }

    // The grid previews 4K files, and Qt decodes a PNG at full size before
    // scaling it down, so the first open cost ~120 MB of peak RSS. One
    // background loop keeps 720px JPEG previews in the cache dir instead and
    // prints the ones it has; it rebuilds only previews older than their
    // source. Runs once per new wallpaper list, not on every menu open.
    // The preview name is a SHA-1 of the full path: replacing "/" with "_"
    // made "a/b.jpg" and "a_b.jpg" share one cache file. The find drops those
    // legacy names once; a hash is hex, so it cannot match them.
    // shortcut: without magick nothing is printed and the tiles load the
    // originals, as before; a wiped cache is only rebuilt on the next scan.
    Process {
        id: thumbs

        command: ["sh", "-c",
            "d=$1; shift; mkdir -p \"$d\" 2>/dev/null; " +
            "find \"$d\" -maxdepth 1 -type f -name '*_*.jpg' -delete 2>/dev/null; " +
            "for f in \"$@\"; do " +
            "t=\"$d/$(printf '%s' \"$f\" | sha1sum | cut -d' ' -f1).jpg\"; " +
            "[ -f \"$t\" ] && [ \"$t\" -nt \"$f\" ] || magick \"$f\" -resize 720x720\\> -quality 85 \"$t\" 2>/dev/null; " +
            "[ -f \"$t\" ] && printf '%s\\t%s\\n' \"$f\" \"$t\"; " +
            "done", "sh", root.thumbDir].concat(root.entries.map(entry => entry.path))

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.parseThumbs(text)
        }
    }

    FileView {
        id: favFile
        Component.onCompleted: text()

        path: Qt.resolvedUrl("../wallpaper-favorites.json")
        preload: false
        blockAllReads: true
        blockWrites: true
        printErrors: false
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: favAdapter

            property var favorites: []
        }
    }
}
