#!/usr/bin/env bash

THEME_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/theme"
THEME_STATE_FILE="$THEME_CONFIG_DIR/current-theme"

THEME_BLACK="black"

THEME_BLACK_WALLPAPER="$HOME/Pictures/Wallpapers/wallpaper1.jpeg"

normalize_theme() {
    case "${1:-}" in
        "$THEME_BLACK")
            printf '%s\n' "$1"
            ;;
        *)
            return 1
            ;;
    esac
}

ensure_theme_state_file() {
    mkdir -p "$THEME_CONFIG_DIR"
    printf '%s\n' "$THEME_BLACK" > "$THEME_STATE_FILE"
}

write_theme_state() {
    local theme
    theme="$(normalize_theme "${1:-}")"

    mkdir -p "$THEME_CONFIG_DIR"
    printf '%s\n' "$theme" > "$THEME_STATE_FILE"
}

current_theme() {
    ensure_theme_state_file
    printf '%s\n' "$THEME_BLACK"
}

wallpaper_for_theme() {
    case "$(normalize_theme "${1:-}")" in
        "$THEME_BLACK")
            printf '%s\n' "$THEME_BLACK_WALLPAPER"
            ;;
    esac
}
