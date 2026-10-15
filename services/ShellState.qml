pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

// Cross-window shell state. Currently: which screen shows the power menu,
// which screen shows the app launcher and which one shows the clipboard
// history (empty string = closed). The IPC targets let scripts toggle them:
//   qs ipc call power toggle
//   qs ipc call launcher toggle
//   qs ipc call clipboard toggle
Singleton {
    id: root

    property string powerMenuScreen: ""
    property string launcherScreen: ""
    property string clipboardScreen: ""

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

        function close(): void {
            root.closeClipboard();
        }
    }
}
