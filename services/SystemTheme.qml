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
//   ~/.config/gtk-3.0/gtk.css             GTK3 colors
//   ~/.config/gtk-4.0/gtk.css             GTK4 colors + libadwaita :root vars
//   ~/.config/ghostty/themes/Quickshell   theme file (`theme = Quickshell`)
//   ~/.config/qt6ct/colors/matugen.conf   Qt palette (`color_scheme_path`)
//   ~/.config/niri/layout.kdl             border/focus-ring color lines, in place
//
// plus `gsettings ... color-scheme`, which is what libadwaita apps read for
// their own light/dark base, and a ghostty config reload so a running terminal
// recolors without a restart. The one-time plumbing (ghostty theme name, the
// qt6ct path) is documented in the readme.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property bool light: Theme.light

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

    // niri reloads its config on save, so no explicit reload is needed. Only the
    // color lines of layout.kdl are rewritten in place: `on`, `width` and the
    // gradients' angles stay whatever the user set.
    readonly property color niriActive: Theme.primary
    readonly property color niriInactive: root.alpha(Theme.primary, 0.35)
    readonly property color niriUrgent: Theme.error
    readonly property color niriActiveFrom: root.alpha(Theme.primary, 0.40)
    readonly property color niriActiveTo: root.alpha(Theme.secondary, 0.40)
    readonly property color niriInactiveFrom: root.alpha(Theme.surfaceVariantText, 0.70)
    readonly property color niriInactiveTo: root.alpha(Theme.surface, 0.70)

    // Rebuilt on every palette change, so a write can be skipped when nothing moved.
    readonly property string niriSignature: [
        rgba(root.niriActive),
        rgba(root.niriInactive),
        rgba(root.niriUrgent),
        rgba(root.niriActiveFrom),
        rgba(root.niriActiveTo),
        rgba(root.niriInactiveFrom),
        rgba(root.niriInactiveTo)
    ].join(" ")

    // First token of a line, comments stripped: "active-color", "layout", ...
    function niriKey(line: string): string {
        let code = line;
        const comment = code.indexOf("//");
        if (comment >= 0)
            code = code.slice(0, comment);
        code = code.trim();
        if (code === "")
            return "";
        const space = code.indexOf(" ");
        return space < 0 ? code : code.slice(0, space);
    }

    function setQuoted(line: string, value: string): string {
        const open = line.indexOf('"');
        const close = line.lastIndexOf('"');
        if (open < 0 || close <= open)
            return line;
        return line.slice(0, open + 1) + value + line.slice(close);
    }

    function setAttr(line: string, name: string, value: string): string {
        const at = line.indexOf(name + "=");
        if (at < 0)
            return line;
        const open = line.indexOf('"', at);
        const close = open < 0 ? -1 : line.indexOf('"', open + 1);
        if (close < 0)
            return line;
        return line.slice(0, open + 1) + value + line.slice(close);
    }

    function niriThemed(text: string): string {
        const named = {
            "active-color": root.niriActive,
            "inactive-color": root.niriInactive,
            "urgent-color": root.niriUrgent
        };
        const lines = text.split("\n");
        for (let i = 0; i < lines.length; i++) {
            const key = root.niriKey(lines[i]);
            if (named[key] !== undefined) {
                lines[i] = root.setQuoted(lines[i], rgba(named[key]));
                continue;
            }
            if (key === "active-gradient" || key === "inactive-gradient") {
                const active = key === "active-gradient";
                let line = root.setAttr(lines[i], "from",
                    rgba(active ? root.niriActiveFrom : root.niriInactiveFrom));
                line = root.setAttr(line, "to",
                    rgba(active ? root.niriActiveTo : root.niriInactiveTo));
                lines[i] = line;
            }
        }
        return lines.join("\n");
    }

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

    function writeNiri(): void {
        const text = niriFile.text();
        if (text.trim() === "")
            return;
        const themed = root.niriThemed(text);
        if (themed !== text)
            niriFile.setText(themed);
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
        root.writeTo(gtk3File, root.gtk3Text);
        root.writeTo(gtk4File, root.gtk4Text);
        root.writeTo(qt6ctFile, root.qt6ctText);
        root.reloadGhostty();
        root.writeNiri();
        root.applyColorScheme();
    }

    onGtk3TextChanged: root.writeTo(gtk3File, root.gtk3Text)
    onGtk4TextChanged: root.writeTo(gtk4File, root.gtk4Text)
    onQt6ctTextChanged: root.writeTo(qt6ctFile, root.qt6ctText)
    onGhosttyTextChanged: root.reloadGhostty()
    onNiriSignatureChanged: root.writeNiri()
    onLightChanged: root.applyColorScheme()

    FileView {
        id: gtk3File

        path: root.home + "/.config/gtk-3.0/gtk.css"
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: gtk4File

        path: root.home + "/.config/gtk-4.0/gtk.css"
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: ghosttyFile

        path: root.home + "/.config/ghostty/themes/Quickshell"
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: qt6ctFile

        path: root.home + "/.config/qt6ct/colors/matugen.conf"
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: niriFile

        path: root.home + "/.config/niri/layout.kdl"
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
