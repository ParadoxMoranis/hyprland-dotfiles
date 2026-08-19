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

安装器不提供组件、功能、Waybar 模块或快捷键选择。运行后会安装所需软件并完整部署仓库中的 Hyprland、Waybar、终端、启动器、通知、GTK 样式、辅助脚本和壁纸，使新机器采用同一套桌面配置。

显示器名称、分辨率和刷新率不写死。Hyprland 启动和显示器热插拔时，脚本会为每个输出选择最高分辨率，并在该分辨率下选择最高刷新率，然后自动排列。显示器菜单支持临时仅启用外接显示器；安装器还会部署合盖休眠配置。

## 安装选项

仅部署配置，不调用 `pacman` 或 AUR helper：

```bash
./install.sh --skip-packages
```

预览将执行的操作：

```bash
./install.sh --dry-run
```

## 默认软件

官方仓库软件会随完整桌面配置一起安装，主要包括 `hyprland`、`waybar`、`kitty`、`alacritty`、`rofi`、`mako`、`awww`、`grim`、`slurp`、`satty`、`cliphist`、`wl-clipboard`、`fcitx5` 和相关 portal。

FlClash、cc-switch 和 Waylyrics 会通过本机已有的 `paru` 或 `yay` 安装。没有 AUR helper 时会跳过这三个 AUR 包，不影响其余配置安装。

## 配置结构

```text
config/                 可部署的桌面配置
  hypr/
    hyprland.conf       主配置与视觉参数
    autostart.conf      完整桌面启动项
    keybinds.conf       带默认值和元数据的全部快捷键
    monitors.conf       自适应显示器初始规则
    preferences.conf    动画、模糊和阴影设置
  waybar/               状态栏配置与黑白主题
  kitty/                Kitty 配置与终端主题
  alacritty/            Alacritty 配置与终端主题
  rofi/                  启动器和菜单主题
  mako/                  通知样式
  gtk-3.0/ gtk-4.0/     GTK 样式
wallpapers/             当前桌面壁纸
install.sh              无交互完整安装器
```

安装完成后再次运行 `./install.sh`，会备份现有配置并重新部署仓库的完整配置。正在运行 Hyprland 时安装器会尝试重新加载配置；首次安装建议注销后从登录管理器进入 Hyprland。

## 隐私处理

仓库刻意排除了剪贴板实际内容、编辑器代理目录、缓存、历史备份和 GTK 文件管理器书签。固定剪贴板文件会在安装时创建为示例内容，不会提交到 Git。
