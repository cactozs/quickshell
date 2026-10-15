pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import "../services"
import "../style"

// Bar icon button that opens the clipboard history on this screen.
IconButton {
    id: root

    property string screenName: ""

    round: true
    icon: Theme.iconClipboard

    onClicked: ShellState.toggleClipboard(root.screenName)

    Tip {
        target: root
        text: "Буфер обмена"
        visible: root.hovered
    }
}
