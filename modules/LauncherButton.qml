pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import "../services"
import "../style"

// Bar icon button that opens the app launcher on this screen.
IconButton {
    id: root

    property string screenName: ""

    round: true
    icon: Theme.iconApps

    onClicked: ShellState.toggleLauncher(root.screenName)

    Tip {
        target: root
        text: "Приложения"
        visible: root.hovered
    }
}
