#!/bin/bash

PINNED_FILE="$HOME/.config/hypr/clipboard-pinned.txt"

if [ ! -f "$PINNED_FILE" ]; then
    cat > "$PINNED_FILE" << 'EOF'
example@email.com
常用文本示例
https://example.com
EOF
fi

selected=$(rofi -dmenu -p "固定条目" -theme "$HOME/.config/rofi/themes/monochrome.rasi" < "$PINNED_FILE")
[ -n "$selected" ] && echo "$selected" | wl-copy
