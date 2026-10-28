pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

// Cross-window shell state. Currently: which screen shows the quick settings,
// which screen shows the app launcher, which one shows the clipboard history,
// which one shows the notification center, which one shows the weather
// popup, which one shows the clock popup (timer and stopwatch), which one
// shows the settings menu, which one shows the wallpaper manager and which one
// shows the system tray (empty string = closed), plus whether the bar is
// hidden. The IPC targets let scripts toggle them:
//   qs ipc call settings toggle
//   qs ipc call launcher toggle
//   qs ipc call clipboard toggle
//   qs ipc call center toggle
//   qs ipc call clock toggle
//   qs ipc call tray toggle
//   qs ipc call wallpaper toggle
//   qs ipc call bar toggle
Singleton {
    id: root

    property string quickSettingsScreen: ""
    property string launcherScreen: ""
    property string clipboardScreen: ""
    property string notificationScreen: ""
    property string weatherScreen: ""
    property string clockScreen: ""
    property string systemScreen: ""
    property string settingsScreen: ""
    property string wallpaperScreen: ""
    property string trayScreen: ""
    property string petScreen: ""

    // Settings live in shell-state.json: PersistentProperties survives a config
    // reload but not the process restarting at login. The read below is
    // synchronous so the adapter holds the stored values before Theme and I18n
    // read them, otherwise the first frame is the default theme.
    FileView {
        id: stateFile

        path: Qt.resolvedUrl("../shell-state.json")
        preload: false
        blockAllReads: true
        blockWrites: true
        blockLoading: true
        printErrors: false

        Component.onCompleted: text()
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: props

            property bool barHidden
            property bool launcherFullscreen
            property string styleMode
            property string barPosition
            property string panelStyle
            property string panelWidth
            property string colorScheme
            property string themeMode
            property string fontMode
            property string animationMode
            property string niriAnimation
            property string windowRadius
            property string blurSource
            property string ambient
            property string language
            property string themeAppsOff
            // Pet: stored negative so a missing key keeps the bar button on.
            property bool petDisabled
            property bool petPlaced
            property int petX
            property int petY
        }
    }

    // A monitor can disappear while its overlay is open; the screen string
    // would then point at an output no window can ever appear on.
    Connections {
        target: Quickshell

        function onScreensChanged(): void {
            if (root.quickSettingsScreen !== "" && !root.screenKnown(root.quickSettingsScreen))
                root.quickSettingsScreen = "";
            if (root.launcherScreen !== "" && !root.screenKnown(root.launcherScreen))
                root.launcherScreen = "";
            if (root.clipboardScreen !== "" && !root.screenKnown(root.clipboardScreen))
                root.clipboardScreen = "";
            if (root.notificationScreen !== "" && !root.screenKnown(root.notificationScreen))
                root.notificationScreen = "";
            if (root.weatherScreen !== "" && !root.screenKnown(root.weatherScreen))
                root.weatherScreen = "";
            if (root.clockScreen !== "" && !root.screenKnown(root.clockScreen))
                root.clockScreen = "";
            if (root.systemScreen !== "" && !root.screenKnown(root.systemScreen))
                root.systemScreen = "";
            if (root.settingsScreen !== "" && !root.screenKnown(root.settingsScreen))
                root.settingsScreen = "";
            if (root.wallpaperScreen !== "" && !root.screenKnown(root.wallpaperScreen))
                root.wallpaperScreen = "";
            if (root.trayScreen !== "" && !root.screenKnown(root.trayScreen))
                root.trayScreen = "";
            if (root.petScreen !== "" && !root.screenKnown(root.petScreen))
                root.petScreen = "";
        }
    }

    readonly property bool barHidden: props.barHidden

    // Launcher appearance: fullscreen = icon grid over the whole output,
    // classic = the centered search card (see modules/Launcher.qml).
    readonly property bool launcherFullscreen: props.launcherFullscreen

    // What the compositor blurs behind the acrylic plates ("Блюр" in the
    // settings menu): "wallpaper" = the wallpaper alone, niri's xray and the
    // default; "window" = whatever sits under the plate, windows included. The
    // choice is niri policy, so services/SystemTheme.qml writes it into the
    // niri config and reads it back from there at startup — that file stays the
    // record, this property is the live copy.
    // Normalized like the other modes.
    readonly property string blurSource: props.blurSource === "window" ? "window" : "wallpaper"

    function setBlurSource(name: string): void {
        props.blurSource = name === "window" ? "window" : "wallpaper";
    }

    // Screen edge the bar is docked to: "top" (default), "bottom", "left" or
    // "right". The horizontal edges keep the strip; a side edge turns it into a
    // vertical rail. See modules/Bar.qml. Normalized like the other modes.
    readonly property string barPosition: props.barPosition === "bottom"
        || props.barPosition === "left" || props.barPosition === "right"
        ? props.barPosition
        : "top"

    function setBarPosition(name: string): void {
        props.barPosition = name === "bottom" || name === "left" || name === "right"
            ? name
            : "top";
    }

    // Bar layout: "islands" = the three floating islands (default), "island" =
    // one floating plate, "panel" = that plate flush to the screen walls. See
    // modules/Bar.qml. Normalized like the other modes.
    readonly property string panelStyle: props.panelStyle === "island" || props.panelStyle === "panel"
        ? props.panelStyle
        : "islands"

    function setPanelStyle(name: string): void {
        props.panelStyle = name === "island" || name === "panel" ? name : "islands";
    }

    // Width of the single plate (ignored while panelStyle is "islands"):
    // "full" = stretched across the output, "fit" = hugging the content.
    readonly property string panelWidth: props.panelWidth === "fit" ? "fit" : "full"

    function setPanelWidth(name: string): void {
        props.panelWidth = name === "fit" ? "fit" : "full";
    }

    // Seasonal desktop dressing: "off" (default) or "xmas" (falling snow and
    // drifts on the wallpaper surface, see modules/Ambient.qml). Normalized.
    readonly property string ambient: props.ambient === "xmas" ? "xmas" : "off"

    function setAmbient(name: string): void {
        props.ambient = name === "xmas" ? "xmas" : "off";
    }

    // Style pack for the whole shell: "m3" = M3 Expressive with the matugen
    // palette (default), "blur" = that pack with acrylic backdrops and the
    // compositor blur behind them, "new" = graphite acrylic, "nothing" =
    // opaque graphite with hairline edges and one red accent, "newNothing" =
    // that graphite with the New acrylic dressing, "old" = retro gray/charcoal
    // chrome with square corners and bevels (see style/Theme.qml).
    // Normalized, so a fresh install or a stale value reads as "m3".
    readonly property string styleMode: props.styleMode === "new" || props.styleMode === "blur"
        || props.styleMode === "nothing" || props.styleMode === "newNothing" || props.styleMode === "old"
        ? props.styleMode
        : "m3"

    function setStyleMode(name: string): void {
        props.styleMode = name === "new" || name === "blur" || name === "nothing"
            || name === "newNothing" || name === "old"
            ? name
            : "m3";
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
    // JetBrainsMono Nerd Font Mono, "old" = Nimbus Mono PS (see style/Theme.qml).
    // Normalized like the other modes.
    readonly property string fontMode: props.fontMode === "mono" || props.fontMode === "old"
        ? props.fontMode
        : "material"

    function setFontMode(name: string): void {
        props.fontMode = name === "mono" || name === "old" ? name : "material";
    }

    // Motion of the shell itself: "normal" (default, the M3 timings), "slow"
    // (everything stretched, style/Theme.qml) or "off" (no shell motion at all).
    // Normalized like the other modes.
    readonly property string animationMode: props.animationMode === "slow"
        || props.animationMode === "off"
        ? props.animationMode
        : "normal"

    function setAnimationMode(name: string): void {
        props.animationMode = name === "slow" || name === "off" ? name : "normal";
    }

    // Motion of the compositor, a separate choice: "normal" (default) writes
    // nothing into the generated niri file, so niri keeps the animations block
    // from the user's own animations.kdl; "slow" writes `slowdown 1.0` and "off"
    // writes `animations { off }`. See services/SystemTheme.qml.
    readonly property string niriAnimation: props.niriAnimation === "slow"
        || props.niriAnimation === "off"
        ? props.niriAnimation
        : "normal"

    function setNiriAnimation(name: string): void {
        props.niriAnimation = name === "slow" || name === "off" ? name : "normal";
    }

    // Corner rounding of the compositor's windows ("Скругление окон"): -1 writes
    // nothing, so the user's own window rules keep their value; 0-24 is written
    // as `geometry-corner-radius` into the generated niri file. Kept as a string
    // in the adapter because an absent key must read as unset, and an int would
    // default to 0 (square corners). See services/SystemTheme.qml.
    readonly property int windowRadius: {
        const value = parseInt(props.windowRadius, 10);
        return isNaN(value) || value < 0 || value > 24 ? -1 : value;
    }

    function setWindowRadius(value: int): void {
        props.windowRadius = value < 0 || value > 24 ? "" : String(Math.round(value));
    }

    // UI language: "ru" (default, the source strings in services/I18n.qml),
    // "en" or "de". Normalized like the other modes.
    readonly property string language: props.language === "en" || props.language === "de"
        ? props.language
        : "ru"

    function setLanguage(name: string): void {
        props.language = name === "en" || name === "de" ? name : "ru";
    }

    // Desktop targets whose colors services/SystemTheme.qml rewrites: "gtk"
    // (GTK3/GTK4 + the gsettings color-scheme), "qt" (qt6ct), "ghostty" and
    // "niri" (borders and focus ring). Stored as the ids that are off, so a
    // missing key keeps every target on — the behavior before the setting.
    // A disabled target is simply not written: its file keeps the last colors.
    readonly property string themeAppsOff: props.themeAppsOff

    function themeAppEnabled(id: string): bool {
        const ids = root.themeAppsOff.split(",");
        for (let i = 0; i < ids.length; i++) {
            if (ids[i] === id)
                return false;
        }
        return true;
    }

    function setThemeApp(id: string, enabled: bool): void {
        const ids = root.themeAppsOff.split(",").filter(name => name !== "" && name !== id);
        if (!enabled)
            ids.push(id);
        props.themeAppsOff = ids.join(",");
    }

    // Desktop pet. The setting stores the negative, so a missing key keeps the
    // bar button on; petPlaced tells an untouched first run from a drag to 0,0.
    readonly property bool petEnabled: !props.petDisabled
    readonly property bool petPlaced: props.petPlaced
    readonly property int petX: props.petX
    readonly property int petY: props.petY
    // Read straight from the environment; the shell never stores the key.
    readonly property string nvidiaKey: String(Quickshell.env("NVIDIA_API_KEY") ?? "").trim()

    function setPetEnabled(enabled: bool): void {
        props.petDisabled = !enabled;
        if (!enabled)
            root.petScreen = "";
    }

    function setPetPosition(x: int, y: int): void {
        props.petX = x;
        props.petY = y;
        props.petPlaced = true;
    }

    // Resolve an IPC/screen name against the live output list. Unknown names
    // (a stale output, a typo) fall back to the first screen instead of
    // leaving an overlay keyed to a screen that does not exist.
    function screenKnown(name: string): bool {
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; i++) {
            if (screens[i].name === name)
                return true;
        }
        return false;
    }

    function resolveScreen(name: string): string {
        const screens = Quickshell.screens;
        if (name !== "" && root.screenKnown(name))
            return name;
        return screens.length > 0 ? screens[0].name : "";
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
        root.clockScreen = "";
        root.weatherScreen = root.weatherScreen === screenName ? "" : screenName;
    }

    function closeWeather(): void {
        root.weatherScreen = "";
    }

    function toggleClock(screenName: string): void {
        root.weatherScreen = "";
        root.clockScreen = root.clockScreen === screenName ? "" : screenName;
    }

    function closeClock(): void {
        root.clockScreen = "";
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

    function toggleTray(screenName: string): void {
        root.trayScreen = root.trayScreen === screenName ? "" : screenName;
    }

    function closeTray(): void {
        root.trayScreen = "";
    }

    function togglePet(screenName: string): void {
        root.petScreen = root.petScreen === screenName ? "" : screenName;
    }

    function closePet(): void {
        root.petScreen = "";
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
            root.toggleSettings(root.resolveScreen(""));
        }

        // Toggles on a specific screen; niri keybinds pass the focused output.
        function toggleOn(screenName: string): void {
            root.toggleSettings(root.resolveScreen(screenName));
        }

        function close(): void {
            root.closeSettings();
        }

        // Launcher view, so scripts can flip it: `qs ipc call settings launcherView true`.
        function launcherView(fullscreen: bool): void {
            root.setLauncherFullscreen(fullscreen);
        }

        // Style pack, so scripts can flip it: `qs ipc call settings style new`.
        function style(name: string): void {
            root.setStyleMode(name);
        }

        // Docked edge, so scripts can move it: `qs ipc call settings barposition left`.
        function barposition(name: string): void {
            root.setBarPosition(name);
        }

        // Bar layout, so scripts can flip it: `qs ipc call settings panel island`.
        function panel(name: string): void {
            root.setPanelStyle(name);
        }

        // Plate width, so scripts can flip it: `qs ipc call settings panelwidth fit`.
        function panelwidth(name: string): void {
            root.setPanelWidth(name);
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

        // Ambient dressing, so scripts can flip it: `qs ipc call settings ambient xmas`.
        function ambient(name: string): void {
            root.setAmbient(name);
        }

        // Font family, so scripts can flip it: `qs ipc call settings font mono`.
        function font(name: string): void {
            root.setFontMode(name);
        }

        // Motion of the shell, so scripts can flip it: `qs ipc call settings animations off`.
        function animations(name: string): void {
            root.setAnimationMode(name);
        }

        // Motion of niri: `qs ipc call settings nirianimations off`.
        function nirianimations(name: string): void {
            root.setNiriAnimation(name);
        }

        // Window corner radius: `qs ipc call settings windowsradius 16`.
        // parseInt can yield NaN, which an `int` parameter would coerce to 0.
        function windowsradius(name: string): void {
            const value = parseInt(name, 10);
            root.setWindowRadius(isNaN(value) ? -1 : value);
        }

        // UI language, so scripts can flip it: `qs ipc call settings language en`.
        function language(name: string): void {
            root.setLanguage(name);
        }

        // Desktop color target on/off: `qs ipc call settings app ghostty false`.
        function app(id: string, enabled: bool): void {
            root.setThemeApp(id, enabled);
        }
    }

    IpcHandler {
        target: "wallpaper"

        // Opens on the first screen; useful for testing and scripted use.
        function toggle(): void {
            root.toggleWallpaper(root.resolveScreen(""));
        }

        // Toggles on a specific screen; niri keybinds pass the focused output.
        function toggleOn(screenName: string): void {
            root.toggleWallpaper(root.resolveScreen(screenName));
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
            else
                Wallpapers.pendingRandom = true;
        }
    }

    IpcHandler {
        target: "launcher"

        // Opens on the first screen; useful for testing and scripted use.
        function toggle(): void {
            root.toggleLauncher(root.resolveScreen(""));
        }

        // Toggles on a specific screen; niri keybinds pass the focused output.
        function toggleOn(screenName: string): void {
            root.toggleLauncher(root.resolveScreen(screenName));
        }

        function close(): void {
            root.closeLauncher();
        }
    }

    IpcHandler {
        target: "clipboard"

        // Opens on the first screen; useful for testing and scripted use.
        function toggle(): void {
            root.toggleClipboard(root.resolveScreen(""));
        }

        // Toggles on a specific screen; niri keybinds pass the focused output.
        function toggleOn(screenName: string): void {
            root.toggleClipboard(root.resolveScreen(screenName));
        }

        function close(): void {
            root.closeClipboard();
        }
    }

    IpcHandler {
        target: "center"

        // Opens on the first screen; useful for testing and scripted use.
        function toggle(): void {
            root.toggleNotificationCenter(root.resolveScreen(""));
        }

        // Toggles on a specific screen; niri keybinds pass the focused output.
        function toggleOn(screenName: string): void {
            root.toggleNotificationCenter(root.resolveScreen(screenName));
        }

        function close(): void {
            root.closeNotificationCenter();
        }
    }

    IpcHandler {
        target: "weather"

        // Opens on the first screen; useful for testing and scripted use.
        function toggle(): void {
            root.toggleWeather(root.resolveScreen(""));
        }

        // Toggles on a specific screen; niri keybinds pass the focused output.
        function toggleOn(screenName: string): void {
            root.toggleWeather(root.resolveScreen(screenName));
        }

        function close(): void {
            root.closeWeather();
        }
    }

    IpcHandler {
        target: "clock"

        // Opens on the first screen; useful for testing and scripted use.
        function toggle(): void {
            root.toggleClock(root.resolveScreen(""));
        }

        // Toggles on a specific screen; niri keybinds pass the focused output.
        function toggleOn(screenName: string): void {
            root.toggleClock(root.resolveScreen(screenName));
        }

        function close(): void {
            root.closeClock();
        }
    }

    IpcHandler {
        target: "system"

        // Opens on the first screen; useful for testing and scripted use.
        function toggle(): void {
            root.toggleSystem(root.resolveScreen(""));
        }

        // Toggles on a specific screen; niri keybinds pass the focused output.
        function toggleOn(screenName: string): void {
            root.toggleSystem(root.resolveScreen(screenName));
        }

        function close(): void {
            root.closeSystem();
        }
    }

    IpcHandler {
        target: "tray"

        // Opens on the first screen; useful for testing and scripted use.
        function toggle(): void {
            root.toggleTray(root.resolveScreen(""));
        }

        // Toggles on a specific screen; niri keybinds pass the focused output.
        function toggleOn(screenName: string): void {
            root.toggleTray(root.resolveScreen(screenName));
        }

        function close(): void {
            root.closeTray();
        }
    }

    IpcHandler {
        target: "pet"

        // Opens on the first screen; useful for testing and scripted use.
        function toggle(): void {
            root.togglePet(root.resolveScreen(""));
        }

        // Toggles on a specific screen; niri keybinds pass the focused output.
        function toggleOn(screenName: string): void {
            root.togglePet(root.resolveScreen(screenName));
        }

        function close(): void {
            root.closePet();
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
