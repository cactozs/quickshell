pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick
import "../services"
import "../style"

// Small, static snow caps for windows whose current positions Niri exposes.
PanelWindow {
    id: root

    required property ShellScreen modelData
    screen: modelData

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    color: "transparent"
    visible: ShellState.ambient === "xmas"
        && Niri.windowSnowFor(root.modelData.name).length > 0
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell:xmas-window-snow"
    mask: Region {}

    Repeater {
        model: Niri.windowSnowFor(root.modelData.name)

        delegate: Item {
            required property var modelData

            x: modelData.x
            y: modelData.y - height / 2
            width: Math.min(modelData.width, 110)
            height: 9
            opacity: 0.48

            Rectangle {
                x: parent.width * 0.05
                y: parent.height * 0.48
                width: parent.width * 0.9
                height: parent.height * 0.38
                radius: height / 2
                color: Theme.snow
                antialiasing: true
            }

            Rectangle {
                x: parent.width * 0.14
                y: parent.height * 0.12
                width: parent.height * 0.72
                height: width
                radius: width / 2
                color: Theme.snow
                antialiasing: true
            }

            Rectangle {
                x: parent.width * 0.58
                y: parent.height * 0.02
                width: parent.height * 0.84
                height: width
                radius: width / 2
                color: Theme.snow
                antialiasing: true
            }

            Rectangle {
                x: parent.width * 0.78
                y: parent.height * 0.25
                width: parent.height * 0.65
                height: width
                radius: width / 2
                color: Theme.snow
                antialiasing: true
            }
        }
    }
}
