#!/usr/bin/env bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Launch Vault Browser
# @raycast.mode silent
# @raycast.packageName IronMac

# Optional parameters:
# @raycast.icon 🌐
# @raycast.description Opens isolated, sandboxed Web3 Vault Browser for trading & DeFi
# @raycast.argument1 { "type": "text", "placeholder": "URL (Optional)", "optional": true }

IRONMAC_BIN="${HOME}/.local/bin/ironmac"
if [[ ! -x "$IRONMAC_BIN" ]]; then
    IRONMAC_BIN="/opt/homebrew/bin/ironmac"
fi
if [[ ! -x "$IRONMAC_BIN" ]]; then
    IRONMAC_BIN="/usr/local/bin/ironmac"
fi
if [[ ! -x "$IRONMAC_BIN" ]]; then
    IRONMAC_BIN="ironmac"
fi

"$IRONMAC_BIN" vault-browser "${1:-https://alphanalyzor.trade}"
