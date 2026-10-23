pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import "../services"
import "../style"

// Pipewire default sink chip: click toggles mute, wheel steps the volume.
// Zero volume and a real mute both render as "muted". The Audio singleton
// pops the shared OSD for every change, including the niri volume keys.
IconButton {
    id: root

    readonly property bool effectiveMuted: Audio.effectiveMuted

    icon: Audio.icon
    label: root.effectiveMuted ? "muted" : Audio.percent + "%"
    iconColor: root.effectiveMuted ? Theme.surfaceVariantText : Theme.primary

    onClicked: button => {
        if (button === Qt.LeftButton)
            Audio.toggleMute();
    }

    onWheeled: delta => {
        if (delta > 0) {
            // raising the volume while muted unmutes, like GNOME does
            if (Audio.muted)
                Audio.toggleMute();
            Audio.setVolume(Audio.volume + 0.05);
        } else if (delta < 0) {
            Audio.setVolume(Audio.volume - 0.05);
        }
    }

    Tip {
        target: root
        text: (Audio.sinkName !== "" ? Audio.sinkName + "\n" : "")
            + (root.effectiveMuted ? I18n.t("Без звука") : I18n.t("Громкость: ") + Audio.percent + "%")
        shown: root.hovered
    }
}
