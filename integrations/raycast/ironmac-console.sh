#!/usr/bin/env bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Launch IronVault Console
# @raycast.mode silent
# @raycast.packageName IronMac

# Optional parameters:
# @raycast.icon ⚡
# @raycast.description Spawns a zero-trace, ephemeral RAM-backed terminal in macOS Terminal

IRONMAC_BIN="${HOME}/.local/bin/ironmac"
if [[ ! -x "$IRONMAC_BIN" ]]; then
    IRONMAC_BIN="/usr/local/bin/ironmac"
fi
if [[ ! -x "$IRONMAC_BIN" ]]; then
    IRONMAC_BIN="ironmac"
fi

osascript -e "tell application \"Terminal\" to do script \"$IRONMAC_BIN console\" activate"
