#!/usr/bin/env bash

set -euo pipefail

ROFI_THEME="$HOME/.config/rofi/themes/monochrome.rasi"
LOG_FILE="${XDG_RUNTIME_DIR:-/tmp}/monitor-menu.log"

log() {
    printf '[%s] %s\n' "$(date '+%F %T')" "$*" >> "$LOG_FILE"
}

notify() {
    notify-send "显示器设置" "$1" >/dev/null 2>&1 || true
}

rofi_pick() {
    local prompt="$1"
    local message="${2:-}"
    local input="${3-}"

    local cmd=(rofi -dmenu -i -p "$prompt" -theme "$ROFI_THEME" \
        -theme-str 'window { width: 46%; }' \
        -theme-str 'listview { lines: 12; }')

    if [[ -n "$message" ]]; then
        cmd+=(-mesg "$message")
    fi

    printf '%s\n' "$input" | "${cmd[@]}"
}

detect_backend() {
    if [[ "${1:-}" == "hypr" || "${1:-}" == "niri" ]]; then
        printf '%s\n' "$1"
        return
    fi

    if [[ -n "${NIRI_SOCKET:-}" ]]; then
        printf 'niri\n'
        return
    fi

    if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
        printf 'hypr\n'
        return
    fi

    printf '无法判断当前是 Hyprland 还是 niri 会话。\n' >&2
    return 1
}

hypr_get_json() {
    hyprctl monitors all
}

hypr_apply() {
    local monitor_value="$1"
    hyprctl -i 0 keyword monitor "$monitor_value" >/dev/null
}

niri_get_json() {
    niri msg -j outputs
}

niri_apply_mode() {
    local output="$1"
    local transform="$2"
    local mode="$3"

    niri msg output "$output" transform "$transform" >/dev/null
    niri msg output "$output" mode "$mode" >/dev/null
}

list_outputs_json() {
    local backend="$1"
    if [[ "$backend" == "hypr" ]]; then
        hypr_get_json
    else
        niri_get_json
    fi
}

transform_label() {
    case "$1" in
        normal) printf '正常\n' ;;
        90) printf '左转 90°\n' ;;
        180) printf '旋转 180°\n' ;;
        270) printf '右转 90°\n' ;;
        flipped) printf '水平翻转\n' ;;
        flipped-90) printf '翻转 + 左转 90°\n' ;;
        flipped-180) printf '垂直翻转\n' ;;
        flipped-270) printf '翻转 + 右转 90°\n' ;;
        *) printf '%s\n' "$1" ;;
    esac
}

parse_outputs() {
    local backend="$1"
    local raw_json
    raw_json="$(cat)"
    python3 - "$backend" "$raw_json" <<'PY'
import json
import re
import sys

backend = sys.argv[1]
raw = sys.argv[2]
mode_re = re.compile(r"^(?P<w>\d+)x(?P<h>\d+)@(?P<r>[\d.]+)Hz$")
hypr_reverse = {0: "normal", 1: "90", 2: "180", 3: "270", 4: "flipped", 5: "flipped-90", 6: "flipped-180", 7: "flipped-270"}

def dedupe_modes(items):
    seen = {}
    for item in items:
        seen.setdefault(item["canonical"], item)
    return list(seen.values())

def sort_modes(items):
    return sorted(
        dedupe_modes(items),
        key=lambda item: (
            0 if item["current"] else 1,
            0 if item.get("preferred", False) else 1,
            -(item["width"] * item["height"]),
            -float(item["refresh"]),
            item["canonical"],
        ),
    )

outputs = []

if backend == "hypr":
    blocks = [block for block in raw.split("\n\n") if block.strip()]
    for block in blocks:
        lines = [line.rstrip() for line in block.splitlines() if line.strip()]
        if not lines or not lines[0].startswith("Monitor "):
            continue

        name = lines[0].split()[1]
        if name.endswith(":"):
            name = name[:-1]

        info = {
            "name": name,
            "description": name,
            "width": None,
            "height": None,
            "refresh": None,
            "x": 0,
            "y": 0,
            "scale": "1",
            "transform": "normal",
            "focused": False,
            "disabled": False,
            "availableModes": [],
        }

        for line in lines[1:]:
            stripped = line.strip()
            current_match = re.match(r"^(?P<w>\d+)x(?P<h>\d+)@(?P<r>[\d.]+) at (?P<x>-?\d+)x(?P<y>-?\d+)$", stripped)
            if current_match:
                info["width"] = int(current_match.group("w"))
                info["height"] = int(current_match.group("h"))
                info["refresh"] = float(current_match.group("r"))
                info["x"] = int(current_match.group("x"))
                info["y"] = int(current_match.group("y"))
                continue

            if stripped.startswith("description:"):
                info["description"] = stripped.split(":", 1)[1].strip() or name
                continue

            if stripped.startswith("scale:"):
                info["scale"] = stripped.split(":", 1)[1].strip().rstrip("0").rstrip(".")
                continue

            if stripped.startswith("transform:"):
                info["transform"] = hypr_reverse.get(int(stripped.split(":", 1)[1].strip()), "normal")
                continue

            if stripped.startswith("focused:"):
                info["focused"] = stripped.split(":", 1)[1].strip() == "yes"
                continue

            if stripped.startswith("disabled:"):
                info["disabled"] = stripped.split(":", 1)[1].strip() == "true"
                continue

            if stripped.startswith("availableModes:"):
                modes_text = stripped.split(":", 1)[1].strip()
                if modes_text:
                    info["availableModes"] = [part for part in modes_text.split() if part]
                continue

        if info["disabled"] or info["width"] is None or info["height"] is None or info["refresh"] is None:
            continue

        modes = []
        for raw_mode in info["availableModes"]:
            match = mode_re.match(raw_mode)
            if not match:
                continue
            mw = int(match.group("w"))
            mh = int(match.group("h"))
            refresh = match.group("r")
            modes.append({
                "width": mw,
                "height": mh,
                "refresh": refresh,
                "canonical": f"{mw}x{mh}@{refresh}",
                "current": mw == info["width"] and mh == info["height"] and abs(float(refresh) - info["refresh"]) < 0.2,
                "preferred": False,
            })
        modes = sort_modes(modes)
        if not modes:
            continue
        outputs.append({
            "name": info["name"],
            "description": info["description"],
            "transform": info["transform"],
            "scale": info["scale"] or "1",
            "position": f'{info["x"]}x{info["y"]}',
            "focused": info["focused"],
            "modes": modes,
        })
    outputs.sort(key=lambda item: (not item["focused"], item["name"]))
else:
    data = json.loads(raw)
    for item in data:
        logical = item.get("logical")
        current_index = item.get("current_mode")
        if logical is None or current_index is None:
            continue
        modes = []
        for index, raw_mode in enumerate(item.get("modes", [])):
            refresh = f'{raw_mode["refresh_rate"] / 1000.0:.3f}'.rstrip("0").rstrip(".")
            modes.append({
                "width": int(raw_mode["width"]),
                "height": int(raw_mode["height"]),
                "refresh": refresh,
                "canonical": f'{raw_mode["width"]}x{raw_mode["height"]}@{refresh}',
                "current": index == current_index,
                "preferred": bool(raw_mode.get("is_preferred")),
            })
        modes = sort_modes(modes)
        if not modes:
            continue
        description = " ".join(part for part in [item.get("make", "").strip(), item.get("model", "").strip()] if part).strip() or item["name"]
        outputs.append({
            "name": item["name"],
            "description": description,
            "transform": str(logical.get("transform", "normal")),
            "scale": str(logical.get("scale", 1)).rstrip("0").rstrip("."),
            "position": f'{int(logical.get("x", 0))}x{int(logical.get("y", 0))}',
            "focused": False,
            "modes": modes,
        })

json.dump(outputs, sys.stdout, ensure_ascii=False)
PY
}

current_mode_text() {
    python3 - <<'PY' "$1"
import json
import sys
output = json.loads(sys.argv[1])
for mode in output["modes"]:
    if mode["current"]:
        print(f'{mode["width"]}x{mode["height"]} @ {mode["refresh"]} Hz')
        break
else:
    print("未知")
PY
}

pick_output() {
    python3 - <<'PY' "$1"
import json
import sys
outputs = json.loads(sys.argv[1])
for item in outputs:
    current = next((m for m in item["modes"] if m["current"]), None)
    current_text = f'{current["width"]}x{current["height"]} @ {current["refresh"]} Hz' if current else "未知"
    print(f'{item["name"]}\t{item["name"]} | {item["description"]} | {current_text} | {item["transform"]}')
PY
}

pick_transform_entries() {
    local current="$1"
    local label
    for key in normal 90 180 270; do
        label="$(transform_label "$key")"
        if [[ "$key" == "$current" ]]; then
            printf '%s\t%s [当前]\n' "$key" "$label"
        else
            printf '%s\t%s\n' "$key" "$label"
        fi
    done
}

pick_resolution_entries() {
    python3 - <<'PY' "$1"
import json
import sys
output = json.loads(sys.argv[1])
groups = {}
for mode in output["modes"]:
    key = f'{mode["width"]}x{mode["height"]}'
    groups.setdefault(key, []).append(mode)

def sort_key(item):
    resolution, modes = item
    width, height = map(int, resolution.split("x"))
    current = any(mode["current"] for mode in modes)
    return (0 if current else 1, -(width * height), -max(width, height), resolution)

for resolution, modes in sorted(groups.items(), key=sort_key):
    suffix = " [当前]" if any(mode["current"] for mode in modes) else ""
    print(f"{resolution}\t{resolution}{suffix}")
PY
}

pick_refresh_entries() {
    python3 - <<'PY' "$1" "$2"
import json
import sys
output = json.loads(sys.argv[1])
resolution = sys.argv[2]

def fmt(mode):
    flags = []
    if mode["current"]:
        flags.append("当前")
    if mode.get("preferred", False):
        flags.append("首选")
    suffix = f" [{' / '.join(flags)}]" if flags else ""
    return f'{mode["refresh"]}\t{resolution} @ {mode["refresh"]} Hz{suffix}'

modes = [m for m in output["modes"] if f'{m["width"]}x{m["height"]}' == resolution]
modes.sort(key=lambda m: (0 if m["current"] else 1, 0 if m.get("preferred", False) else 1, -float(m["refresh"]), m["canonical"]))
for mode in modes:
    print(fmt(mode))
PY
}

get_output_json() {
    python3 - <<'PY' "$1" "$2"
import json
import sys
outputs = json.loads(sys.argv[1])
name = sys.argv[2]
for output in outputs:
    if output["name"] == name:
        print(json.dumps(output, ensure_ascii=False))
        break
else:
    raise SystemExit(1)
PY
}

get_mode_canonical() {
    python3 - <<'PY' "$1" "$2" "$3"
import json
import sys
output = json.loads(sys.argv[1])
resolution = sys.argv[2]
refresh = sys.argv[3]
for mode in output["modes"]:
    if f'{mode["width"]}x{mode["height"]}' == resolution and mode["refresh"] == refresh:
        print(mode["canonical"])
        break
else:
    raise SystemExit(1)
PY
}

main() {
    : > "$LOG_FILE"
    log "script started: $*"
    local forced_backend=""
    local list_only="false"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --backend)
                forced_backend="${2:-}"
                shift 2
                ;;
            --list)
                list_only="true"
                shift
                ;;
            *)
                printf '未知参数: %s\n' "$1" >&2
                return 1
                ;;
        esac
    done

    local backend
    backend="$(detect_backend "$forced_backend")"
    log "backend=$backend"

    local raw_json parsed_json
    raw_json="$(list_outputs_json "$backend")"
    log "raw_json_prefix=${raw_json:0:120}"
    parsed_json="$(printf '%s' "$raw_json" | parse_outputs "$backend")"
    log "parsed_json_prefix=${parsed_json:0:120}"

    if [[ "$list_only" == "true" ]]; then
        python3 - <<'PY' "$parsed_json"
import json
import sys
for output in json.loads(sys.argv[1]):
    current = next((m for m in output["modes"] if m["current"]), None)
    current_text = f'{current["width"]}x{current["height"]} @ {current["refresh"]} Hz' if current else "未知"
    print(f'{output["name"]}: {current_text} | {output["transform"]}')
PY
        return 0
    fi

    local output_entries output_pick output_name output_json
    output_entries="$(pick_output "$parsed_json")"
    [[ -n "$output_entries" ]] || { notify "没有检测到可调整的显示器。"; return 1; }
    output_pick="$(rofi_pick "显示器" "先选择要调整的显示器" "$(printf '%s\n' "$output_entries" | cut -f2-)")" || return 0
    log "output_pick=$output_pick"
    output_name="$(printf '%s\n' "$output_entries" | awk -F '\t' -v pick="$output_pick" '$2==pick {print $1; exit}')"
    [[ -n "$output_name" ]] || return 1
    output_json="$(get_output_json "$parsed_json" "$output_name")"

    local current_transform current_mode transform_entries transform_pick transform_value
    current_transform="$(python3 - <<'PY' "$output_json"
import json, sys
print(json.loads(sys.argv[1])["transform"])
PY
)"
    current_mode="$(current_mode_text "$output_json")"
    transform_entries="$(pick_transform_entries "$current_transform")"
    transform_pick="$(rofi_pick "方向" "$output_name 当前方向：$(transform_label "$current_transform")" "$(printf '%s\n' "$transform_entries" | cut -f2-)")" || return 0
    log "transform_pick=$transform_pick"
    transform_value="$(printf '%s\n' "$transform_entries" | awk -F '\t' -v pick="$transform_pick" '$2==pick {print $1; exit}')"
    [[ -n "$transform_value" ]] || return 1

    local resolution_entries resolution_pick resolution_value
    resolution_entries="$(pick_resolution_entries "$output_json")"
    resolution_pick="$(rofi_pick "分辨率" "$output_name 当前模式：$current_mode" "$(printf '%s\n' "$resolution_entries" | cut -f2-)")" || return 0
    log "resolution_pick=$resolution_pick"
    resolution_value="$(printf '%s\n' "$resolution_entries" | awk -F '\t' -v pick="$resolution_pick" '$2==pick {print $1; exit}')"
    [[ -n "$resolution_value" ]] || return 1

    local refresh_entries refresh_pick refresh_value canonical_mode
    refresh_entries="$(pick_refresh_entries "$output_json" "$resolution_value")"
    refresh_pick="$(rofi_pick "刷新率" "$output_name | $resolution_value" "$(printf '%s\n' "$refresh_entries" | cut -f2-)")" || return 0
    log "refresh_pick=$refresh_pick"
    refresh_value="$(printf '%s\n' "$refresh_entries" | awk -F '\t' -v pick="$refresh_pick" '$2==pick {print $1; exit}')"
    [[ -n "$refresh_value" ]] || return 1
    canonical_mode="$(get_mode_canonical "$output_json" "$resolution_value" "$refresh_value")"

    if [[ "$backend" == "hypr" ]]; then
        local scale position hypr_transform transform_code
        scale="$(python3 - <<'PY' "$output_json"
import json, sys
print(json.loads(sys.argv[1])["scale"])
PY
)"
        position="$(python3 - <<'PY' "$output_json"
import json, sys
print(json.loads(sys.argv[1])["position"])
PY
)"
        case "$transform_value" in
            normal) transform_code=0 ;;
            90) transform_code=1 ;;
            180) transform_code=2 ;;
            270) transform_code=3 ;;
            *) printf '不支持的方向: %s\n' "$transform_value" >&2; return 1 ;;
        esac
        hypr_apply "$output_name,$canonical_mode,$position,$scale,transform,$transform_code"
    else
        niri_apply_mode "$output_name" "$transform_value" "$canonical_mode"
    fi

    notify "$output_name 已切换到 $canonical_mode，方向：$(transform_label "$transform_value")"
    log "apply_done output=$output_name mode=$canonical_mode transform=$transform_value"
}

main "$@"
