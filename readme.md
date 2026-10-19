## MOSTLY WRITTEN BY AI

<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/cb5d604d-3d5a-4edc-9d16-75ab9f15e2b1" />
<img width="579" height="359" alt="image" src="https://github.com/user-attachments/assets/7193665a-4ee3-4f24-a5fb-fef10c932e15" />
<img width="579" height="359" alt="image" src="https://github.com/user-attachments/assets/eda354e7-c38f-4d7a-a7c6-81b005560a1f" />
<img width="434" height="389" alt="image" src="https://github.com/user-attachments/assets/4bfb5946-5605-494c-9701-2d5d1e908301" />
<img width="435" height="705" alt="image" src="https://github.com/user-attachments/assets/3770ab2e-68da-4e1a-900f-6fbbc270d477" />
<img width="364" height="115" alt="image" src="https://github.com/user-attachments/assets/72eddaa6-babc-431c-be72-0d5de2d9d425" />
<img width="135" height="69" alt="image" src="https://github.com/user-attachments/assets/c5e1990e-3629-4787-b6a8-09da612e7978" />

a bit inspired by Material 3 Expressive

## installation

### Way #1:
promt your agent: "install this quickshell config for me: https://github.com/cactozs/quickshell"

### Way #2:

The repo *is* the config: Quickshell picks up `~/.config/quickshell/shell.qml` as its "default" configuration, so clone it exactly there. Nothing to build — the QML is read at runtime and the shell reloads itself when a file changes.

The files the shell needs *outside* the repo — the matugen configs and the `awww` shim — are in the repo too, under `install/`, so they can be copied instead of written by hand. Every step below also spells the file out, so nothing has to be copied blind.

### 1. clone

```sh
git clone https://github.com/cactozs/quickshell.git ~/.config/quickshell
```

Cloning somewhere else works, but two paths stay hardcoded to `$HOME/.config/quickshell`: the light-palette pass in `style/Theme.qml:426` reads and writes `style/Colors.json` and `style/ColorsLight.json` from there.

### 2. packages

```sh
sudo pacman -S quickshell niri alacritty jq cliphist wl-clipboard brightnessctl \
    curl fd ripgrep matugen awww ttf-material-symbols-variable ttf-nerd-fonts-symbols \
    ttf-jetbrains-mono-nerd hyprlock \
    pipewire wireplumber upower networkmanager ghostty qt6ct gtk3 gtk4
```

`ghostty`, `qt6ct`, `gtk3` and `gtk4` are what the shell themes (step 7); the shell itself runs without them. Optional — the matching feature just disappears without them:

```sh
sudo pacman -S nvidia-utils wlsunset swayidle playerctl papirus-icon-theme imagemagick
```

`imagemagick` only builds the 720px wallpaper previews; without it the manager loads the originals, which is slow for 4K images.

### 3. fonts

Material Symbols (every icon) and Symbols Nerd Font (the one ornament glyph Material Symbols does not carry) come from pacman. The **Monospace** option in the settings menu («Шрифт») is **JetBrainsMono Nerd Font Mono**, also from pacman:

```sh
sudo pacman -S ttf-jetbrains-mono-nerd
fc-list | grep -i "jetbrainsmono nerd font mono"
```

The last line has to print the family. Without it the shell falls back to the default sans in monospace mode.

The default UI font, **Google Sans** (the **Material** option), has no Arch package:

```sh
mkdir -p ~/.local/share/fonts
curl -L -o ~/.local/share/fonts/GoogleSans.ttf \
    "https://raw.githubusercontent.com/google/fonts/main/ofl/googlesans/GoogleSans%5BGRAD%2Copsz%2Cwght%5D.ttf"
fc-cache -f
fc-list | grep -i "google sans"
```

The last line has to print the family. Without the font the text falls back to the default sans.

### 4. the palette (matugen)

The shell's colors come from `style/Colors.json`, written by matugen from the wallpaper. Three files live outside the repo; they are in it too, under `install/`, so the short way is:

```sh
mkdir -p ~/.config/matugen
cp -r install/matugen/. ~/.config/matugen/
```

That is `config.toml` (the dark pass, and the wallpaper setter), `light.toml` (the light pass) and `templates/quickshell.json` (the roles matugen fills in). The `output_path`s inside point at `~/.config/quickshell/style/` — change them if you cloned elsewhere.

`~/.config/matugen/config.toml`:

```toml
[config]
version_check = false
source_color_index = 0
fallback_color = "#6750A4"

[config.wallpaper]
set = true
command = "/usr/sbin/awww img --transition-type center {{ image }}"

[templates.quickshell]
input_path = "templates/quickshell.json"
output_path = "~/.config/quickshell/style/Colors.json"
type = "SchemeContent"
```

`~/.config/matugen/light.toml` — the same template with a different output and deliberately **no** `[config.wallpaper]`: regenerating the light palette must not re-apply the wallpaper. The mode comes from the command line only (`matugen -m light`), a template cannot ask for another one, which is why the light pass needs its own config:

```toml
[config]
version_check = false
source_color_index = 0
fallback_color = "#6750A4"

[templates.quickshell]
input_path = "templates/quickshell.json"
output_path = "~/.config/quickshell/style/ColorsLight.json"
type = "SchemeContent"
```

`~/.config/matugen/templates/quickshell.json` — the roles the shell reads, one per line:

```json
{
  "primary": "{{colors.primary.default.hex}}",
  "on_primary": "{{colors.on_primary.default.hex}}",
  "primary_container": "{{colors.primary_container.default.hex}}",
  "on_primary_container": "{{colors.on_primary_container.default.hex}}",
  "secondary": "{{colors.secondary.default.hex}}",
  "on_secondary": "{{colors.on_secondary.default.hex}}",
  "secondary_container": "{{colors.secondary_container.default.hex}}",
  "on_secondary_container": "{{colors.on_secondary_container.default.hex}}",
  "tertiary": "{{colors.tertiary.default.hex}}",
  "on_tertiary": "{{colors.on_tertiary.default.hex}}",
  "tertiary_container": "{{colors.tertiary_container.default.hex}}",
  "on_tertiary_container": "{{colors.on_tertiary_container.default.hex}}",
  "error": "{{colors.error.default.hex}}",
  "on_error": "{{colors.on_error.default.hex}}",
  "error_container": "{{colors.error_container.default.hex}}",
  "on_error_container": "{{colors.on_error_container.default.hex}}",
  "surface": "{{colors.surface.default.hex}}",
  "on_surface": "{{colors.on_surface.default.hex}}",
  "surface_variant": "{{colors.surface_variant.default.hex}}",
  "on_surface_variant": "{{colors.on_surface_variant.default.hex}}",
  "surface_dim": "{{colors.surface_dim.default.hex}}",
  "surface_bright": "{{colors.surface_bright.default.hex}}",
  "surface_container_lowest": "{{colors.surface_container_lowest.default.hex}}",
  "surface_container_low": "{{colors.surface_container_low.default.hex}}",
  "surface_container": "{{colors.surface_container.default.hex}}",
  "surface_container_high": "{{colors.surface_container_high.default.hex}}",
  "surface_container_highest": "{{colors.surface_container_highest.default.hex}}",
  "outline": "{{colors.outline.default.hex}}",
  "outline_variant": "{{colors.outline_variant.default.hex}}",
  "inverse_surface": "{{colors.inverse_surface.default.hex}}",
  "inverse_on_surface": "{{colors.inverse_on_surface.default.hex}}",
  "inverse_primary": "{{colors.inverse_primary.default.hex}}",
  "scrim": "{{colors.scrim.default.hex}}",
  "shadow": "{{colors.shadow.default.hex}}"
}
```

Then generate the first palette from any image:

```sh
matugen image ~/Pictures/Wallpapers/<file>
```

### 5. the awww shim

`awww img <file>` has to go through matugen, or the colors never follow the wallpaper. A shim in `/usr/local/bin` (ahead of `/usr/bin` in PATH) does that:

```sh
sudo install -m755 install/awww /usr/local/bin/awww
```

The shim itself:

```sh
#!/bin/sh
# Wallpapers set as `awww img <file>` go through matugen, which applies the
# image (via the real /usr/sbin/awww) and regenerates
# ~/.config/quickshell/style/Colors.json; the Quickshell bar watches that
# file and recolors live.
#
# Only plain `awww img <existing-file>` is intercepted. Everything else
# (query/restore/pause, extra flags, `0xRRGGBB` colors, `-` from stdin)
# reaches the real binary unchanged, just without regenerating colors.
if [ $# -eq 2 ] && [ "$1" = img ] && [ -f "$2" ]; then
    matugen image "$2" && exit 0
    # matugen failed to read the image: still set the wallpaper.
fi
exec /usr/sbin/awww "$@"
```

The wallpaper command in `config.toml` calls the real `/usr/sbin/awww` on purpose — going through the shim again would loop.

### 6. niri

`~/.config/niri/config.kdl` — the generated colors have to come after the layout, niri merges includes positionally:

```kdl
include "layout.kdl"
include "quickshell.kdl"
```

`~/.config/niri/quickshell.kdl` is written by the shell (border colors, focus ring, blur source). It does not exist before the first run — `touch ~/.config/niri/quickshell.kdl` before adding the include, or niri refuses to start on a missing include.

`~/.config/niri/autostart.kdl`:

```kdl
spawn-at-startup "quickshell"
spawn-at-startup "awww-daemon"
spawn-at-startup "sh" "-c" "wl-paste --type text --watch cliphist store"
spawn-at-startup "sh" "-c" "wl-paste --type image --watch cliphist store"
```

`~/.config/niri/environment.kdl`:

```kdl
environment {
    QT_QPA_PLATFORMTHEME "qt6ct"
}
```

The keybinds go into `~/.config/niri/keybinds.kdl` — see [keybinds](#keybinds) below.

### 7. the terminal and the rest of the desktop

The shell writes the palette onto GTK, Qt, ghostty and the niri border (`services/SystemTheme.qml` is the single writer). Three pointers are yours to add — two here, the third is the niri include from step 6:

`~/.config/ghostty/config`:

```ini
theme = Quickshell
```

`~/.config/qt6ct/qt6ct.conf` (create the file if qt6ct is not set up yet):

```ini
[Appearance]
color_scheme_path=/home/you/.config/qt6ct/colors/matugen.conf
custom_palette=true
```

(Qt apps read the palette at startup, so they need a restart to pick it up.) The shell writes the file the path points at (`~/.config/qt6ct/colors/matugen.conf`) on its first run, and creates the directory if it is missing.

### 8. wallpapers and the two local settings

The wallpaper manager lists `~/Pictures/Wallpapers`, recursively:

```sh
mkdir -p ~/Pictures/Wallpapers
```

Put the images there. Dropping one onto the bare desktop or onto the bar sets it as the wallpaper instead.

Two paths are yours to change: `services/Wallpapers.qml:18` (the wallpaper folder) and `services/Weather.qml:15-16` (the city the weather chip asks about — Moscow by default).

### 9. run it

```sh
quickshell
```

In the foreground first: this project has no build and no tests, so the stderr of the running shell is the only check there is. It reloads itself when a file changes, so the config can be edited while it runs.

Afterwards put `spawn-at-startup "quickshell"` in niri's autostart (step 6) and stop the manual instance. `qs ipc show` prints the live list of IPC targets, `qs log` prints what the running instance says.

### 10. check

- the bar is up, with the clock, the workspaces and the volume/battery chips;
- the colors follow the wallpaper: `matugen image <file>` recolors the bar live;
- `qs ipc call launcher toggle` opens the launcher, `qs ipc call clipboard toggle` the clipboard;
- `qs ipc call settings theme light` flips the shell *and* the terminal, the GTK apps and the niri border to light;
- `qs ipc call settings style new` switches the style pack, `qs ipc call settings colorscheme gruvbox` the palette;
- the wallpaper manager lists `~/Pictures/Wallpapers` and the previews load.

### troubleshooting

| symptom | cause | fix |
|---|---|---|
| the text is in the default sans | Google Sans (or JetBrainsMono Nerd Font Mono, in monospace mode) is not installed | step 3 |
| the bar stays on the default purple | matugen never ran, or `output_path` points elsewhere | step 4, `matugen image <file>` |
| the wallpaper changes but the colors do not | the `awww` shim is missing | step 5 |
| a panel opens on the wrong monitor | `toggle` opens on the first screen | `toggleOn $(niri msg --json focused-output \| jq -r .name)` |
| the blur does nothing | the niri include is missing, or the style pack paints no acrylic | step 6, «Блюр» and the style in the settings menu |
| `awww img` does nothing | the daemon is not running | `spawn-at-startup "awww-daemon"` |
| Qt apps keep the old colors | they read the palette at startup | restart them |
| the shell does not start | QML error | run `quickshell` in the terminal and read the error, `qs log` for a running instance |

## dependencies

Wayland + niri, Arch package names. The install commands are in [installation](#installation); this table is what each package is for.

| package | used for |
|---|---|
| `fd` | wallpaper library scan, replaces `find` (`services/Wallpapers.qml`) |
| `grep` | replaced by `rg` (`services/SystemMonitor.qml`) |
| `ripgrep` (`rg`) | reads `/proc/meminfo` for the RAM chip, replaces `grep` (`services/SystemMonitor.qml:158`) |
| `quickshell` | the shell itself and `qs` IPC (`qs ipc call launcher toggle`); pulls in Qt 6 |
| `niri` | workspaces, window title, keyboard layout, focus/quit via `niri msg -j` (`services/Niri.qml`) |
| `alacritty` | terminal for `Terminal=true` desktop entries (`modules/Launcher.qml:27`) |
| `jq` | niri keybinds resolve the focused output before `qs ipc call` |
| `cliphist` | clipboard history backend (`modules/ClipboardLauncher.qml`) |
| `wl-clipboard` | `wl-paste --watch cliphist store` at startup, `wl-copy` on paste-back |
| `brightnessctl` | backlight chip and quick settings slider (`services/Brightness.qml`) |
| `curl` | weather chip, open-meteo.com (`services/Weather.qml:64`) |
| `matugen` | generates `style/Colors.json` (dark) from the wallpaper (SchemeContent), and `style/ColorsLight.json` (light) through the second `matugen -m light` pass the shell runs (`~/.config/matugen/light.toml`) |
| `awww` | wallpaper; `awww-daemon` at startup, `awww img` routed through matugen by the `/usr/local/bin/awww` shim |
| `gtk3` / `gtk4` | GTK colors: `~/.config/gtk-3.0/gtk.css` and `gtk-4.0/gtk.css`, written from the shell palette (`services/SystemTheme.qml`) |
| `ghostty` | terminal; the shell writes `~/.config/ghostty/themes/Quickshell` and reloads it with `SIGUSR2` |
| `qt6ct` | Qt palette: the shell writes `~/.config/qt6ct/colors/matugen.conf`; niri sets `QT_QPA_PLATFORMTHEME=qt6ct` |
| `ttf-material-symbols-variable` | every icon (`Theme.iconFont`) |
| `ttf-nerd-fonts-symbols` | "Symbols Nerd Font" (`Theme.nerdFont`), the one ornament glyph Material Symbols doesn't carry (`modules/Settings.qml:319`) |
| `ttf-jetbrains-mono-nerd` | "JetBrainsMono Nerd Font Mono", the **Monospace** option of the «Шрифт» setting (`Theme.fontFamily`) |
| `hyprlock` | "Блокировка" in the power menu, `Super+Alt+L` |
| `pipewire` + `wireplumber` | volume chip, slider, mute (`Quickshell.Services.Pipewire`) |
| `upower` | battery chip (`Quickshell.Services.UPower`) |
| `networkmanager` | Wi-Fi tile and network list (`Quickshell.Networking`) |
| `nvidia-utils` | GPU rows in the system popup (`nvidia-smi`, `services/SystemMonitor.qml:203`) |
| `wlsunset` | night light tile (`services/NightLight.qml`) |
| `swayidle` | idle → lock (niri autostart, not the shell) |
| `playerctl` | media keys in niri keybinds |
| `papirus-icon-theme` | app icons; `hicolor-icon-theme` is pulled in by quickshell |
| `imagemagick` | 720px wallpaper previews (`magick`, `services/Wallpapers.qml:127`); without it the tiles load the originals |

## keybinds

A bind is just a `qs ipc` call: `qs` ships with quickshell, and the shell has to be running (`spawn-at-startup "quickshell"` in niri's autostart). To open a panel on the monitor you're on, the bind also needs `niri` and `jq`, to pass the focused output name:

```kdl
Mod+A       repeat=false { spawn-sh "qs ipc call launcher toggleOn $(niri msg --json focused-output | jq -r .name)"; }
Mod+V       repeat=false { spawn-sh "qs ipc call clipboard toggleOn $(niri msg --json focused-output | jq -r .name)"; }
Mod+N       repeat=false { spawn-sh "qs ipc call center toggleOn $(niri msg --json focused-output | jq -r .name)"; }
Mod+Ctrl+W  repeat=false { spawn-sh "qs ipc call wallpaper toggleOn $(niri msg --json focused-output | jq -r .name)"; }
Mod+Shift+N repeat=false { spawn "qs" "ipc" "call" "notifs" "toggleDnd"; }
Mod+P       repeat=false { spawn "qs" "ipc" "call" "bar" "toggle"; }
```

Without niri/jq, drop `toggleOn $(…)` for `toggle` — it opens on the first screen.

| target | functions |
|---|---|
| `launcher`, `clipboard`, `center` (notifications) | `toggle`, `toggleOn <output>`, `close` |
| `settings` (quick settings) | the same + `launcherView <bool>`, `style <m3\|blur\|new>`, `colorscheme <matugen\|oled\|gruvbox>`, `theme <dark\|light>`, `font <material\|mono>`, `blur <wallpaper\|window>` |
| `wallpaper` (manager) | the same + `random` — applies a random wallpaper without opening the panel |
| `bar` | `toggle` |
| `notifs` | `toggleDnd`, `dnd`, `clear` |

`<output>` is a monitor name (`"eDP-1"`, see `niri msg outputs`), not a number. `qs ipc show` prints the live list of targets and functions. Esc or a click outside closes an open panel. Volume, brightness, media and lock binds don't go through the shell at all: plain `wpctl`, `brightnessctl`, `playerctl`, `hyprlock`.

Notes:

- The shell themes the whole desktop, not just itself: «Тема» and «Цвета» in the settings menu (or `qs ipc call settings theme light`, `… colorscheme gruvbox`) also rewrite the GTK3/GTK4 `gtk.css`, the ghostty theme, the qt6ct palette, the niri border colors and `gsettings color-scheme`; `services/SystemTheme.qml` is the single writer. These files are generated — hand edits survive until the next theme change. Three pieces of one-time plumbing are expected on the user's side: `theme = Quickshell` in `~/.config/ghostty/config`, `color_scheme_path=/…/qt6ct/colors/matugen.conf` in `qt6ct.conf` (Qt apps pick a new palette up on restart), and `include "quickshell.kdl"` in `~/.config/niri/config.kdl` — after `layout.kdl`, since niri merges includes positionally and the colors in `quickshell.kdl` (niri border + focus-ring, generated) have to come later to win. Alacritty, btop and yazi keep their own hand-written colors.
- «Блюр» in the settings menu picks what the compositor blurs behind the acrylic plates (the `M3 Blur` and `New` styles paint such plates; under `M3 Inspired` the row is hidden because nothing blurs there). «Обои» is niri's xray blur — the wallpaper alone, the default — and «Окна» blurs what actually sits under the plate, windows included. It lands in the same generated `~/.config/niri/quickshell.kdl` as a `layer-rule` for the shell's namespaces (`qs ipc call settings blur window` also works), and the shell reads the choice back from that file at startup, so it survives a reboot.
- Light mode is a second matugen pass: `~/.config/matugen/light.toml` writes `style/ColorsLight.json` (`matugen -m light` is CLI-only, a template can't ask for another mode), and the shell reruns it whenever the dark palette is newer — on a wallpaper change, or after a shell start. Its `[config]` source-color settings must stay identical to `config.toml`, and it deliberately has no `[config.wallpaper]`, so regenerating light colors never re-applies the wallpaper.
- The UI font is switchable in the settings menu («Шрифт»): **Material** is **Google Sans** (`Theme.fontFamily`), **Monospace** is **JetBrainsMono Nerd Font Mono**. Google Sans has no Arch package — install it by hand, otherwise text falls back to the default sans; the monospace family comes from `ttf-jetbrains-mono-nerd` (step 3). Icons stay in Material Symbols in both modes.
- The wallpaper manager lists `~/Pictures/Wallpapers` recursively (change `services/Wallpapers.qml:18` for another folder); the scan result is cached, so reopening the menu no longer re-decodes all previews; favorites go to `wallpaper-favorites.json` next to the config — runtime state, don't commit it, and are pinned first in the grid.
- Dropping an image file onto the bare desktop or the bar sets it as the wallpaper (`modules/WallpaperDrop.qml`).
- MPRIS players (mpv, browsers, Spotify…) are what the media tile talks to; nothing to install for it.
- Quickshell *is* the notification daemon — don't run dunst/mako/swaync next to it.
- No waybar, wofi/rofi/fuzzel or cava: bar, launcher, clipboard, OSD, notifications and the power menu are all QML. The shell only shells out to `sh` + coreutils against `/proc` and `/sys/class/thermal`, plus `fd` (wallpaper scan) and `rg` (`/proc/meminfo`).
- `brightnessctl` needs access to `/sys/class/backlight` (video group or a udev rule).
