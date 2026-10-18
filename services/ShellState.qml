pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

// Cross-window shell state. Currently: which screen shows the quick settings,
// which screen shows the app launcher, which one shows the clipboard history,
// which one shows the notification center, which one shows the weather
// popup, which one shows the settings menu and which one shows the wallpaper
// manager (empty string = closed), plus whether the bar is hidden. The IPC
// targets let scripts toggle them:
//   qs ipc call settings toggle
//   qs ipc call launcher toggle
//   qs ipc call clipboard toggle
//   qs ipc call center toggle
//   qs ipc call wallpaper toggle
//   qs ipc call bar toggle
Singleton {
    id: root

    property string quickSettingsScreen: ""
    property string launcherScreen: ""
    property string clipboardScreen: ""
    property string notificationScreen: ""
    property string weatherScreen: ""
    property string systemScreen: ""
    property string settingsScreen: ""
    property string wallpaperScreen: ""

    // Carried in-memory across config reloads, so a hidden bar stays hidden
    // while editing the shell.
    PersistentProperties {
        id: props
        reloadableId: "shell-state"
        property bool barHidden
        property bool launcherFullscreen
        property string styleMode
        property string colorScheme
    }

    readonly property bool barHidden: props.barHidden

    // Launcher appearance: fullscreen = icon grid over the whole output,
    // classic = the centered search card (see modules/Launcher.qml).
    readonly property bool launcherFullscreen: props.launcherFullscreen

    // Style pack for the whole shell: "m3" = M3 Expressive with the matugen
    // palette (default), "new" = graphite acrylic (see style/Theme.qml).
    // Normalized, so a fresh install or a stale value reads as "m3".
    readonly property string styleMode: props.styleMode === "new" ? "new" : "m3"

    function setStyleMode(name: string): void {
        props.styleMode = name === "new" ? "new" : "m3";
    }

    // Palette source for the whole shell: "matugen" = generated from the
    // wallpaper (default), "oled" = strict black/white, "gruvbox" = Gruvbox
    // dark (see style/Theme.qml). Normalized like styleMode.
    readonly property string colorScheme: props.colorScheme === "oled" || props.colorScheme === "gruvbox"
        ? props.colorScheme
        : "matugen"

    function setColorScheme(name: string): void {
        props.colorScheme = name === "oled" || name === "gruvbox" ? name : "matugen";
    }

    function toggleQuickSettings(screenName: string): void {
        root.quickSettingsScreen = root.quickSettingsScreen === screenName ? "" : screenName;
    }

    function closeQuickSettings(): void {
        root.quickSettingsScreen = "";
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

    function toggleWeather(screenName: string): void {
        root.weatherScreen = root.weatherScreen === screenName ? "" : screenName;
    }

    function closeWeather(): void {
        root.weatherScreen = "";
    }

    function toggleSystem(screenName: string): void {
        root.systemScreen = root.systemScreen === screenName ? "" : screenName;
    }

    function closeSystem(): void {
        root.systemScreen = "";
    }

    function toggleSettings(screenName: string): void {
        root.settingsScreen = root.settingsScreen === screenName ? "" : screenName;
    }

    function closeSettings(): void {
        root.settingsScreen = "";
    }

    function toggleWallpaper(screenName: string): void {
        root.wallpaperScreen = root.wallpaperScreen === screenName ? "" : screenName;
    }

    function closeWallpaper(): void {
        root.wallpaperScreen = "";
    }

    function setLauncherFullscreen(value: bool): void {
        props.launcherFullscreen = value;
    }

    function toggleBar(): void {
        props.barHidden = !props.barHidden;
    }

    IpcHandler {
        target: "settings"

        // Opens on the first screen; useful for testing and scripted use.
        function toggle(): void {
            const screens = Quickshell.screens;
            root.toggleQuickSettings(screens.length > 0 ? screens[0].name : "");
        }

        // Toggles on a specific screen; niri keybinds pass the focused output.
        function toggleOn(screenName: string): void {
            const screens = Quickshell.screens;
            root.toggleQuickSettings(screenName !== "" ? screenName : (screens.length > 0 ? screens[0].name : ""));
        }

        function close(): void {
            root.closeQuickSettings();
        }

        // Launcher view, so scripts can flip it: `qs ipc call settings launcherView true`.
        function launcherView(fullscreen: bool): void {
            root.setLauncherFullscreen(fullscreen);
        }

        // Style pack, so scripts can flip it: `qs ipc call settings style new`.
        function style(name: string): void {
            root.setStyleMode(name);
        }

        // Color scheme, so scripts can flip it: `qs ipc call settings colorscheme oled`.
        function colorscheme(name: string): void {
            root.setColorScheme(name);
        }
    }

    IpcHandler {
        target: "wallpaper"

        // Opens on the first screen; useful for testing and scripted use.
        function toggle(): void {
            const screens = Quickshell.screens;
            root.toggleWallpaper(screens.length > 0 ? screens[0].name : "");
        }

        // Toggles on a specific screen; niri keybinds pass the focused output.
        function toggleOn(screenName: string): void {
            const screens = Quickshell.screens;
            root.toggleWallpaper(screenName !== "" ? screenName : (screens.length > 0 ? screens[0].name : ""));
        }

        function close(): void {
            root.closeWallpaper();
        }

        // Applies a random wallpaper without opening the manager, so it can be
        // bound to a niri keybind: `qs ipc call wallpaper random`.
        function random(): void {
            const path = Wallpapers.randomPath();
            if (path !== "")
                Wallpapers.apply(path);
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
