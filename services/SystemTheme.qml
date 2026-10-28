pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import "../style"

// Mirrors the shell palette onto the rest of the desktop: GTK, Qt (qt6ct),
// ghostty and the niri border follow the theme picked in the settings menu,
// light/dark included, and the fixed Oled/Gruvbox packs too — the desktop never
// drifts from the bar. Colors come from Theme.* and not from matugen, which
// only knows the wallpaper palette.
//
// A file is written only when its content actually changed, so file watchers
// (GTK, niri) are not woken for nothing. Generated content is deterministic, so
// a hand-edited file is simply regenerated on the next theme change.
//
//   $XDG_CONFIG_HOME/gtk-3.0/gtk.css             GTK3 colors
//   $XDG_CONFIG_HOME/gtk-4.0/gtk.css             GTK4 colors + libadwaita :root vars
//   $XDG_CONFIG_HOME/ghostty/themes/Quickshell   theme file (`theme = Quickshell`)
//   $XDG_CONFIG_HOME/qt6ct/colors/matugen.conf   Qt palette (`color_scheme_path`)
//   $XDG_CONFIG_HOME/niri/quickshell.kdl         border/focus-ring colors + blur source
//                                                (needs `include "quickshell.kdl"` in
//                                                config.kdl, after layout.kdl)
//
// $XDG_CONFIG_HOME defaults to ~/.config; see SystemTheme.configHome.
//
// plus `gsettings ... color-scheme`, which is what libadwaita apps read for
// their own light/dark base, and a ghostty config reload so a running terminal
// recolors without a restart. The one-time plumbing (ghostty theme name, the
// qt6ct path, the niri include) is documented in README.md. Which of the four
// targets are written at all is the "Приложения" tab in the settings menu
// (ShellState.themeAppsOff): a disabled target is skipped and keeps its file.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")

    // XDG config home: GTK, ghostty, qt6ct and niri follow it instead of
    // assuming ~/.config. Defaults to ~/.config.
    readonly property string configHome: {
        const xdg = Quickshell.env("XDG_CONFIG_HOME");
        return xdg && xdg.length > 0 ? xdg : root.home + "/.config";
    }

    readonly property bool light: Theme.light

    // Targets switched on in the settings menu ("Приложения"). A disabled one
    // is not written at all: its file keeps the colors it last had.
    readonly property bool gtkOn: ShellState.themeAppEnabled("gtk")
    readonly property bool qtOn: ShellState.themeAppEnabled("qt")
    readonly property bool ghosttyOn: ShellState.themeAppEnabled("ghostty")
    readonly property bool niriOn: ShellState.themeAppEnabled("niri")

    // ---- color formats --------------------------------------------------------

    function pad(value: real): string {
        const text = Math.round(value).toString(16);
        return text.length < 2 ? "0" + text : text;
    }

    // GTK and ghostty; niri takes the same with the alpha byte appended.
    function rgb(c: color): string {
        return "#" + pad(c.r * 255) + pad(c.g * 255) + pad(c.b * 255);
    }

    // niri colors are #rrggbbaa, alpha last.
    function rgba(c: color): string {
        return rgb(c) + pad(c.a * 255);
    }

    // Qt palette files are #aarrggbb.
    function argb(c: color): string {
        return "#" + pad(c.a * 255) + pad(c.r * 255) + pad(c.g * 255) + pad(c.b * 255);
    }

    // CSS needs rgba() when the palette carries alpha (the acrylic surfaces).
    function css(c: color): string {
        if (c.a >= 1)
            return rgb(c);
        return "rgba(" + Math.round(c.r * 255) + ", " + Math.round(c.g * 255) + ", "
            + Math.round(c.b * 255) + ", " + (Math.round(c.a * 100) / 100) + ")";
    }

    function alpha(c: color, factor: real): color {
        return Qt.rgba(c.r, c.g, c.b, factor);
    }

    // ---- GTK ------------------------------------------------------------------

    // The same keys the hand-written overrides carried (these replace them), so
    // nothing GTK-side changes shape — only the colors do.
    readonly property var gtkColors: [
        ["accent_color", Theme.primary],
        ["accent_bg_color", Theme.primary],
        ["accent_fg_color", Theme.primaryText],
        ["destructive_bg_color", Theme.error],
        ["destructive_fg_color", Theme.errorText],
        ["error_bg_color", Theme.error],
        ["error_fg_color", Theme.errorText],
        ["window_bg_color", Theme.surface],
        ["window_fg_color", Theme.surfaceText],
        ["view_bg_color", Theme.surfaceContainerLowest],
        ["view_fg_color", Theme.surfaceText],
        ["headerbar_bg_color", Theme.surfaceContainer],
        ["headerbar_fg_color", Theme.surfaceText],
        ["headerbar_backdrop_color", Theme.surface],
        ["popover_bg_color", Theme.surfaceContainerHigh],
        ["popover_fg_color", Theme.surfaceText],
        ["card_bg_color", Theme.surfaceContainerHigh],
        ["card_fg_color", Theme.surfaceText],
        ["dialog_bg_color", Theme.surfaceContainerHigh],
        ["dialog_fg_color", Theme.surfaceText],
        ["overview_bg_color", Theme.surfaceContainerHighest],
        ["overview_fg_color", Theme.surfaceText],
        ["sidebar_bg_color", Theme.surfaceContainerLow],
        ["sidebar_fg_color", Theme.surfaceText],
        ["sidebar_backdrop_color", Theme.surface],
        ["sidebar_border_color", Theme.surface],
        ["secondary_sidebar_bg_color", Theme.surfaceContainerLow],
        ["secondary_sidebar_fg_color", Theme.surfaceText]
    ]

    // Focused/backdrop states stay aliases, the way the original files had them.
    readonly property var gtkAliases: [
        ["theme_selected_bg_color", "accent_bg_color"],
        ["theme_selected_fg_color", "accent_fg_color"],
        ["theme_unfocused_fg_color", "window_fg_color"],
        ["theme_unfocused_text_color", "view_fg_color"],
        ["theme_unfocused_bg_color", "window_bg_color"],
        ["theme_unfocused_base_color", "window_bg_color"],
        ["theme_unfocused_selected_bg_color", "accent_bg_color"],
        ["theme_unfocused_selected_fg_color", "accent_fg_color"]
    ]

    // libadwaita reads these from :root on top of the @define-color lines.
    readonly property var gtk4Extra: [
        ["error-color", Theme.error],
        ["warning-bg-color", Theme.tertiary],
        ["warning-fg-color", Theme.tertiaryText],
        ["warning-color", Theme.tertiary],
        ["success-color", Theme.secondary],
        ["success-bg-color", Theme.secondary],
        ["success-fg-color", Theme.secondaryText],
        ["shade-color", Qt.rgba(0, 0, 0, 0.36)]
    ]

    function gtkCss(gtk4: bool): string {
        const lines = [
            "/*",
            "* GTK colors — generated by quickshell (services/SystemTheme.qml) from",
            "* the active " + (root.light ? "light" : "dark") + " palette; edits are overwritten.",
            "*/",
            ""
        ];
        for (let i = 0; i < root.gtkColors.length; i++) {
            const entry = root.gtkColors[i];
            lines.push("@define-color " + entry[0] + " " + css(entry[1]) + ";");
        }
        lines.push("");
        lines.push("/* Focused selection and backdrop states */");
        for (let i = 0; i < root.gtkAliases.length; i++)
            lines.push("@define-color " + root.gtkAliases[i][0] + " @" + root.gtkAliases[i][1] + ";");
        if (!gtk4)
            return lines.join("\n") + "\n";

        lines.push("");
        lines.push(":root {");
        for (let i = 0; i < root.gtkColors.length; i++) {
            const entry = root.gtkColors[i];
            lines.push("    --" + entry[0].replace(/_/g, "-") + ": " + css(entry[1]) + ";");
        }
        lines.push("");
        for (let i = 0; i < root.gtk4Extra.length; i++) {
            const entry = root.gtk4Extra[i];
            lines.push("    --" + entry[0] + ": " + css(entry[1]) + ";");
        }
        lines.push("}");
        return lines.join("\n") + "\n";
    }

    // ---- ghostty --------------------------------------------------------------

    // The 16 ANSI slots are built from M3 roles rather than matugen's base16:
    // roles stay contrast-safe against `surface` in both modes, while base16
    // accents collapse into near-background grays on muted wallpapers.
    // Containers are fills (close to the surface) and would be unreadable as
    // text, so the slots repeat roles instead.
    readonly property var terminalNormal: [
        Theme.terminalBlack,
        Theme.terminalRed,
        Theme.terminalGreen,
        Theme.terminalYellow,
        Theme.terminalBlue,
        Theme.terminalMagenta,
        Theme.terminalCyan,
        Theme.terminalWhite
    ]

    readonly property var terminalBright: [
        Theme.terminalBrightBlack,
        Theme.terminalRed,
        Theme.terminalGreen,
        Theme.terminalYellow,
        Theme.terminalBlue,
        Theme.terminalMagenta,
        Theme.terminalCyan,
        Theme.terminalBrightWhite
    ]

    function ghosttyTheme(): string {
        const lines = [
            "# Ghostty theme — generated by quickshell (services/SystemTheme.qml)",
            "# from the active " + (root.light ? "light" : "dark") + " palette; edits are overwritten.",
            "background = " + rgb(Theme.surface),
            "foreground = " + rgb(Theme.surfaceText),
            "cursor-color = " + rgb(Theme.primary),
            "cursor-text = " + rgb(Theme.primaryText),
            "selection-background = " + rgb(Theme.primaryContainer),
            "selection-foreground = " + rgb(Theme.primaryContainerText)
        ];
        for (let i = 0; i < 8; i++)
            lines.push("palette = " + i + "=" + rgb(root.terminalNormal[i]));
        for (let i = 0; i < 8; i++)
            lines.push("palette = " + (i + 8) + "=" + rgb(root.terminalBright[i]));
        return lines.join("\n") + "\n";
    }

    // ---- Qt (qt6ct) -----------------------------------------------------------

    // The 22 slots are the QPalette order documented inside the file itself.
    // The button ladder flips with the mode: on light surfaces the darkest role
    // is `highest`, on dark ones it is `lowest`.
    function qtPalette(): string {
        const light = root.light;
        const row = [
            Theme.surfaceText, // windowText
            Theme.surfaceContainer, // button
            light ? Theme.surfaceContainerLowest : Theme.surfaceContainerHighest, // light
            light ? Theme.surfaceContainerLow : Theme.surfaceContainerHigh, // midlight
            light ? Theme.surfaceContainerHighest : Theme.surfaceContainerLowest, // dark
            light ? Theme.surfaceContainerHigh : Theme.surfaceContainerLow, // mid
            Theme.surfaceText, // text
            Theme.primaryText, // brightText
            Theme.surfaceText, // buttonText
            Theme.surfaceContainerLow, // base
            Theme.surface, // window
            Theme.scrim, // shadow
            Theme.primary, // highlight
            Theme.primaryText, // highlightedText
            Theme.primary, // link
            Theme.tertiary, // linkVisited
            Theme.surfaceContainer, // alternateBase
            Theme.surfaceContainerLow, // NO_IDEA
            Theme.inverseSurface, // toolTipBase
            Theme.inverseOnSurface, // toolTipText
            Theme.surfaceVariantText, // placeholderText
            Theme.primary // accent
        ];
        let colors = "";
        for (let i = 0; i < row.length; i++)
            colors += (i === 0 ? "" : ", ") + argb(row[i]);
        return [
            "[ColorScheme]",
            "#https://doc.qt.io/qt-6/qpalette.html",
            "# Generated by quickshell (services/SystemTheme.qml) from the active "
                + (root.light ? "light" : "dark") + " palette; edits are overwritten.",
            "# windowText,button,light,midlight,dark,mid,text,brightText,buttonText,base,window,"
                + "shadow,highlight,highlightedText,link,linkVisited,alternateBase,NO_IDEA,"
                + "toolTipBase,toolTipText,placeholderText,accent",
            "active_colors=" + colors,
            "disabled_colors=" + colors,
            "inactive_colors=" + colors,
            ""
        ].join("\n");
    }

    // ---- niri -----------------------------------------------------------------

    // niri reads three things from the shell: the focus-ring/border colors, the
    // blur source ("Блюр" in the settings menu) and the animations switch
    // ("Анимации niri"). All go into one generated file, quickshell.kdl, which
    // config.kdl includes after layout.kdl: includes are positional in niri, so
    // ours has to come later to win, and niri live-reloads on save. Gradients are
    // written whole — niri replaces a gradient node instead of merging its
    // properties, so the angles live here, in the file. "Обычные" writes no
    // animations block at all, so niri keeps whatever the user's own
    // animations.kdl (included earlier, and merged per property) sets. The shell
    // has its own motion setting, Theme.motion.
    readonly property color niriActive: Theme.primary
    readonly property color niriInactive: root.alpha(Theme.primary, 0.35)
    readonly property color niriUrgent: Theme.error
    readonly property color niriActiveFrom: root.alpha(Theme.primary, 0.40)
    readonly property color niriActiveTo: root.alpha(Theme.secondary, 0.40)
    readonly property color niriInactiveFrom: root.alpha(Theme.surfaceVariantText, 0.70)
    readonly property color niriInactiveTo: root.alpha(Theme.surface, 0.70)

    // The blur source is niri policy, not something a client can ask for, and it
    // has to outlive the shell process: quickshell.kdl holds it and is read back
    // once at startup (sync). The file must not be written before that read — the
    // first evaluation of niriText would overwrite the stored choice with the
    // default — hence the arm-on-sync guard on the writer.
    property bool niriArmed: false

    function adoptBlurSource(): void {
        const lines = niriFile.text().split("\n");
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim();
            if (line.indexOf("xray ") === 0) {
                ShellState.setBlurSource(line.slice(5).trim() === "false" ? "window" : "wallpaper");
                return;
            }
        }
    }

    readonly property string niriText: [
        "// Generated by quickshell (services/SystemTheme.qml) — edits are overwritten.",
        "",
        "layout {",
        "    focus-ring {",
        "        active-gradient from=\"" + rgba(root.niriActiveFrom) + "\" to=\""
            + rgba(root.niriActiveTo) + "\" angle=180",
        "        inactive-gradient from=\"" + rgba(root.niriInactiveFrom) + "\" to=\""
            + rgba(root.niriInactiveTo) + "\" angle=45 relative-to=\"workspace-view\"",
        "    }",
        "",
        "    border {",
        "        active-color \"" + rgba(root.niriActive) + "\"",
        "        inactive-color \"" + rgba(root.niriInactive) + "\"",
        "        urgent-color \"" + rgba(root.niriUrgent) + "\"",
        "        active-gradient from=\"" + rgba(root.niriActiveFrom) + "\" to=\""
            + rgba(root.niriActiveTo) + "\" angle=150",
        "        inactive-gradient from=\"" + rgba(root.niriInactiveFrom) + "\" to=\""
            + rgba(root.niriInactiveTo) + "\" angle=150",
        "    }",
        "}",
        "",
        "layer-rule {",
        "    // \"Блюр\" in the settings menu. \"Обои\" writes nothing: niri already",
        "    // x-ray-blurs whatever blur a client asks for (wallpaper alone), and an",
        "    // explicit `xray true` would also paint the wallpaper behind surfaces",
        "    // that ask for no effect (the full-screen transparent popups under M3),",
        "    // hiding the windows underneath. \"Окна\" needs the rule to turn that",
        "    // default xray off, so what sits under the plate, windows included, blurs.",
        "    match namespace=\"^quickshell:\""
            + (ShellState.blurSource === "window"
                ? "\n\n    background-effect {\n        xray false\n    }"
                : ""),
        "}",
        // The optional niri blocks ("Скругление окон", "Анимации niri"), built as
        // one element so an unset choice leaves no stray blank line. A radius of
        // -1 (untouched) leaves the user's own window rules alone; otherwise a
        // catch-all rule wins, because this file is included last and niri applies
        // matching window rules in order. clip-to-geometry makes the corners cut
        // the content, not just the border. "Медленные" overrides niri's own
        // slowdown (the user's animations.kdl is faster than 1.0); "Обычные"
        // leaves niri's block alone.
        (ShellState.windowRadius < 0 ? ""
            : "\nwindow-rule {\n    geometry-corner-radius " + ShellState.windowRadius
                + "\n    clip-to-geometry true\n}\n")
            + (ShellState.niriAnimation === "off"
                ? "\nanimations {\n    off\n}"
                : ShellState.niriAnimation === "slow"
                    ? "\nanimations {\n    slowdown 1.0\n}"
                    : ""),
        ""
    ].join("\n")

    // ---- writers --------------------------------------------------------------

    // What the files should hold right now; recomputed whenever a role changes.
    readonly property string gtk3Text: root.gtkCss(false)
    readonly property string gtk4Text: root.gtkCss(true)
    readonly property string ghosttyText: root.ghosttyTheme()
    readonly property string qt6ctText: root.qtPalette()

    // Returns whether the file changed. Compared through text(), which reads the
    // file on demand, so the watchers below only see real changes.
    function writeTo(view: var, text: string): bool {
        if (view.text() === text)
            return false;
        view.setText(text);
        return true;
    }

    function reloadGhostty(): void {
        if (!root.writeTo(ghosttyFile, root.ghosttyText))
            return;
        ghosttyReload.running = false;
        ghosttyReload.running = true;
    }

    function applyColorScheme(): void {
        colorScheme.running = false;
        colorScheme.running = true;
    }

    // Called once from shell.qml: the handlers below only fire on a change, and
    // a first start has nothing to change from.
    function sync(): void {
        // The blur choice is read back before the writer is armed: quickshell.kdl
        // is the record, the shell must not overwrite it with the default.
        root.adoptBlurSource();
        root.niriArmed = true;
        root.applyAll();
    }

    // Writes every enabled target. Re-run when one is switched back on: the
    // palette did not change, so no on*Changed fires for it.
    function applyAll(): void {
        if (root.gtkOn) {
            root.writeTo(gtk3File, root.gtk3Text);
            root.writeTo(gtk4File, root.gtk4Text);
            root.applyColorScheme();
        }
        if (root.qtOn)
            root.writeTo(qt6ctFile, root.qt6ctText);
        if (root.ghosttyOn)
            root.reloadGhostty();
        if (root.niriArmed && root.niriOn)
            root.writeTo(niriFile, root.niriText);
    }

    onGtk3TextChanged: if (root.gtkOn) root.writeTo(gtk3File, root.gtk3Text)
    onGtk4TextChanged: if (root.gtkOn) root.writeTo(gtk4File, root.gtk4Text)
    onQt6ctTextChanged: if (root.qtOn) root.writeTo(qt6ctFile, root.qt6ctText)
    onGhosttyTextChanged: if (root.ghosttyOn) root.reloadGhostty()
    onNiriTextChanged: if (root.niriArmed && root.niriOn) root.writeTo(niriFile, root.niriText)
    onLightChanged: if (root.gtkOn) root.applyColorScheme()

    // Switching a target back on writes the current palette right away. The
    // four gtkOn/qtOn/... bindings carry no change handler of their own.
    Connections {
        target: ShellState

        function onThemeAppsOffChanged(): void {
            root.applyAll();
        }
    }

    FileView {
        id: gtk3File

        path: root.configHome + "/gtk-3.0/gtk.css"
        preload: false
        blockAllReads: true
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: gtk4File

        path: root.configHome + "/gtk-4.0/gtk.css"
        preload: false
        blockAllReads: true
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: ghosttyFile

        path: root.configHome + "/ghostty/themes/Quickshell"
        preload: false
        blockAllReads: true
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: qt6ctFile

        path: root.configHome + "/qt6ct/colors/matugen.conf"
        preload: false
        blockAllReads: true
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: niriFile

        path: root.configHome + "/niri/quickshell.kdl"
        preload: false
        blockAllReads: true
        blockLoading: true
        printErrors: false
    }

    // ghostty re-reads its config (and the theme file it points at) on SIGUSR2.
    Process {
        id: ghosttyReload

        command: ["pkill", "-USR2", "-x", "ghostty"]
    }

    Process {
        id: colorScheme

        command: [
            "gsettings", "set", "org.gnome.desktop.interface", "color-scheme",
            Theme.light ? "prefer-light" : "prefer-dark"
        ]
    }
}
