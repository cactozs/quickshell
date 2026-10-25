pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import "../style"

// brightnessctl singleton: the bar chip and the quick settings slider share
// one source of truth. The percent is polled once a second through sysfs when
// the machine exposes a backlight; brightnessctl stays for writes and as the
// fallback poll. Every change pops the shared OSD with the fresh value.
Singleton {
    id: root

    property int percent: 0
    property bool deviceFound: false

    // sysfs backlight path (".../brightness") when the machine exposes one.
    // Empty means the brightnessctl fallback below is in charge.
    property string brightnessPath: ""
    property int maxBrightness: 0
    property bool hasReadBrightness: false

    // Set while a change is in flight; the OSD pops when the new value arrives.
    property bool osdPending: false

    // The first poll after startup must not pop an OSD; later changes are
    // external (the niri brightness keys call brightnessctl directly).
    property bool started: false
    property int lastPercent: 0

    readonly property string icon: root.percent <= 33
        ? Theme.iconBrightnessLow
        : (root.percent <= 66 ? Theme.iconBrightnessMedium : Theme.iconBrightnessHigh)

    onPercentChanged: {
        if (!root.started)
            return;
        if (root.osdPending) {
            root.lastPercent = root.percent;
            return;
        }
        if (root.percent === root.lastPercent)
            return;
        root.lastPercent = root.percent;
        Osd.show(root.icon, root.percent / 100);
    }

    Timer {
        interval: 500
        running: true

        onTriggered: {
            root.started = true;
            root.lastPercent = root.percent;
        }
    }

    function refresh(): void {
        if (root.brightnessPath !== "") {
            // Two file reads per second instead of a process spawn per second.
            brightnessFile.reload();
            return;
        }
        if (!pctProc.running)
            pctProc.running = true;
    }

    // brightnessctl refuses 0 on most backlights, so the floor is 1%.
    function setPercent(p: real): void {
        const clamped = Math.max(1, Math.min(100, Math.round(p)));
        // Optimistic: the slider follows the release instead of snapping back
        // until the poll returns. osdPending first so this pop is suppressed.
        root.osdPending = true;
        root.percent = clamped;
        Quickshell.execDetached(["brightnessctl", "set", clamped + "%"]);
        applyDelay.restart();
    }

    function step(delta: int): void {
        root.setPercent(root.percent + delta);
    }

    Timer {
        id: applyDelay
        interval: 120
        onTriggered: root.refresh()
    }

    // One-shot probe for a readable sysfs backlight. Writing still goes
    // through brightnessctl; this only replaces the once-a-second poll.
    Process {
        id: sysfsProbe

        command: [
            "sh", "-c",
            "for b in /sys/class/backlight/*; do " +
            "[ -r \"$b/brightness\" ] || continue; " +
            "m=$(cat \"$b/max_brightness\" 2>/dev/null) || continue; " +
            "[ \"$m\" -gt 0 ] 2>/dev/null || continue; " +
            "echo \"$b/brightness|$m\"; exit 0; " +
            "done"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split("|");
                if (parts.length < 2)
                    return;
                const max = parseInt(parts[1]);
                if (parts[0] === "" || isNaN(max) || max <= 0)
                    return;
                root.brightnessPath = parts[0];
                root.maxBrightness = max;
                brightnessFile.reload();
            }
        }
    }

    FileView {
        id: brightnessFile

        path: root.brightnessPath
        preload: false
        blockAllReads: true
        printErrors: false

        onTextChanged: {
            const value = parseInt(text().trim());
            if (isNaN(value) || root.maxBrightness <= 0)
                return;
            const p = Math.round(100 * value / root.maxBrightness);
            // The first sysfs sample is the startup baseline, not a change:
            // set it before `percent` so the OSD stays quiet.
            if (!root.hasReadBrightness) {
                root.hasReadBrightness = true;
                root.lastPercent = p;
            }
            root.percent = p;
            root.deviceFound = true;
            if (root.osdPending) {
                root.osdPending = false;
                Osd.show(root.icon, p / 100);
            }
        }
    }

    Process {
        id: pctProc

        command: ["brightnessctl", "-m"]

        stdout: StdioCollector {
            onStreamFinished: {
                // "device,class,current,percent%,max"
                const parts = text.trim().split(",");
                if (parts.length < 4) {
                    root.deviceFound = false;
                    root.osdPending = false;
                    return;
                }
                const p = Math.round(parseFloat(parts[3]));
                if (!isNaN(p)) {
                    // Fallback path: the first sample is the baseline too.
                    if (!root.hasReadBrightness) {
                        root.hasReadBrightness = true;
                        root.lastPercent = p;
                    }
                    root.percent = p;
                    root.deviceFound = true;
                    if (root.osdPending) {
                        root.osdPending = false;
                        Osd.show(root.icon, p / 100);
                    }
                }
            }
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: {
        sysfsProbe.running = true;
        root.refresh();
    }
}
