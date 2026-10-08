#!/usr/bin/env bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title EMERGENCY AIR-GAP PANIC
# @raycast.mode compact
# @raycast.packageName IronMac

# Optional parameters:
# @raycast.icon 🚨
# @raycast.description Instantly power off Wi-Fi, purge clipboard memory, kill browsers, and lock screen

IRONMAC_BIN="${HOME}/.local/bin/ironmac"
if [[ ! -x "$IRONMAC_BIN" ]]; then
    IRONMAC_BIN="/usr/local/bin/ironmac"
fi
if [[ ! -x "$IRONMAC_BIN" ]]; then
    IRONMAC_BIN="ironmac"
fi

"$IRONMAC_BIN" panic trigger "Triggered via Raycast Script Command"

echo "🚨 EMERGENCY PANIC ACTIVATED: Hardware isolated, clipboard wiped, screen locked."
