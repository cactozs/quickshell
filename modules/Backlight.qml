pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import "../services"
import "../style"

// brightnessctl-backed status chip: click -5%, middle +5%, wheel ±5%.
// Hidden entirely when there is no backlight device (desktop); each change
// pops the shared OSD once brightnessctl reports the new value.
IconButton {
    id: root

    property int percent: 0
    property bool deviceFound: false

    // Set while a brightness change is in flight; the OSD pops when the new
    // value arrives from brightnessctl.
    property bool osdPending: false

    function refresh(): void {
        if (!pctProc.running) pctProc.running = true;
    }

    function setBrightness(delta: string): void {
        Quickshell.execDetached(["brightnessctl", "set", delta]);
        // brightnessctl finishes fast; pick up the new value right after.
        root.osdPending = true;
        applyDelay.restart();
    }

    icon: root.percent <= 33
        ? Theme.iconBrightnessLow
        : (root.percent <= 66 ? Theme.iconBrightnessMedium : Theme.iconBrightnessHigh)
    label: root.percent + "%"
    iconColor: Theme.tertiary
    visible: root.deviceFound

    onClicked: button => {
        if (button === Qt.MiddleButton)
            root.setBrightness("5%+");
        else
            root.setBrightness("5%-");
    }

    onWheeled: delta => {
        if (delta > 0)
            root.setBrightness("5%+");
        else if (delta < 0)
            root.setBrightness("5%-");
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

    Tip {
        target: root
        text: "Brightness: " + root.percent + "%"
        visible: root.hovered
    }
}
