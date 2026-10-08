#!/usr/bin/env bash
#
# IronMac - Anti-AMOS Honeypot Trap Module
# Deploys realistic canary decoys in known infostealer search paths and monitors them.
#

set -euo pipefail

BOLD="\033[1m"
GREEN="\033[32m"
CYAN="\033[36m"
YELLOW="\033[33m"
RED="\033[31m"
RESET="\033[0m"

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PID_FILE="${HOME}/.ironmac/trap.pid"
LOG_FILE="${HOME}/.ironmac/trap.log"

# High-value paths targeted by AMOS and crypto infostealers
TRAP_ETH="${HOME}/.ethereum/keystore"
TRAP_SOL="${HOME}/.config/solana"
TRAP_DOC="${HOME}/Documents/.ironmac_canary"
TRAP_DIR="${HOME}/.ironmac/honeypot"

TRAP_DIRS=(
    "${TRAP_ETH}"
    "${TRAP_SOL}"
    "${TRAP_DOC}"
    "${TRAP_DIR}"
)

deploy_decoys() {
    echo -e "${CYAN}${BOLD}=== Deploying Anti-AMOS Honeypot Decoys ===${RESET}"
    echo "Placing realistic canary wallet decoys in standard infostealer search targets..."

    # 1. Ethereum Keystore Decoy (~/.ethereum/keystore)
    mkdir -p "${TRAP_ETH}"
    cat <<'EOF' > "${TRAP_ETH}/UTC--canary-ironmac-trap.json"
{"address":"00000000000000000000000000000000000ca7a1","crypto":{"cipher":"aes-128-ctr","ciphertext":"c4a7a1fa4e01928475a8927495b41294857291a2b3c4d5e6f7a8b9c0d1e2f3a4","cipherparams":{"iv":"1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d"},"kdf":"scrypt","kdfparams":{"dklen":32,"n":262144,"p":1,"r":8,"salt":"9a8b7c6d5e4f3a2b1c0d9e8f7a6b5c4d3e2f1a0b9c8d7e6f5a4b3c2d1e0f9a8b"},"mac":"fa4e01928475a8927495b41294857291a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7"},"id":"ironmac-canary-eth-001","version":3}
EOF
    echo -e "  ${GREEN}✓ Decoy deployed:${RESET} ${TRAP_ETH}/UTC--canary-ironmac-trap.json"

    # 2. Solana Keypair Decoy (~/.config/solana)
    mkdir -p "${TRAP_SOL}"
    cat <<'EOF' > "${TRAP_SOL}/id.json"
[142,215,89,12,74,233,180,95,14,201,88,145,23,67,189,45,210,99,14,87,233,120,45,98,12,65,198,76,23,109,87,34,142,215,89,12,74,233,180,95,14,201,88,145,23,67,189,45,210,99,14,87,233,120,45,98,12,65,198,76,23,109,87,34]
EOF
    echo -e "  ${GREEN}✓ Decoy deployed:${RESET} ${TRAP_SOL}/id.json"

    # 3. Documents Seed Backup Decoy (~/Documents/.ironmac_canary)
    mkdir -p "${TRAP_DOC}"
    cat <<'EOF' > "${TRAP_DOC}/wallet_backup_do_not_share.txt"
# IRONMAC CANARY WALLET DECOY - DO NOT USE
# If you are an attacker copying this file, your PID and IP are being logged.
seed_phrase: abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon canary
address: 0x000000000000000000000000000000000000CA7A
EOF
    echo -e "  ${GREEN}✓ Decoy deployed:${RESET} ${TRAP_DOC}/wallet_backup_do_not_share.txt"

    # 4. Local Test Honeypot
    mkdir -p "${TRAP_DIR}"
    echo "canary_active=true" > "${TRAP_DIR}/canary.token"
    echo -e "  ${GREEN}✓ Decoy deployed:${RESET} ${TRAP_DIR}/canary.token"

    echo ""
    echo -e "${GREEN}${BOLD}✓ All honeypot decoys successfully armed!${RESET}"
}

start_sentry() {
    if [[ -f "${PID_FILE}" ]] && kill -0 "$(cat "${PID_FILE}")" 2>/dev/null; then
        echo -e "${YELLOW}IronMac Trap Sentry is already running (PID: $(cat "${PID_FILE}")).${RESET}"
        return
    fi

    deploy_decoys

    echo -e "\n${BOLD}Starting Trap Sentry daemon in background...${RESET}"
    nohup python3 "${SOURCE_DIR}/modules/trap_sentry.py" "${TRAP_DIRS[@]}" >/dev/null 2>&1 &
    sleep 1

    if [[ -f "${PID_FILE}" ]] && kill -0 "$(cat "${PID_FILE}")" 2>/dev/null; then
        echo -e "${GREEN}✓ Trap Sentry active (PID: $(cat "${PID_FILE}")).${RESET}"
        echo "Active monitoring engaged. Any process tampering with decoy keys will trigger instant alerts."
    else
        echo -e "${RED}Failed to start Trap Sentry daemon.${RESET}"
    fi
}

stop_sentry() {
    if [[ -f "${PID_FILE}" ]]; then
        PID=$(cat "${PID_FILE}")
        if kill -0 "${PID}" 2>/dev/null; then
            kill "${PID}" 2>/dev/null || true
            echo -e "${GREEN}✓ Trap Sentry daemon stopped (PID: ${PID}).${RESET}"
        else
            echo "Trap Sentry was not active."
        fi
        rm -f "${PID_FILE}"
    else
        echo "Trap Sentry is not running."
    fi
}

status_sentry() {
    echo -e "${CYAN}${BOLD}=== IronMac Anti-AMOS Honeypot Status ===${RESET}"
    if [[ -f "${PID_FILE}" ]] && kill -0 "$(cat "${PID_FILE}")" 2>/dev/null; then
        echo -e "Sentry Daemon: ${GREEN}${BOLD}● ACTIVE${RESET} (PID: $(cat "${PID_FILE}"))"
    else
        echo -e "Sentry Daemon: ${YELLOW}○ STOPPED${RESET}"
    fi

    echo -e "\n${BOLD}Active Decoy Traps:${RESET}"
    for dir in "${TRAP_DIRS[@]}"; do
        if [[ -d "${dir}" ]]; then
            echo -e "  ${GREEN}✓ ARMED:${RESET} ${dir}"
        else
            echo -e "  ${YELLOW}○ Unarmed:${RESET} ${dir} (Run 'ironmac trap deploy' to setup)"
        fi
    done

    echo -e "\n${BOLD}Recent Alerts (from ~/.ironmac/trap.log):${RESET}"
    if [[ -f "${LOG_FILE}" ]]; then
        tail -n 5 "${LOG_FILE}" || echo "No alerts yet."
    else
        echo "No alerts logged."
    fi
    echo ""
}

test_trap() {
    echo -e "${YELLOW}Simulating unauthorized tripwire event on canary trap...${RESET}"
    touch "${TRAP_DIR}/canary.token"
    sleep 1
    echo -e "${GREEN}✓ Probe sent! Check your screen for the macOS notification and sound.${RESET}"
}

ACTION="${1:-status}"

case "${ACTION}" in
    start)
        start_sentry
        ;;
    stop)
        stop_sentry
        ;;
    deploy)
        deploy_decoys
        ;;
    status)
        status_sentry
        ;;
    test)
        test_trap
        ;;
    *)
        echo "Usage: ironmac trap [start|stop|deploy|status|test]"
        exit 1
        ;;
esac
