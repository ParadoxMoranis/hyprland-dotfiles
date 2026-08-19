#!/usr/bin/env bash

set -euo pipefail

ROFI_THEME="$HOME/.config/rofi/themes/monochrome.rasi"

notify() {
    command -v notify-send >/dev/null 2>&1 || return 0
    notify-send "音频设备" "$1" >/dev/null 2>&1 || true
}

fail() {
    printf 'audio-device-menu: %s\n' "$1" >&2
    notify "$1"
    exit 1
}

rofi_pick() {
    local prompt="$1"
    local message="${2:-}"
    local cmd=(rofi -dmenu -i -p "$prompt" -theme "$ROFI_THEME"
        -theme-str 'window { width: 46%; }'
        -theme-str 'listview { lines: 10; }'
        -no-custom)

    [[ -z "$message" ]] || cmd+=(-mesg "$message")
    "${cmd[@]}"
}

current_endpoint_id() {
    local endpoint="$1"
    wpctl inspect "$endpoint" 2>/dev/null | sed -n 's/^id \([0-9][0-9]*\),.*/\1/p' | head -n 1
}

list_endpoints() {
    local kind="$1"
    local media_class

    case "$kind" in
        output) media_class='Audio/Sink' ;;
        input) media_class='Audio/Source' ;;
        *) return 2 ;;
    esac

    pw-dump | python3 -c '
import json
import sys

media_class = sys.argv[1]
endpoints = []

for item in json.load(sys.stdin):
    props = item.get("info", {}).get("props", {})
    if props.get("media.class") != media_class:
        continue

    name = props.get("node.name", "")
    if not name:
        continue
    if media_class == "Audio/Source" and (
        name.endswith(".monitor") or props.get("device.class") == "monitor"
    ):
        continue

    description = props.get("node.description") or props.get("node.nick") or name
    endpoints.append((description.casefold(), item["id"], name, description))

for _, endpoint_id, name, description in sorted(endpoints):
    print(f"{endpoint_id}\t{name}\t{description}")
' "$media_class"
}

move_active_streams() {
    local kind="$1"
    local target="$2"
    local stream_id

    command -v pactl >/dev/null 2>&1 || return 0
    if [[ "$kind" == output ]]; then
        while IFS=$'\t' read -r stream_id _; do
            [[ -n "$stream_id" ]] || continue
            pactl move-sink-input "$stream_id" "$target" >/dev/null 2>&1 || true
        done < <(pactl list short sink-inputs 2>/dev/null || true)
    else
        while IFS=$'\t' read -r stream_id _; do
            [[ -n "$stream_id" ]] || continue
            pactl move-source-output "$stream_id" "$target" >/dev/null 2>&1 || true
        done < <(pactl list short source-outputs 2>/dev/null || true)
    fi
}

choose_endpoint() {
    local kind="$1"
    local current_alias prompt type_label current_id selected selected_id selected_name
    local id name description marker label
    local -a entries=()
    declare -A endpoint_ids=()
    declare -A endpoint_names=()
    declare -A endpoint_descriptions=()

    if [[ "$kind" == output ]]; then
        current_alias='@DEFAULT_AUDIO_SINK@'
        prompt='输出设备'
        type_label='音频输出'
    else
        current_alias='@DEFAULT_AUDIO_SOURCE@'
        prompt='输入设备'
        type_label='音频输入'
    fi

    current_id="$(current_endpoint_id "$current_alias" || true)"
    while IFS=$'\t' read -r id name description; do
        [[ -n "$id" ]] || continue
        if [[ "$id" == "$current_id" ]]; then marker='● '; else marker='  '; fi
        label="${marker}${description}  (#${id})"
        entries+=("$label")
        endpoint_ids["$label"]="$id"
        endpoint_names["$id"]="$name"
        endpoint_descriptions["$id"]="$description"
    done < <(list_endpoints "$kind")

    ((${#entries[@]})) || fail "未找到可用的${type_label}设备"
    selected="$(printf '%s\n' "${entries[@]}" | rofi_pick "$prompt" '● 表示当前默认设备')" || return 0
    [[ -n "$selected" ]] || return 0

    selected_id="${endpoint_ids[$selected]:-}"
    [[ -n "$selected_id" ]] || fail '无法识别所选设备'
    selected_name="${endpoint_names[$selected_id]}"

    wpctl set-default "$selected_id" || fail "无法切换${type_label}设备"
    move_active_streams "$kind" "$selected_name"
    notify "已切换${type_label}：${endpoint_descriptions[$selected_id]}"
}

main() {
    local category

    command -v wpctl >/dev/null 2>&1 || fail '未找到 wpctl'
    command -v pw-dump >/dev/null 2>&1 || fail '未找到 pw-dump'
    command -v python3 >/dev/null 2>&1 || fail '未找到 python3'

    if [[ "${1:-}" == '--list' ]]; then
        [[ "${2:-}" == output || "${2:-}" == input ]] || fail '用法：--list output|input'
        list_endpoints "$2"
        return
    fi

    command -v rofi >/dev/null 2>&1 || fail '未找到 rofi'
    category="$(printf '%s\n' '输出设备' '输入设备' | rofi_pick '音频设备' '选择要切换的设备类型')" || return 0
    case "$category" in
        输出设备) choose_endpoint output ;;
        输入设备) choose_endpoint input ;;
    esac
}

main "$@"
