pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import "../services"
import "../style"

// CPU/GPU/RAM/network details on hover; a bare icon control (no container).
IconButton {
    id: root

    icon: Theme.iconMonitoring
    iconColor: Theme.surfaceVariantText
    containerColor: "transparent"

    Tip {
        target: root
        text: SystemMonitor.tooltip
        shown: root.hovered
    }
}
