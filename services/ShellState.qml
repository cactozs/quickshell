pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

// Cross-window shell state. Currently: which screen shows the power menu,
// which screen shows the app launcher, which one shows the clipboard history
// and which one shows the notification center (empty string = closed), plus
// whether the bar is hidden. The IPC targets let scripts toggle them:
//   qs ipc call power toggle
//   qs ipc call launcher toggle
//   qs ipc call clipboard toggle
//   qs ipc call center toggle
//   qs ipc call bar toggle
Singleton {
    id: root

    property string powerMenuScreen: ""
    property string launcherScreen: ""
    property string clipboardScreen: ""
    property string notificationScreen: ""

    // Carried in-memory across config reloads, so a hidden bar stays hidden
    // while editing the shell.
    PersistentProperties {
        id: props
        reloadableId: "shell-state"
        property bool barHidden
    }

    readonly property bool barHidden: props.barHidden

    function togglePowerMenu(screenName: string): void {
        root.powerMenuScreen = root.powerMenuScreen === screenName ? "" : screenName;
    }

    function closePowerMenu(): void {
        root.powerMenuScreen = "";
    }

    function toggleLauncher(screenName: string): void {
        root.launcherScreen = root.launcherScreen === screenName ? "" : screenName;
    }

    function closeLauncher(): void {
        root.launcherScreen = "";
    }

    function toggleClipboard(screenName: string): void {
        root.clipboardScreen = root.clipboardScreen === screenName ? "" : screenName;
    }

    function closeClipboard(): void {
        root.clipboardScreen = "";
    }

    function toggleNotificationCenter(screenName: string): void {
        root.notificationScreen = root.notificationScreen === screenName ? "" : screenName;
    }

    function closeNotificationCenter(): void {
        root.notificationScreen = "";
    }

    function toggleBar(): void {
        props.barHidden = !props.barHidden;
    }

    IpcHandler {
        target: "power"

        // Opens on the first screen; useful for testing and scripted use.
        function toggle(): void {
            const screens = Quickshell.screens;
            root.togglePowerMenu(screens.length > 0 ? screens[0].name : "");
        }
    }

    IpcHandler {
        target: "launcher"

        // Opens on the first screen; useful for testing and scripted use.
        function toggle(): void {
            const screens = Quickshell.screens;
            root.toggleLauncher(screens.length > 0 ? screens[0].name : "");
        }

        // Toggles on a specific screen; niri keybinds pass the focused output.
        function toggleOn(screenName: string): void {
            const screens = Quickshell.screens;
            root.toggleLauncher(screenName !== "" ? screenName : (screens.length > 0 ? screens[0].name : ""));
        }

        function close(): void {
            root.closeLauncher();
        }
    }

    IpcHandler {
        target: "clipboard"

        // Opens on the first screen; useful for testing and scripted use.
        function toggle(): void {
            const screens = Quickshell.screens;
            root.toggleClipboard(screens.length > 0 ? screens[0].name : "");
        }

        // Toggles on a specific screen; niri keybinds pass the focused output.
        function toggleOn(screenName: string): void {
            const screens = Quickshell.screens;
            root.toggleClipboard(screenName !== "" ? screenName : (screens.length > 0 ? screens[0].name : ""));
        }

        function close(): void {
            root.closeClipboard();
        }
    }

    IpcHandler {
        target: "center"

        // Opens on the first screen; useful for testing and scripted use.
        function toggle(): void {
            const screens = Quickshell.screens;
            root.toggleNotificationCenter(screens.length > 0 ? screens[0].name : "");
        }

        // Toggles on a specific screen; niri keybinds pass the focused output.
        function toggleOn(screenName: string): void {
            const screens = Quickshell.screens;
            root.toggleNotificationCenter(screenName !== "" ? screenName : (screens.length > 0 ? screens[0].name : ""));
        }

        function close(): void {
            root.closeNotificationCenter();
        }
    }

    IpcHandler {
        target: "bar"

        // Mod+P: hides or shows the bar on every screen.
        function toggle(): void {
            root.toggleBar();
        }
    }
}
