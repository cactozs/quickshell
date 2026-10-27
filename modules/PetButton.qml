pragma ComponentBehavior: Bound

import QtQuick
import "../services"
import "../style"

// Bar chip: shows or hides the desktop pet on this screen. Hidden entirely
// when the pet is switched off in settings.
IconButton {
    id: root

    required property string screenName

    readonly property bool opened: ShellState.petScreen === root.screenName

    round: true
    icon: Theme.iconPets
    containerColor: root.opened ? Theme.primaryContainer : Theme.surfaceContainerHigh
    contentColor: root.opened ? Theme.primaryContainerText : Theme.surfaceText

    onClicked: ShellState.togglePet(root.screenName)

    Tip {
        target: root
        text: I18n.t("Питомец")
        shown: root.hovered
    }
}
