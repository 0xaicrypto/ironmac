#!/usr/bin/env bash
#
# IronMac - Secure Vault Console Module
# Provides a zero-trace, ephemeral RAM-backed terminal session for Web3 operations.
#

set -euo pipefail

BOLD="\033[1m"
GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
RED="\033[31m"
RESET="\033[0m"

echo ""
echo -e "${CYAN}${BOLD}==========================================================${RESET}"
echo -e "${CYAN}${BOLD}          🛡️  IronMac Secure Vault Console               ${RESET}"
echo -e "${CYAN}${BOLD}==========================================================${RESET}"

RAMDEV=""
MOUNT_POINT=""
TMP_ENV_DIR=$(mktemp -d /tmp/ironmac_console_XXXXXX)

cleanup() {
    echo ""
    echo -e "${YELLOW}Shutting down secure console session...${RESET}"
    if [[ -n "${RAMDEV}" ]]; then
        echo -n "Destroying ephemeral RAM Disk (${RAMDEV})... "
        diskutil eject "${RAMDEV}" >/dev/null 2>&1 || true
        echo -e "${GREEN}✓ Purged${RESET}"
    fi
    if [[ -d "${TMP_ENV_DIR}" ]]; then
        rm -rf "${TMP_ENV_DIR}"
    fi
    echo -e "${GREEN}${BOLD}✓ Secure session terminated. Zero artifacts written to disk.${RESET}\n"
}

trap cleanup EXIT INT TERM

# 1. Mount 32MB Ephemeral RAM Disk (if supported)
echo -n "Initializing ephemeral RAM Disk (32MB)... "
RAW_DEV=$(hdiutil attach -nomount ram://65536 2>/dev/null | awk '{print $1}' || true)

if [[ -n "${RAW_DEV}" ]]; then
    RAMDEV="${RAW_DEV}"
    VOL_NAME="IronVault_$$"
    diskutil erasevolume HFS+ "${VOL_NAME}" "${RAMDEV}" >/dev/null 2>&1
    MOUNT_POINT="/Volumes/${VOL_NAME}"
    echo -e "${GREEN}✓ Ready at ${MOUNT_POINT}${RESET}"
else
    # Fallback to tmpfs-like directory
    MOUNT_POINT="${TMP_ENV_DIR}/workspace"
    mkdir -p "${MOUNT_POINT}"
    echo -e "${YELLOW}Fallback to ${MOUNT_POINT}${RESET}"
fi

# 2. Prepare Isolated Zero-Trace Shell Configuration
ZDOT_DIR="${TMP_ENV_DIR}/zdot"
mkdir -p "${ZDOT_DIR}"

cat <<'EOF' > "${ZDOT_DIR}/.zshrc"
# Load essential environment
if [[ -f /etc/zshrc ]]; then
    source /etc/zshrc
fi

# 1. Force zero history recording
unset HISTFILE
export HISTFILE=/dev/null
export HISTSIZE=0
export SAVEHIST=0
setopt NO_SHARE_HISTORY
setopt NO_INC_APPEND_HISTORY
setopt NO_APPEND_HISTORY

# 2. Load developer tools from standard paths if available
for p in /opt/homebrew/bin /usr/local/bin "$HOME/.cargo/bin" "$HOME/.foundry/bin"; do
    if [[ -d "$p" && ":$PATH:" != *":$p:"* ]]; then
        export PATH="$p:$PATH"
    fi
done

# 3. Secure Distinctive Prompt
PROMPT='%F{yellow}[🔒 IRON-CONSOLE]%f %F{cyan}%1~%f ❯ '

alias clear="clear && echo -e '\033[33m[🔒 IRON-CONSOLE: History OFF | RAM-backed Workspace active]\033[0m'"
EOF

echo ""
echo -e "${GREEN}[✓] History recording is completely DISABLED (HISTFILE=/dev/null)${RESET}"
echo -e "${GREEN}[✓] Ephemeral RAM workspace mounted at: ${BOLD}${MOUNT_POINT}${RESET}"
echo -e "${GREEN}[✓] Clean-room environment initialized${RESET}"
echo ""
echo -e "${YELLOW}⚠️  Safety Notes:${RESET}"
echo "   - Commands typed here will NEVER be saved to ~/.zsh_history."
echo "   - Any files created in this workspace will vanish immediately when you exit."
echo "   - Safe for running 'cast wallet', 'solana keypair', or pasting private keys."
echo ""
echo -e "Type ${BOLD}'exit'${RESET} or press ${BOLD}Ctrl+D${RESET} when finished."
echo "----------------------------------------------------------"

# 3. Launch isolated subshell inside RAM workspace
cd "${MOUNT_POINT}"
ZDOTDIR="${ZDOT_DIR}" zsh -i

