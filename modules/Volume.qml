pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import "../services"
import "../style"

// Pipewire default sink chip: click toggles mute, wheel steps the volume;
// zero volume and a real mute both render as "muted". Every change pops the
// shared OSD.
IconButton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property int percent: Math.round(volume * 100)
    readonly property string sinkDescription: sink?.description ?? ""
    readonly property bool effectiveMuted: root.muted || root.percent === 0

    // audio.volume/muted are invalid until the node is bound, so keep the
    // default sink tracked for as long as the chip is alive.
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    function setVolume(v: real): void {
        if (sink?.ready && sink?.audio)
            sink.audio.volume = Math.max(0, Math.min(1.0, v));
    }

    function toggleMute(): void {
        if (sink?.ready && sink?.audio)
            sink.audio.muted = !sink.audio.muted;
    }

    // Called after the mutation so the OSD mirrors the fresh state.
    function showOsd(): void {
        Osd.show(root.icon, root.effectiveMuted ? 0 : root.volume);
    }

    icon: root.effectiveMuted
        ? Theme.iconVolumeOff
        : (root.percent < 66 ? Theme.iconVolumeDown : Theme.iconVolumeUp)
    label: root.effectiveMuted ? "muted" : root.percent + "%"
    iconColor: root.effectiveMuted ? Theme.surfaceVariantText : Theme.primary

    onClicked: button => {
        if (button === Qt.LeftButton) {
            root.toggleMute();
            root.showOsd();
        }
    }

    onWheeled: delta => {
        if (delta > 0) {
            // raising the volume while muted unmutes, like GNOME does
            if (root.muted)
                root.toggleMute();
            root.setVolume(root.volume + 0.05);
        } else if (delta < 0) {
            root.setVolume(root.volume - 0.05);
        }
        root.showOsd();
    }

    Tip {
        target: root
        text: (root.sinkDescription !== "" ? root.sinkDescription + "\n" : "")
            + (root.effectiveMuted ? "muted" : "Volume: " + root.percent + "%")
        shown: root.hovered
    }
}
