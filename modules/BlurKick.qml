pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import "../style"

// Repaint driver for popup blur regions. niri takes the region from the
// commit that follows the frame that set it, so the last frame of an
// animated resize can leave the blur one step behind the plate, and it
// composites the blur only where the surface was damaged, so nothing
// repaints that strip. kick() re-applies the region and toggles a
// full-window 0.002-alpha wash so the trailing frames keep the whole
// surface damaged until the region lands; the timer repeats the nudge once
// the plate has stopped.
// shortcut: a repaint nudge, not a guarantee — drop it once Quickshell/niri
// repaint on a region change.
Rectangle {
    id: root

    // The popup's blur region, re-applied on every kick.
    property Region region: null

    anchors.fill: parent
    color: Theme.surface
    opacity: root.active ? 0.002 : 0
    property bool active: false

    // Nudge now and once more after the plate stops moving. Call from the
    // geometry-changed handlers of whatever the region follows.
    function kick(): void {
        root.nudge();
        settle.restart();
    }

    function nudge(): void {
        root.active = !root.active;
        if (root.region)
            root.region.changed();
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.durShort
            easing.type: Easing.Linear
        }
    }

    Timer {
        id: settle

        interval: 80
        onTriggered: root.nudge()
    }
}
