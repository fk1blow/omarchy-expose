#!/bin/bash
# Prints 1 when a real game process is running, 0 otherwise.
#
# Every game carries a signature environment variable set by its launcher,
# whether it is a native Linux binary, a Proton game, or a Wine prefix.
# Checking /proc/*/environ this way is far more reliable than matching process
# names, which vary per game. A launcher client merely sitting open is
# deliberately not a game - Steam idling in the tray must not disarm anything.
#
# The scan is adapted from detect.sh in "Hey! I'm Gaming Here!"
# (https://github.com/linuxg33k76/hey-im-gaming-here, MIT, (c) linuxg33k76),
# reduced to the one question this plugin has: is a game up right now. The
# launcher inventory and its jq dependency are dropped.
set -uo pipefail

# The Heroic and Bottles patterns match those launchers' default prefix layout.
# A prefix relocated somewhere without the launcher's name in the path is a miss,
# as is a game started straight from a shell with no launcher to stamp it. Both
# are inherent to reading the environment rather than guessing at process names,
# and both fail towards leaving the hot corner alone.
if grep -qaz '^SteamAppId=' /proc/[0-9]*/environ 2>/dev/null \
  || grep -qaz '^LUTRIS_GAME_UUID=' /proc/[0-9]*/environ 2>/dev/null \
  || grep -qaz '^WINEPREFIX=.*[Hh]eroic' /proc/[0-9]*/environ 2>/dev/null \
  || grep -qaz '^WINEPREFIX=.*/bottles/' /proc/[0-9]*/environ 2>/dev/null; then
  echo 1
else
  echo 0
fi
