#!/usr/bin/env bash
set -euo pipefail

config="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/keybinds.conf"

awk -F ',' '
    /^[[:space:]]*bind[a-z]*[[:space:]]*=/ {
        type = $1
        sub(/^[[:space:]]*/, "", type)
        sub(/[[:space:]]*=[[:space:]]*/, "", type)
        mods = $2
        key = $3
        action = $4
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", mods)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", action)
        combo = (mods == "" ? key : mods " + " key)
        printf "%-30s %s\n", combo, action
    }
' "$config" | rofi -dmenu -i -p "快捷键" \
    -theme "$HOME/.config/rofi/themes/monochrome.rasi" \
    -theme-str 'window {width: 50%; height: 70%;}' \
    -theme-str 'listview {lines: 30;}' \
    -theme-str 'element-text {horizontal-align: 0;}' \
    -no-custom || true
