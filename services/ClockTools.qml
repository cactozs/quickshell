pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import QtQuick

// Countdown and stopwatch state for the clock popup. The popup window is torn
// down by LazyOverlay once it closes, so the numbers live here; deadlines are
// absolute (Date.now) so they stay correct through sleep and a config reload.
Singleton {
    id: root

    property double now: Date.now()

    PersistentProperties {
        id: props

        reloadableId: "clockTools"

        property real countdownEnd
        property int countdownPaused: 300000
        property int countdownTotal: 300000
        property real stopwatchStart
        property real stopwatchAccum
    }

    // ---- countdown ---------------------------------------------------------

    readonly property bool countdownRunning: props.countdownEnd > 0

    readonly property int countdownLeftMs: root.countdownRunning
        ? Math.max(0, props.countdownEnd - root.now)
        : props.countdownPaused

    function startCountdown(): void {
        if (root.countdownRunning)
            return;
        const left = root.countdownLeftMs;
        if (left <= 0)
            return;
        root.now = Date.now();
        props.countdownPaused = 0;
        props.countdownEnd = root.now + left;
    }

    function pauseCountdown(): void {
        if (!root.countdownRunning)
            return;
        const left = root.countdownLeftMs;
        props.countdownEnd = 0;
        props.countdownPaused = left;
        root.now = Date.now();
    }

    function toggleCountdown(): void {
        if (root.countdownRunning)
            root.pauseCountdown();
        else
            root.startCountdown();
    }

    function setCountdown(ms: int): void {
        const clamped = Math.max(1000, Math.min(ms, 24 * 3600 * 1000));
        props.countdownEnd = 0;
        props.countdownTotal = clamped;
        props.countdownPaused = clamped;
        root.now = Date.now();
    }

    function resetCountdown(): void {
        props.countdownEnd = 0;
        props.countdownPaused = props.countdownTotal;
        root.now = Date.now();
    }

    // The alarm has to reach the user while the popup is closed, so it is a
    // desktop notification and not something the popup draws.
    function finishCountdown(): void {
        props.countdownEnd = 0;
        props.countdownPaused = props.countdownTotal;
        root.now = Date.now();
        Quickshell.execDetached(["notify-send", "-a", "Quickshell", "-u", "critical",
            I18n.t("Таймер"), I18n.t("Время вышло")]);
        // shortcut: fixed freedesktop theme sound, revisit if the theme is not installed
        Quickshell.execDetached(["paplay", "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"]);
    }

    // ---- stopwatch ---------------------------------------------------------

    readonly property bool stopwatchRunning: props.stopwatchStart > 0

    readonly property real stopwatchElapsedMs: props.stopwatchAccum
        + (root.stopwatchRunning ? Math.max(0, root.now - props.stopwatchStart) : 0)

    // Laps are display-only, so they are not persisted across a reload.
    property var laps: []

    function toggleStopwatch(): void {
        root.now = Date.now();
        if (root.stopwatchRunning) {
            props.stopwatchAccum += root.now - props.stopwatchStart;
            props.stopwatchStart = 0;
        } else {
            props.stopwatchStart = root.now;
        }
    }

    function resetStopwatch(): void {
        props.stopwatchStart = 0;
        props.stopwatchAccum = 0;
        root.laps = [];
        root.now = Date.now();
    }

    function lapStopwatch(): void {
        if (!root.stopwatchRunning)
            return;
        root.laps = [{ "n": root.laps.length + 1, "ms": root.stopwatchElapsedMs }, ...root.laps];
    }

    // ---- tick --------------------------------------------------------------

    // One timer for both tools; the stopwatch wants tenths, a countdown only
    // needs whole seconds.
    Timer {
        interval: root.stopwatchRunning ? 100 : 500
        repeat: true
        running: root.countdownRunning || root.stopwatchRunning

        onTriggered: {
            root.now = Date.now();
            if (root.countdownRunning && root.now >= props.countdownEnd)
                root.finishCountdown();
        }
    }

    // ---- formatting --------------------------------------------------------

    function pad(value: int): string {
        return value < 10 ? "0" + value : "" + value;
    }

    // Countdown rounds up so a fresh 5:00 shows 05:00, not 04:59.
    function format(ms: real, roundUp: bool): string {
        const total = Math.max(0, roundUp ? Math.ceil(ms / 1000) : Math.floor(ms / 1000));
        const seconds = total % 60;
        const minutes = Math.floor(total / 60) % 60;
        const hours = Math.floor(total / 3600);
        return hours > 0
            ? hours + ":" + root.pad(minutes) + ":" + root.pad(seconds)
            : root.pad(minutes) + ":" + root.pad(seconds);
    }

    function formatStopwatch(ms: real): string {
        const total = Math.max(0, Math.floor(ms / 1000));
        const seconds = total % 60;
        const minutes = Math.floor(total / 60) % 60;
        const hours = Math.floor(total / 3600);
        if (hours > 0)
            return hours + ":" + root.pad(minutes) + ":" + root.pad(seconds);
        return root.pad(minutes) + ":" + root.pad(seconds)
            + "." + Math.floor(Math.max(0, ms) / 100) % 10;
    }
}
