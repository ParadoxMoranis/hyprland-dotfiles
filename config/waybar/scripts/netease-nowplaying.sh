#!/usr/bin/env bash

set -u

pick_player() {
  if playerctl -l 2>/dev/null | grep -Fxq "plasma-browser-integration"; then
    printf 'plasma-browser-integration'
    return
  fi

  playerctl -l 2>/dev/null | grep -E '^chromium\.instance' | head -n 1
}

player="$(pick_player)"

if [[ -z "$player" ]]; then
  printf ' 网易云未运行\n'
  exit 0
fi

status="$(playerctl -p "$player" status 2>/dev/null || true)"

if [[ -z "$status" ]]; then
  printf ' 网易云未运行\n'
  exit 0
fi

artist="$(playerctl -p "$player" metadata xesam:artist 2>/dev/null || true)"
title="$(playerctl -p "$player" metadata xesam:title 2>/dev/null || true)"

if [[ -z "$artist" && -z "$title" ]]; then
  printf ' 网易云音乐\n'
  exit 0
fi

if [[ -n "$artist" && -n "$title" ]]; then
  text="$artist - $title"
elif [[ -n "$title" ]]; then
  text="$title"
else
  text="$artist"
fi

if [[ "$status" == "Paused" ]]; then
  printf ' %s\n' "$text"
else
  printf ' %s\n' "$text"
fi
