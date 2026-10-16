pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

// Niri IPC bridge: live state from `niri msg event-stream` + one-shot queries.
Singleton {
    id: root

    // Emitted when the active keyboard layout index actually changes.
    signal layoutSwitched()

    // Raw objects straight from niri IPC (JSON).
    property var workspaces: []
    property var windows: []
    property var keyboardLayouts: ({ names: [], currentIdx: 0 })

    // Bar workspace chips: the Repeater rebuilds every delegate whenever the
    // workspace list is reassigned, so "new chip" and "just activated" cannot
    // be told apart on the delegate side. The service arms the activation pop
    // here (consumed once by the chip that reacts) and remembers first-seen
    // ids for the entrance animation.
    property int poppingWorkspaceId: -1
    property var seenWorkspaceIds: ({})

    function consumeWorkspacePop(id: int): bool {
        if (root.poppingWorkspaceId !== id)
            return false;
        root.poppingWorkspaceId = -1;
        return true;
    }

    function markWorkspaceSeen(id: int): bool {
        if (root.seenWorkspaceIds[id] === true)
            return false;
        const next = Object.assign({}, root.seenWorkspaceIds);
        next[id] = true;
        root.seenWorkspaceIds = next;
        return true;
    }

    readonly property var focusedWindow: {
        for (const w of windows)
            if (w.is_focused) return w;
        return null;
    }

    readonly property string currentLayout: layoutShortName(
        keyboardLayouts.names[keyboardLayouts.currentIdx] ?? "")

    function workspacesFor(output: string): var {
        return workspaces
            .filter(w => w.output === output)
            .sort((a, b) => a.idx - b.idx);
    }

    // waybar niri/language: format-en "us", format-ru "ru".
    function layoutShortName(name: string): string {
        if (name === "") return "";
        const known = { "English (US)": "us", "Russian": "ru" };
        return known[name] ?? name.slice(0, 2).toLowerCase();
    }

    function focusWorkspace(idx: number): void {
        Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", String(idx)]);
    }

    function focusWorkspaceDown(): void {
        Quickshell.execDetached(["niri", "msg", "action", "focus-workspace-down"]);
    }

    function focusWorkspaceUp(): void {
        Quickshell.execDetached(["niri", "msg", "action", "focus-workspace-up"]);
    }

    function handleLine(line: string): void {
        if (line === "") return;
        let ev = null;
        try {
            ev = JSON.parse(line);
        } catch (e) {
            return;
        }
        if (!ev || typeof ev !== "object") return;

        if (ev.WorkspacesChanged) {
            root.workspaces = ev.WorkspacesChanged.workspaces;
        } else if (ev.WindowsChanged) {
            root.windows = ev.WindowsChanged.windows;
        } else if (ev.WindowOpenedOrChanged) {
            // WindowsChanged arrives only when the stream connects; afterwards
            // niri sends per-window events. A focused window clears the flag
            // on every other one, same rule niri applies internally.
            const win = ev.WindowOpenedOrChanged.window;
            const next = root.windows.filter(w => w.id !== win.id);
            next.push(win);
            root.windows = win.is_focused
                ? next.map(w => Object.assign({}, w, { is_focused: w.id === win.id }))
                : next;
        } else if (ev.WindowClosed) {
            root.windows = root.windows.filter(w => w.id !== ev.WindowClosed.id);
        } else if (ev.KeyboardLayoutsChanged) {
            const kl = ev.KeyboardLayoutsChanged.keyboard_layouts;
            root.keyboardLayouts = { names: kl.names ?? [], currentIdx: kl.current_idx ?? 0 };
        } else if (ev.KeyboardLayoutSwitched) {
            // Active layout changed (Win+Space / switch-layout): only the
            // index moves, the list stays the same.
            const idx = ev.KeyboardLayoutSwitched.idx;
            const changed = idx !== root.keyboardLayouts.currentIdx;
            root.keyboardLayouts = {
                names: root.keyboardLayouts.names,
                currentIdx: idx
            };
            // No names yet (startup race) means the badge would show empty.
            if (changed && root.keyboardLayouts.names.length > 0)
                root.layoutSwitched();
        } else if (ev.WorkspaceActivated) {
            root.poppingWorkspaceId = ev.WorkspaceActivated.id;
            refreshWorkspaces();
        } else if (ev.WindowFocusChanged) {
            const id = ev.WindowFocusChanged.id;
            root.windows = root.windows.map(w =>
                Object.assign({}, w, { is_focused: id !== null && w.id === id }));
        }
    }

    function refreshWorkspaces(): void {
        if (!wsProc.running) wsProc.running = true;
    }

    function refreshWindows(): void {
        if (!winProc.running) winProc.running = true;
    }

    function refreshKeyboardLayouts(): void {
        if (!kbProc.running) kbProc.running = true;
    }

    Process {
        id: streamProc
        command: ["niri", "msg", "-j", "event-stream"]
        running: true

        stdout: SplitParser {
            onRead: line => root.handleLine(line)
        }

        onExited: restartTimer.restart()
    }

    Timer {
        id: restartTimer
        interval: 1000
        onTriggered: streamProc.running = true
    }

    Process {
        id: wsProc
        command: ["niri", "msg", "-j", "workspaces"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.workspaces = JSON.parse(text);
                } catch (e) {
                    console.warn("niri workspaces parse failed:", e);
                }
            }
        }
    }

    Process {
        id: winProc
        command: ["niri", "msg", "-j", "windows"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.windows = JSON.parse(text);
                } catch (e) {
                    console.warn("niri windows parse failed:", e);
                }
            }
        }
    }

    Process {
        id: kbProc
        command: ["niri", "msg", "-j", "keyboard-layouts"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const kl = JSON.parse(text);
                    root.keyboardLayouts = {
                        names: kl.names ?? [],
                        currentIdx: kl.current_idx ?? 0
                    };
                } catch (e) {
                    console.warn("niri keyboard-layouts parse failed:", e);
                }
            }
        }
    }

    Component.onCompleted: {
        refreshWorkspaces();
        refreshWindows();
        refreshKeyboardLayouts();
    }
}
