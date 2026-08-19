#!/usr/bin/env bash

set -uo pipefail

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
LOG_DIR="$STATE_HOME/desktop-dotfiles"
LOG_FILE="$LOG_DIR/session-start.log"
REFRESH_UI=0
DRY_RUN=0

while (($#)); do
    case "$1" in
        --refresh-ui) REFRESH_UI=1 ;;
        --dry-run) DRY_RUN=1 ;;
        *) printf '用法: session-start.sh [--refresh-ui] [--dry-run]\n' >&2; exit 2 ;;
    esac
    shift
done

mkdir -p "$LOG_DIR"
: > "$LOG_FILE"

log() {
    printf '[%s] %s\n' "$(date '+%F %T')" "$*" >> "$LOG_FILE"
}

command_exists() {
    local executable="$1"
    if [[ "$executable" == */* ]]; then
        [[ -x "$executable" ]]
    else
        command -v "$executable" >/dev/null 2>&1
    fi
}

start_background() {
    local label="$1" pattern="$2" executable="$3"
    shift 3

    if pgrep -f -- "$pattern" >/dev/null 2>&1; then
        log "$label 已在运行"
        return 0
    fi
    if ! command_exists "$executable"; then
        log "$label 未安装，跳过"
        return 0
    fi
    if ((DRY_RUN)); then
        log "[dry-run] 启动 $label"
        return 0
    fi

    log "启动 $label"
    nohup "$executable" "$@" >> "$LOG_FILE" 2>&1 &
    local pid=$!
    sleep 0.25
    if kill -0 "$pid" >/dev/null 2>&1 || pgrep -f -- "$pattern" >/dev/null 2>&1; then
        log "$label 启动成功"
    else
        wait "$pid" >/dev/null 2>&1
        local status=$?
        log "$label 启动失败，退出码 $status"
    fi
}

run_step() {
    local label="$1" executable="$2"
    shift 2

    if ! command_exists "$executable"; then
        log "$label 所需命令不存在：$executable"
        return 0
    fi
    if ((DRY_RUN)); then
        log "[dry-run] 执行 $label"
        return 0
    fi
    log "执行 $label"
    if "$executable" "$@" >> "$LOG_FILE" 2>&1; then
        log "$label 完成"
    else
        local status=$?
        log "$label 失败，退出码 $status"
    fi
}

log "开始启动桌面会话"
sleep 1

start_background "Fcitx5" '(^|/)fcitx5( |$)' fcitx5 -d
start_background "FlClash" '(^|/)flclash( |$)' flclash
start_background "壁纸守护进程" '(^|/)awww-daemon( |$)' awww-daemon --quiet

# Configure outputs before creating layer-shell surfaces such as Waybar.
run_step "显示器布局" "$CONFIG_HOME/hypr/scripts/monitor-switch.sh"
run_step "桌面主题" "$CONFIG_HOME/hypr/scripts/apply-theme.sh" --startup
start_background "显示器热插拔监听" '(^|/)monitor-watch\.sh( |$)' "$CONFIG_HOME/hypr/scripts/monitor-watch.sh"

if ((REFRESH_UI && !DRY_RUN)); then
    pkill -x waybar >/dev/null 2>&1 || true
    sleep 0.2
fi
start_background "Waybar" '(^|/)waybar( |$)' waybar \
    -c "$CONFIG_HOME/waybar/config" -s "$CONFIG_HOME/waybar/style.css"

start_background "cc-switch" '(^|/)cc-switch( |$)' cc-switch
start_background "文本剪贴板监听" 'wl-paste --type text --watch cliphist store' \
    wl-paste --type text --watch cliphist store
start_background "图片剪贴板监听" 'wl-paste --type image --watch cliphist store' \
    wl-paste --type image --watch cliphist store
start_background "Mako" '(^|/)mako( |$)' mako
start_background "Waylyrics" '(^|/)waylyrics( |$)' "$CONFIG_HOME/hypr/scripts/start-waylyrics.sh"
start_background "Polkit 认证代理" 'polkit-kde-authentication-agent-1' \
    /usr/lib/polkit-kde-authentication-agent-1

log "桌面会话启动完成"
