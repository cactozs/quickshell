pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import "../services"
import "../style"

// niri keyboard layout as a tonal chip: keyboard glyph + uppercased code.
IconButton {
    id: root

    icon: Theme.iconKeyboard
    label: Niri.currentLayout.toUpperCase()
    iconColor: Theme.surfaceVariantText
}
