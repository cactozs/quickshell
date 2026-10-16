pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import "../services"
import "../style"

// brightnessctl-backed status chip: click -5%, middle +5%, wheel ±5%. The
// value lives in the Brightness singleton, shared with the quick settings
// slider; the chip only hides itself when there is no backlight device.
IconButton {
    id: root

    icon: Brightness.icon
    label: Brightness.percent + "%"
    iconColor: Theme.tertiary
    visible: Brightness.deviceFound

    onClicked: button => Brightness.step(button === Qt.MiddleButton ? 5 : -5)

    onWheeled: delta => {
        if (delta !== 0)
            Brightness.step(delta > 0 ? 5 : -5);
    }

    Tip {
        target: root
        text: "Brightness: " + Brightness.percent + "%"
        visible: root.hovered
    }
}
