#!/bin/bash

# 固定的剪贴板条目配置文件
PINNED_FILE="$HOME/.config/hypr/clipboard-pinned.txt"

# 如果配置文件不存在，创建示例
if [ ! -f "$PINNED_FILE" ]; then
    cat > "$PINNED_FILE" << 'EOF'
📌 example@email.com
📌 常用文本示例
📌 https://example.com
EOF
fi

# 读取固定条目并添加到列表顶部
pinned_items=$(cat "$PINNED_FILE")

# 获取历史记录
history_items=$(cliphist list)

# 合并显示（固定条目在上方）
selected=$(printf "%s\n%s" "$pinned_items" "$history_items" | rofi -dmenu -p "剪贴板")

# 如果选择的是固定条目（以📌开头），去掉标记
if [[ "$selected" == 📌* ]]; then
    echo "${selected:2}" | wl-copy
else
    # 否则使用 cliphist decode
    echo "$selected" | cliphist decode | wl-copy
fi
