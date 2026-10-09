#!/usr/bin/env bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Defense HUD Telemetry
# @raycast.mode fullOutput
# @raycast.packageName IronMac

# Optional parameters:
# @raycast.icon ⚡
# @raycast.description Display live defensive telemetry (Honey Traps, ClipGuard, RAM Vault, Air-Gap)

IRONMAC_BIN="${HOME}/.local/bin/ironmac"
if [[ ! -x "$IRONMAC_BIN" ]]; then
    IRONMAC_BIN="/usr/local/bin/ironmac"
fi
if [[ ! -x "$IRONMAC_BIN" ]]; then
    IRONMAC_BIN="ironmac"
fi

echo "=========================================================="
echo "          ⚡  IronMac Active Defense Telemetry           "
echo "=========================================================="
echo ""

# 1. Airgap
WIFI_STATE=$(networksetup -getairportpower en0 2>/dev/null | awk '{print $4}')
if [[ "$WIFI_STATE" == "On" ]]; then
    echo "📶 Network State     : Online (Wi-Fi On)"
else
    echo "⚡ Network State     : AIR-GAPPED (Hardware Wi-Fi Isolated)"
fi

# 2. Trap
if pgrep -f "trap_sentry.py" >/dev/null; then
    echo "🪤 Anti-AMOS Trap    : ARMED (kqueue zero-CPU sentry active)"
else
    echo "🪤 Anti-AMOS Trap    : INACTIVE (Run 'ironmac trap start')"
fi

# 3. ClipGuard
if pgrep -f "clip_guard.py" >/dev/null; then
    echo "📋 Clipboard Guard   : ACTIVE (Anti-swap + 30s TTL key purge)"
else
    echo "📋 Clipboard Guard   : INACTIVE (Run 'ironmac clip-guard start')"
fi

# 4. RAM Vaults
RAM_MOUNTS=$(df -h | grep -i "IronVault" || true)
if [[ -n "$RAM_MOUNTS" ]]; then
    echo "💻 RAM Vault Workspace: Mounted (/Volumes/IronVault_*)"
else
    echo "💻 RAM Vault Workspace: None active (Type 'ironmac console')"
fi

echo ""
echo "Quick Commands:"
echo "  • Open Terminal  : ironmac console"
echo "  • Toggle Air-Gap : ironmac-airgap"
echo "  • Emergency Panic: ironmac panic"
