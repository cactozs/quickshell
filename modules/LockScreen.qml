pragma ComponentBehavior: Bound

import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "../services"

// Built-in lock screen: ext-session-lock, the idle timers that start it, the
// monitor power-off and the pre-suspend hook. `qs ipc call lock lock` locks;
// nothing unlocks but PAM (services/LockAuth.qml).
QtObject {
    id: root

    // Wallpaper reported by `awww query`; "" until it arrives.
    property string wallpaper: ""

    function lock(): void {
        if (sessionLock.locked)
            return;
        LockAuth.reset();
        wallpaperProc.running = true;
        sessionLock.locked = true;
    }

    // WlSessionLock's default property is `surface`, so this file cannot use it
    // as the root: the idle monitors and IPC would be taken for lock surfaces.
    property WlSessionLock sessionLock: WlSessionLock {
        id: lock

        // Keeps the lock across a config reload instead of dropping it.
        reloadableId: "quickshell-lock"

        surface: Component {
            WlSessionLockSurface {
                LockSurface {
                    anchors.fill: parent
                    wallpaper: root.wallpaper
                }
            }
        }
    }

    property IdleMonitor idleLock: IdleMonitor {
        timeout: 300

        onIsIdleChanged: {
            if (isIdle)
                root.lock();
        }
    }

    property IdleMonitor idleMonitors: IdleMonitor {
        timeout: 450

        onIsIdleChanged: {
            if (isIdle)
                Niri.powerOffMonitors();
        }
    }

    // logind waits on a delay inhibitor at sleep time, so the lock is already up
    // when the screen comes back. PrepareForSleep(true) locks and releases it,
    // (false) on resume re-arms it.
    property Process sleepInhibitor: Process {
        command: ["systemd-inhibit", "--what=sleep", "--mode=delay",
                  "--who=quickshell", "--why=Lock screen", "sleep", "infinity"]
        running: true
    }

    property Process sleepWatcher: Process {
        command: ["dbus-monitor", "--system",
                  "type='signal',interface='org.freedesktop.login1.Manager',member='PrepareForSleep'"]
        running: true

        stdout: SplitParser {
            property bool armed: false

            onRead: line => {
                if (line.includes("member=PrepareForSleep")) {
                    armed = true;
                    return;
                }
                if (!armed)
                    return;
                armed = false;
                if (line.trim() === "boolean true") {
                    root.lock();
                    root.sleepRelease.start();
                } else {
                    root.sleepInhibitor.running = true;
                }
            }
        }

        onExited: root.sleepRestart.restart()
    }

    // One frame for niri to map the lock surfaces before logind may freeze us.
    property Timer sleepRelease: Timer {
        interval: 150

        onTriggered: root.sleepInhibitor.running = false
    }

    property Timer sleepRestart: Timer {
        interval: 2000

        onTriggered: root.sleepWatcher.running = true
    }

    property Process wallpaperProc: Process {
        command: ["awww", "query"]

        stdout: StdioCollector {
            onStreamFinished: {
                const match = text.match(/currently displaying: image: (.+)/);
                root.wallpaper = match ? match[1].trim() : "";
            }
        }
    }

    property IpcHandler ipc: IpcHandler {
        target: "lock"

        // Locking only. Unlocking is PAM-only by design, so no IPC for it.
        function lock(): void {
            root.lock();
        }
    }

    property Connections auth: Connections {
        target: LockAuth

        function onUnlocked(): void {
            root.sessionLock.locked = false;
        }
    }
}
