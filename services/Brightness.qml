pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import "../style"

// brightnessctl singleton: the bar chip and the quick settings slider share
// one source of truth. The percent is polled once a second; every change pops
// the shared OSD with the fresh value read back from brightnessctl.
Singleton {
    id: root

    property int percent: 0
    property bool deviceFound: false

    // Set while a change is in flight; the OSD pops when the new value arrives.
    property bool osdPending: false

    readonly property string icon: root.percent <= 33
        ? Theme.iconBrightnessLow
        : (root.percent <= 66 ? Theme.iconBrightnessMedium : Theme.iconBrightnessHigh)

    function refresh(): void {
        if (!pctProc.running) pctProc.running = true;
    }

    // brightnessctl refuses 0 on most backlights, so the floor is 1%.
    function setPercent(p: real): void {
        const clamped = Math.max(1, Math.min(100, Math.round(p)));
        Quickshell.execDetached(["brightnessctl", "set", clamped + "%"]);
        root.osdPending = true;
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

    Component.onCompleted: root.refresh()
}
