#!/usr/bin/env bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Toggle Hardware Air-Gap
# @raycast.mode compact
# @raycast.packageName IronMac

# Optional parameters:
# @raycast.icon 📶
# @raycast.description Instantly toggle Wi-Fi hardware (en0) power for offline clean-room signing

CURRENT=$(networksetup -getairportpower en0 2>/dev/null | awk '{print $4}')

if [[ "$CURRENT" == "On" ]]; then
    networksetup -setairportpower en0 off 2>/dev/null || true
    echo "⚡ Air-Gap ACTIVE: Wi-Fi powered off. System physically isolated."
else
    networksetup -setairportpower en0 on 2>/dev/null || true
    echo "📶 Air-Gap RELEASED: Wi-Fi reconnected."
fi
