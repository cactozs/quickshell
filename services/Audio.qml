pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import "../style"

// Default sink/source state shared by the bar chip and quick settings. Every
// volume or mute change pops the OSD, including changes made outside the shell
// (the niri volume keys call wpctl directly).
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property var sinks: Pipewire.nodes.values.filter(n => !n.isStream && n.isSink)

    readonly property bool muted: root.sink?.audio?.muted ?? false
    readonly property real volume: root.sink?.audio?.volume ?? 0
    readonly property int percent: Math.round(root.volume * 100)
    readonly property bool effectiveMuted: root.muted || root.percent === 0
    readonly property bool micMuted: root.source?.audio?.muted ?? false

    readonly property string sinkName: root.sink?.description ?? ""

    readonly property string icon: root.effectiveMuted
        ? Theme.iconVolumeOff
        : (root.percent < 66 ? Theme.iconVolumeDown : Theme.iconVolumeUp)

    // The first sample after startup must not pop an OSD.
    property bool started: false
    property real lastVolume: 0
    property bool lastMuted: false
    property bool lastMicMuted: false

    PwObjectTracker {
        objects: [root.sink, root.source].filter(o => o != null)
    }

    Timer {
        interval: 500
        running: true

        onTriggered: {
            // Pipewire can hand over the default sink later; a baseline at 0
            // would make the first real volume look like a user change.
            if (!root.sink?.ready) {
                restart();
                return;
            }
            root.started = true;
            root.lastVolume = root.volume;
            root.lastMuted = root.muted;
            root.lastMicMuted = root.micMuted;
        }
    }

    function setVolume(v: real): void {
        if (root.sink?.ready && root.sink?.audio)
            root.sink.audio.volume = Math.max(0, Math.min(1.0, v));
    }

    function toggleMute(): void {
        if (root.sink?.ready && root.sink?.audio)
            root.sink.audio.muted = !root.sink.audio.muted;
    }

    function toggleMicMute(): void {
        if (root.source?.ready && root.source?.audio)
            root.source.audio.muted = !root.source.audio.muted;
    }

    function cycleSink(): void {
        const list = root.sinks;
        if (list.length < 2)
            return;
        const at = list.indexOf(root.sink);
        Pipewire.preferredDefaultAudioSink = list[(at + 1 + list.length) % list.length];
    }

    function showSinkOsd(): void {
        if (!root.started || !root.sink?.ready)
            return;
        if (root.volume === root.lastVolume && root.muted === root.lastMuted)
            return;
        root.lastVolume = root.volume;
        root.lastMuted = root.muted;
        Osd.show(root.icon, root.effectiveMuted ? 0 : root.volume);
    }

    function showMicOsd(): void {
        if (!root.started || !root.source?.ready)
            return;
        if (root.micMuted === root.lastMicMuted)
            return;
        root.lastMicMuted = root.micMuted;
        Osd.show(root.micMuted ? Theme.iconMicOff : Theme.iconMic, root.micMuted ? 0 : 1);
    }

    Connections {
        target: root.sink?.audio ?? null

        function onVolumesChanged(): void {
            root.showSinkOsd();
        }

        function onMutedChanged(): void {
            root.showSinkOsd();
        }
    }

    Connections {
        target: root.source?.audio ?? null

        function onMutedChanged(): void {
            root.showMicOsd();
        }
    }
}
