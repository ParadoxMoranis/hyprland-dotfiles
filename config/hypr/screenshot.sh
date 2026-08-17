#!/bin/bash
# Hyprland 截图脚本 - 使用 Satty 注释工具

SCREENSHOT_DIR="$HOME/Pictures/Screenshots"
mkdir -p "$SCREENSHOT_DIR"

run_satty() {
    local output_file="$1"
    satty \
        --filename - \
        --output-filename "$output_file" \
        --copy-command wl-copy \
        --actions-on-enter save-to-clipboard,save-to-file,exit \
        --actions-on-right-click save-to-clipboard,save-to-file,exit \
        --actions-on-escape exit \
        --early-exit
}

is_hypr() {
    [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && command -v hyprctl >/dev/null 2>&1
}

restore_after_selection() {
    sleep 0.1

    if is_hypr; then
        hyprctl dispatch focuscurrentorlast >/dev/null 2>&1 || true
    fi
}

case "$1" in
    # 截全屏并复制到剪贴板
    "full-copy")
        if grim - | wl-copy; then
            notify-send -u low "📸 截图" "全屏已复制到剪贴板"
        else
            notify-send -u critical "❌ 截图失败" "无法截取全屏"
        fi
        ;;

    # 截全屏并保存
    "full-save")
        FILENAME="$SCREENSHOT_DIR/$(date +%Y%m%d_%H%M%S).png"
        if grim "$FILENAME"; then
            notify-send -u low "📸 截图" "已保存到 $FILENAME"
        else
            notify-send -u critical "❌ 截图失败" "无法保存截图"
        fi
        ;;

    # 截取选区并复制到剪贴板
    "area-copy")
        SELECTION=$(slurp)
        if [ -n "$SELECTION" ]; then
            if grim -g "$SELECTION" - | wl-copy; then
                notify-send -u low "📸 截图" "选区已复制到剪贴板"
            else
                notify-send -u critical "❌ 截图失败" "无法截取选区"
            fi
        fi
        restore_after_selection
        ;;

    # 截取选区并保存
    "area-save")
        FILENAME="$SCREENSHOT_DIR/$(date +%Y%m%d_%H%M%S).png"
        SELECTION=$(slurp)
        if [ -n "$SELECTION" ]; then
            if grim -g "$SELECTION" "$FILENAME"; then
                notify-send -u low "📸 截图" "已保存到 $FILENAME"
            else
                notify-send -u critical "❌ 截图失败" "无法保存截图"
            fi
        fi
        restore_after_selection
        ;;

    # 截取选区并用 Satty 注释编辑（主要编辑模式）
    "area-satty")
        SELECTION=$(slurp)
        if [ -n "$SELECTION" ]; then
            FILENAME="$SCREENSHOT_DIR/$(date +%Y%m%d_%H%M%S).png"
            grim -g "$SELECTION" - | run_satty "$FILENAME"
        fi
        restore_after_selection
        ;;

    # 截取全屏并用 Satty 注释编辑
    "full-satty")
        FILENAME="$SCREENSHOT_DIR/$(date +%Y%m%d_%H%M%S).png"
        grim - | run_satty "$FILENAME"
        restore_after_selection
        ;;

    *)
        echo "用法: $0 {full-copy|full-save|area-copy|area-save|area-satty|full-satty}"
        exit 1
        ;;
esac
