pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import "../services"
import "../style"

// Filled tonal icon button (primaryContainer); toggles the power menu.
IconButton {
    id: root

    property string screenName: ""

    round: true
    icon: Theme.iconPower
    containerColor: Theme.primaryContainer
    contentColor: Theme.primaryContainerText

    onClicked: ShellState.togglePowerMenu(root.screenName)
}
