#!/usr/bin/env bash

set -euo pipefail

# Dynamically select the largest resolution and the highest refresh rate
# available at that resolution for every connected output.

THEME_SCRIPT="$HOME/.config/hypr/scripts/apply-theme.sh"
STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/hypr-external-monitor-only"
ACTION=auto
PRINT_ONLY=0

usage() {
    cat <<'EOF'
用法: monitor-switch.sh [--normal|--external-only] [--print-layout]

  --normal          启用全部已连接显示器并自动排列
  --external-only   仅启用外接显示器
  --print-layout    只输出将应用的 Hyprland 规则
EOF
}

while (($#)); do
    case "$1" in
        --normal) ACTION=normal ;;
        --external-only) ACTION=external-only ;;
        --print-layout) PRINT_ONLY=1 ;;
        -h|--help) usage; exit 0 ;;
        *) printf '未知选项: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

get_monitors_json() {
    if [[ -n "${MONITOR_SWITCH_JSON_FILE:-}" ]]; then
        cat "$MONITOR_SWITCH_JSON_FILE"
    else
        hyprctl -j monitors all
    fi
}

parse_monitors() {
    python3 -c '
import json
import re
import sys

mode_re = re.compile(r"^(\d+)x(\d+)@([0-9.]+)(?:Hz)?$")

try:
    monitors = json.load(sys.stdin)
except (json.JSONDecodeError, TypeError) as error:
    raise SystemExit(f"无法解析 Hyprland 显示器信息: {error}")

outputs = []
for monitor in monitors:
    name = str(monitor.get("name", ""))
    if not name:
        continue

    modes = []
    for raw_mode in monitor.get("availableModes", []):
        match = mode_re.match(str(raw_mode))
        if not match:
            continue
        width, height = int(match[1]), int(match[2])
        modes.append((width, height, float(match[3])))

    if not modes:
        width = int(monitor.get("width", 0) or 0)
        height = int(monitor.get("height", 0) or 0)
        refresh = float(monitor.get("refreshRate", 0) or 0)
        if width and height and refresh:
            modes.append((width, height, refresh))
    if not modes:
        continue

    width, height, refresh = max(
        modes,
        key=lambda mode: (mode[0] * mode[1], mode[0], mode[1], mode[2]),
    )
    refresh_text = f"{refresh:.3f}".rstrip("0").rstrip(".")
    kind = "internal" if re.match(r"^(eDP|LVDS|DSI)(-|$)", name, re.I) else "external"
    outputs.append((kind, name, f"{width}x{height}@{refresh_text}"))

for kind, name, mode in sorted(outputs, key=lambda output: (output[0] != "internal", output[1])):
    print(f"{kind}\t{name}\t{mode}")
'
}

json="$(get_monitors_json)"
parsed="$(printf '%s' "$json" | parse_monitors)"
[[ -n "$parsed" ]] || {
    printf '未检测到带有可用模式的显示器。\n' >&2
    exit 1
}
mapfile -t MONITORS <<< "$parsed"

external_count=0
for entry in "${MONITORS[@]}"; do
    IFS=$'\t' read -r kind _ _ <<< "$entry"
    if [[ "$kind" == external ]]; then
        ((external_count += 1))
    fi
done

if [[ "$ACTION" == auto ]]; then
    if [[ -s "$STATE_FILE" && $external_count -gt 0 ]]; then
        ACTION=external-only
    else
        ACTION=normal
    fi
fi

if [[ "$ACTION" == external-only && $external_count -eq 0 ]]; then
    printf '未检测到外接显示器，保持内置显示器启用。\n' >&2
    exit 1
fi

declare -a rules=()
for entry in "${MONITORS[@]}"; do
    IFS=$'\t' read -r kind name mode <<< "$entry"
    if [[ "$ACTION" == external-only && "$kind" == internal ]]; then
        continue
    fi
    rules+=("$name,$mode,auto,auto")
done
if [[ "$ACTION" == external-only ]]; then
    for entry in "${MONITORS[@]}"; do
        IFS=$'\t' read -r kind name _ <<< "$entry"
        [[ "$kind" == internal ]] && rules+=("$name,disable")
    done
fi

if ((PRINT_ONLY)); then
    printf 'monitor = %s\n' "${rules[@]}"
    exit 0
fi

# Enable the requested outputs before disabling any internal panel so the
# active workspace always has somewhere to move.
for rule in "${rules[@]}"; do
    [[ "$rule" == *,disable ]] && continue
    hyprctl keyword monitor "$rule" >/dev/null
done
for rule in "${rules[@]}"; do
    [[ "$rule" == *,disable ]] || continue
    hyprctl keyword monitor "$rule" >/dev/null
done

if [[ "$ACTION" == external-only ]]; then
    mkdir -p "$(dirname "$STATE_FILE")"
    printf '1\n' > "$STATE_FILE"
else
    rm -f "$STATE_FILE"
fi

sleep 0.5
if [[ -x "$THEME_SCRIPT" ]]; then
    "$THEME_SCRIPT" --wallpaper-only --quiet
fi
