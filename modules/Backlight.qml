pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import "../style"

// brightnessctl-backed status chip: click -5%, middle +5%, wheel ±5%.
IconButton {
    id: root

    property int percent: 0

    function refresh(): void {
        if (!pctProc.running) pctProc.running = true;
    }

    function setBrightness(delta: string): void {
        Quickshell.execDetached(["brightnessctl", "set", delta]);
        // brightnessctl finishes fast; pick up the new value right after.
        applyDelay.restart();
    }

    icon: root.percent <= 33
        ? Theme.iconBrightnessLow
        : (root.percent <= 66 ? Theme.iconBrightnessMedium : Theme.iconBrightnessHigh)
    label: root.percent + "%"
    iconColor: Theme.tertiary

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
                if (parts.length < 4) return;
                const p = Math.round(parseFloat(parts[3]));
                if (!isNaN(p)) root.percent = p;
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
