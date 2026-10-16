pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

// Night light via wlsunset (niri implements wlr-gamma-control). While enabled
// the daemon holds the screen at nightTemp; stopping it releases gamma control
// and the compositor restores the native output instantly. The manual schedule
// sunrise 23:59 / sunset 00:01 keeps wlsunset in its night branch all day.
Singleton {
    id: root

    readonly property int nightTemp: 4000

    // Whether wlsunset is installed; the tile stays hidden otherwise.
    property bool available: false
    property bool enabled: false

    function toggle(): void {
        root.enabled = !root.enabled;
    }

    // Re-runs the availability probe; called when the panel opens so a
    // wlsunset installed after shell start is picked up without a reload.
    function recheck(): void {
        if (root.available)
            return;
        probe.running = false;
        probe.running = true;
    }

    Process {
        id: probe

        command: ["sh", "-c", "command -v wlsunset"]
        running: true

        onExited: (code, status) => root.available = code === 0
    }

    Process {
        id: daemon

        command: [
            "wlsunset",
            "-T", "6500",
            "-t", String(root.nightTemp),
            "-S", "23:59",
            "-s", "00:01"
        ]
        running: root.enabled
    }
}
