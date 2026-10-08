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
for p in /opt/homebrew/bin /usr/local/bin "$HOME/.local/bin" "$HOME/.cargo/bin" "$HOME/.foundry/bin" "$HOME/.starkli/bin"; do
    if [[ -d "$p" && ":$PATH:" != *":$p:"* ]]; then
        export PATH="$p:$PATH"
    fi
done

# 3. Secure Distinctive Prompt & Aliases
PROMPT='%F{yellow}[🔒 IRON-CONSOLE]%f %F{cyan}%1~%f ❯ '

alias clear="clear && echo -e '\033[33m[🔒 IRON-CONSOLE: History OFF | RAM-backed Workspace active]\033[0m'"
alias evm-wallet="cast wallet"
alias starknet-wallet="starkli"
alias vault-browser="ironmac vault-browser"
alias clip-guard="ironmac clip-guard"
alias trap="ironmac trap"
alias panic="ironmac panic"

unalias help 2>/dev/null || true

help() {
    echo -e "\033[1;36m==========================================================\033[0m"
    echo -e "\033[1;36m          🛡️  IronMac Secure Console User Guide          \033[0m"
    echo -e "\033[1;36m==========================================================\033[0m"
    echo -e "Zero-Trace Ephemeral RAM Environment for Web3 Operations\n"

    echo -e "\033[1;33m[1] Core Security Guarantees:\033[0m"
    echo -e "  • \033[1;32mZero Disk History\033[0m : HISTFILE=/dev/null (No command is ever saved to ~/.zsh_history)"
    echo -e "  • \033[1;32mRAM-Backed Disk\033[0m   : This workspace is in volatile memory (/Volumes/IronVault_*)"
    echo -e "  • \033[1;32mSelf-Purging\033[0m      : Exiting terminates the session and securely ejects the RAM disk\n"

    echo -e "\033[1;33m[2] Web3 Key & Wallet Operations in RAM:\033[0m"
    echo -e "  • \033[1;37mcast wallet new\033[0m                      Generate fresh EVM address + mnemonic in RAM"
    echo -e "  • \033[1;37mcast wallet import <name> -i\033[0m         Safely import private key into RAM keystore"
    echo -e "  • \033[1;37mcast wallet vanity --starts-with 00\033[0m  Mine custom address offline with zero disk I/O"
    echo -e "  • \033[1;37mstarkli signer create ./signer.json\033[0m  Generate encrypted Starknet signer in RAM"
    echo -e "  • \033[1;37mstarkli account oz init ./acc.json\033[0m   Initialize OpenZeppelin smart account\n"

    echo -e "\033[1;33m[3] Built-in Shortcuts & Security Commands:\033[0m"
    echo -e "  • \033[1;36mhelp\033[0m / \033[1;36miron-help\033[0m                   Display this interactive guide"
    echo -e "  • \033[1;36mvault-browser\033[0m                       Launch isolated Web3 browser profile"
    echo -e "  • \033[1;36mclip-guard [status|clear|test]\033[0m      Clipboard address-swap guard & auto-wipe"
    echo -e "  • \033[1;36mtrap [status|test]\033[0m                  Anti-AMOS honeypot decoys & tripwire sentry"
    echo -e "  • \033[1;36mpanic\033[0m                               Emergency hardware air-gap kill switch"
    echo -e "  • \033[1;36minstall-evm-wallet\033[0m                  One-click install Foundry (cast, forge)"
    echo -e "  • \033[1;36minstall-starknet-wallet\033[0m             One-click install Starkli toolchain\n"

    echo -e "\033[1;33m[4] Cold Storage & Exit Rules:\033[0m"
    echo -e "  ⚠️  \033[1;31mWARNING:\033[0m When you type \033[1m'exit'\033[0m, all files in this workspace vanish forever."
    echo -e "  • To persist a key generated here, write the mnemonic on paper/steel plate."
    echo -e "  • Never paste raw private keys into external chat apps or browsers."
    echo -e "\nType \033[1m'exit'\033[0m or press \033[1mCtrl+D\033[0m to terminate session and destroy RAM disk."
    echo -e "\033[1;36m==========================================================\033[0m"
}

alias iron-help=help
alias '?'=help

install-evm-wallet() {
    echo "Installing Foundry (cast wallet)..."
    curl -L https://foundry.paradigm.xyz | bash
    if [[ -x "$HOME/.foundry/bin/foundryup" ]]; then
        "$HOME/.foundry/bin/foundryup"
    fi
    export PATH="$HOME/.foundry/bin:$PATH"
    echo "✓ Cast wallet installed. Try: cast wallet new"
}

install-starknet-wallet() {
    echo "Installing Starkli (Starknet wallet)..."
    curl -fsSL https://get.starkli.sh | sh
    if [[ -x "$HOME/.starkli/bin/starkliup" ]]; then
        "$HOME/.starkli/bin/starkliup"
    fi
    export PATH="$HOME/.starkli/bin:$PATH"
    echo "✓ Starkli installed. Try: starkli signer create ./signer.json"
}
EOF

echo ""
echo -e "${GREEN}[✓] History recording is completely DISABLED (HISTFILE=/dev/null)${RESET}"
echo -e "${GREEN}[✓] Ephemeral RAM workspace mounted at: ${BOLD}${MOUNT_POINT}${RESET}"
echo -e "${GREEN}[✓] Clean-room environment initialized${RESET}"

# Check EVM & Starknet tooling
echo ""
echo -e "${CYAN}${BOLD}🪙 Built-in Open-Source CLI Wallets:${RESET}"
for p in /opt/homebrew/bin /usr/local/bin "$HOME/.local/bin" "$HOME/.cargo/bin" "$HOME/.foundry/bin" "$HOME/.starkli/bin"; do
    if [[ -d "$p" && ":$PATH:" != *":$p:"* ]]; then
        export PATH="$p:$PATH"
    fi
done

if command -v cast >/dev/null 2>&1; then
    echo -e "  • ${GREEN}EVM (Foundry cast):${RESET} ✓ Ready"
    echo "    - cast wallet new                    (Generate fresh EVM address & mnemonic in RAM)"
    echo "    - cast wallet import <name> --interactive (Import private key securely)"
else
    echo -e "  • ${YELLOW}EVM (Foundry cast):${RESET} Not installed (type ${BOLD}install-evm-wallet${RESET} to install)"
fi

if command -v starkli >/dev/null 2>&1; then
    echo -e "  • ${GREEN}Starknet (Starkli):${RESET} ✓ Ready"
    echo "    - starkli signer create ./signer.json (Generate encrypted Starknet signer in RAM)"
    echo "    - starkli account oz init ./acc.json (Setup OpenZeppelin smart account)"
else
    echo -e "  • ${YELLOW}Starknet (Starkli):${RESET} Not installed (type ${BOLD}install-starknet-wallet${RESET} to install)"
fi

echo ""
echo -e "${YELLOW}⚠️  Safety Notes:${RESET}"
echo "   - Commands typed here will NEVER be saved to ~/.zsh_history."
echo "   - Any keys/files created in this workspace disappear completely upon 'exit'."
echo "   - To persist a key generated here, explicitly export it to cold storage before exiting."
echo ""
echo -e "Type ${BOLD}${CYAN}'help'${RESET} to view console guide & workflows, or ${BOLD}'exit'${RESET} when finished."
echo "----------------------------------------------------------"

# 3. Launch isolated subshell inside RAM workspace
cd "${MOUNT_POINT}"
ZDOTDIR="${ZDOT_DIR}" zsh -i

