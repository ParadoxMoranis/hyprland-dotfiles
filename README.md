# Moranis Desktop Dotfiles

这是一套以 Hyprland 为核心的 Arch Linux 桌面配置，整理自日常使用环境。仓库包含 Hyprland、Waybar、Kitty、Alacritty、Rofi、Mako、GTK 3/4 样式、辅助脚本和壁纸。

安装器不会直接无备份覆盖现有配置。被替换的目录会保存到：

```text
~/.local/state/desktop-dotfiles/backups/<时间戳>/
```

## 一键安装

```bash
git clone https://github.com/ParadoxMoranis/hyprland-dotfiles.git
cd hyprland-dotfiles
./install.sh
```

安装器默认进入交互模式，可以选择：

- 是否安装每个配置组件和对应软件
- 动画、模糊、阴影、壁纸、显示器热插拔等 Hyprland 功能
- Fcitx5、剪贴板、截图、Polkit、FlClash、cc-switch、Waylyrics 等启动功能
- Waybar 的每一个可见模块
- 当前机器的显示器规则、默认终端、文件管理器和命令菜单
- 是否逐项修改所有已启用的 Hyprland 快捷键

逐项设置快捷键时，直接回车保留本仓库默认值；输入 `off` 可以禁用单独一项。快捷键格式例如 `SUPER+RETURN`、`SUPER+SHIFT+S`、`PRINT`。

## 非交互安装

完全采用仓库默认值：

```bash
./install.sh --defaults
```

仅部署配置，不调用 `pacman` 或 AUR helper：

```bash
./install.sh --defaults --skip-packages
```

预览将执行的操作：

```bash
./install.sh --defaults --dry-run
```

强制进入逐项快捷键设置：

```bash
./install.sh --customize-keybinds
```

## 默认软件

官方仓库软件按所选功能动态安装，主要包括 `hyprland`、`waybar`、`kitty`、`alacritty`、`rofi`、`mako`、`awww`、`grim`、`slurp`、`satty`、`cliphist`、`wl-clipboard`、`fcitx5` 和相关 portal。

选择 FlClash、cc-switch 或 Waylyrics 时，安装器会优先使用本机已有的 `paru`，其次使用 `yay`。没有 AUR helper 时只跳过这些可选包，不影响其余配置安装。

## 配置结构

```text
config/                 可部署的桌面配置
  hypr/
    hyprland.conf       主配置与视觉参数
    autostart.conf      安装器生成的启动项
    keybinds.conf       带默认值和元数据的全部快捷键
    monitors.conf       安装器生成的显示器布局
    preferences.conf    动画、模糊和阴影开关
  waybar/               状态栏配置与黑白主题
  kitty/                Kitty 配置与终端主题
  alacritty/            Alacritty 配置与终端主题
  rofi/                  启动器和菜单主题
  mako/                  通知样式
  gtk-3.0/ gtk-4.0/     GTK 样式
wallpapers/             当前桌面壁纸
install.sh              交互式安装器
```

安装完成后再次运行 `./install.sh`，即可重新选择功能或生成快捷键。正在运行 Hyprland 时安装器会尝试重新加载配置；首次安装建议注销后从登录管理器进入 Hyprland。

## 隐私处理

仓库刻意排除了剪贴板实际内容、编辑器代理目录、缓存、历史备份和 GTK 文件管理器书签。固定剪贴板文件会在安装时创建为示例内容，不会提交到 Git。
