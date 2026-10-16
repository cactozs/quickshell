pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import "../services"
import "../style"

// CPU/GPU/RAM/network popup on click; short hint on hover.
IconButton {
    id: root

    property string screenName: ""

    icon: Theme.iconMonitoring
    iconColor: Theme.surfaceVariantText
    containerColor: "transparent"

    onClicked: ShellState.toggleSystem(root.screenName)

    Tip {
        target: root
        text: SystemMonitor.tooltip
        shown: root.hovered && ShellState.systemScreen === ""
    }
}
