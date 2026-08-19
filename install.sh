#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$STATE_HOME/desktop-dotfiles/backups/$TIMESTAMP"

SKIP_PACKAGES=0
DRY_RUN=0

declare -A PACKAGE_SEEN=()
declare -a OFFICIAL_PACKAGES=()
declare -a AUR_PACKAGES=()

usage() {
    cat <<'EOF'
用法: ./install.sh [选项]

  --skip-packages         不安装软件，只部署配置
  --dry-run               显示将执行的操作，不修改系统
  -h, --help              显示帮助

安装过程没有交互选项，始终部署仓库中的全部桌面配置。
EOF
}

while (($#)); do
    case "$1" in
        --defaults) ;;
        --skip-packages) SKIP_PACKAGES=1 ;;
        --dry-run) DRY_RUN=1 ;;
        -h|--help) usage; exit 0 ;;
        *) printf '未知选项: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

trim() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

run() {
    if ((DRY_RUN)); then
        printf '[dry-run]'
        printf ' %q' "$@"
        printf '\n'
    else
        "$@"
    fi
}

add_package() {
    local package="$1"
    [[ -n "${PACKAGE_SEEN[$package]:-}" ]] && return
    PACKAGE_SEEN[$package]=1
    OFFICIAL_PACKAGES+=("$package")
}

add_aur_package() {
    local package="$1"
    [[ -n "${PACKAGE_SEEN[$package]:-}" ]] && return
    PACKAGE_SEEN[$package]=1
    AUR_PACKAGES+=("$package")
}

set_defaults() {
    COMP_HYPR=1
    COMP_WAYBAR=1
    COMP_KITTY=1
    COMP_ALACRITTY=1
    COMP_ROFI=1
    COMP_MAKO=1
    COMP_GTK=1
    COMP_WALLPAPERS=1

    FEATURE_ANIMATIONS=1
    FEATURE_BLUR=1
    FEATURE_SHADOWS=1
    FEATURE_WALLPAPER=1
    FEATURE_MONITOR_AUTO=1
    FEATURE_MONITOR_MENU=1
    FEATURE_AUDIO_DEVICE_MENU=1
    FEATURE_INPUT_METHOD=1
    FEATURE_CLIPBOARD=1
    FEATURE_PINNED_CLIPBOARD=1
    FEATURE_SCREENSHOTS=1
    FEATURE_AUDIO_KEYS=1
    FEATURE_BRIGHTNESS_KEYS=1
    FEATURE_MEDIA_KEYS=1
    FEATURE_KEYBIND_HELP=1
    FEATURE_POLKIT=1
    FEATURE_FLCLASH=1
    FEATURE_CC_SWITCH=1
    FEATURE_WAYLYRICS=1

    WB_LAUNCHER=1
    WB_WORKSPACES=1
    WB_CLOCK=1
    WB_DISK=1
    WB_MEMORY=1
    WB_CPU=1
    WB_TEMPERATURE=1
    WB_TRAY=1
    WB_BACKLIGHT=1
    WB_AUDIO=1
    WB_BLUETOOTH=1
    WB_NETWORK=1
    WB_BATTERY=1

    TERMINAL_COMMAND='kitty'
    FILE_MANAGER_COMMAND='dolphin'
    MENU_COMMAND='hyprlauncher'
}

feature_enabled() {
    case "$1" in
        core) return 0 ;;
        clipboard) ((FEATURE_CLIPBOARD)) ;;
        pinned_clipboard) ((FEATURE_PINNED_CLIPBOARD)) ;;
        monitor_menu) ((FEATURE_MONITOR_MENU)) ;;
        audio_device_menu) ((FEATURE_AUDIO_DEVICE_MENU)) ;;
        screenshots) ((FEATURE_SCREENSHOTS)) ;;
        audio_keys) ((FEATURE_AUDIO_KEYS)) ;;
        brightness_keys) ((FEATURE_BRIGHTNESS_KEYS)) ;;
        media_keys) ((FEATURE_MEDIA_KEYS)) ;;
        keybind_help) ((FEATURE_KEYBIND_HELP)) ;;
        *) return 1 ;;
    esac
}

binding_combo() {
    local mods key
    mods="$(trim "$1")"
    key="$(trim "$2")"
    mods="${mods// /+}"
    if [[ -n "$mods" ]]; then printf '%s+%s' "$mods" "$key"; else printf '%s' "$key"; fi
}

collect_packages() {
    if ((COMP_HYPR)); then
        for package in hyprland xorg-xwayland xdg-desktop-portal xdg-desktop-portal-hyprland \
            xdg-desktop-portal-gtk xdg-utils qt5-wayland qt6-wayland pipewire pipewire-pulse \
            wireplumber libnotify hyprlauncher dolphin; do
            add_package "$package"
        done
    fi
    ((COMP_WAYBAR)) && add_package waybar
    ((COMP_KITTY)) && { add_package kitty; add_package zsh; add_package ttf-jetbrains-mono-nerd; }
    ((COMP_ALACRITTY)) && add_package alacritty
    ((COMP_ROFI)) && add_package rofi
    ((COMP_MAKO)) && add_package mako
    ((COMP_GTK)) && { add_package breeze; add_package breeze-icons; add_package noto-fonts-cjk; }
    ((FEATURE_WALLPAPER && COMP_HYPR)) && add_package awww
    ((FEATURE_MONITOR_AUTO && COMP_HYPR)) && add_package socat
    ((FEATURE_MONITOR_MENU && COMP_HYPR)) && { add_package jq; add_package python; }
    ((FEATURE_AUDIO_DEVICE_MENU && COMP_HYPR)) && add_package python
    ((FEATURE_INPUT_METHOD && COMP_HYPR)) && { add_package fcitx5; add_package fcitx5-gtk; add_package fcitx5-qt; }
    ((FEATURE_CLIPBOARD && COMP_HYPR)) && { add_package cliphist; add_package wl-clipboard; }
    ((FEATURE_PINNED_CLIPBOARD && COMP_HYPR)) && add_package wl-clipboard
    ((FEATURE_SCREENSHOTS && COMP_HYPR)) && { add_package grim; add_package slurp; add_package satty; add_package wl-clipboard; }
    ((FEATURE_BRIGHTNESS_KEYS && COMP_HYPR)) && add_package brightnessctl
    ((FEATURE_MEDIA_KEYS && COMP_HYPR)) && add_package playerctl
    ((FEATURE_POLKIT && COMP_HYPR)) && add_package polkit-kde-agent
    ((WB_BLUETOOTH && COMP_WAYBAR)) && add_package blueman
    if ((COMP_HYPR && (FEATURE_CLIPBOARD || FEATURE_PINNED_CLIPBOARD || FEATURE_MONITOR_MENU || FEATURE_AUDIO_DEVICE_MENU || FEATURE_KEYBIND_HELP))); then
        add_package rofi
    fi
    ((COMP_WAYBAR && WB_LAUNCHER)) && add_package rofi
    ((FEATURE_FLCLASH && COMP_HYPR)) && add_aur_package flclash-bin
    ((FEATURE_CC_SWITCH && COMP_HYPR)) && add_aur_package cc-switch-bin
    ((FEATURE_WAYLYRICS && COMP_HYPR)) && add_aur_package waylyrics
    return 0
}

install_packages() {
    local helper package
    ((SKIP_PACKAGES || DRY_RUN)) && {
        ((DRY_RUN)) && printf '[dry-run] 将安装官方包: %s\n' "${OFFICIAL_PACKAGES[*]:-(无)}"
        ((DRY_RUN && ${#AUR_PACKAGES[@]})) && printf '[dry-run] 将安装 AUR 包: %s\n' "${AUR_PACKAGES[*]}"
        return 0
    }

    command -v pacman >/dev/null 2>&1 || {
        printf '未找到 pacman；此安装器当前支持 Arch Linux。可使用 --skip-packages 仅部署配置。\n' >&2
        exit 1
    }

    if ((${#OFFICIAL_PACKAGES[@]})); then
        sudo pacman -Syu --needed "${OFFICIAL_PACKAGES[@]}"
    fi

    ((${#AUR_PACKAGES[@]})) || return 0
    if command -v paru >/dev/null 2>&1; then helper=paru
    elif command -v yay >/dev/null 2>&1; then helper=yay
    else
        printf '未找到 paru/yay，跳过 AUR 包: %s\n' "${AUR_PACKAGES[*]}" >&2
        return 0
    fi

    for package in "${AUR_PACKAGES[@]}"; do
        "$helper" -S --needed "$package"
    done
}

backup_and_copy_dir() {
    local name="$1" source="$SCRIPT_DIR/config/$1" target="$CONFIG_HOME/$1"
    [[ -d "$source" ]] || return 0
    if [[ -e "$target" ]]; then
        run mkdir -p "$BACKUP_DIR"
        run cp -a "$target" "$BACKUP_DIR/$name"
    fi
    run mkdir -p "$target"
    run cp -a "$source/." "$target/"
}

deploy_configs() {
    ((COMP_HYPR)) && backup_and_copy_dir hypr
    ((COMP_WAYBAR)) && backup_and_copy_dir waybar
    ((COMP_KITTY)) && backup_and_copy_dir kitty
    ((COMP_ALACRITTY)) && backup_and_copy_dir alacritty
    ((COMP_ROFI)) && backup_and_copy_dir rofi
    ((COMP_MAKO)) && backup_and_copy_dir mako
    if ((COMP_GTK)); then
        backup_and_copy_dir gtk-3.0
        backup_and_copy_dir gtk-4.0
    fi

    if ((COMP_WALLPAPERS)); then
        run mkdir -p "$HOME/Pictures/Wallpapers"
        local wallpaper target
        for wallpaper in "$SCRIPT_DIR"/wallpapers/*; do
            [[ -f "$wallpaper" ]] || continue
            target="$HOME/Pictures/Wallpapers/$(basename "$wallpaper")"
            if [[ -e "$target" ]]; then
                run mkdir -p "$BACKUP_DIR/wallpapers"
                run cp -a "$target" "$BACKUP_DIR/wallpapers/"
            fi
            run cp -a "$wallpaper" "$target"
        done
    fi
}

deploy_lid_suspend_config() {
    local source="$SCRIPT_DIR/config/systemd/logind.conf.d/90-lid-suspend.conf"
    local target="/etc/systemd/logind.conf.d/90-lid-suspend.conf"

    [[ -f "$source" ]] || return 0
    if ((DRY_RUN)); then
        printf '[dry-run] sudo install -Dm644 %s %s\n' "$source" "$target"
        printf '[dry-run] sudo systemctl reload systemd-logind\n'
        return 0
    fi

    command -v sudo >/dev/null 2>&1 || {
        printf '未找到 sudo，无法部署合盖休眠配置：%s\n' "$target" >&2
        return 1
    }
    sudo install -Dm644 "$source" "$target"
    sudo systemctl reload systemd-logind >/dev/null 2>&1 || true
}

write_hypr_fragments() {
    local target="$CONFIG_HOME/hypr"
    ((COMP_HYPR)) || return 0
    ((DRY_RUN)) && { printf '[dry-run] 生成 Hyprland 配置片段\n'; return 0; }

    {
        printf '# Generated by desktop-dotfiles/install.sh\n'
        printf '# monitor-switch.sh applies the highest-resolution/highest-refresh layout at startup.\n'
        printf 'monitor = ,preferred,auto,auto\n'
    } > "$target/monitors.conf"

    {
        printf '# Monitor names and modes are detected dynamically by monitor-switch.sh.\n'
    } > "$target/monitor-settings.conf"

    {
        printf '# Generated by desktop-dotfiles/install.sh\n'
        printf 'animations:enabled = %s\n' "$([[ "$FEATURE_ANIMATIONS" == 1 ]] && printf yes || printf no)"
        printf 'decoration:blur:enabled = %s\n' "$([[ "$FEATURE_BLUR" == 1 ]] && printf true || printf false)"
        printf 'decoration:shadow:enabled = %s\n' "$([[ "$FEATURE_SHADOWS" == 1 ]] && printf true || printf false)"
    } > "$target/preferences.conf"

    {
        printf '# Generated by desktop-dotfiles/install.sh\n'
        printf 'exec-once = ~/.config/hypr/scripts/session-start.sh\n'
    } > "$target/autostart.conf"

    {
        printf '$terminal = %s\n' "$TERMINAL_COMMAND"
        printf '$fileManager = %s\n' "$FILE_MANAGER_COMMAND"
        printf '$menu = %s\n' "$MENU_COMMAND"
    } > "$target/programs.conf"

    [[ -f "$target/clipboard-pinned.txt" ]] || printf 'example@email.com\nhttps://example.com\n' > "$target/clipboard-pinned.txt"
}

split_combo() {
    local combo="$1" mods_variable="$2" key_variable="$3" parsed_mods parsed_key
    combo="$(trim "$combo")"
    if [[ "$combo" == *+* ]]; then
        parsed_key="${combo##*+}"
        parsed_mods="${combo%+*}"
        parsed_mods="${parsed_mods//+/ }"
    else
        parsed_mods=''
        parsed_key="$combo"
    fi
    printf -v "$mods_variable" '%s' "$(trim "$parsed_mods")"
    printf -v "$key_variable" '%s' "$(trim "$parsed_key")"
}

render_keybinds() {
    local source="$SCRIPT_DIR/config/hypr/keybinds.conf" target="$CONFIG_HOME/hypr/keybinds.conf"
    local temporary line meta_id='' meta_feature='' meta_label=''
    local rhs mods key dispatcher args combo bind_type
    declare -A seen_combos=()

    ((COMP_HYPR)) || return 0
    ((DRY_RUN)) && { printf '[dry-run] 生成 Hyprland 快捷键配置\n'; return 0; }
    temporary="$(mktemp "$target.tmp.XXXXXX")"
    printf '# Generated by desktop-dotfiles/install.sh\n\n' > "$temporary"

    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" == '# bind-meta: '* ]]; then
            IFS='|' read -r meta_id meta_feature meta_label <<< "${line#\# bind-meta: }"
            continue
        fi
        [[ -n "$meta_id" && "$line" =~ ^bind[a-z]*[[:space:]]*= ]] || continue
        if feature_enabled "$meta_feature"; then
            rhs="${line#*=}"
            IFS=',' read -r mods key dispatcher args <<< "$rhs"
            combo="$(binding_combo "$mods" "$key")"
            if [[ "${combo,,}" != off ]]; then
                split_combo "$combo" mods key
                combo="$(binding_combo "$mods" "$key")"
                if [[ -n "${seen_combos[${combo,,}]:-}" ]]; then
                    printf '警告：快捷键 %s 同时分配给 %s 和 %s。\n' "$combo" "${seen_combos[${combo,,}]}" "$meta_label" >&2
                fi
                seen_combos["${combo,,}"]="$meta_label"
                bind_type="$(trim "${line%%=*}")"
                printf '# %s\n' "$meta_label" >> "$temporary"
                printf '%s = %s, %s, %s' "$bind_type" "$mods" "$key" "$(trim "$dispatcher")" >> "$temporary"
                if [[ -n "$(trim "${args:-}")" ]]; then
                    printf ', %s' "$(trim "$args")" >> "$temporary"
                elif [[ "$bind_type" != bindm ]]; then
                    printf ',' >> "$temporary"
                fi
                printf '\n' >> "$temporary"
            fi
        fi
        meta_id=''
    done < "$source"

    mv "$temporary" "$target"
}

json_array() {
    local first=1 item
    printf '['
    for item in "$@"; do
        ((first)) || printf ','
        printf '"%s"' "$item"
        first=0
    done
    printf ']'
}

render_waybar() {
    local config temporary
    local index
    local -a left=() right=() config_left=()
    ((COMP_WAYBAR)) || return 0
    ((DRY_RUN)) && { printf '[dry-run] 生成 Waybar 模块列表\n'; return 0; }
    command -v jq >/dev/null 2>&1 || {
        printf '生成 Waybar 配置需要 jq；请安装 jq 或不要使用 --skip-packages。\n' >&2
        exit 1
    }

    ((WB_LAUNCHER)) && left+=(custom/launcher)
    ((WB_WORKSPACES)) && left+=(hyprland/workspaces)
    ((WB_CLOCK)) && left+=(clock)
    ((WB_DISK)) && left+=(disk)
    ((WB_MEMORY)) && left+=(memory)
    ((WB_CPU)) && left+=(cpu)
    ((WB_TEMPERATURE)) && left+=(temperature)
    ((WB_TRAY)) && right+=(tray)
    ((WB_BACKLIGHT)) && right+=(backlight)
    ((WB_AUDIO)) && right+=(pulseaudio)
    ((WB_BLUETOOTH)) && right+=(bluetooth)
    ((WB_NETWORK)) && right+=(network)
    ((WB_BATTERY)) && right+=(battery)

    for config in "$CONFIG_HOME/waybar/config" "$CONFIG_HOME/waybar/config.niri"; do
        [[ -f "$config" ]] || continue
        config_left=("${left[@]}")
        if [[ "$config" == *.niri ]]; then
            for index in "${!config_left[@]}"; do
                [[ "${config_left[$index]}" == hyprland/workspaces ]] && config_left[$index]=niri/workspaces
            done
        fi
        temporary="$(mktemp "$config.tmp.XXXXXX")"
        jq --argjson left "$(json_array "${config_left[@]}")" \
           --argjson right "$(json_array "${right[@]}")" \
           '."modules-left" = $left | ."modules-center" = [] | ."modules-right" = $right' \
           "$config" > "$temporary"
        mv "$temporary" "$config"
    done
}

reload_desktop() {
    ((DRY_RUN)) && return 0
    if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && command -v hyprctl >/dev/null 2>&1; then
        hyprctl reload >/dev/null 2>&1 || true
        "$CONFIG_HOME/hypr/scripts/session-start.sh" --refresh-ui
    fi
}

main() {
    set_defaults
    collect_packages

    printf '\n开始安装。现有配置会备份到：%s\n' "$BACKUP_DIR"
    install_packages
    deploy_configs
    ((COMP_HYPR)) && deploy_lid_suspend_config
    write_hypr_fragments
    render_keybinds
    render_waybar
    reload_desktop

    if ((DRY_RUN)); then
        printf '\nDry run 完成，没有修改系统。\n'
    else
        printf '\n安装完成。注销后从登录管理器进入 Hyprland，或在当前会话执行 hyprctl reload。\n'
        if [[ -d "$BACKUP_DIR" ]]; then
            printf '旧配置备份：%s\n' "$BACKUP_DIR"
        fi
    fi
    return 0
}

main "$@"
