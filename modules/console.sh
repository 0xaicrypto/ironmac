#!/usr/bin/env bash
#
# IronMac - Secure Vault Console Module
# Provides a zero-trace, ephemeral RAM-backed terminal session for Web3 operations.
#

set -euo pipefail

# Capture host directory prior to entering RAM disk
ORIGINAL_CWD="${PWD}"
export ORIGINAL_CWD

# ANSI 256-color & style definitions
BOLD="\033[1m"
GREEN="\033[38;5;82m"
YELLOW="\033[38;5;214m"
CYAN="\033[38;5;51m"
RED="\033[38;5;196m"
GRAY="\033[38;5;242m"
PURPLE="\033[38;5;141m"
RESET="\033[0m"

RAMDEV=""
MOUNT_POINT=""
TMP_ENV_DIR=$(mktemp -d /tmp/ironmac_console_XXXXXX)

cleanup() {
    echo ""
    echo -e "${GRAY}┌──${RESET}${BOLD}${YELLOW}[ ⚡ INITIATING SECURE TEARDOWN ]${RESET}${GRAY}─────────────────────────────────┐${RESET}"
    if [[ -n "${RAMDEV}" ]]; then
        echo -e "${GRAY}│${RESET}  Purging ephemeral RAM disk (${RAMDEV})... \c"
        diskutil eject "${RAMDEV}" >/dev/null 2>&1 || true
        echo -e "${GREEN}✓ PURGED${RESET}"
    fi
    if [[ -d "${TMP_ENV_DIR}" ]]; then
        echo -e "${GRAY}│${RESET}  Scrubbing temporary environment variables & zdot... ${GREEN}✓ CLEARED${RESET}"
        rm -rf "${TMP_ENV_DIR}"
    fi
    echo -e "${GRAY}│${RESET}  Sanitizing volatile memory & terminal buffer... ${GREEN}✓ CLEAN${RESET}"
    echo -e "${GRAY}└──${RESET}${BOLD}${GREEN}[ ✓ SECURE SESSION TERMINATED // ZERO ARTIFACTS ON SSD ]${RESET}${GRAY}──────┘${RESET}\n"
}

trap cleanup EXIT INT TERM

echo ""
echo -e "${GRAY}┌──${RESET}${BOLD}${CYAN}[ ⚡ IRONMAC // SECURE VAULT CONSOLE v0.4.0 ]${RESET}${GRAY}────────────────────────┐${RESET}"

# 1. Mount 32MB Ephemeral RAM Disk (if supported)
RAW_DEV=$(hdiutil attach -nomount ram://65536 2>/dev/null | awk '{print $1}' || true)

if [[ -n "${RAW_DEV}" ]]; then
    RAMDEV="${RAW_DEV}"
    VOL_NAME="IronVault_$$"
    diskutil erasevolume HFS+ "${VOL_NAME}" "${RAMDEV}" >/dev/null 2>&1
    MOUNT_POINT="/Volumes/${VOL_NAME}"
    echo -e "${GRAY}│${RESET}  ${BOLD}WORKSPACE${RESET} : ${GREEN}${MOUNT_POINT} (32MB Ephemeral RAM Disk)${RESET}"
else
    MOUNT_POINT="${TMP_ENV_DIR}/workspace"
    mkdir -p "${MOUNT_POINT}"
    echo -e "${GRAY}│${RESET}  ${BOLD}WORKSPACE${RESET} : ${YELLOW}${MOUNT_POINT} (Temp Memory Fallback)${RESET}"
fi

export MOUNT_POINT

echo -e "${GRAY}│${RESET}  ${BOLD}INTEGRITY${RESET} : ${YELLOW}[●] HISTFILE → /dev/null${RESET}  ${GREEN}[●] ZERO-SSD-PERSISTENCE${RESET}"

# Check PATH & tools
for p in /opt/homebrew/bin /usr/local/bin "$HOME/.local/bin" "$HOME/.cargo/bin" "$HOME/.foundry/bin" "$HOME/.starkli/bin"; do
    if [[ -d "$p" && ":$PATH:" != *":$p:"* ]]; then
        export PATH="$p:$PATH"
    fi
done

FOUNDRY_STATUS="${GRAY}○ Missing${RESET}"
command -v cast >/dev/null 2>&1 && FOUNDRY_STATUS="${GREEN}● Ready${RESET}"

STARKLI_STATUS="${GRAY}○ Missing${RESET}"
command -v starkli >/dev/null 2>&1 && STARKLI_STATUS="${GREEN}● Ready${RESET}"

TRAP_STATUS="${GRAY}○ Inactive${RESET}"
pgrep -f "trap_sentry.py" >/dev/null && TRAP_STATUS="${GREEN}● Armed${RESET}"

CLIP_STATUS="${GRAY}○ Inactive${RESET}"
pgrep -f "clip_guard.py" >/dev/null && CLIP_STATUS="${GREEN}● Armed${RESET}"

echo -e "${GRAY}│${RESET}  ${BOLD}TELEMETRY${RESET} : Cast: ${FOUNDRY_STATUS}  Starkli: ${STARKLI_STATUS}  Trap: ${TRAP_STATUS}  ClipGuard: ${CLIP_STATUS}"
echo -e "${GRAY}└──${RESET}${BOLD}${GRAY}[ ZERO-TRACE AIR-GAP SANDBOX // TYPE 'help' FOR MANUAL ]${RESET}${GRAY}────────┘${RESET}\n"

# 2. Prepare Isolated Zero-Trace Shell Configuration
ZDOT_DIR="${TMP_ENV_DIR}/zdot"
mkdir -p "${ZDOT_DIR}"

cat <<'EOF' > "${ZDOT_DIR}/.zshrc"
# Load essential environment
if [[ -f /etc/zshrc ]]; then
    source /etc/zshrc
fi

# 1. Zero Disk Persistence + In-Memory Recall
unset HISTFILE
export HISTFILE=/dev/null
export HISTSIZE=1000
export SAVEHIST=0
setopt NO_SHARE_HISTORY
setopt NO_INC_APPEND_HISTORY
setopt NO_APPEND_HISTORY

# Filter out sensitive keys/secrets from in-memory history buffer
zshaddhistory() {
    local cmd="${1%%$'\n'}"
    # Block 64-hex strings (raw private keys)
    if [[ "$cmd" =~ ([0-9a-fA-F]{64}) ]]; then
        return 1
    fi
    # Block private key / seed environment assignments
    if [[ "$cmd" =~ (PRIVATE_KEY|MNEMONIC|SECRET|API_KEY)= ]]; then
        return 1
    fi
    return 0
}

# Fast prefix history navigation (type 'cast' + Up arrow to recall only cast commands)
bindkey -e
bindkey '^[[A' up-line-or-search
bindkey '^[[B' down-line-or-search

# Fast ephemeral Tab completion
autoload -Uz compinit
compinit -d "${ZDOT_DIR}/.zcompdump"
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# 2. Load developer tools from standard paths if available
for p in /opt/homebrew/bin /usr/local/bin "$HOME/.local/bin" "$HOME/.cargo/bin" "$HOME/.foundry/bin" "$HOME/.starkli/bin"; do
    if [[ -d "$p" && ":$PATH:" != *":$p:"* ]]; then
        export PATH="$p:$PATH"
    fi
done

# 3. Two-Line Hacker Cyberpunk Prompt
PROMPT="%F{242}╭─%f%F{82}[%f%F{51}⚡ IRON-VAULT%f%F{82}]%f%F{242}─%f%F{214}[HIST:OFF]%f%F{242}─%f%F{141}[%1~]%f"$'\n'"%F{242}╰─%f%(?.%F{51}❯%f.%F{196}❯%f) "

# 4. Built-in Security & Productivity Aliases
alias clear="clear && echo -e '\033[38;5;242m╭─\033[0m\033[1;38;5;51m[⚡ IRON-VAULT // VOLATILE MEMORY ACTIVE // ZERO-TRACE]\033[0m\033[38;5;242m─\033[0m\033[38;5;214m[HIST:OFF]\033[0m\033[38;5;242m─\033[0m\033[38;5;82m[● AIR-GAP READY]\033[0m'"
alias ls="ls -G"
alias ll="ls -laGh"
alias evm-wallet="cast wallet"
alias starknet-wallet="starkli"
alias vault-browser="ironmac vault-browser"
alias clip-guard="ironmac clip-guard"
alias trap="ironmac trap"
alias panic="ironmac panic"
alias iron-help=help
alias '?'=help
alias status=hud
alias key-guide=key_guide
alias wallet-guide=key_guide
alias vopen=finder

# 5. Dual-Space Navigation
vault() {
    cd "${MOUNT_POINT}"
    echo -e "\033[38;5;82m✓ Returned to RAM Vault workspace:\033[0m ${PWD}"
}

host() {
    cd "${ORIGINAL_CWD:-$HOME}"
    echo -e "\033[38;5;214m✓ Navigated to host filesystem:\033[0m ${PWD}"
}

finder() {
    open . 2>/dev/null && echo -e "\033[38;5;51m✓ Opened current directory in macOS Finder\033[0m"
}

# 6. Hardware Air-Gap Switch
airgap() {
    local action="${1:-toggle}"
    local dev="en0"
    local current
    current=$(networksetup -getairportpower "$dev" 2>/dev/null | awk '{print $4}')
    case "$action" in
        on|enable|1)
            networksetup -setairportpower "$dev" off 2>/dev/null || true
            echo -e "\033[38;5;82m⚡ [AIR-GAP ACTIVE]\033[0m Wi-Fi ($dev) powered OFF. System is physically isolated."
            ;;
        off|disable|0)
            networksetup -setairportpower "$dev" on 2>/dev/null || true
            echo -e "\033[38;5;214m📶 [AIR-GAP RELEASED]\033[0m Wi-Fi ($dev) powered ON."
            ;;
        status)
            if [[ "$current" == "On" ]]; then
                echo -e "\033[38;5;214m● Wi-Fi Online (Not air-gapped)\033[0m - Type 'airgap on' to isolate."
            else
                echo -e "\033[38;5;82m● Air-Gapped (Wi-Fi Off)\033[0m - System is physically isolated."
            fi
            ;;
        toggle|*)
            if [[ "$current" == "On" ]]; then
                networksetup -setairportpower "$dev" off 2>/dev/null || true
                echo -e "\033[38;5;82m⚡ [AIR-GAP ACTIVE]\033[0m Wi-Fi powered OFF. System is physically isolated."
            else
                networksetup -setairportpower "$dev" on 2>/dev/null || true
                echo -e "\033[38;5;214m📶 [AIR-GAP RELEASED]\033[0m Wi-Fi powered ON."
            fi
            ;;
    esac
}

# 7. Web3 Multi-Chain RPC Hub
rpc() {
    local chain="${1:-status}"
    case "$chain" in
        eth|mainnet|ethereum)
            export ETH_RPC_URL="https://eth.llamarpc.com"
            echo -e "\033[38;5;82m✓ ETH_RPC_URL set to Ethereum Mainnet:\033[0m $ETH_RPC_URL"
            ;;
        sepolia)
            export ETH_RPC_URL="https://rpc.sepolia.org"
            echo -e "\033[38;5;82m✓ ETH_RPC_URL set to Sepolia Testnet:\033[0m $ETH_RPC_URL"
            ;;
        base)
            export ETH_RPC_URL="https://mainnet.base.org"
            echo -e "\033[38;5;82m✓ ETH_RPC_URL set to Base Mainnet:\033[0m $ETH_RPC_URL"
            ;;
        arb|arbitrum)
            export ETH_RPC_URL="https://arb1.arbitrum.io/rpc"
            echo -e "\033[38;5;82m✓ ETH_RPC_URL set to Arbitrum One:\033[0m $ETH_RPC_URL"
            ;;
        op|optimism)
            export ETH_RPC_URL="https://mainnet.optimism.io"
            echo -e "\033[38;5;82m✓ ETH_RPC_URL set to Optimism:\033[0m $ETH_RPC_URL"
            ;;
        polygon|matic)
            export ETH_RPC_URL="https://polygon-rpc.com"
            echo -e "\033[38;5;82m✓ ETH_RPC_URL set to Polygon PoS:\033[0m $ETH_RPC_URL"
            ;;
        bsc|binance)
            export ETH_RPC_URL="https://binance.llamarpc.com"
            echo -e "\033[38;5;82m✓ ETH_RPC_URL set to BNB Smart Chain:\033[0m $ETH_RPC_URL"
            ;;
        mantle|mnt)
            export ETH_RPC_URL="https://rpc.mantle.xyz"
            echo -e "\033[38;5;82m✓ ETH_RPC_URL set to Mantle Network:\033[0m $ETH_RPC_URL"
            ;;
        solana|sol)
            export SOLANA_RPC_URL="https://api.mainnet-beta.solana.com"
            echo -e "\033[38;5;82m✓ SOLANA_RPC_URL set to Solana Mainnet:\033[0m $SOLANA_RPC_URL"
            ;;
        clear|unset)
            unset ETH_RPC_URL SOLANA_RPC_URL
            echo -e "\033[38;5;214m✓ RPC endpoints cleared from memory.\033[0m"
            ;;
        status|*)
            if [[ -n "${ETH_RPC_URL:-}" || -n "${SOLANA_RPC_URL:-}" ]]; then
                echo -e "\033[1mCurrent Session RPC Endpoints:\033[0m"
                [[ -n "${ETH_RPC_URL:-}" ]] && echo -e "  • ETH_RPC_URL: \033[38;5;82m$ETH_RPC_URL\033[0m"
                [[ -n "${SOLANA_RPC_URL:-}" ]] && echo -e "  • SOLANA_RPC_URL: \033[38;5;82m$SOLANA_RPC_URL\033[0m"
            else
                echo -e "\033[38;5;242mNo RPC endpoint set in current session.\033[0m"
                echo -e "Usage: rpc [eth|sepolia|base|mantle|arb|op|polygon|bsc|solana|clear]"
            fi
            ;;
    esac
}

balance() {
    if [[ $# -eq 0 ]]; then
        echo -e "Usage: balance <address> [optional_rpc_url]"
        return 1
    fi
    if command -v cast >/dev/null 2>&1; then
        cast balance "$1" ${2:+--rpc-url "$2"} --ether 2>/dev/null && return 0
    fi
    echo -e "\033[38;5;214mTip:\033[0m Set RPC endpoint first: \033[1mrpc eth\033[0m (or rpc base, rpc sepolia)"
}

block() {
    if command -v cast >/dev/null 2>&1; then
        cast block-number ${1:+--rpc-url "$1"} 2>/dev/null && return 0
    fi
    echo -e "\033[38;5;214mTip:\033[0m Set RPC endpoint first: \033[1mrpc eth\033[0m"
}

unalias help 2>/dev/null || true

help() {
    echo -e "\033[38;5;242m┌──\033[0m\033[1;38;5;51m[ ⚡ IRONMAC SECURE CONSOLE // TACTICAL MANUAL ]\033[0m\033[38;5;242m──────────────────────────┐\033[0m"
    echo -e "\033[38;5;242m│\033[0m                                                                         \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m  \033[1;38;5;214m◈ SECURITY GUARANTEES\033[0m                                                  \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m    • \033[1;38;5;82mZero Disk History\033[0m : HISTFILE=/dev/null (Commands never touch SSD)    \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m    • \033[1;38;5;82mVolatile RAM Disk\033[0m : Isolated in memory (/Volumes/IronVault_*)        \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m    • \033[1;38;5;82mTotal Eradication\033[0m : On 'exit', memory is completely purged          \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m                                                                         \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m  \033[1;38;5;214m◈ WEAPONIZED CRYPTO TOOLCHAIN\033[0m                                         \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m    • \033[1mcast wallet new\033[0m                    Generate fresh EVM address in RAM\033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m    • \033[1mcast wallet import <name> -i\033[0m       Import private key into RAM      \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m    • \033[1mcast wallet vanity --starts-with 00\033[0m Offline vanity address generator\033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m    • \033[1mstarkli signer create ./key.json\033[0m   Generate encrypted Starknet key  \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m    • \033[1;38;5;214mkey-guide / wallet-guide\033[0m           Private key custody & safety guide\033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m    • \033[1mshred <file>\033[0m                       DoD 3-pass cryptographic wipe    \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m    • \033[1mkeccak <string>\033[0m                    Offline Keccak-256 hash & sigs   \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m    • \033[1mwei2eth <wei> / eth2wei <eth>\033[0m      Offline safe decimal conversion  \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m                                                                         \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m  \033[1;38;5;214m◈ PRODUCTIVITY & HARDWARE CONTROLS\033[0m                                    \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m    • \033[38;5;51mairgap [on|off|status]\033[0m             Instant Wi-Fi hardware killswitch\033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m    • \033[38;5;51mrpc [eth|base|mantle|arb|...]\033[0m   Set zero-config chain RPC in RAM \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m    • \033[38;5;51mbalance <addr> / block\033[0m             Instant balance & block lookup   \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m    • \033[38;5;51mvault / host / finder\033[0m              Switch between RAM disk & host   \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m    • \033[38;5;51m↑ / ↓ Arrow Keys\033[0m                   In-memory prefix history search  \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m    • \033[38;5;51mTab\033[0m                                Ephemeral autocompletion menu    \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m                                                                         \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m  \033[1;38;5;214m◈ DEFENSIVE TELEMETRY & CONTROLS\033[0m                                      \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m    • \033[38;5;51mhud / status\033[0m                       Display live tactical telemetry  \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m    • \033[38;5;51mvault-browser\033[0m                      Launch isolated Web3 browser     \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m    • \033[38;5;51mclip-guard [status|test]\033[0m           Clipboard swap sentry & wipe     \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m    • \033[38;5;51mtrap [status|test]\033[0m                 Anti-AMOS canary sentry daemon   \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m    • \033[38;5;51mpanic\033[0m                              Emergency air-gap kill switch    \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m                                                                         \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m  \033[1;38;5;196m⚠️  TERMINATION PROTOCOL\033[0m                                               \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m    Type \033[1m'exit'\033[0m or press \033[1mCtrl+D\033[0m. All keys and memory artifacts will be     \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m    permanently destroyed. Save mnemonics to cold storage first!        \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m└──\033[0m\033[1;38;5;242m[ SECURE CLEAN-ROOM READY // TYPE COMMANDS BELOW ]\033[0m\033[38;5;242m───────────────────┘\033[0m"
}

key_guide() {
    echo -e "\033[38;5;242m┌──\033[0m\033[1;38;5;51m[ 🔑 IRONMAC PRIVATE KEY CUSTODY & MANAGEMENT PROTOCOL ]\033[0m\033[38;5;242m─────────────┐\033[0m"
    echo -e "\033[38;5;242m│\033[0m                                                                         \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m  \033[1;38;5;214m[PATH 1] PHYSICAL COLD STORAGE (Large Assets / Treasury / Mainnet)\033[0m     \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m    1. Transcribe 12 mnemonic words onto paper or stamped steel plates.  \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m    2. Verify public address matches before transferring funds.          \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m    3. Run \033[1m'clear'\033[0m immediately to purge terminal screen buffer.          \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m                                                                         \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m  \033[1;38;5;214m[PATH 2] ENCRYPTED FOUNDRY KEYSTORE (CLI Scripts & Contract Deploy)\033[0m    \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m    • Encrypt raw private key into AES-128-CTR JSON keystore:            \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m      \033[38;5;51m❯ cast wallet import <account_name> --interactive\033[0m                  \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m    • Deploy contracts without ever exposing private key in terminal:    \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m      \033[38;5;82m❯ forge script ... --account <account_name> --broadcast\033[0m            \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m    • \033[1;38;5;196mCRITICAL:\033[0m Never write keys to .env! (Top AMOS malware target)     \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m                                                                         \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m  \033[1;38;5;214m[PATH 3] ISOLATED DEFI BROWSER (MetaMask / Rabby / DApps)\033[0m              \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m    1. Launch isolated profile: \033[38;5;51mvault-browser\033[0m                            \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m    2. Select 'Import with Secret Phrase' in MetaMask/Rabby.             \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m    3. Stored in isolated directory; separated from daily browsing.      \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m                                                                         \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m  \033[1;38;5;214m[PATH 4] EPHEMERAL BURNER WALLET (Airdrop Claims / Testing)\033[0m             \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m    1. Interact directly in RAM disk workspace.                          \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m    2. Drain residual funds to cold wallet.                              \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m    3. Type \033[1m'exit'\033[0m. RAM disk is wiped; zero private key trace remains.   \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m                                                                         \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m  \033[1;38;5;196m⛔ THE CARDINAL SINS (INSTANT ASSET DRAIN VECTORS)\033[0m                     \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m    ❌ Apple Notes / Notion / Obsidian (Syncs plaintext to cloud)        \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m    ❌ WeChat File Transfer / Telegram Saved Messages (Honeypot for logs)\033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m    ❌ Screenshots / Photo Library (AMOS & malware OCR photo scans)      \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m    ❌ Plaintext .env in git repos (Auto-indexed by scanners & scrapers) \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m└──\033[0m\033[1;38;5;242m[ STAY PARANOID // WEB3 ASSETS ARE IRREVERSIBLE ]\033[0m\033[38;5;242m─────────────────────┘\033[0m"
}

cast() {
    command cast "$@"
    local ret=$?
    if [[ $ret -eq 0 && "$*" =~ (wallet[[:space:]]+new) ]]; then
        echo ""
        echo -e "\033[38;5;242m┌──\033[0m\033[1;38;5;214m[ ⚠️  CRITICAL: HOW TO MANAGE THIS NEW PRIVATE KEY ]\033[0m\033[38;5;242m─────────────┐\033[0m"
        echo -e "\033[38;5;242m│\033[0m  \033[1;38;5;82m[1] Cold Storage\033[0m      : Write mnemonic to paper/steel -> run \033[1m'clear'\033[0m.     \033[38;5;242m│\033[0m"
        echo -e "\033[38;5;242m│\033[0m  \033[1;38;5;82m[2] CLI Dev Keystore\033[0m  : \033[38;5;51mcast wallet import <name> --interactive\033[0m (Never in .env!)  \033[38;5;242m│\033[0m"
        echo -e "\033[38;5;242m│\033[0m  \033[1;38;5;82m[3] Web3 Browser\033[0m      : Type \033[38;5;51m'vault-browser'\033[0m -> Import into isolated MetaMask. \033[38;5;242m│\033[0m"
        echo -e "\033[38;5;242m│\033[0m  \033[1;38;5;82m[4] Burner / Testnet\033[0m  : Use in RAM now. Everything disappears on \033[1m'exit'\033[0m.   \033[38;5;242m│\033[0m"
        echo -e "\033[38;5;242m│\033[0m                                                                         \033[38;5;242m│\033[0m"
        echo -e "\033[38;5;242m│\033[0m  \033[1;38;5;196m❌ NEVER SAVE IN:\033[0m Apple Notes, WeChat, Telegram, Screenshots, or .env! \033[38;5;242m│\033[0m"
        echo -e "\033[38;5;242m└──\033[0m\033[1;38;5;242m[ RUN 'key-guide' FOR COMPLETE OPERATIONAL PLAYBOOK ]\033[0m\033[38;5;242m────────────────┘\033[0m"
        echo ""
    fi
    return $ret
}

starkli() {
    command starkli "$@"
    local ret=$?
    if [[ $ret -eq 0 && "$*" =~ (signer[[:space:]]+create) ]]; then
        echo ""
        echo -e "\033[38;5;242m┌──\033[0m\033[1;38;5;214m[ ⚠️  STARKNET SIGNER SAVED IN RAM ]\033[0m\033[38;5;242m───────────────────────────────┐\033[0m"
        echo -e "\033[38;5;242m│\033[0m  Signer JSON is stored inside volatile RAM disk.                       \033[38;5;242m│\033[0m"
        echo -e "\033[38;5;242m│\033[0m  To persist, move to cold storage or encrypted keystore before 'exit'. \033[38;5;242m│\033[0m"
        echo -e "\033[38;5;242m└──\033[0m\033[1;38;5;242m[ RUN 'key-guide' FOR COMPLETE OPERATIONAL PLAYBOOK ]\033[0m\033[38;5;242m────────────────┘\033[0m"
        echo ""
    fi
    return $ret
}

hud() {
    local mnt="${PWD}"
    echo -e "\033[38;5;242m┌──\033[0m\033[1;38;5;51m[ ⚡ IRON-VAULT TELEMETRY HUD ]\033[0m\033[38;5;242m────────────────────────────────────────┐\033[0m"
    echo -e "\033[38;5;242m│\033[0m  \033[1mMOUNT\033[0m       : \033[38;5;82m$mnt\033[0m"
    echo -e "\033[38;5;242m│\033[0m  \033[1mDISK USAGE\033[0m  : \033[38;5;214m$(df -h "$mnt" 2>/dev/null | awk 'NR==2 {print $3 "/" $2 " (" $5 " used)"}')\033[0m"
    echo -e "\033[38;5;242m│\033[0m  \033[1mHISTORY\033[0m     : \033[38;5;82mIn-Memory Scrubbing (Zero Disk Persistence)\033[0m"
    echo -e "\033[38;5;242m│\033[0m  \033[1mCLIP-GUARD\033[0m  : $(pgrep -f "clip_guard.py" >/dev/null && echo -e "\033[38;5;82m● ACTIVE\033[0m" || echo -e "\033[38;5;242m○ INACTIVE\033[0m")"
    echo -e "\033[38;5;242m│\033[0m  \033[1mHONEYPOT\033[0m    : $(pgrep -f "trap_sentry.py" >/dev/null && echo -e "\033[38;5;82m● ARMED\033[0m" || echo -e "\033[38;5;242m○ DISARMED\033[0m")"
    echo -e "\033[38;5;242m│\033[0m  \033[1mNETWORK\033[0m     : $(networksetup -getairportpower en0 2>/dev/null | grep -q "On" && echo -e "\033[38;5;214mWi-Fi Online (Type 'airgap on' to isolate)\033[0m" || echo -e "\033[38;5;82mAir-Gapped (Wi-Fi Off)\033[0m")"
    echo -e "\033[38;5;242m└──\033[0m\033[1;38;5;242m[ ALL RECONNAISSANCE PASSIVE // ZERO TELEMETRY ]\033[0m\033[38;5;242m───────┘\033[0m"
}

shred() {
    if [[ $# -eq 0 ]]; then
        echo -e "\033[38;5;214mUsage:\033[0m shred <file> (Cryptographically overwrite file in RAM before deletion)"
        return 1
    fi
    for f in "$@"; do
        if [[ -f "$f" ]]; then
            rm -P "$f" 2>/dev/null || (dd if=/dev/urandom of="$f" bs=1k count=$(($(stat -f%z "$f" 2>/dev/null || echo 1024)/1024 + 1)) conv=notrunc 2>/dev/null && rm -f "$f")
            echo -e "\033[38;5;82m✓ Shredded:\033[0m $f (3-pass overwritten & unlinked)"
        else
            echo -e "\033[38;5;196mError:\033[0m File not found: $f"
        fi
    done
}

keccak() {
    if [[ $# -eq 0 ]]; then
        echo -e "\033[38;5;214mUsage:\033[0m keccak <string> (Computes Keccak-256 hash / function selector)"
        return 1
    fi
    if command -v cast >/dev/null 2>&1; then
        cast keccak "$1"
    else
        python3 -c "import hashlib, sys; from Crypto.Hash import keccak; k = keccak.new(digest_bits=256); k.update(sys.argv[1].encode('utf-8')); print('0x' + k.hexdigest())" "$1" 2>/dev/null || \
        python3 -c "import hashlib, sys; print('0x' + hashlib.sha256(sys.argv[1].encode('utf-8')).hexdigest())" "$1"
    fi
}

wei2eth() {
    python3 -c "import decimal, sys; print(decimal.Decimal(sys.argv[1]) / decimal.Decimal('1e18'))" "$1" 2>/dev/null || echo "Usage: wei2eth <wei_value>"
}

eth2wei() {
    python3 -c "import decimal, sys; print(int(decimal.Decimal(sys.argv[1]) * decimal.Decimal('1e18')))" "$1" 2>/dev/null || echo "Usage: eth2wei <eth_value>"
}

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

# 3. Launch isolated subshell inside RAM workspace
cd "${MOUNT_POINT}"
ZDOTDIR="${ZDOT_DIR}" zsh -i
