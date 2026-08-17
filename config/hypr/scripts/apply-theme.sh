#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"

source "$SCRIPT_DIR/theme-lib.sh"

QUIET=0
STARTUP=0
WALLPAPER_ONLY=0
TARGET_THEME=""

copy_theme_files() {
    local theme="$1"

    local source_file target_file
    local pairs=(
        "hypr/themes/${theme}.conf:hypr/themes/current.conf"
        "waybar/themes/${theme}.css:waybar/theme-current.css"
        "kitty/themes/${theme}.conf:kitty/current-theme.conf"
        "alacritty/themes/${theme}.toml:alacritty/themes/current-theme.toml"
        "rofi/themes/${theme}.rasi:rofi/themes/current-theme.rasi"
        "mako/themes/${theme}.conf:mako/config"
    )

    for pair in "${pairs[@]}"; do
        source_file="$CONFIG_DIR/${pair%%:*}"
        target_file="$CONFIG_DIR/${pair#*:}"
        if [ -f "$source_file" ] && [ -d "$(dirname "$target_file")" ]; then
            cp "$source_file" "$target_file"
        fi
    done
}

apply_wallpaper() {
    local theme="$1"
    local wallpaper

    wallpaper="$(wallpaper_for_theme "$theme")"

    if command -v awww >/dev/null 2>&1 && pgrep -x awww-daemon >/dev/null 2>&1; then
        awww img "$wallpaper" --transition-type fade --transition-duration 0.5 >/dev/null 2>&1 || true
    elif command -v swww >/dev/null 2>&1 && pgrep -x swww-daemon >/dev/null 2>&1; then
        swww img "$wallpaper" --transition-type fade --transition-duration 0.5 >/dev/null 2>&1 || true
    fi
}

reload_hyprland() {
    if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        hyprctl reload >/dev/null 2>&1 || true
    fi
}

restart_waybar() {
    local waybar_config

    waybar_config="$(waybar_config_path)"

    if pgrep -x waybar >/dev/null 2>&1; then
        pkill -x waybar || true
        sleep 0.2
    fi

    if [ -n "${WAYLAND_DISPLAY:-}" ]; then
        env GDK_BACKEND=wayland WAYLAND_DISPLAY="$WAYLAND_DISPLAY" \
            waybar -c "$waybar_config" >/dev/null 2>&1 &
        return 0
    fi

    waybar -c "$waybar_config" >/dev/null 2>&1 &
}

restart_mako() {
    if pgrep -x mako >/dev/null 2>&1; then
        makoctl reload >/dev/null 2>&1 || {
            pkill -x mako || true
            sleep 0.2
        }
        return 0
    fi

    mako >/dev/null 2>&1 &
}

reload_kitty() {
    if pgrep -x kitty >/dev/null 2>&1; then
        kitten @ --to "unix:/tmp/kitty-${USER}" load-config "$CONFIG_DIR/kitty/kitty.conf" >/dev/null 2>&1 || true
    fi
}

waybar_config_path() {
    local pid cmdline arg next_is_config
    local default_config="$CONFIG_DIR/waybar/config"
    local niri_config="$CONFIG_DIR/waybar/config.niri"

    for pid in $(pgrep -x waybar 2>/dev/null || true); do
        [ -r "/proc/$pid/cmdline" ] || continue
        cmdline="$(tr '\0' '\n' < "/proc/$pid/cmdline")"
        next_is_config=0

        while IFS= read -r arg; do
            if [ "$next_is_config" -eq 1 ]; then
                [ -n "$arg" ] && printf '%s\n' "$arg" && return 0
                break
            fi

            case "$arg" in
                -c|--config)
                    next_is_config=1
                    ;;
                --config=*)
                    printf '%s\n' "${arg#--config=}"
                    return 0
                    ;;
            esac
        done <<< "$cmdline"
    done

    if [ -n "${NIRI_SOCKET:-}" ] && [ -f "$niri_config" ]; then
        printf '%s\n' "$niri_config"
        return 0
    fi

    printf '%s\n' "$default_config"
}

notify_theme_change() {
    local theme="$1"
    local theme_label wallpaper_name

    [ "$QUIET" -eq 1 ] && return 0

    case "$theme" in
        black)
            theme_label="黑白主题"
            ;;
    esac

    wallpaper_name="$(basename "$(wallpaper_for_theme "$theme")")"
    notify-send "主题切换" "已切换到 ${theme_label} (${wallpaper_name})" -t 2200
}

while [ $# -gt 0 ]; do
    case "$1" in
        --theme)
            TARGET_THEME="$(normalize_theme "${2:-}")"
            shift 2
            ;;
        --quiet)
            QUIET=1
            shift
            ;;
        --startup)
            STARTUP=1
            QUIET=1
            shift
            ;;
        --wallpaper-only)
            WALLPAPER_ONLY=1
            shift
            ;;
        *)
            printf 'Unknown option: %s\n' "$1" >&2
            exit 1
            ;;
    esac
done

if [ -z "$TARGET_THEME" ]; then
    TARGET_THEME="$(current_theme)"
else
    write_theme_state "$TARGET_THEME"
fi

if [ "$WALLPAPER_ONLY" -eq 0 ]; then
    copy_theme_files "$TARGET_THEME"
    reload_hyprland

    if [ "$STARTUP" -eq 0 ]; then
        restart_waybar
        restart_mako
        reload_kitty
    fi
fi

apply_wallpaper "$TARGET_THEME"
notify_theme_change "$TARGET_THEME"
