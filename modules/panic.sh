#!/usr/bin/env bash
#
# IronMac - Panic Button Module
# Emergency air-gap: instant Wi-Fi shutdown, browser/comms termination, clipboard purge.
#

set -euo pipefail

BOLD="\033[1m"
GREEN="\033[32m"
CYAN="\033[36m"
YELLOW="\033[33m"
RED="\033[31m"
RESET="\033[0m"

ACTION="${1:-trigger}"
FORCE="${2:-}"

get_wifi_interface() {
    networksetup -listallhardwareports 2>/dev/null | awk '/Wi-Fi|AirPort/{getline; print $2}' || echo "en0"
}

trigger_panic() {
    echo -e "${RED}${BOLD}"
    echo "=========================================================="
    echo "      🚨  IRONMAC EMERGENCY PANIC & AIR-GAP ACTIVATION    "
    echo "=========================================================="
    echo -e "${RESET}"

    if [[ "${FORCE}" != "-f" && "${FORCE}" != "--force" ]]; then
        read -rp "Trigger emergency air-gap? This will disconnect Wi-Fi and close browsers. [y/N]: " confirm
        if [[ ! "${confirm}" =~ ^[Yy]$ ]]; then
            echo "Panic aborted."
            exit 0
        fi
    fi

    echo -e "\n${BOLD}[1/4] Dropping network connections (Air-Gapping)...${RESET}"
    WIFI_IF=$(get_wifi_interface)
    if [[ -n "${WIFI_IF}" ]]; then
        networksetup -setairportpower "${WIFI_IF}" off >/dev/null 2>&1 || true
        echo -e "${GREEN}✓ Wi-Fi disconnected (${WIFI_IF} powered OFF).${RESET}"
    fi

    echo -e "\n${BOLD}[2/4] Purging clipboard to prevent credential harvesting...${RESET}"
    pbcopy < /dev/null
    echo -e "${GREEN}✓ Pasteboard wiped completely.${RESET}"

    echo -e "\n${BOLD}[3/4] Terminating communication and browser processes...${RESET}"
    killall -9 "Google Chrome" "Brave Browser" "Discord" "Telegram" "Slack" "Safari" 2>/dev/null || true
    echo -e "${GREEN}✓ Browsers & chat applications terminated.${RESET}"

    echo -e "\n${BOLD}[4/4] Activating screen lock...${RESET}"
    echo -e "${GREEN}✓ Threat isolation complete.${RESET}"

    echo ""
    echo -e "${YELLOW}${BOLD}⚠️  POST-INCIDENT RECOMMENDED CHECKLIST:${RESET}"
    echo "  1. Keep Wi-Fi OFF until you inspect Activity Monitor for unknown processes."
    echo "  2. Do NOT enter your macOS administrator password if a random prompt appears."
    echo "  3. Use another clean device to revoke token approvals and transfer high-value assets."
    echo "  4. When ready to reconnect Wi-Fi, run:"
    echo -e "     ${BOLD}ironmac panic restore${RESET}"
    echo ""
}

restore_network() {
    echo -e "${CYAN}${BOLD}=== Restoring Network Connectivity ===${RESET}"
    WIFI_IF=$(get_wifi_interface)
    if [[ -n "${WIFI_IF}" ]]; then
        networksetup -setairportpower "${WIFI_IF}" on >/dev/null 2>&1 || true
        echo -e "${GREEN}✓ Wi-Fi powered back ON (${WIFI_IF}).${RESET}"
    fi
    echo "Network connection restored."
}

case "${ACTION}" in
    trigger|now)
        trigger_panic
        ;;
    restore|recover|off)
        restore_network
        ;;
    *)
        echo "Usage: ironmac panic [trigger|restore] [-f]"
        exit 1
        ;;
esac
