#!/usr/bin/env bash
#
# IronMac - Clipboard Guard Module
# Monitors pasteboard for address swapping trojans & auto-wipes sensitive keys.
#

set -euo pipefail

BOLD="\033[1m"
GREEN="\033[32m"
CYAN="\033[36m"
YELLOW="\033[33m"
RED="\033[31m"
RESET="\033[0m"

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PID_FILE="${HOME}/.ironmac/clip_guard.pid"
LOG_FILE="${HOME}/.ironmac/clip_guard.log"

start_guard() {
    if [[ -f "${PID_FILE}" ]] && kill -0 "$(cat "${PID_FILE}")" 2>/dev/null; then
        echo -e "${YELLOW}Clipboard Guard is already running (PID: $(cat "${PID_FILE}")).${RESET}"
        return
    fi

    echo -e "${BOLD}Starting IronMac Clipboard Guard daemon in background...${RESET}"
    nohup python3 "${SOURCE_DIR}/modules/clip_guard.py" >/dev/null 2>&1 &
    sleep 1

    if [[ -f "${PID_FILE}" ]] && kill -0 "$(cat "${PID_FILE}")" 2>/dev/null; then
        echo -e "${GREEN}✓ Clipboard Guard active (PID: $(cat "${PID_FILE}")).${RESET}"
        echo "Active protections:"
        echo "  • Detects rapid address substitution trojans (EVM, Solana, Bitcoin)"
        echo "  • Automatically wipes private keys and seed phrases after 30 seconds"
    else
        echo -e "${RED}Failed to start Clipboard Guard daemon.${RESET}"
    fi
}

stop_guard() {
    if [[ -f "${PID_FILE}" ]]; then
        PID=$(cat "${PID_FILE}")
        if kill -0 "${PID}" 2>/dev/null; then
            kill "${PID}" 2>/dev/null || true
            echo -e "${GREEN}✓ Clipboard Guard stopped (PID: ${PID}).${RESET}"
        else
            echo "Clipboard Guard is not running."
        fi
        rm -f "${PID_FILE}"
    else
        echo "Clipboard Guard is not running."
    fi
}

status_guard() {
    echo -e "${CYAN}${BOLD}=== IronMac Clipboard Guard Status ===${RESET}"
    if [[ -f "${PID_FILE}" ]] && kill -0 "$(cat "${PID_FILE}")" 2>/dev/null; then
        echo -e "Daemon Status: ${GREEN}${BOLD}● ACTIVE${RESET} (PID: $(cat "${PID_FILE}"))"
    else
        echo -e "Daemon Status: ${YELLOW}○ STOPPED${RESET}"
    fi

    echo -e "\n${BOLD}Recent Events (from ~/.ironmac/clip_guard.log):${RESET}"
    if [[ -f "${LOG_FILE}" ]]; then
        tail -n 5 "${LOG_FILE}" || echo "No events logged."
    else
        echo "No events logged yet."
    fi
    echo ""
}

clear_clipboard() {
    pbcopy < /dev/null
    echo -e "${GREEN}✓ Clipboard wiped completely.${RESET}"
}

test_guard() {
    echo -e "${CYAN}${BOLD}=== Testing Clipboard Guard (30s Key Auto-Purge) ===${RESET}"
    echo "Simulating copying a dummy private key to clipboard..."
    # Put a fake 64-char hex key into clipboard
    echo -n "0x1111222233334444555566667777888899990000aaaabbbbccccddddeeeeffff" | pbcopy
    echo -e "${GREEN}✓ Dummy private key placed in clipboard!${RESET}"
    echo "Check your screen for the initial alert. In 30 seconds, it will be automatically erased."
}

ACTION="${1:-status}"

case "${ACTION}" in
    start)
        start_guard
        ;;
    stop)
        stop_guard
        ;;
    status)
        status_guard
        ;;
    clear)
        clear_clipboard
        ;;
    test)
        test_guard
        ;;
    *)
        echo "Usage: ironmac clip-guard [start|stop|status|clear|test]"
        exit 1
        ;;
esac
