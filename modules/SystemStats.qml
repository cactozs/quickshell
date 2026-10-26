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

    // Wakes the 2 s monitor poll while the chip is hovered, so the tip and
    // the popup always show fresh values.
    onHoveredChanged: SystemMonitor.statsHovered = hovered

    Tip {
        target: root
        text: SystemMonitor.tooltip
        shown: root.hovered && ShellState.systemScreen === ""
    }
}
