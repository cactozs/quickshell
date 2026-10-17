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
    curl matugen awww ttf-material-symbols-variable hyprlock \
    pipewire wireplumber upower networkmanager
```

Optional (the matching feature just disappears without them):

```sh
sudo pacman -S nvidia-utils wlsunset swayidle playerctl papirus-icon-theme
```

| package | used for |
|---|---|
| `quickshell` | the shell itself and `qs` IPC (`qs ipc call launcher toggle`); pulls in Qt 6 |
| `niri` | workspaces, window title, keyboard layout, focus/quit via `niri msg -j` (`services/Niri.qml`) |
| `alacritty` | terminal for `Terminal=true` desktop entries (`modules/Launcher.qml:24`) |
| `jq` | niri keybinds resolve the focused output before `qs ipc call` |
| `cliphist` | clipboard history backend (`modules/ClipboardLauncher.qml`) |
| `wl-clipboard` | `wl-paste --watch cliphist store` at startup, `wl-copy` on paste-back |
| `brightnessctl` | backlight chip and quick settings slider (`services/Brightness.qml`) |
| `curl` | weather chip, open-meteo.com (`services/Weather.qml:64`) |
| `matugen` | generates `style/Colors.json` (SchemeExpressive) from the wallpaper |
| `awww` | wallpaper; `awww-daemon` at startup, `awww img` routed through matugen by the `/usr/local/bin/awww` shim |
| `ttf-material-symbols-variable` | every icon (`Theme.iconFont`) |
| `hyprlock` | "Блокировка" in the power menu, `Super+Alt+L` |
| `pipewire` + `wireplumber` | volume chip, slider, mute (`Quickshell.Services.Pipewire`) |
| `upower` | battery chip (`Quickshell.Services.UPower`) |
| `networkmanager` | Wi-Fi tile and network list (`Quickshell.Networking`) |
| `nvidia-utils` | GPU rows in the system popup (`nvidia-smi`, `services/SystemMonitor.qml:203`) |
| `wlsunset` | night light tile (`services/NightLight.qml`) |
| `swayidle` | idle → lock (niri autostart, not the shell) |
| `playerctl` | media keys in niri keybinds |
| `papirus-icon-theme` | app icons; `hicolor-icon-theme` is pulled in by quickshell |

Notes:

- The UI font is **Google Sans** (`Theme.fontFamily`); no Arch package — install it by hand, otherwise text falls back to the default sans.
- Dropping an image file onto the bare desktop or the bar sets it as the wallpaper (`modules/WallpaperDrop.qml`).
- MPRIS players (mpv, browsers, Spotify…) are what the media tile talks to; nothing to install for it.
- Quickshell *is* the notification daemon — don't run dunst/mako/swaync next to it.
- No waybar, wofi/rofi/fuzzel or cava: bar, launcher, clipboard, OSD, notifications and the power menu are all QML. The shell only shells out to `sh` + coreutils against `/proc` and `/sys/class/thermal`.
- `brightnessctl` needs access to `/sys/class/backlight` (video group or a udev rule).
