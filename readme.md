## MOSTLY WRITTEN BY AI

<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/cb5d604d-3d5a-4edc-9d16-75ab9f15e2b1" />
<img width="579" height="359" alt="image" src="https://github.com/user-attachments/assets/7193665a-4ee3-4f24-a5fb-fef10c932e15" />
<img width="579" height="359" alt="image" src="https://github.com/user-attachments/assets/eda354e7-c38f-4d7a-a7c6-81b005560a1f" />
<img width="434" height="389" alt="image" src="https://github.com/user-attachments/assets/4bfb5946-5605-494c-9701-2d5d1e908301" />
<img width="435" height="705" alt="image" src="https://github.com/user-attachments/assets/3770ab2e-68da-4e1a-900f-6fbbc270d477" />
<img width="364" height="115" alt="image" src="https://github.com/user-attachments/assets/72eddaa6-babc-431c-be72-0d5de2d9d425" />
<img width="135" height="69" alt="image" src="https://github.com/user-attachments/assets/c5e1990e-3629-4787-b6a8-09da612e7978" />

a bit inspired by Material 3 Expressive

## dependencies

Wayland + niri, Arch package names. Everything at once:

```sh
sudo pacman -S quickshell niri alacritty jq cliphist wl-clipboard brightnessctl \
    curl fd ripgrep matugen awww ttf-material-symbols-variable ttf-nerd-fonts-symbols hyprlock \
    pipewire wireplumber upower networkmanager
```

Optional (the matching feature just disappears without them):

```sh
sudo pacman -S nvidia-utils wlsunset swayidle playerctl papirus-icon-theme
```

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
| `hyprlock` | "Блокировка" in the power menu, `Super+Alt+L` |
| `pipewire` + `wireplumber` | volume chip, slider, mute (`Quickshell.Services.Pipewire`) |
| `upower` | battery chip (`Quickshell.Services.UPower`) |
| `networkmanager` | Wi-Fi tile and network list (`Quickshell.Networking`) |
| `nvidia-utils` | GPU rows in the system popup (`nvidia-smi`, `services/SystemMonitor.qml:203`) |
| `wlsunset` | night light tile (`services/NightLight.qml`) |
| `swayidle` | idle → lock (niri autostart, not the shell) |
| `playerctl` | media keys in niri keybinds |
| `papirus-icon-theme` | app icons; `hicolor-icon-theme` is pulled in by quickshell |

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
| `settings` (quick settings) | the same + `launcherView <bool>`, `style <m3\|blur\|new>`, `colorscheme <matugen\|oled\|gruvbox>`, `theme <dark\|light>` |
| `wallpaper` (manager) | the same + `random` — applies a random wallpaper without opening the panel |
| `bar` | `toggle` |
| `notifs` | `toggleDnd`, `dnd`, `clear` |

`<output>` is a monitor name (`"eDP-1"`, see `niri msg outputs`), not a number. `qs ipc show` prints the live list of targets and functions. Esc or a click outside closes an open panel. Volume, brightness, media and lock binds don't go through the shell at all: plain `wpctl`, `brightnessctl`, `playerctl`, `hyprlock`.

Notes:

- The shell themes the whole desktop, not just itself: «Тема» and «Цвета» in the settings menu (or `qs ipc call settings theme light`, `… colorscheme gruvbox`) also rewrite the GTK3/GTK4 `gtk.css`, the ghostty theme, the qt6ct palette, the niri border colors and `gsettings color-scheme`; `services/SystemTheme.qml` is the single writer. These files are generated — hand edits survive until the next theme change. Two pieces of one-time plumbing are expected on the user's side: `theme = Quickshell` in `~/.config/ghostty/config`, and `color_scheme_path=/…/qt6ct/colors/matugen.conf` in `qt6ct.conf` (Qt apps pick a new palette up on restart). Alacritty, btop and yazi keep their own hand-written colors.
- Light mode is a second matugen pass: `~/.config/matugen/light.toml` writes `style/ColorsLight.json` (`matugen -m light` is CLI-only, a template can't ask for another mode), and the shell reruns it whenever the dark palette is newer — on a wallpaper change, or after a shell start. Its `[config]` source-color settings must stay identical to `config.toml`, and it deliberately has no `[config.wallpaper]`, so regenerating light colors never re-applies the wallpaper.
- The UI font is **Google Sans** (`Theme.fontFamily`); no Arch package — install it by hand, otherwise text falls back to the default sans.
- The wallpaper manager lists `~/Pictures/Wallpapers` recursively (change `services/Wallpapers.qml:18` for another folder); the scan result is cached, so reopening the menu no longer re-decodes all previews; favorites go to `wallpaper-favorites.json` next to the config — runtime state, don't commit it, and are pinned first in the grid.
- Dropping an image file onto the bare desktop or the bar sets it as the wallpaper (`modules/WallpaperDrop.qml`).
- MPRIS players (mpv, browsers, Spotify…) are what the media tile talks to; nothing to install for it.
- Quickshell *is* the notification daemon — don't run dunst/mako/swaync next to it.
- No waybar, wofi/rofi/fuzzel or cava: bar, launcher, clipboard, OSD, notifications and the power menu are all QML. The shell only shells out to `sh` + coreutils against `/proc` and `/sys/class/thermal`, plus `fd` (wallpaper scan) and `rg` (`/proc/meminfo`).
- `brightnessctl` needs access to `/sys/class/backlight` (video group or a udev rule).
