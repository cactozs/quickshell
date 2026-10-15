pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import "../style"

// Pipewire default sink chip: click toggles mute, wheel steps the volume.
IconButton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property int percent: Math.round(volume * 100)
    readonly property string sinkDescription: sink?.description ?? ""

    function setVolume(v: real): void {
        if (sink?.ready && sink?.audio)
            sink.audio.volume = Math.max(0, Math.min(1.0, v));
    }

    function toggleMute(): void {
        if (sink?.ready && sink?.audio)
            sink.audio.muted = !sink.audio.muted;
    }

    icon: root.muted
        ? Theme.iconVolumeOff
        : (root.percent < 66 ? Theme.iconVolumeDown : Theme.iconVolumeUp)
    label: root.percent + "%"
    iconColor: root.muted ? Theme.surfaceVariantText : Theme.primary

    onClicked: root.toggleMute()

    onWheeled: delta => {
        if (delta > 0)
            root.setVolume(root.volume + 0.05);
        else if (delta < 0)
            root.setVolume(root.volume - 0.05);
    }

    Tip {
        target: root
        text: root.sinkDescription + "\nVolume: " + root.percent + "%"
        visible: root.hovered
    }
}
