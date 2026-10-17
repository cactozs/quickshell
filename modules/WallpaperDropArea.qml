import Quickshell
import QtQuick

// Drop target for wallpaper images, shared by the desktop surface
// (WallpaperDrop) and the bar: dropping an image file runs `awww img <file>`,
// which the /usr/local/bin/awww shim routes through matugen, so the wallpaper
// *and* style/Colors.json update from it.
DropArea {
    onEntered: (drag) => drag.accepted = drag.hasUrls

    onDropped: (drop) => {
        const url = drop.urls[0]?.toString() ?? "";
        if (!url.startsWith("file://"))
            return;

        // File URLs are percent-encoded; awww needs the plain path.
        Quickshell.execDetached(["awww", "img", decodeURIComponent(url.slice(7))]);
        drop.accept();
    }
}
