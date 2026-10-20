#!/usr/bin/env bash
#
# Quickshell installer / doctor for niri.
#
#   ./install.sh              install packages, fonts, matugen configs, shim
#   ./install.sh --check      check the environment, write nothing
#   ./install.sh --no-apply   do not touch niri/ghostty/qt6ct configs
#   ./install.sh --link       symlink ~/.config/quickshell to this checkout
#
# Existing config files are backed up next to the original before an edit.
# Keybinds are never changed automatically; they are printed for you to merge.

set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
NIRI_DIR="$CONFIG_HOME/niri"
MATUGEN_DIR="$CONFIG_HOME/matugen"
QUICKSHELL_LINK="$CONFIG_HOME/quickshell"
GOOGLE_SANS_URL="https://raw.githubusercontent.com/google/fonts/main/ofl/googlesans/GoogleSans%5BGRAD%2Copsz%2Cwght%5D.ttf"

MODE="install"
APPLY=1
PACKAGES=1
FONTS=1
SHIM=1
LINK=0
ERRORS=0
WARNINGS=0

REQUIRED_PACKAGES=(
    quickshell niri matugen awww fd ripgrep jq curl cliphist wl-clipboard
    brightnessctl pipewire wireplumber upower power-profiles-daemon
    networkmanager ttf-material-symbols-variable ttf-nerd-fonts-symbols
    ttf-jetbrains-mono-nerd alacritty gtk3 gtk4 qt6ct ghostty hyprlock
    imagemagick wlsunset swayidle playerctl
)
OPTIONAL_PACKAGES=(papirus-icon-theme nvidia-utils)

if [[ -t 1 ]]; then
    C_RESET=$'\033[0m'
    C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'
    C_RED=$'\033[31m'
    C_BOLD=$'\033[1m'
else
    C_RESET="" C_GREEN="" C_YELLOW="" C_RED="" C_BOLD=""
fi

ok()   { printf '  %s✓%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn() { WARNINGS=$((WARNINGS + 1)); printf '  %s!%s %s\n' "$C_YELLOW" "$C_RESET" "$*"; }
fail() { ERRORS=$((ERRORS + 1)); printf '  %s✗%s %s\n' "$C_RED" "$C_RESET" "$*"; }
note() { printf '%s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

usage() {
    cat <<'EOF'
Usage: ./install.sh [options]

  (no options)       install packages, fonts, matugen configs and the awww shim
  --check            diagnose the environment; do not write anything
  --apply            apply safe niri/ghostty/qt6ct changes (default)
  --no-apply         do not touch niri/ghostty/qt6ct configs
  --no-packages      skip pacman
  --no-fonts         skip the Google Sans download
  --no-shim          skip /usr/local/bin/awww
  --link             symlink ~/.config/quickshell to this checkout if it is free
  -h, --help         show this help

Requires Arch Linux (pacman) and niri. Existing files are backed up before
they are changed. Keybinds are always printed, never edited.
EOF
}

while (($# > 0)); do
    case "$1" in
        --check) MODE="check" ;;
        --apply) APPLY=1 ;;
        --no-apply) APPLY=0 ;;
        --no-packages) PACKAGES=0 ;;
        --no-fonts) FONTS=0 ;;
        --no-shim) SHIM=0 ;;
        --link) LINK=1 ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Unknown option: %s\n\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

backup_file() {
    local file="$1"
    [[ -e "$file" ]] || return 0
    local bak="$file.bak.$(date +%Y%m%d-%H%M%S).$$"
    cp -a -- "$file" "$bak"
    note "  backup: $bak"
}

# Write $2 to $1, but only when the content differs. Returns 0 either way.
write_file() {
    local file="$1" content="$2" tmp
    tmp="$(mktemp "${TMPDIR:-/tmp}/quickshell-install.XXXXXX")"
    printf '%s' "$content" >"$tmp"
    if [[ -f "$file" ]] && cmp -s "$tmp" "$file"; then
        rm -f "$tmp"
        return 0
    fi
    backup_file "$file"
    mkdir -p -- "$(dirname -- "$file")"
    mv -- "$tmp" "$file"
}

append_if_missing() {
    local file="$1" line="$2"
    if [[ -f "$file" ]] && grep -Fqx -- "$line" "$file"; then
        return 0
    fi
    backup_file "$file"
    mkdir -p -- "$(dirname -- "$file")"
    if [[ -s "$file" ]] && [[ -n "$(tail -c 1 -- "$file" 2>/dev/null || true)" ]]; then
        printf '\n' >>"$file"
    fi
    printf '%s\n' "$line" >>"$file"
}

sed_escape() { printf '%s' "$1" | sed 's/[&|\\]/\\&/g'; }

run_root() {
    if ((EUID == 0)); then
        "$@"
    elif have sudo; then
        sudo "$@"
    else
        fail "root is required for: $*"
        return 1
    fi
}

install_packages() {
    local missing=() p
    note "${C_BOLD}Packages${C_RESET}"
    if ! have pacman; then
        warn "pacman not found; install the packages from README.md manually"
        return 0
    fi
    for p in "${REQUIRED_PACKAGES[@]}"; do
        pacman -Q "$p" >/dev/null 2>&1 || missing+=("$p")
    done
    if ((${#missing[@]} == 0)); then
        ok "required packages are installed"
    else
        note "  installing: ${missing[*]}"
        if ! run_root pacman -S --needed -- "${missing[@]}"; then
            fail "pacman failed; install the missing packages manually"
            return 0
        fi
        ok "packages installed"
    fi
    local opt=()
    for p in "${OPTIONAL_PACKAGES[@]}"; do
        pacman -Q "$p" >/dev/null 2>&1 || opt+=("$p")
    done
    if ((${#opt[@]})); then
        note "  optional, not installed: ${opt[*]}"
    fi
}

install_fonts() {
    note "${C_BOLD}Fonts${C_RESET}"
    if ! have fc-match; then
        warn "fontconfig not found; cannot check fonts"
        return 0
    fi
    if fc-match -f '%{family}\n' "Google Sans" 2>/dev/null | head -n 1 | grep -q '^Google Sans'; then
        ok "Google Sans is installed"
    else
        note "  downloading Google Sans (OFL)…"
        mkdir -p -- "$HOME/.local/share/fonts"
        local dest="$HOME/.local/share/fonts/GoogleSans.ttf" tmp
        tmp="$dest.tmp.$$"
        if have curl && curl -fL --retry 3 --connect-timeout 15 -o "$tmp" "$GOOGLE_SANS_URL"; then
            mv -f -- "$tmp" "$dest"
            fc-cache -f >/dev/null 2>&1 || true
            if fc-match -f '%{family}\n' "Google Sans" 2>/dev/null | head -n 1 | grep -q '^Google Sans'; then
                ok "Google Sans installed to $dest"
            else
                warn "Google Sans downloaded but fontconfig does not see it"
            fi
        else
            rm -f -- "$tmp"
            warn "could not download Google Sans; text falls back to the default sans"
        fi
    fi
    if fc-match -f '%{family}\n' "Material Symbols Rounded" 2>/dev/null | head -n 1 | grep -q '^Material Symbols Rounded'; then
        ok "Material Symbols Rounded is installed"
    else
        warn "Material Symbols Rounded is missing (ttf-material-symbols-variable)"
    fi
    if fc-match -f '%{family}\n' "JetBrainsMono Nerd Font Mono" 2>/dev/null | head -n 1 | grep -q '^JetBrainsMono Nerd Font Mono'; then
        ok "JetBrainsMono Nerd Font Mono is installed"
    else
        warn "JetBrainsMono Nerd Font Mono is missing (ttf-jetbrains-mono-nerd)"
    fi
}

install_matugen() {
    note "${C_BOLD}matugen${C_RESET}"
    local source_dir="$REPO_DIR/install/matugen"
    if [[ ! -f "$source_dir/config.toml" ]]; then
        fail "install/matugen/config.toml is missing"
        return 0
    fi
    mkdir -p -- "$MATUGEN_DIR/templates"
    local repo_sed matugen_sed config light
    repo_sed="$(sed_escape "$REPO_DIR")"
    matugen_sed="$(sed_escape "$MATUGEN_DIR")"
    config="$(sed -e "s|~/.config/quickshell|$repo_sed|g" \
        -e "s|input_path = \"templates/quickshell.json\"|input_path = \"$matugen_sed/templates/quickshell.json\"|" \
        "$source_dir/config.toml")"
    light="$(sed -e "s|~/.config/quickshell|$repo_sed|g" \
        -e "s|input_path = \"templates/quickshell.json\"|input_path = \"$matugen_sed/templates/quickshell.json\"|" \
        "$source_dir/light.toml")"
    write_file "$MATUGEN_DIR/config.toml" "$config"$'\n'
    write_file "$MATUGEN_DIR/light.toml" "$light"$'\n'
    if ! cmp -s "$source_dir/templates/quickshell.json" "$MATUGEN_DIR/templates/quickshell.json"; then
        backup_file "$MATUGEN_DIR/templates/quickshell.json"
        cp -- "$source_dir/templates/quickshell.json" "$MATUGEN_DIR/templates/quickshell.json"
    fi
    ok "matugen configs point at $REPO_DIR/style"
}

install_shim() {
    note "${C_BOLD}awww shim${C_RESET}"
    local shim="/usr/local/bin/awww"
    if [[ ! -x /usr/bin/awww ]]; then
        warn "/usr/bin/awww not found; the shim will fall through to a missing binary"
    fi
    if [[ -f "$shim" ]] && cmp -s "$REPO_DIR/install/awww" "$shim"; then
        ok "shim is up to date"
    else
        if [[ -e "$shim" ]]; then
            run_root cp -a -- "$shim" "$shim.bak.$(date +%Y%m%d-%H%M%S).$$" || true
        fi
        if run_root install -Dm755 -- "$REPO_DIR/install/awww" "$shim"; then
            ok "installed $shim"
        else
            fail "could not install $shim"
            return 0
        fi
    fi
    local found
    found="$(command -v awww 2>/dev/null || true)"
    if [[ "$found" == "$shim" ]]; then
        ok "awww resolves to the shim"
    else
        warn "awww resolves to '$found', not '$shim'; check PATH order"
    fi
    if pgrep -x awww-daemon >/dev/null 2>&1; then
        ok "awww-daemon is running"
    else
        warn "awww-daemon is not running; add it to niri autostart"
    fi
}

install_dirs() {
    note "${C_BOLD}Directories${C_RESET}"
    mkdir -p -- "$HOME/Pictures/Wallpapers" \
        "$CONFIG_HOME/gtk-3.0" "$CONFIG_HOME/gtk-4.0" \
        "$CONFIG_HOME/ghostty/themes" "$CONFIG_HOME/qt6ct/colors" \
        "$CONFIG_HOME/hypr"
    mkdir -p -- "$NIRI_DIR"
    [[ -e "$NIRI_DIR/quickshell.kdl" ]] || touch -- "$NIRI_DIR/quickshell.kdl"
    ok "wallpaper and desktop config directories exist"
}

install_hyprlock() {
    local file="$CONFIG_HOME/hypr/hyprlock.conf"
    if [[ -f "$file" ]]; then
        ok "hyprlock config already exists"
    elif [[ -f "$REPO_DIR/install/hyprlock.conf" ]]; then
        cp -- "$REPO_DIR/install/hyprlock.conf" "$file"
        ok "installed a minimal hyprlock config"
    else
        warn "install/hyprlock.conf is missing; create ~/.config/hypr/hyprlock.conf by hand"
    fi
}

maybe_link() {
    local target_real
    target_real="$(readlink -f -- "$QUICKSHELL_LINK" 2>/dev/null || true)"
    if [[ "$REPO_DIR" == "$QUICKSHELL_LINK" ]] || [[ "$target_real" == "$REPO_DIR" ]]; then
        return 0
    fi
    if [[ -e "$QUICKSHELL_LINK" || -L "$QUICKSHELL_LINK" ]]; then
        warn "$QUICKSHELL_LINK exists and is not this checkout"
        note "  launch with: quickshell -p $REPO_DIR"
        note "  or move this checkout there; keybinds use plain 'qs ipc'"
        return 0
    fi
    if ((LINK)); then
        ln -s -- "$REPO_DIR" "$QUICKSHELL_LINK"
        ok "linked $QUICKSHELL_LINK -> $REPO_DIR"
    else
        warn "checkout is not at $QUICKSHELL_LINK"
        note "  run ./install.sh --link to make 'quickshell' and 'qs ipc' find it"
    fi
}

append_niri_autostart() {
    local file="$NIRI_DIR/autostart.kdl"
    if [[ ! -f "$file" ]]; then
        write_file "$file" $'spawn-at-startup "quickshell"\nspawn-at-startup "awww-daemon"\nspawn-at-startup "sh" "-c" "wl-paste --type text --watch cliphist store"\nspawn-at-startup "sh" "-c" "wl-paste --type image --watch cliphist store"\n'
        ok "created autostart.kdl"
        return 0
    fi
    if ! grep -Eq '^[[:space:]]*spawn-at-startup[[:space:]]+.*quickshell' "$file"; then
        append_if_missing "$file" 'spawn-at-startup "quickshell"'
    fi
    append_if_missing "$file" 'spawn-at-startup "awww-daemon"'
    append_if_missing "$file" 'spawn-at-startup "sh" "-c" "wl-paste --type text --watch cliphist store"'
    append_if_missing "$file" 'spawn-at-startup "sh" "-c" "wl-paste --type image --watch cliphist store"'
    ok "autostart entries are present"
}

append_niri_environment() {
    local file="$NIRI_DIR/environment.kdl"
    if [[ ! -f "$file" ]]; then
        write_file "$file" $'environment {\n    QT_QPA_PLATFORMTHEME "qt6ct"\n}\n'
        ok "created environment.kdl"
        return 0
    fi
    if grep -q 'QT_QPA_PLATFORMTHEME' "$file"; then
        ok "QT_QPA_PLATFORMTHEME is set"
        return 0
    fi
    if ! grep -qE '^[[:space:]]*environment[[:space:]]*\{' "$file"; then
        backup_file "$file"
        printf '\n%s\n' 'environment {' '    QT_QPA_PLATFORMTHEME "qt6ct"' '}' >>"$file"
        ok "added an environment block to environment.kdl"
        return 0
    fi
    backup_file "$file"
    local tmp
    tmp="$(mktemp "${TMPDIR:-/tmp}/quickshell-env.XXXXXX")"
    awk '
        BEGIN { inenv = 0; done = 0 }
        /^[[:space:]]*environment[[:space:]]*\{/ { inenv = 1 }
        inenv && /^[[:space:]]*\}/ && !done {
            print "    QT_QPA_PLATFORMTHEME \"qt6ct\""
            done = 1
            inenv = 0
        }
        { print }
    ' "$file" >"$tmp"
    mv -- "$tmp" "$file"
    ok "added QT_QPA_PLATFORMTHEME to environment.kdl"
}

apply_niri() {
    note "${C_BOLD}niri${C_RESET}"
    local config="$NIRI_DIR/config.kdl"
    local quickshell_include='include "quickshell.kdl"'
    if [[ ! -f "$config" ]]; then
        warn "$config not found; add this after layout.kdl:"
        note "  $quickshell_include"
    elif grep -Eq '^[[:space:]]*include[[:space:]]+"quickshell\.kdl"' "$config"; then
        ok "config.kdl includes quickshell.kdl"
    else
        backup_file "$config"
        printf '\n// Quickshell: border/focus-ring colors and blur source (generated).\n%s\n' "$quickshell_include" >>"$config"
        ok "added include to config.kdl"
    fi
    touch -- "$NIRI_DIR/quickshell.kdl"
    append_niri_autostart
    append_niri_environment
    if ! grep -q 'autostart.kdl' "$config" 2>/dev/null; then
        warn "config.kdl does not include autostart.kdl; add the autostart lines manually"
    fi
    if ! grep -q 'environment.kdl' "$config" 2>/dev/null; then
        warn "config.kdl does not include environment.kdl; add the environment block manually"
    fi
}

apply_ghostty() {
    note "${C_BOLD}ghostty${C_RESET}"
    local file="$CONFIG_HOME/ghostty/config"
    if ! have ghostty && [[ ! -d "$CONFIG_HOME/ghostty" ]]; then
        warn "ghostty is not installed; skipping its theme pointer"
        return 0
    fi
    mkdir -p -- "$CONFIG_HOME/ghostty"
    if [[ -f "$file" ]] && grep -Eq '^[[:space:]]*theme[[:space:]]*=' "$file"; then
        if grep -Eq '^[[:space:]]*theme[[:space:]]*=[[:space:]]*Quickshell[[:space:]]*$' "$file"; then
            ok "ghostty already uses the Quickshell theme"
        else
            warn "ghostty already has a theme; set 'theme = Quickshell' manually"
        fi
        return 0
    fi
    append_if_missing "$file" 'theme = Quickshell'
    ok "ghostty will use the Quickshell theme"
}

apply_qt6ct() {
    note "${C_BOLD}qt6ct${C_RESET}"
    local file="$CONFIG_HOME/qt6ct/qt6ct.conf"
    local palette="$CONFIG_HOME/qt6ct/colors/matugen.conf"
    if [[ -f "$file" ]] && grep -q '^color_scheme_path=' "$file"; then
        if grep -q 'matugen.conf' "$file"; then
            ok "qt6ct already points at matugen.conf"
        else
            warn "qt6ct color_scheme_path does not point at matugen.conf"
        fi
        return 0
    fi
    if [[ ! -f "$file" ]]; then
        write_file "$file" $'[Appearance]\ncolor_scheme_path='"$palette"$'\ncustom_palette=true\n'
        ok "created qt6ct.conf"
        return 0
    fi
    backup_file "$file"
    local tmp
    tmp="$(mktemp "${TMPDIR:-/tmp}/quickshell-qt6ct.XXXXXX")"
    awk -v path="$palette" '
        BEGIN { inapp = 0; done = 0; custom = 0 }
        /^\[/ {
            if (inapp && !custom) {
                print "custom_palette=true"
                custom = 1
            }
            inapp = ($0 ~ /^\[Appearance\]/)
            if (inapp) {
                print
                print "color_scheme_path=" path
                done = 1
                next
            }
        }
        inapp && /^[[:space:]]*custom_palette[[:space:]]*=/ {
            print "custom_palette=true"
            custom = 1
            next
        }
        { print }
        END {
            if (inapp && !custom)
                print "custom_palette=true"
            if (!done) {
                print ""
                print "[Appearance]"
                print "color_scheme_path=" path
                print "custom_palette=true"
            }
        }
    ' "$file" >"$tmp"
    mv -- "$tmp" "$file"
    ok "added color_scheme_path to qt6ct.conf"
}

print_keybinds() {
    note ""
    note "${C_BOLD}Add these to $NIRI_DIR/keybinds.kdl (merge, do not replace):${C_RESET}"
    cat <<'EOF'
    Mod+A       repeat=false { spawn-sh "qs ipc call launcher toggleOn $(niri msg --json focused-output | jq -r .name)"; }
    Mod+V       repeat=false { spawn-sh "qs ipc call clipboard toggleOn $(niri msg --json focused-output | jq -r .name)"; }
    Mod+N       repeat=false { spawn-sh "qs ipc call center toggleOn $(niri msg --json focused-output | jq -r .name)"; }
    Mod+Ctrl+W  repeat=false { spawn-sh "qs ipc call wallpaper toggleOn $(niri msg --json focused-output | jq -r .name)"; }
    Mod+Shift+N repeat=false { spawn "qs" "ipc" "call" "notifs" "toggleDnd"; }
    Mod+P       repeat=false { spawn "qs" "ipc" "call" "bar" "toggle"; }
EOF
}

print_final() {
    note ""
    note "${C_BOLD}Done.${C_RESET}"
    if [[ "$REPO_DIR" != "$QUICKSHELL_LINK" ]] && [[ "$(readlink -f -- "$QUICKSHELL_LINK" 2>/dev/null || true)" != "$REPO_DIR" ]]; then
        note "  run: quickshell -p $REPO_DIR"
    else
        note "  run: quickshell"
    fi
    note "  check: ./install.sh --check"
    note "  logs:  qs log"
    note ""
    note "The shell reloads itself when a QML file changes. Quickshell is the"
    note "notification daemon: do not run dunst, mako or swaync next to it."
}

# ---- doctor ----------------------------------------------------------------

check_pkg() {
    local p="$1"
    if ! have pacman; then return 0; fi
    if pacman -Q "$p" >/dev/null 2>&1; then ok "$p"; else warn "$p is not installed"; fi
}

check_font() {
    local family="$1" package="$2"
    if have fc-match && fc-match -f '%{family}\n' "$family" 2>/dev/null | head -n 1 | grep -qF "$family"; then
        ok "$family"
    else
        warn "$family is missing ($package)"
    fi
}

version_ge() {
    [[ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n 1)" == "$2" ]]
}

check_versions() {
    note "${C_BOLD}Versions${C_RESET}"
    if have quickshell; then
        local raw v
        raw="$(quickshell --version 2>/dev/null | head -n 1 || true)"
        v="$(printf '%s' "$raw" | grep -oE '[0-9]+(\.[0-9]+)+' | head -n 1 || true)"
        if [[ -n "$v" ]] && version_ge "$v" "0.3.2"; then
            ok "$raw"
        else
            warn "Quickshell 0.3.2+ is expected, got: ${raw:-unknown}"
        fi
    else
        fail "quickshell is not installed"
    fi
    if have niri; then ok "$(niri --version 2>/dev/null | head -n 1)"; else fail "niri is not installed"; fi
    if have matugen; then ok "$(matugen --version 2>/dev/null | head -n 1)"; else warn "matugen is not installed"; fi
    if have awww; then ok "$(awww --version 2>/dev/null | head -n 1)"; else warn "awww is not installed"; fi
}

check_matugen() {
    note "${C_BOLD}matugen${C_RESET}"
    local config="$MATUGEN_DIR/config.toml" light="$MATUGEN_DIR/light.toml"
    local template="$MATUGEN_DIR/templates/quickshell.json"
    for f in "$config" "$light" "$template"; do
        if [[ -f "$f" ]]; then ok "$f"; else fail "$f is missing (run ./install.sh)"; fi
    done
    if [[ -f "$config" ]] && grep -Fq "output_path = \"$REPO_DIR/style/Colors.json\"" "$config"; then
        ok "dark palette points at $REPO_DIR/style/Colors.json"
    elif [[ -f "$config" ]]; then
        warn "config.toml output_path does not point at $REPO_DIR/style/Colors.json"
    fi
    if [[ -f "$light" ]] && grep -Fq "output_path = \"$REPO_DIR/style/ColorsLight.json\"" "$light"; then
        ok "light palette points at $REPO_DIR/style/ColorsLight.json"
    elif [[ -f "$light" ]]; then
        warn "light.toml output_path does not point at $REPO_DIR/style/ColorsLight.json"
    fi
}

check_shim() {
    note "${C_BOLD}awww${C_RESET}"
    local shim="/usr/local/bin/awww" found
    found="$(command -v awww 2>/dev/null || true)"
    if [[ "$found" == "$shim" ]]; then ok "PATH resolves to $shim"; else warn "awww resolves to '${found:-nothing}', expected $shim"; fi
    if [[ -x "$shim" ]] && grep -q 'matugen image' "$shim"; then ok "shim calls matugen"; else warn "shim is missing or does not call matugen"; fi
    if [[ -x /usr/bin/awww ]]; then ok "/usr/bin/awww exists"; else fail "/usr/bin/awww is missing"; fi
    if pgrep -x awww-daemon >/dev/null 2>&1; then ok "awww-daemon is running"; else warn "awww-daemon is not running"; fi
}

check_niri() {
    note "${C_BOLD}niri${C_RESET}"
    local config="$NIRI_DIR/config.kdl"
    if [[ -f "$config" ]] && grep -Eq '^[[:space:]]*include[[:space:]]+"quickshell\.kdl"' "$config"; then
        ok "config.kdl includes quickshell.kdl"
    else
        warn "add include \"quickshell.kdl\" to $config (after layout.kdl)"
    fi
    if [[ -f "$NIRI_DIR/quickshell.kdl" ]]; then ok "quickshell.kdl exists"; else fail "$NIRI_DIR/quickshell.kdl is missing"; fi
    if [[ -f "$NIRI_DIR/autostart.kdl" ]] && grep -Eq '^[[:space:]]*spawn-at-startup[[:space:]]+.*quickshell' "$NIRI_DIR/autostart.kdl"; then
        ok "autostart: quickshell"
    else
        warn "missing autostart: spawn-at-startup \"quickshell\""
    fi
    for line in \
        'spawn-at-startup "awww-daemon"' \
        'spawn-at-startup "sh" "-c" "wl-paste --type text --watch cliphist store"'; do
        if [[ -f "$NIRI_DIR/autostart.kdl" ]] && grep -Fqx "$line" "$NIRI_DIR/autostart.kdl"; then
            ok "autostart: $line"
        else
            warn "missing autostart: $line"
        fi
    done
    if [[ -f "$NIRI_DIR/environment.kdl" ]] && grep -q 'QT_QPA_PLATFORMTHEME' "$NIRI_DIR/environment.kdl"; then
        ok "QT_QPA_PLATFORMTHEME is set"
    else
        warn "QT_QPA_PLATFORMTHEME is not set in $NIRI_DIR/environment.kdl"
    fi
}

check_desktop() {
    note "${C_BOLD}Desktop${C_RESET}"
    local ghostty="$CONFIG_HOME/ghostty/config" qt6ct="$CONFIG_HOME/qt6ct/qt6ct.conf"
    local palette="$CONFIG_HOME/qt6ct/colors/matugen.conf"
    if [[ -f "$ghostty" ]] && grep -Eq '^[[:space:]]*theme[[:space:]]*=[[:space:]]*Quickshell[[:space:]]*$' "$ghostty"; then
        ok "ghostty theme = Quickshell"
    else
        warn "set 'theme = Quickshell' in $ghostty"
    fi
    if [[ -f "$qt6ct" ]] && grep -q "color_scheme_path=.*matugen.conf" "$qt6ct"; then
        ok "qt6ct points at matugen.conf"
    else
        warn "qt6ct color_scheme_path is missing"
    fi
    if [[ -f "$palette" ]]; then ok "$palette exists"; else warn "$palette does not exist yet (first shell start writes it)"; fi
    if [[ -d "$HOME/Pictures/Wallpapers" ]]; then
        local count
        count="$(find "$HOME/Pictures/Wallpapers" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) 2>/dev/null | wc -l)"
        if ((count > 0)); then ok "$count wallpaper(s) in ~/Pictures/Wallpapers"; else warn "$HOME/Pictures/Wallpapers is empty"; fi
    else
        warn "$HOME/Pictures/Wallpapers does not exist"
    fi
    if [[ -f "$REPO_DIR/style/Colors.json" ]]; then ok "style/Colors.json exists"; else note "  style/Colors.json is absent; the built-in baseline palette is used"; fi
    if have hyprlock; then
        if [[ -f "$CONFIG_HOME/hypr/hyprlock.conf" ]]; then ok "hyprlock config exists"; else warn "hyprlock is installed but ~/.config/hypr/hyprlock.conf is missing"; fi
    else
        warn "hyprlock is not installed (the power menu lock entry will fail)"
    fi
}

check_services() {
    note "${C_BOLD}Services${C_RESET}"
    local unit
    for unit in upower power-profiles-daemon NetworkManager; do
        if have systemctl && systemctl is-active --quiet "$unit"; then ok "$unit is active"; else warn "$unit is not active"; fi
    done
    if have qs && qs ipc show >/dev/null 2>&1; then ok "running shell answers qs ipc"; else warn "no running shell (start quickshell)"; fi
}

check_repo() {
    note "${C_BOLD}Checkout${C_RESET}"
    if [[ "$REPO_DIR" == "$QUICKSHELL_LINK" ]] || [[ "$(readlink -f -- "$QUICKSHELL_LINK" 2>/dev/null || true)" == "$REPO_DIR" ]]; then
        ok "checkout is reachable as $QUICKSHELL_LINK"
    else
        warn "checkout is $REPO_DIR, not $QUICKSHELL_LINK (use --link or quickshell -p)"
    fi
    if [[ -f "$REPO_DIR/shell.qml" ]]; then ok "shell.qml exists"; else fail "shell.qml is missing"; fi
}

run_checks() {
    note "${C_BOLD}Quickshell doctor${C_RESET}"
    note ""
    check_versions
    note "${C_BOLD}Packages${C_RESET}"
    local p
    if have pacman; then
        for p in "${REQUIRED_PACKAGES[@]}"; do
            check_pkg "$p"
        done
    else
        for p in quickshell niri matugen awww fd rg jq curl cliphist wl-copy brightnessctl; do
            if have "$p"; then ok "$p"; else warn "$p is not installed"; fi
        done
    fi
    note "${C_BOLD}Fonts${C_RESET}"
    check_font "Google Sans" "GoogleSans.ttf"
    check_font "Material Symbols Rounded" "ttf-material-symbols-variable"
    check_font "JetBrainsMono Nerd Font Mono" "ttf-jetbrains-mono-nerd"
    check_font "Symbols Nerd Font" "ttf-nerd-fonts-symbols"
    check_matugen
    check_shim
    check_niri
    check_desktop
    check_services
    check_repo
    note ""
    if ((ERRORS > 0)); then
        note "${C_RED}${ERRORS} error(s), ${WARNINGS} warning(s).${C_RESET}"
        return 1
    fi
    note "${C_GREEN}No errors, ${WARNINGS} warning(s).${C_RESET}"
}

# ---- main ------------------------------------------------------------------

if [[ "$MODE" == "check" ]]; then
    run_checks
    exit $?
fi

note "${C_BOLD}Quickshell installer${C_RESET}"
note "  repo:   $REPO_DIR"
note "  config: $CONFIG_HOME"
note ""

((PACKAGES)) && install_packages
((FONTS)) && install_fonts
install_matugen
((SHIM)) && install_shim
install_dirs
install_hyprlock
maybe_link

if ((APPLY)); then
    note "${C_BOLD}Config pointers${C_RESET}"
    apply_niri
    apply_ghostty
    apply_qt6ct
else
    warn "skipping niri/ghostty/qt6ct changes (--no-apply)"
fi

print_keybinds
print_final
