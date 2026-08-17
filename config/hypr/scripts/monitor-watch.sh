#!/bin/bash
# 监听 Hyprland 显示器插拔事件，自动调用 monitor-switch.sh

SWITCH_SCRIPT="$HOME/.config/hypr/scripts/monitor-switch.sh"

handle() {
    case $1 in
        monitoradded*|monitorremoved*)
            sleep 0.5  # 等待显示器完全初始化
            "$SWITCH_SCRIPT"
            ;;
    esac
}

socat - "UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" | while read -r line; do
    handle "$line"
done
