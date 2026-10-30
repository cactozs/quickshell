pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import "../style"

// Mirrors the shell palette onto the rest of the desktop: GTK, Qt (qt6ct),
// ghostty, the niri border and a handful of terminals, editors and shells
// follow the theme picked in the settings menu, light/dark included, and the
// fixed Oled/Gruvbox packs too — the desktop never drifts from the bar. Colors
// come from Theme.* and not from matugen, which only knows the wallpaper
// palette.
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
//   $XDG_CONFIG_HOME/foot/quickshell.ini         foot colors (`include=` in foot.ini)
//   $XDG_CONFIG_HOME/alacritty/quickshell.toml   Alacritty colors (`import = [...]`)
//   $XDG_CONFIG_HOME/kitty/quickshell.conf       Kitty colors (`include` in kitty.conf)
//   $XDG_CONFIG_HOME/nvim/colors/quickshell.lua  Neovim colorscheme (`:colorscheme quickshell`)
//   $XDG_CONFIG_HOME/helix/themes/quickshell.toml Helix theme (`theme = "quickshell"`)
//   $XDG_CONFIG_HOME/zed/themes/quickshell.json  Zed theme (picked in its selector)
//   $XDG_CONFIG_HOME/bash/quickshell.sh          LS_COLORS/GREP_COLORS (`source` in ~/.bashrc)
//   $XDG_CONFIG_HOME/fish/conf.d/quickshell.fish fish colors (conf.d is sourced)
//   $XDG_CONFIG_HOME/bat/themes/quickshell.tmTheme bat theme (`BAT_THEME=quickshell`)
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
    readonly property bool footOn: ShellState.themeAppEnabled("foot")
    readonly property bool alacrittyOn: ShellState.themeAppEnabled("alacritty")
    readonly property bool kittyOn: ShellState.themeAppEnabled("kitty")
    readonly property bool nvimOn: ShellState.themeAppEnabled("nvim")
    readonly property bool helixOn: ShellState.themeAppEnabled("helix")
    readonly property bool zedOn: ShellState.themeAppEnabled("zed")
    readonly property bool bashOn: ShellState.themeAppEnabled("bash")
    readonly property bool fishOn: ShellState.themeAppEnabled("fish")
    readonly property bool batOn: ShellState.themeAppEnabled("bat")

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
        // Global blur strength ("Сила блюра" in Custom style). niri takes `passes`
        // in the top-level `blur {}` section — not inside background-effect — and it
        // applies to all background blur. 0 means niri's default, so nothing is
        // written while the knob is untouched.
        (ShellState.customBlur > 0
            ? "\nblur {\n    passes " + ShellState.customBlur + "\n}"
            : ""),
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

    // ---- other terminals ------------------------------------------------------

    // Same 16 ANSI slots as ghostty, only the syntax differs. foot wants bare
    // RRGGBB (no `#`) in `[colors-dark]`/`[colors-light]`; both slots get the
    // active palette so foot's own theme switch cannot fall back to defaults.
    function footTheme(): string {
        const hex = c => rgb(c).substring(1);
        const colors = [
            "background=" + hex(Theme.surface),
            "foreground=" + hex(Theme.surfaceText),
            "cursor=" + hex(Theme.surface) + " " + hex(Theme.primary),
            "selection-background=" + hex(Theme.primaryContainer),
            "selection-foreground=" + hex(Theme.primaryContainerText)
        ];
        for (let i = 0; i < 8; i++)
            colors.push("regular" + i + "=" + hex(root.terminalNormal[i]));
        for (let i = 0; i < 8; i++)
            colors.push("bright" + i + "=" + hex(root.terminalBright[i]));
        const lines = [
            "# Foot colors — generated by quickshell (services/SystemTheme.qml)",
            "# from the active " + (root.light ? "light" : "dark") + " palette; edits are overwritten.",
            ""
        ];
        for (const section of ["[colors-dark]", "[colors-light]"]) {
            lines.push(section);
            for (const line of colors)
                lines.push(line);
            lines.push("");
        }
        return lines.join("\n");
    }

    function alacrittyTheme(): string {
        const names = ["black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"];
        const lines = [
            "# Alacritty colors — generated by quickshell (services/SystemTheme.qml)",
            "# from the active " + (root.light ? "light" : "dark") + " palette; edits are overwritten.",
            "",
            "[colors.primary]",
            "background = \"" + rgb(Theme.surface) + "\"",
            "foreground = \"" + rgb(Theme.surfaceText) + "\"",
            "dim_foreground = \"" + rgb(Theme.surfaceVariantText) + "\"",
            "bright_foreground = \"" + rgb(Theme.surfaceText) + "\"",
            "",
            "[colors.cursor]",
            "text = \"" + rgb(Theme.surface) + "\"",
            "cursor = \"" + rgb(Theme.primary) + "\"",
            "",
            "[colors.selection]",
            "text = \"" + rgb(Theme.primaryContainerText) + "\"",
            "background = \"" + rgb(Theme.primaryContainer) + "\"",
            "",
            "[colors.normal]"
        ];
        for (let i = 0; i < 8; i++)
            lines.push(names[i] + " = \"" + rgb(root.terminalNormal[i]) + "\"");
        lines.push("");
        lines.push("[colors.bright]");
        for (let i = 0; i < 8; i++)
            lines.push(names[i] + " = \"" + rgb(root.terminalBright[i]) + "\"");
        return lines.join("\n") + "\n";
    }

    function kittyTheme(): string {
        const lines = [
            "# Kitty colors — generated by quickshell (services/SystemTheme.qml)",
            "# from the active " + (root.light ? "light" : "dark") + " palette; edits are overwritten.",
            "background " + rgb(Theme.surface),
            "foreground " + rgb(Theme.surfaceText),
            "cursor " + rgb(Theme.primary),
            "cursor_text_color " + rgb(Theme.primaryText),
            "selection_background " + rgb(Theme.primaryContainer),
            "selection_foreground " + rgb(Theme.primaryContainerText),
            "url_color " + rgb(Theme.secondary),
            "active_border_color " + rgb(Theme.primary),
            "inactive_border_color " + rgb(Theme.outlineVariant)
        ];
        for (let i = 0; i < 8; i++)
            lines.push("color" + i + " " + rgb(root.terminalNormal[i]));
        for (let i = 0; i < 8; i++)
            lines.push("color" + (i + 8) + " " + rgb(root.terminalBright[i]));
        return lines.join("\n") + "\n";
    }

    // ---- editors --------------------------------------------------------------

    // Neovim has no include file: this is a colorscheme, so the user adds
    // `colorscheme quickshell` once. Treesitter and LSP reuse these groups.
    function nvimTheme(): string {
        const hi = (group, fg, bg, opts) => "set(0, \"" + group + "\", { fg = \""
            + rgb(fg) + "\"" + (bg ? ", bg = \"" + rgb(bg) + "\"" : "")
            + (opts ? ", " + opts : "") + " })";
        return [
            "-- Generated by quickshell (services/SystemTheme.qml) — edits are overwritten.",
            "vim.o.background = \"" + (root.light ? "light" : "dark") + "\"",
            "vim.g.colors_name = \"quickshell\"",
            "local set = vim.api.nvim_set_hl",
            "",
            hi("Normal", Theme.surfaceText, Theme.surface),
            hi("NormalNC", Theme.surfaceVariantText, Theme.surface),
            hi("NormalFloat", Theme.surfaceText, Theme.surfaceContainerHigh),
            hi("FloatBorder", Theme.outline, Theme.surfaceContainerHigh),
            hi("Cursor", Theme.surface, Theme.primary),
            hi("CursorLine", Theme.surfaceText, Theme.surfaceContainerLow),
            hi("CursorLineNr", Theme.primary, null, "bold = true"),
            hi("LineNr", Theme.outline, null),
            hi("SignColumn", Theme.surfaceText, Theme.surface),
            hi("Visual", Theme.surfaceText, Theme.primaryContainer),
            hi("Search", Theme.primaryContainerText, Theme.primaryContainer),
            hi("IncSearch", Theme.primaryText, Theme.primary),
            hi("CurSearch", Theme.primaryText, Theme.primary),
            hi("Pmenu", Theme.surfaceText, Theme.surfaceContainerHigh),
            hi("PmenuSel", Theme.primaryContainerText, Theme.primaryContainer),
            hi("PmenuSbar", Theme.surfaceText, Theme.surfaceContainer),
            hi("PmenuThumb", Theme.surfaceText, Theme.outlineVariant),
            hi("StatusLine", Theme.surfaceText, Theme.surfaceContainer),
            hi("StatusLineNC", Theme.surfaceVariantText, Theme.surfaceContainerLow),
            hi("TabLine", Theme.surfaceVariantText, Theme.surfaceContainerLow),
            hi("TabLineSel", Theme.surfaceText, Theme.surfaceContainer),
            hi("TabLineFill", Theme.surfaceText, Theme.surfaceContainerLow),
            hi("WinSeparator", Theme.outlineVariant, null),
            hi("VertSplit", Theme.outlineVariant, null),
            hi("NonText", Theme.outlineVariant, null),
            hi("EndOfBuffer", Theme.surface, null),
            hi("Folded", Theme.surfaceVariantText, Theme.surfaceContainer),
            hi("Title", Theme.primary, null, "bold = true"),
            hi("Directory", Theme.primary, null),
            hi("MatchParen", Theme.primary, Theme.surfaceContainerHighest, "bold = true"),
            hi("Comment", Theme.surfaceVariantText, null, "italic = true"),
            hi("Constant", Theme.tertiary, null),
            hi("String", Theme.secondary, null),
            hi("Identifier", Theme.surfaceText, null),
            hi("Function", Theme.primary, null),
            hi("Statement", Theme.tertiary, null),
            hi("Keyword", Theme.tertiary, null),
            hi("Operator", Theme.surfaceVariantText, null),
            hi("Type", Theme.tertiary, null),
            hi("PreProc", Theme.tertiary, null),
            hi("Special", Theme.secondary, null),
            hi("Error", Theme.error, null),
            hi("ErrorMsg", Theme.error, null),
            hi("WarningMsg", Theme.tertiary, null),
            hi("Todo", Theme.error, null, "bold = true"),
            hi("DiagnosticError", Theme.error, null),
            hi("DiagnosticWarn", Theme.tertiary, null),
            hi("DiagnosticInfo", Theme.secondary, null),
            hi("DiagnosticHint", Theme.surfaceVariantText, null),
            hi("DiffAdd", Theme.secondary, null),
            hi("DiffChange", Theme.tertiary, null),
            hi("DiffDelete", Theme.error, null),
            hi("DiffText", Theme.primary, null),
            hi("SpellBad", Theme.error, null, "undercurl = true"),
            ""
        ].join("\n");
    }

    // Helix reads a theme name from config.toml; the file is a plain TOML table
    // with a palette at the end (everything after `[palette]` belongs to it).
    function helixTheme(): string {
        const palette = {
            surface: rgb(Theme.surface),
            surface_low: rgb(Theme.surfaceContainerLow),
            surface_high: rgb(Theme.surfaceContainerHigh),
            text: rgb(Theme.surfaceText),
            muted: rgb(Theme.surfaceVariantText),
            outline: rgb(Theme.outline),
            outline_variant: rgb(Theme.outlineVariant),
            primary: rgb(Theme.primary),
            primary_container: rgb(Theme.primaryContainer),
            secondary: rgb(Theme.secondary),
            tertiary: rgb(Theme.tertiary),
            error: rgb(Theme.error)
        };
        const lines = [
            "# Helix theme — generated by quickshell (services/SystemTheme.qml)",
            "# from the active " + (root.light ? "light" : "dark") + " palette; edits are overwritten.",
            "\"ui.background\" = { bg = \"surface\" }",
            "\"ui.text\" = { fg = \"text\" }",
            "\"ui.text.focus\" = { fg = \"text\" }",
            "\"ui.cursor\" = { fg = \"surface\", bg = \"primary\" }",
            "\"ui.cursor.primary\" = { fg = \"surface\", bg = \"primary\" }",
            "\"ui.cursorline.primary\" = { bg = \"surface_low\" }",
            "\"ui.selection\" = { bg = \"primary_container\" }",
            "\"ui.selection.primary\" = { bg = \"primary_container\" }",
            "\"ui.linenr\" = { fg = \"outline\" }",
            "\"ui.linenr.selected\" = { fg = \"text\" }",
            "\"ui.statusline\" = { fg = \"text\", bg = \"surface_low\" }",
            "\"ui.statusline.inactive\" = { fg = \"outline\", bg = \"surface\" }",
            "\"ui.statusline.normal\" = { fg = \"surface\", bg = \"primary\" }",
            "\"ui.popup\" = { fg = \"text\", bg = \"surface_high\" }",
            "\"ui.help\" = { fg = \"text\", bg = \"surface_high\" }",
            "\"ui.menu\" = { fg = \"text\", bg = \"surface_high\" }",
            "\"ui.menu.selected\" = { fg = \"surface\", bg = \"primary\" }",
            "\"ui.window\" = { fg = \"outline_variant\" }",
            "\"ui.virtual.whitespace\" = { fg = \"outline_variant\" }",
            "\"ui.virtual.indent-guide\" = { fg = \"outline_variant\" }",
            "\"ui.virtual.ruler\" = { bg = \"surface_low\" }",
            "\"comment\" = { fg = \"outline\", modifiers = [\"italic\"] }",
            "\"keyword\" = { fg = \"tertiary\" }",
            "\"operator\" = { fg = \"muted\" }",
            "\"punctuation\" = { fg = \"muted\" }",
            "\"string\" = { fg = \"secondary\" }",
            "\"constant\" = { fg = \"tertiary\" }",
            "\"constant.numeric\" = { fg = \"tertiary\" }",
            "\"function\" = { fg = \"primary\" }",
            "\"function.method\" = { fg = \"primary\" }",
            "\"variable\" = { fg = \"text\" }",
            "\"type\" = { fg = \"tertiary\" }",
            "\"attribute\" = { fg = \"primary\" }",
            "\"namespace\" = { fg = \"primary\" }",
            "\"label\" = { fg = \"primary\" }",
            "\"error\" = { fg = \"error\" }",
            "\"warning\" = { fg = \"tertiary\" }",
            "\"info\" = { fg = \"secondary\" }",
            "\"hint\" = { fg = \"muted\" }",
            "\"diff.plus\" = { fg = \"secondary\" }",
            "\"diff.minus\" = { fg = \"error\" }",
            "\"diff.delta\" = { fg = \"primary\" }",
            "\"markup.heading\" = { fg = \"primary\", modifiers = [\"bold\"] }",
            "\"markup.link.url\" = { fg = \"secondary\", modifiers = [\"underlined\"] }",
            "\"markup.raw\" = { fg = \"secondary\" }",
            "",
            "[palette]"
        ];
        for (const key in palette)
            lines.push(key + " = \"" + palette[key] + "\"");
        return lines.join("\n") + "\n";
    }

    // Zed takes a whole theme family JSON; only the current mode is written.
    function zedTheme(): string {
        const c = {
            bg: rgb(Theme.surface),
            low: rgb(Theme.surfaceContainerLow),
            mid: rgb(Theme.surfaceContainer),
            high: rgb(Theme.surfaceContainerHigh),
            highest: rgb(Theme.surfaceContainerHighest),
            text: rgb(Theme.surfaceText),
            muted: rgb(Theme.surfaceVariantText),
            outline: rgb(Theme.outline),
            variant: rgb(Theme.outlineVariant),
            primary: rgb(Theme.primary),
            container: rgb(Theme.primaryContainer),
            onContainer: rgb(Theme.primaryContainerText),
            secondary: rgb(Theme.secondary),
            tertiary: rgb(Theme.tertiary),
            error: rgb(Theme.error),
            errorContainer: rgb(Theme.errorContainer)
        };
        return JSON.stringify({
            "$schema": "https://zed.dev/schema/themes/v0.2.0.json",
            name: "Quickshell",
            author: "quickshell",
            themes: [{
                name: "Quickshell",
                appearance: root.light ? "light" : "dark",
                style: {
                    background: c.bg,
                    "surface.background": c.low,
                    "elevated_surface.background": c.high,
                    "panel.background": c.bg,
                    "panel.focused_border": c.primary,
                    "pane.focused_border": c.primary,
                    "editor.background": c.bg,
                    "editor.foreground": c.text,
                    "editor.gutter.background": c.bg,
                    "editor.active_line.background": c.low,
                    "editor.line_number": c.outline,
                    "editor.active_line_number": c.primary,
                    "status_bar.background": c.mid,
                    "title_bar.background": c.low,
                    "title_bar.inactive_background": c.bg,
                    "toolbar.background": c.low,
                    "tab_bar.background": c.low,
                    "tab.active_background": c.bg,
                    "tab.inactive_background": c.low,
                    border: c.variant,
                    "border.variant": c.variant,
                    "border.focused": c.primary,
                    "border.selected": c.primary,
                    "border.disabled": c.variant,
                    text: c.text,
                    "text.muted": c.muted,
                    "text.placeholder": c.outline,
                    "text.disabled": c.variant,
                    "text.accent": c.primary,
                    icon: c.muted,
                    "icon.muted": c.outline,
                    "icon.accent": c.primary,
                    "icon.disabled": c.variant,
                    "element.background": c.high,
                    "element.hover": c.highest,
                    "element.active": c.highest,
                    "element.selected": c.container,
                    "element.disabled": c.mid,
                    "ghost_element.hover": c.high,
                    "ghost_element.selected": c.highest,
                    "ghost_element.active": c.highest,
                    "search.match_background": c.container,
                    "scrollbar.thumb.background": c.variant,
                    "scrollbar.thumb.hover_background": c.outline,
                    "scrollbar.track.background": c.bg,
                    "drop_target.background": c.container,
                    error: c.error,
                    "error.background": c.errorContainer,
                    "error.border": c.error,
                    warning: c.tertiary,
                    "warning.background": c.high,
                    "warning.border": c.tertiary,
                    success: c.secondary,
                    info: c.primary,
                    hint: c.outline,
                    modified: c.tertiary,
                    created: c.secondary,
                    deleted: c.error,
                    conflict: c.error,
                    renamed: c.primary,
                    ignored: c.outline,
                    unreachable: c.outline,
                    "link_text.hover": c.secondary,
                    "terminal.background": c.bg,
                    "terminal.foreground": c.text,
                    "terminal.bright_foreground": c.text,
                    "terminal.dim_foreground": c.muted,
                    "terminal.ansi.background": c.bg,
                    "terminal.ansi.black": rgb(root.terminalNormal[0]),
                    "terminal.ansi.red": rgb(root.terminalNormal[1]),
                    "terminal.ansi.green": rgb(root.terminalNormal[2]),
                    "terminal.ansi.yellow": rgb(root.terminalNormal[3]),
                    "terminal.ansi.blue": rgb(root.terminalNormal[4]),
                    "terminal.ansi.magenta": rgb(root.terminalNormal[5]),
                    "terminal.ansi.cyan": rgb(root.terminalNormal[6]),
                    "terminal.ansi.white": rgb(root.terminalNormal[7]),
                    "terminal.ansi.bright_black": rgb(root.terminalBright[0]),
                    "terminal.ansi.bright_red": rgb(root.terminalBright[1]),
                    "terminal.ansi.bright_green": rgb(root.terminalBright[2]),
                    "terminal.ansi.bright_yellow": rgb(root.terminalBright[3]),
                    "terminal.ansi.bright_blue": rgb(root.terminalBright[4]),
                    "terminal.ansi.bright_magenta": rgb(root.terminalBright[5]),
                    "terminal.ansi.bright_cyan": rgb(root.terminalBright[6]),
                    "terminal.ansi.bright_white": rgb(root.terminalBright[7]),
                    players: [{ cursor: c.primary, selection: c.container, background: c.secondary }],
                    syntax: {
                        comment: { color: c.muted, font_style: "italic" },
                        "comment.doc": { color: c.muted, font_style: "italic" },
                        string: { color: c.secondary },
                        "string.escape": { color: c.tertiary },
                        "string.regex": { color: c.tertiary },
                        "string.special": { color: c.tertiary },
                        number: { color: c.tertiary },
                        boolean: { color: c.tertiary },
                        keyword: { color: c.tertiary },
                        type: { color: c.tertiary },
                        function: { color: c.primary },
                        "function.method": { color: c.primary },
                        variable: { color: c.text },
                        "variable.special": { color: c.primary },
                        property: { color: c.text },
                        attribute: { color: c.primary },
                        title: { color: c.primary, font_weight: 700 },
                        emphasis: { font_style: "italic" },
                        link_text: { color: c.primary },
                        link_uri: { color: c.secondary },
                        punctuation: { color: c.muted },
                        "punctuation.bracket": { color: c.muted },
                        "punctuation.delimiter": { color: c.muted },
                        operator: { color: c.muted },
                        preproc: { color: c.tertiary },
                        special: { color: c.secondary },
                        embedded: { color: c.text },
                        predicate: { color: c.primary },
                        primary: { color: c.text },
                        hint: { color: c.outline }
                    }
                }
            }]
        }, null, 2) + "\n";
    }

    // ---- pagers ---------------------------------------------------------------

    // bat takes a Sublime `.tmTheme`; the name inside has to match BAT_THEME,
    // and `bat cache --build` must run after each rewrite (see reloadBat).
    function batTheme(): string {
        const entry = (scope, fg, style) => "    <dict>\n"
            + "      <key>scope</key><string>" + scope + "</string>\n"
            + "      <key>settings</key>\n"
            + "      <dict><key>foreground</key><string>" + rgb(fg) + "</string>"
            + (style ? "<key>fontStyle</key><string>" + style + "</string>" : "")
            + "</dict>\n    </dict>";
        const scopes = [
            ["comment", Theme.surfaceVariantText, "italic"],
            ["string", Theme.secondary, ""],
            ["constant.numeric", Theme.tertiary, ""],
            ["constant.language", Theme.tertiary, ""],
            ["keyword", Theme.tertiary, ""],
            ["storage", Theme.tertiary, ""],
            ["entity.name.function", Theme.primary, ""],
            ["support.function", Theme.primary, ""],
            ["entity.name.type", Theme.tertiary, ""],
            ["support.type", Theme.tertiary, ""],
            ["variable", Theme.surfaceText, ""],
            ["attribute", Theme.primary, ""],
            ["entity.name.tag", Theme.primary, ""],
            ["operator", Theme.surfaceVariantText, ""],
            ["punctuation", Theme.surfaceVariantText, ""],
            ["invalid", Theme.error, ""],
            ["markup.heading", Theme.primary, "bold"],
            ["markup.bold", Theme.surfaceText, "bold"],
            ["markup.italic", Theme.surfaceText, "italic"],
            ["markup.underline", Theme.surfaceText, "underline"],
            ["markup.raw", Theme.secondary, ""],
            ["markup.inserted", Theme.secondary, ""],
            ["markup.deleted", Theme.error, ""],
            ["markup.changed", Theme.tertiary, ""],
            ["markup.link", Theme.secondary, "underline"]
        ];
        return [
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
            "<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">",
            "<plist version=\"1.0\">",
            "<dict>",
            "  <key>name</key><string>quickshell</string>",
            "  <key>settings</key>",
            "  <array>",
            "    <dict>",
            "      <key>settings</key>",
            "      <dict>",
            "        <key>background</key><string>" + rgb(Theme.surface) + "</string>",
            "        <key>foreground</key><string>" + rgb(Theme.surfaceText) + "</string>",
            "        <key>caret</key><string>" + rgb(Theme.primary) + "</string>",
            "        <key>selection</key><string>" + rgb(Theme.primaryContainer) + "</string>",
            "        <key>lineHighlight</key><string>" + rgb(Theme.surfaceContainerLow) + "</string>",
            "      </dict>",
            "    </dict>",
            scopes.map(s => entry(s[0], s[1], s[2])).join("\n"),
            "  </array>",
            "</dict>",
            "</plist>",
            ""
        ].join("\n");
    }

    // ---- shells ---------------------------------------------------------------

    // Bash has no auto-sourced file, so this one needs a `source` line. Only the
    // standard ANSI slots are set, so it follows whichever themed terminal runs.
    readonly property string bashText: [
        "# Bash colors — generated by quickshell (services/SystemTheme.qml)",
        "# One-time: add `source " + root.configHome + "/bash/quickshell.sh` to ~/.bashrc.",
        "LS_COLORS=\"rs=0:di=34:ln=36:mh=36:pi=33:so=33:do=33:bd=33:cd=33:or=31:"
            + "mi=31:su=31:sg=31:ca=31:tw=31:ow=31:st=31:ex=32:*.tar=31:*.tgz=31:"
            + "*.zip=31:*.gz=31:*.xz=31:*.7z=31:*.mp3=35:*.mp4=35:*.jpg=35:*.png=35:"
            + "*.pdf=33:*.md=33\"",
        "export LS_COLORS",
        "GREP_COLORS=\"ms=01;34:mc=01;34:fn=35:ln=32:bn=32:se=36\"",
        "export GREP_COLORS",
        ""
    ].join("\n")

    // fish sources conf.d on every new shell, so nothing else needs wiring.
    readonly property string fishText: [
        "# Fish colors — generated by quickshell (services/SystemTheme.qml)",
        "set -g fish_color_normal '" + rgb(Theme.surfaceText) + "'",
        "set -g fish_color_command '" + rgb(Theme.primary) + "'",
        "set -g fish_color_param '" + rgb(Theme.surfaceText) + "'",
        "set -g fish_color_keyword '" + rgb(Theme.tertiary) + "'",
        "set -g fish_color_function '" + rgb(Theme.primary) + "'",
        "set -g fish_color_operator '" + rgb(Theme.secondary) + "'",
        "set -g fish_color_escape '" + rgb(Theme.tertiary) + "'",
        "set -g fish_color_quote '" + rgb(Theme.secondary) + "'",
        "set -g fish_color_redirection '" + rgb(Theme.tertiary) + "'",
        "set -g fish_color_end '" + rgb(Theme.surfaceVariantText) + "'",
        "set -g fish_color_error '" + rgb(Theme.error) + "'",
        "set -g fish_color_comment '" + rgb(Theme.surfaceVariantText) + "'",
        "set -g fish_color_selection \"--background=" + rgb(Theme.primaryContainer) + "\"",
        "set -g fish_color_search_match \"--background=" + rgb(Theme.primaryContainer) + "\"",
        "set -g fish_color_autosuggestion '" + rgb(Theme.outline) + "'",
        "set -g fish_color_cwd '" + rgb(Theme.primary) + "'",
        "set -g fish_color_user '" + rgb(Theme.secondary) + "'",
        "set -g fish_color_host '" + rgb(Theme.primary) + "'",
        "set -g fish_color_cancel '" + rgb(Theme.error) + "'",
        "set -g fish_color_status '" + rgb(Theme.error) + "'",
        "set -g fish_pager_color_prefix '" + rgb(Theme.primary) + "'",
        "set -g fish_pager_color_completion '" + rgb(Theme.surfaceText) + "'",
        "set -g fish_pager_color_description '" + rgb(Theme.surfaceVariantText) + "'",
        "set -g fish_pager_color_selected_background \"--background="
            + rgb(Theme.primaryContainer) + "\"",
        ""
    ].join("\n")

    // ---- writers --------------------------------------------------------------

    // What the files should hold right now; recomputed whenever a role changes.
    readonly property string gtk3Text: root.gtkCss(false)
    readonly property string gtk4Text: root.gtkCss(true)
    readonly property string ghosttyText: root.ghosttyTheme()
    readonly property string qt6ctText: root.qtPalette()
    readonly property string footText: root.footTheme()
    readonly property string alacrittyText: root.alacrittyTheme()
    readonly property string kittyText: root.kittyTheme()
    readonly property string nvimText: root.nvimTheme()
    readonly property string helixText: root.helixTheme()
    readonly property string zedText: root.zedTheme()
    readonly property string batText: root.batTheme()

    // Returns whether the file changed. reload() first: text() is a cached read,
    // so a hand-edited or deleted file would otherwise compare equal and stay
    // stale — «Применить сейчас» and a chip switched back on rely on this.
    function writeTo(view: var, text: string): bool {
        view.reload();
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

    function reloadFoot(): void {
        if (!root.writeTo(footFile, root.footText))
            return;
        footReload.running = false;
        footReload.running = true;
    }

    function reloadKitty(): void {
        if (!root.writeTo(kittyFile, root.kittyText))
            return;
        kittyReload.running = false;
        kittyReload.running = true;
    }

    // bat compiles themes into a cache, so a new tmTheme alone changes nothing.
    function reloadBat(): void {
        if (!root.writeTo(batFile, root.batText))
            return;
        batCacheBuild.running = false;
        batCacheBuild.running = true;
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
        if (root.footOn)
            root.reloadFoot();
        if (root.alacrittyOn)
            root.writeTo(alacrittyFile, root.alacrittyText);
        if (root.kittyOn)
            root.reloadKitty();
        if (root.nvimOn)
            root.writeTo(nvimFile, root.nvimText);
        if (root.helixOn)
            root.writeTo(helixFile, root.helixText);
        if (root.zedOn)
            root.writeTo(zedFile, root.zedText);
        if (root.bashOn)
            root.writeTo(bashFile, root.bashText);
        if (root.fishOn)
            root.writeTo(fishFile, root.fishText);
        if (root.batOn)
            root.reloadBat();
    }

    onGtk3TextChanged: if (root.gtkOn) root.writeTo(gtk3File, root.gtk3Text)
    onGtk4TextChanged: if (root.gtkOn) root.writeTo(gtk4File, root.gtk4Text)
    onQt6ctTextChanged: if (root.qtOn) root.writeTo(qt6ctFile, root.qt6ctText)
    onGhosttyTextChanged: if (root.ghosttyOn) root.reloadGhostty()
    onNiriTextChanged: if (root.niriArmed && root.niriOn) root.writeTo(niriFile, root.niriText)
    onFootTextChanged: if (root.footOn) root.reloadFoot()
    onAlacrittyTextChanged: if (root.alacrittyOn) root.writeTo(alacrittyFile, root.alacrittyText)
    onKittyTextChanged: if (root.kittyOn) root.reloadKitty()
    onNvimTextChanged: if (root.nvimOn) root.writeTo(nvimFile, root.nvimText)
    onHelixTextChanged: if (root.helixOn) root.writeTo(helixFile, root.helixText)
    onZedTextChanged: if (root.zedOn) root.writeTo(zedFile, root.zedText)
    onBashTextChanged: if (root.bashOn) root.writeTo(bashFile, root.bashText)
    onFishTextChanged: if (root.fishOn) root.writeTo(fishFile, root.fishText)
    onBatTextChanged: if (root.batOn) root.reloadBat()
    onLightChanged: if (root.gtkOn) root.applyColorScheme()

    // Switching a target back on writes the current palette right away. The
    // gtkOn/qtOn/... bindings carry no change handler of their own.
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

    FileView {
        id: footFile

        path: root.configHome + "/foot/quickshell.ini"
        preload: false
        blockAllReads: true
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: alacrittyFile

        path: root.configHome + "/alacritty/quickshell.toml"
        preload: false
        blockAllReads: true
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: kittyFile

        path: root.configHome + "/kitty/quickshell.conf"
        preload: false
        blockAllReads: true
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: nvimFile

        path: root.configHome + "/nvim/colors/quickshell.lua"
        preload: false
        blockAllReads: true
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: helixFile

        path: root.configHome + "/helix/themes/quickshell.toml"
        preload: false
        blockAllReads: true
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: zedFile

        path: root.configHome + "/zed/themes/quickshell.json"
        preload: false
        blockAllReads: true
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: bashFile

        path: root.configHome + "/bash/quickshell.sh"
        preload: false
        blockAllReads: true
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: fishFile

        path: root.configHome + "/fish/conf.d/quickshell.fish"
        preload: false
        blockAllReads: true
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: batFile

        path: root.configHome + "/bat/themes/quickshell.tmTheme"
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

    // foot and kitty reload their config on SIGUSR1.
    Process {
        id: footReload

        command: ["pkill", "-USR1", "-x", "foot"]
    }

    Process {
        id: kittyReload

        command: ["pkill", "-USR1", "-x", "kitty"]
    }

    // bat only sees a theme after recompiling its cache.
    Process {
        id: batCacheBuild

        command: ["bat", "cache", "--build"]
    }

    Process {
        id: colorScheme

        command: [
            "gsettings", "set", "org.gnome.desktop.interface", "color-scheme",
            Theme.light ? "prefer-light" : "prefer-dark"
        ]
    }
}
