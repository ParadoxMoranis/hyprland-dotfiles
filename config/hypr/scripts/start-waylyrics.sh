#!/usr/bin/env bash

set -eu

schema="io.github.waylyrics.Waylyrics"

gsettings set "$schema" window-decorated false
gsettings set "$schema" window-click-through true
gsettings set "$schema" window-width 1400
gsettings set "$schema" window-height 140
gsettings set "$schema" lyric-align-mode "Center"
gsettings set "$schema" lyric-display-mode "show_both"

if ! pgrep -x waylyrics >/dev/null 2>&1; then
  waylyrics >/dev/null 2>&1 &
fi
