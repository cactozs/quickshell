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
        property string themeMode
        property string fontMode
        property string blurSource
    }

    readonly property bool barHidden: props.barHidden

    // Launcher appearance: fullscreen = icon grid over the whole output,
    // classic = the centered search card (see modules/Launcher.qml).
    readonly property bool launcherFullscreen: props.launcherFullscreen

    // What the compositor blurs behind the acrylic plates ("Блюр" in the
    // settings menu): "wallpaper" = the wallpaper alone, niri's xray and the
    // default; "window" = whatever sits under the plate, windows included. The
    // choice is niri policy, so services/SystemTheme.qml writes it into the
    // niri config and reads it back from there at startup — that file is what
    // carries the setting across a reboot, this property is the live copy.
    // Normalized like the other modes.
    readonly property string blurSource: props.blurSource === "window" ? "window" : "wallpaper"

    function setBlurSource(name: string): void {
        props.blurSource = name === "window" ? "window" : "wallpaper";
    }

    // Style pack for the whole shell: "m3" = M3 Expressive with the matugen
    // palette (default), "blur" = that pack with acrylic backdrops and the
    // compositor blur behind them, "new" = graphite acrylic, "nothing" =
    // opaque graphite with hairline edges and one red accent (see
    // style/Theme.qml). Normalized, so a fresh install or a stale value reads
    // as "m3".
    readonly property string styleMode: props.styleMode === "new" || props.styleMode === "blur" || props.styleMode === "nothing"
        ? props.styleMode
        : "m3"

    function setStyleMode(name: string): void {
        props.styleMode = name === "new" || name === "blur" || name === "nothing" ? name : "m3";
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

    // Theme mode for the whole shell: "dark" (default) or "light". Picks the
    // palette file in style/Theme.qml and, with it, the system theme written by
    // services/SystemTheme.qml. Normalized like the others.
    readonly property string themeMode: props.themeMode === "light" ? "light" : "dark"

    function setThemeMode(name: string): void {
        props.themeMode = name === "light" ? "light" : "dark";
    }

    // UI font: "material" = Google Sans (default, the M3 look), "mono" =
    // JetBrainsMono Nerd Font Mono (see style/Theme.qml). Normalized like the
    // other modes.
    readonly property string fontMode: props.fontMode === "mono" ? "mono" : "material"

    function setFontMode(name: string): void {
        props.fontMode = name === "mono" ? "mono" : "material";
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

        // Theme mode, so scripts can flip it: `qs ipc call settings theme light`.
        function theme(name: string): void {
            root.setThemeMode(name);
        }

        // Blur source, so scripts can flip it: `qs ipc call settings blur window`.
        function blur(name: string): void {
            root.setBlurSource(name);
        }

        // Font family, so scripts can flip it: `qs ipc call settings font mono`.
        function font(name: string): void {
            root.setFontMode(name);
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
