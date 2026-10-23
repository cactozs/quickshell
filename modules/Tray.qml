pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Services.SystemTray
import QtQuick
import "../services"
import "../style"

// Bar chip for StatusNotifierItems. The items themselves live in the popup
// (TrayPopup); this chip only appears while at least one app exports one.
IconButton {
    id: root

    property string screenName: ""

    visible: SystemTray.items.values.length > 0
    round: true
    icon: Theme.iconTray

    onClicked: ShellState.toggleTray(root.screenName)

    Tip {
        target: root
        text: I18n.t("Трей")
        shown: root.hovered
    }
}
