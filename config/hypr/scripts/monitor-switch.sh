#!/usr/bin/env bash

set -euo pipefail

# 自动切换显示器：有外接屏则拓展显示，无外接屏则仅用内置屏

MONITOR_SETTINGS="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/monitor-settings.conf"
[ -r "$MONITOR_SETTINGS" ] && source "$MONITOR_SETTINGS"

INTERNAL="${INTERNAL:-eDP-1}"
EXTERNAL="${EXTERNAL:-DP-1}"
INTERNAL_RULE="${INTERNAL_RULE:-preferred,0x0,2}"
EXTERNAL_RULE="${EXTERNAL_RULE:-1920x1080@144,1440x0,1,transform,0}"
THEME_SCRIPT="$HOME/.config/hypr/scripts/apply-theme.sh"

# 检查外接显示器是否已连接（包含disabled状态）
if hyprctl monitors all | grep -q "^Monitor $EXTERNAL"; then
    # 有外接显示器：拓展模式，外接屏放在内置屏右侧
    hyprctl keyword monitor "$EXTERNAL,$EXTERNAL_RULE"
    hyprctl keyword monitor "$INTERNAL,$INTERNAL_RULE"
else
    # 无外接显示器：仅内置屏
    hyprctl keyword monitor "$INTERNAL,$INTERNAL_RULE"
fi

sleep 0.5
"$THEME_SCRIPT" --wallpaper-only --quiet
