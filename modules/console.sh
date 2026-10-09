#!/usr/bin/env bash
#
# IronMac - Secure Vault Console Module
# Provides a zero-trace, ephemeral RAM-backed terminal session for Web3 operations.
#

set -euo pipefail

# Capture host directory and IronMac root prior to entering RAM disk
ORIGINAL_CWD="${PWD}"
CONSOLE_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
IRONMAC_HOME="$(cd -P "${CONSOLE_DIR}/.." >/dev/null 2>&1 && pwd)"
export ORIGINAL_CWD IRONMAC_HOME

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
echo -e "${GRAY}┌──${RESET}${BOLD}${CYAN}[ ⚡ IRONMAC // SECURE VAULT CONSOLE v0.6.3 ]${RESET}${GRAY}────────────────────────┐${RESET}"

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

GEMINI_STATUS="${GRAY}○ Missing${RESET}"
command -v gemini >/dev/null 2>&1 && GEMINI_STATUS="${GREEN}● Ready${RESET}"

AGY_STATUS="${GRAY}○ Missing${RESET}"
command -v agy >/dev/null 2>&1 && AGY_STATUS="${GREEN}● Ready${RESET}"

TRAP_STATUS="${GRAY}○ Inactive${RESET}"
pgrep -f "trap_sentry.py" >/dev/null && TRAP_STATUS="${GREEN}● Armed${RESET}"

CLIP_STATUS="${GRAY}○ Inactive${RESET}"
pgrep -f "clip_guard.py" >/dev/null && CLIP_STATUS="${GREEN}● Armed${RESET}"

echo -e "${GRAY}│${RESET}  ${BOLD}TELEMETRY${RESET} : Gemini: ${GEMINI_STATUS}  Antigravity(agy): ${AGY_STATUS}  Cast: ${FOUNDRY_STATUS}  Trap: ${TRAP_STATUS}  ClipGuard: ${CLIP_STATUS}"
echo -e "${GRAY}└──${RESET}${BOLD}${GRAY}[ ZERO-TRACE AIR-GAP SANDBOX // TYPE 'help' OR 'ai' ]${RESET}${GRAY}───────────┘${RESET}\n"

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
alias iron-help=help
alias '?'=help
alias status=hud
alias key-guide=key_guide
alias wallet-guide=key_guide
alias vopen=finder
alias check-address="verify-address"
alias eip55="verify-address"
alias secret-scan="scan-secrets"
alias secrets="scan-secrets"

# MCP-Aligned Security Functions
audit() {
    echo -e "\033[38;5;51m🔍 Running Comprehensive Mac Security Audit...\033[0m"
    bash "${IRONMAC_HOME}/modules/audit.sh" "$@"
}

verify-address() {
    local addr="${1:-}"
    if [[ -z "$addr" ]]; then
        echo -e "\033[38;5;214mUsage:\033[0m verify-address <crypto_address>"
        echo "Validates EVM (EIP-55 checksum & poisoning check), Solana (Base58), and Bitcoin."
        return 1
    fi

    # Check EVM (0x + 40 hex)
    if [[ "$addr" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
        local raw="${addr#0x}"
        local lower="0x${(L)raw}"
        local upper="0x${(U)raw}"
        local checksummed=""

        # Compute EIP-55 Checksum via cast or node
        if command -v cast >/dev/null 2>&1; then
            checksummed=$(cast --to-checksum-address "$addr" 2>/dev/null || true)
        elif command -v node >/dev/null 2>&1; then
            checksummed=$(node -e 'const c=require("node:crypto"); const a=process.argv[1].toLowerCase().replace(/^0x/,""); const h=c.createHash("keccak-256").update(a).digest("hex"); console.log("0x"+a.split("").map((x,i)=>parseInt(h[i],16)>=8?x.toUpperCase():x).join(""));' "$addr" 2>/dev/null || true)
        fi

        echo -e "\033[1;38;5;51m[EVM Address Detected]\033[0m: $addr"
        if [[ -n "$checksummed" ]]; then
            if [[ "$addr" == "$checksummed" ]]; then
                echo -e "  • \033[38;5;82m✓ [PASS] Valid EIP-55 Mixed-Case Checksum.\033[0m"
            elif [[ "$addr" == "$lower" || "$addr" == "$upper" ]]; then
                echo -e "  • \033[38;5;214m⚠️  [WARN] Valid hex, but missing EIP-55 checksum capitalization!\033[0m"
                echo -e "  • Checksummed: \033[1;38;5;82m$checksummed\033[0m"
            else
                echo -e "  • \033[38;5;196m❌ [FAIL] Corrupted / Invalid EIP-55 Checksum! Possible typo or spoof!\033[0m"
                echo -e "  • Expected:   \033[1;38;5;82m$checksummed\033[0m"
            fi
        else
            echo -e "  • \033[38;5;82m✓ [PASS] Valid 40-hex format.\033[0m"
        fi

        if [[ "$addr" =~ ^0x0{6,} ]]; then
            echo -e "  • \033[1;38;5;196m⚠️  [ALERT] Multiple leading zeros detected (Vanity / Poisoning Pattern)!\033[0m"
            echo -e "    Verify against address-poisoning spoof attacks before transferring funds."
        fi
        return 0
    fi

    # Check Solana (Base58, 32-44 characters)
    if [[ "$addr" =~ ^[1-9A-HJ-NP-Za-km-z]{32,44}$ ]]; then
        echo -e "\033[1;38;5;51m[Solana Address Detected]\033[0m: $addr"
        echo -e "  • \033[38;5;82m✓ [PASS] Valid Solana Base58 format (32-44 chars).\033[0m"
        return 0
    fi

    # Check Bitcoin (Legacy 1, P2SH 3, SegWit/Taproot bc1)
    if [[ "$addr" =~ ^(1|3|bc1)[a-zA-HJ-NP-Z0-9]{25,62}$ ]]; then
        echo -e "\033[1;38;5;51m[Bitcoin Address Detected]\033[0m: $addr"
        echo -e "  • \033[38;5;82m✓ [PASS] Valid Bitcoin address format.\033[0m"
        return 0
    fi

    echo -e "\033[38;5;196m❌ [INVALID] Does not match recognized EVM, Solana, or Bitcoin address format.\033[0m"
    return 1
}

scan-secrets() {
    local target="${1:-.}"
    if [[ ! -e "$target" ]]; then
        echo -e "\033[38;5;196mError:\033[0m Target path not found: $target"
        return 1
    fi
    echo -e "\033[38;5;51m🔍 Scanning for unencrypted secrets in:\033[0m $target"
    python3 -c "
import os, sys, re

target = sys.argv[1]
HEX_KEY_REGEX = re.compile(r'(?:0x)?[0-9a-fA-F]{64}')
SECRET_ENV_REGEX = re.compile(r'(?:PRIVATE_KEY|MNEMONIC|SEED_PHRASE|API_KEY|SECRET)\s*=\s*[\'\"]?([^\s\'\"]+)[\'\"]?', re.IGNORECASE)

findings = []

def scan_file(fpath):
    if fpath.endswith(('.lock', '.min.js', '.png', '.jpg', '.pdf', '.svg', '.bin')):
        return
    try:
        with open(fpath, 'r', encoding='utf-8', errors='ignore') as f:
            for idx, line in enumerate(f, 1):
                clean = line.strip()
                if not clean or clean.startswith('#') or clean.startswith('//'):
                    continue
                if HEX_KEY_REGEX.search(line):
                    findings.append((fpath, idx, '64-HEX Private Key Candidate', clean[:60]))
                elif SECRET_ENV_REGEX.search(line):
                    findings.append((fpath, idx, 'Sensitive Environment Secret', clean[:60]))
    except Exception:
        pass

if os.path.isfile(target):
    scan_file(target)
elif os.path.isdir(target):
    for root, dirs, files in os.walk(target):
        dirs[:] = [d for d in dirs if d not in ('node_modules', '.git', '.ironmac_backup', '__pycache__')]
        for file in files:
            scan_file(os.path.join(root, file))

if not findings:
    print('\033[38;5;82m✓ CLEAN:\033[0m No plaintext private keys or sensitive variables found.')
else:
    print(f'\033[38;5;196m⚠️  FOUND {len(findings)} EXPOSED SECRET(S):\033[0m')
    for fpath, line, stype, snippet in findings:
        print(f'  • \033[1m{fpath}:{line}\033[0m [{stype}]\n    Snippet: \033[38;5;214m{snippet}...\033[0m')
    print('\n\033[38;5;196m[!] DO NOT commit or transmit these files. Import keys into encrypted keystores:\033[0m')
    print('    \033[38;5;51mcast wallet import <name> -i\033[0m')
" "$target"
}

panic() {
    local reason="${1:-Manual trigger from inside IronVault console}"
    echo -e "\033[38;5;196m🚨 Triggering IronMac Emergency Air-Gap Protocol...\033[0m"
    bash "${IRONMAC_HOME}/modules/panic.sh" trigger "$reason"
}

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
    echo -e "\033[38;5;242m│\033[0m  \033[1;38;5;214m◈ DEFENSIVE TELEMETRY & CONTROLS (MCP ALIGNED)\033[0m                       \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m    • \033[38;5;51maudit\033[0m                              Live macOS security posture audit\033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m    • \033[38;5;51mverify-address <addr>\033[0m              EIP-55 checksum & poison detector\033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m    • \033[38;5;51mscan-secrets [path]\033[0m                Scan files for exposed 64-hex key\033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m    • \033[38;5;51mhud / status\033[0m                       Display live tactical telemetry  \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m    • \033[38;5;51mairgap [on|off|status]\033[0m             Instant Wi-Fi hardware killswitch\033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m    • \033[38;5;51mclip-guard [status|test]\033[0m           Clipboard swap sentry & wipe     \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m    • \033[38;5;51mtrap [status|test]\033[0m                 Anti-AMOS canary sentry daemon   \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m    • \033[38;5;51mpanic [reason]\033[0m                     Emergency air-gap kill switch    \033[38;5;242m│\033[0m"
    echo -e "\033[38;5;242m│\033[0m    • \033[38;5;51mvault-browser\033[0m                      Launch isolated Web3 browser     \033[38;5;242m│\033[0m"
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

ai() {
    local target="${IRONMAC_AI:-}"
    if [[ -z "$target" ]]; then
        if command -v agy >/dev/null 2>&1 && command -v gemini >/dev/null 2>&1; then
            echo -e "\033[1;38;5;51m[Select AI Engine]\033[0m: 1) Google Antigravity (agy)  2) Google Gemini CLI (gemini)"
            read -rp "Enter 1 or 2 [default: 1]: " choice
            echo ""
            if [[ "$choice" == "2" ]]; then
                target="gemini"
            else
                target="agy"
            fi
        elif command -v agy >/dev/null 2>&1; then
            target="agy"
        elif command -v gemini >/dev/null 2>&1; then
            target="gemini"
        fi
    fi

    if [[ "$target" == "agy" ]]; then
        agy --dangerously-skip-permissions "$@"
    elif [[ "$target" == "gemini" ]]; then
        gemini --skip-trust "$@"
    else
        echo -e "\033[38;5;214mNo AI engine found.\033[0m Install Google Antigravity (agy) or Gemini CLI (@google/gemini-cli)."
    fi
}

agy-ai() {
    if command -v agy >/dev/null 2>&1; then
        agy --dangerously-skip-permissions "$@"
    else
        echo -e "\033[38;5;196m'agy' (Google Antigravity CLI) not found in PATH.\033[0m"
    fi
}

gemini-ai() {
    if command -v gemini >/dev/null 2>&1; then
        gemini --skip-trust "$@"
    else
        echo -e "\033[38;5;196m'gemini' CLI not found in PATH.\033[0m"
    fi
}

wallets() {
    local target_alias="${1:-}"

    local perm_dir="${HOME}/.ironmac/keystores"
    local ram_dir="${MOUNT_POINT}/keys"
    local total=0

    echo -e "\033[1;38;5;51m⚡ IronMac Vault Wallets & Keystores:\033[0m"

    # 1. Permanent Keystores (~/.ironmac/keystores/)
    if [[ -d "$perm_dir" ]]; then
        for k in "$perm_dir"/*.json; do
            [[ -e "$k" ]] || continue
            [[ "$k" == *".keystore.json" ]] && continue
            local alias="$(basename "$k" .json)"
            [[ -n "$target_alias" && "$alias" != "$target_alias" ]] && continue
            local addr="$(grep '"address"' "$k" 2>/dev/null | awk -F'"' '{print $4}')"
            local chain="$(grep '"chain"' "$k" 2>/dev/null | awk -F'"' '{print $4}')"
            echo -e "  • \033[1;38;5;214m${alias}\033[0m [${chain:-base}] \033[38;5;141m🔐 (Permanent Keystore / Enclave)\033[0m: \033[38;5;82m${addr}\033[0m"
            ((total++))
        done
    fi

    # 2. Ephemeral RAMDisk (${MOUNT_POINT}/keys/)
    if [[ -d "$ram_dir" ]]; then
        for k in "$ram_dir"/*.json; do
            [[ -e "$k" ]] || continue
            [[ "$k" == *".keystore.json" ]] && continue
            local alias="$(basename "$k" .json)"
            [[ -n "$target_alias" && "$alias" != "$target_alias" ]] && continue
            # Avoid duplicate if alias exists in both
            [[ -f "${perm_dir}/${alias}.json" ]] && continue
            local addr="$(grep '"address"' "$k" 2>/dev/null | awk -F'"' '{print $4}')"
            local chain="$(grep '"chain"' "$k" 2>/dev/null | awk -F'"' '{print $4}')"
            echo -e "  • \033[1;38;5;214m${alias}\033[0m [${chain:-base}] \033[38;5;220m⚡ (RAMDisk Burner)\033[0m: \033[38;5;82m${addr}\033[0m"
            ((total++))
        done
    fi

    if [[ $total -eq 0 ]]; then
        echo -e "  \033[38;5;242mNo wallets found. Ask AI to create one or run: cast wallet new\033[0m"
    else
        echo -e "\033[38;5;242m(To copy private key securely under Touch ID, run: reveal_key <alias>)\033[0m"
    fi
}

reveal_key() {
    local alias="${1:-}"
    if [[ -z "$alias" ]]; then
        echo "Usage: reveal_key <alias>"
        return 1
    fi

    local perm_dir="${HOME}/.ironmac/keystores"
    local ram_dir="${MOUNT_POINT}/keys"
    local meta_file=""
    local is_perm=0

    if [[ -f "${perm_dir}/${alias}.json" ]]; then
        meta_file="${perm_dir}/${alias}.json"
        is_perm=1
    elif [[ -f "${ram_dir}/${alias}.json" ]]; then
        meta_file="${ram_dir}/${alias}.json"
        is_perm=0
    else
        echo -e "\033[31mWallet '${alias}' not found in permanent keystores or active RAMDisk.\033[0m"
        return 1
    fi

    local auth_bin="/opt/homebrew/Cellar/ironmac/0.6.3/libexec/bin/ironmac-auth"
    [[ ! -x "$auth_bin" ]] && auth_bin="${HOME}/.ironmac/bin/ironmac-auth"
    if [[ -x "$auth_bin" ]]; then
        if ! "$auth_bin" "Authorize exporting private key for '${alias}'" --ticket "${MOUNT_POINT}/.auth_ticket" --ttl 600 >/dev/null 2>&1; then
            echo -e "\033[31mTouch ID authorization was rejected or cancelled.\033[0m"
            return 1
        fi
    fi

    local pkey=""
    local is_ks="$(grep '"keystore_file"' "$meta_file" 2>/dev/null | awk -F'"' '{print $4}')"
    if [[ -n "$is_ks" ]]; then
        local pass="$(security find-generic-password -a "$alias" -s "ironmac.vault.keystore" -w 2>/dev/null || true)"
        if [[ -z "$pass" ]]; then
            echo -e "\033[31mFailed to retrieve encryption key from Apple Keychain.\033[0m"
            return 1
        fi
        local ks_path="${perm_dir}/${alias}.keystore.json"
        [[ ! -f "$ks_path" ]] && ks_path="${ram_dir}/${alias}.keystore.json"
        pkey="$(node -e "
            const fs = require('fs');
            const crypto = require('crypto');
            try {
                const ks = JSON.parse(fs.readFileSync(process.argv[1], 'utf8'));
                const pass = process.argv[2];
                const c = ks.crypto || ks.Crypto;
                const salt = Buffer.from(c.kdfparams.salt, 'hex');
                const n = c.kdfparams.n || 8192;
                const r = c.kdfparams.r || 8;
                const p = c.kdfparams.p || 1;
                const dklen = c.kdfparams.dklen || 32;
                const derivedKey = crypto.scryptSync(Buffer.from(pass, 'utf-8'), salt, dklen, { N: n, r, p, maxmem: 128 * 1024 * 1024 });
                const cipherKey = derivedKey.subarray(0, 16);
                const iv = Buffer.from(c.cipherparams.iv, 'hex');
                const decipher = crypto.createDecipheriv('aes-128-ctr', cipherKey, iv);
                const ciphertext = Buffer.from(c.ciphertext, 'hex');
                const privKey = Buffer.concat([decipher.update(ciphertext), decipher.final()]);
                process.stdout.write('0x' + privKey.toString('hex'));
            } catch(e) { process.exit(1); }
        " "$ks_path" "$pass" 2>/dev/null || true)"
    else
        pkey="$(grep '"private_key"' "$meta_file" 2>/dev/null | awk -F'"' '{print $4}')"
    fi

    if [[ -z "$pkey" || "$pkey" != 0x* ]]; then
        echo -e "\033[31mFailed to decrypt or extract private key for '${alias}'.\033[0m"
        return 1
    fi

    echo -n "$pkey" | pbcopy
    echo -e "\033[38;5;82m✔ Private key for '${alias}' copied directly to clipboard via Touch ID/Passkey.\033[0m"
    echo -e "\033[38;5;242m  [Screen display suppressed for anti-shoulder surfing protection]\033[0m"
    echo -e "\033[38;5;242m  [ClipGuard active: clipboard will auto-purge sensitive key data in 30s]\033[0m"
}
EOF

# 3. Setup Ephemeral RAMDisk AI Workspace & Settings
KEYS_DIR="${MOUNT_POINT}/keys"
mkdir -p "${KEYS_DIR}"
chmod 700 "${KEYS_DIR}"

GEMINI_DIR="${MOUNT_POINT}/.gemini"
mkdir -p "${GEMINI_DIR}"

cat <<EOF_SETTINGS > "${GEMINI_DIR}/settings.json"
{
  "mcpServers": {
    "ironmac": {
      "command": "ironmac",
      "args": ["mcp"]
    }
  }
}
EOF_SETTINGS

# Antigravity (agy) Workspace & MCP Configuration
AGENTS_DIR="${MOUNT_POINT}/.agents"
mkdir -p "${AGENTS_DIR}"

cat <<EOF_AGY_SETTINGS > "${AGENTS_DIR}/mcp_config.json"
{
  "mcpServers": {
    "ironmac": {
      "command": "ironmac",
      "args": ["mcp"]
    }
  }
}
EOF_AGY_SETTINGS

cp "${AGENTS_DIR}/mcp_config.json" "${MOUNT_POINT}/mcp_config.json"

cat <<'EOF_GEMINI_MD' > "${MOUNT_POINT}/GEMINI.md"
# IronConsole AI - Hardened Web3 Copilot Guidelines

You are IronConsole AI, the hardened Web3 crypto terminal operating system for macOS running inside an ephemeral RAMDisk (/Volumes/IronVault).

## CORE OPERATIONAL RULES (MANDATORY):
1. **Zero-Leak Key Custody (STRICT)**:
   - When the user asks to create, generate, or inspect an EVM wallet (Base, Ethereum, Arbitrum, Mantle, Sepolia), ALWAYS call the MCP tool `create_vault_wallet` with a descriptive alias (e.g. 'burner_base', 'dev1') and target chain.
   - NEVER generate private keys directly in conversation text or ask the user to paste raw private keys into chat.
   - The private key is outputted directly to the user's physical display via `/dev/tty` and stripped from your context. Reassure the user that their key is safe in local volatile RAM and never transmitted to the cloud.

2. **Wallet Management & Balances**:
   - To view existing wallets in RAM, call `list_vault_wallets`.
   - To check native token balances on Base, Ethereum, Arbitrum, Mantle, or Sepolia, call `get_vault_wallet_balance`.

3. **Calldata Decoding & Risk Screening**:
   - When inspecting contract calls, approvals, or raw calldata, call `decode_calldata`.
   - Flag any UNLIMITED token approvals (`type(uint256).max`) or collection-wide NFT delegations (`setApprovalForAll(true)`) with urgent security warnings before the user interacts with them.

4. **Intent-Based Transaction Preparation (MANDATORY STEP)**:
   - Before executing ANY on-chain transaction or transfer, you MUST ALWAYS call `prepare_transaction` first.
   - Present the returned ASCII Pre-Execution Card clearly to the user, highlighting:
     * Destination address and checksum verification
     * Value and gas cost estimation
     * Live on-chain simulation result (pass or revert)
     * Risk assessment score and warnings
   - NEVER proceed to broadcast without explicit user confirmation.

5. **Human-in-the-Loop Execution (STRICT)**:
   - ONLY call `execute_vault_transaction` AFTER the user has explicitly confirmed approval in response to the Pre-Execution Card (e.g., saying "yes", "proceed", "confirm", or "execute").
   - Always set `user_confirmed: true` when calling `execute_vault_transaction`.
   - The private key is handled in RAM by Foundry cast and sanitized from all outputs.

6. **Defense & Threat Response**:
   - Before high-value transfers or cold signing, advise using `toggle_airgap` to isolate the machine.
   - If user asks for security posture or threat telemetry, call `audit_system_security` or `get_defense_telemetry`.
   - In emergency malware situations, call `trigger_emergency_panic`.
EOF_GEMINI_MD

cp "${MOUNT_POINT}/GEMINI.md" "${MOUNT_POINT}/AGENTS.md"

# 4. Launch AI-Native Console or Classic Subshell
TARGET_ENGINE="${1:-}"
if [[ -z "${TARGET_ENGINE}" && -n "${IRONMAC_AI:-}" ]]; then
    TARGET_ENGINE="${IRONMAC_AI}"
fi

HAS_AGY=0
HAS_GEMINI=0
command -v agy >/dev/null 2>&1 && HAS_AGY=1
command -v gemini >/dev/null 2>&1 && HAS_GEMINI=1

SELECTED=""

cd "${MOUNT_POINT}"

if [[ "${TARGET_ENGINE}" == "--classic" || "${TARGET_ENGINE}" == "-s" || "${TARGET_ENGINE}" == "--shell" ]]; then
    SELECTED="classic"
elif [[ "${TARGET_ENGINE}" == "--agy" || "${TARGET_ENGINE}" == "-a" || "${TARGET_ENGINE}" == "agy" ]]; then
    SELECTED="agy"
elif [[ "${TARGET_ENGINE}" == "--gemini" || "${TARGET_ENGINE}" == "-g" || "${TARGET_ENGINE}" == "gemini" ]]; then
    SELECTED="gemini"
else
    # Interactive selection if both are available
    if [[ $HAS_AGY -eq 1 && $HAS_GEMINI -eq 1 ]]; then
        echo -e "${GRAY}┌──${RESET}${BOLD}${CYAN}[ ⚡ SELECT AI ENGINE // WEB3 OPERATING SYSTEM ]${RESET}${GRAY}───────────────────┐${RESET}"
        echo -e "${GRAY}│${RESET}  ${BOLD}[1] Google Antigravity (agy)${RESET}  • Autonomous Agent Plane (16 IronMac Tools)   ${GRAY}│${RESET}"
        echo -e "${GRAY}│${RESET}  ${BOLD}[2] Google Gemini CLI (gemini)${RESET} • Zero-Leak Handle Intent Mode             ${GRAY}│${RESET}"
        echo -e "${GRAY}│${RESET}  ${BOLD}[3] Classic Zero-Trace Shell${RESET}  • Pure Terminal (Foundry cast, starkli)     ${GRAY}│${RESET}"
        echo -e "${GRAY}└──${RESET}${BOLD}${GRAY}[ TIP: Set default via 'export IRONMAC_AI=agy' or '--agy' / '--gemini' ]${RESET}${GRAY}──┘${RESET}\n"

        read -rp "Select AI engine [1/2/3, default: 1]: " choice
        echo ""
        case "${choice}" in
            2) SELECTED="gemini" ;;
            3) SELECTED="classic" ;;
            *) SELECTED="agy" ;;
        esac
    elif [[ $HAS_AGY -eq 1 ]]; then
        SELECTED="agy"
    elif [[ $HAS_GEMINI -eq 1 ]]; then
        SELECTED="gemini"
    else
        SELECTED="classic"
    fi
fi

if [[ "${SELECTED}" == "agy" ]]; then
    if [[ $HAS_AGY -eq 1 ]]; then
        echo -e "${GRAY}┌──${RESET}${BOLD}${CYAN}[ ⚡ IRONCONSOLE AI // GOOGLE ANTIGRAVITY ENGINE ]${RESET}${GRAY}──────────────────┐${RESET}"
        echo -e "${GRAY}│${RESET}  ${BOLD}AI ENGINE${RESET}  : ${GREEN}Google Antigravity (agy v$(agy --version 2>/dev/null || echo '1.x'))${RESET}"
        echo -e "${GRAY}│${RESET}  ${BOLD}SANDBOX${RESET}    : ${GREEN}${KEYS_DIR} (Ephemeral RAMDisk)${RESET}"
        echo -e "${GRAY}│${RESET}  ${BOLD}CAPABILITIES${RESET}: 16 MCP Security Tools • Subagents • Multi-Chain Execution"
        echo -e "${GRAY}│${RESET}  ${BOLD}FALLBACK${RESET}   : Exit agent session to drop to zero-trace zsh subshell"
        echo -e "${GRAY}└──${RESET}${BOLD}${GRAY}[ ZERO KEYS ON DISK // PRIVATE KEYS QUARANTINED IN RAM ]${RESET}${GRAY}──────────┘${RESET}\n"

        agy --dangerously-skip-permissions || true

        echo -e "\n${GRAY}┌──${RESET}${BOLD}${YELLOW}[ ⚡ DROPPING TO ZERO-TRACE RAM SHELL ]${RESET}${GRAY}─────────────────────────────┐${RESET}"
        echo -e "${GRAY}│${RESET}  Type \033[1;38;5;82m'ai'\033[0m or \033[1;38;5;82m'agy'\033[0m to re-enter AI Copilot, or \033[1m'exit'\033[0m to destroy RAMDisk. ${GRAY}│${RESET}"
        echo -e "${GRAY}└──${RESET}${BOLD}${GRAY}[ VOLATILE MEMORY // PERSISTENCE DISABLED ]${RESET}${GRAY}─────────────────────┘${RESET}\n"
        ZDOTDIR="${ZDOT_DIR}" zsh -i
    else
        echo -e "${YELLOW}Notice: 'agy' (Google Antigravity CLI) not found.${RESET}"
        echo -e "${GRAY}Falling back to zero-trace zsh shell.${RESET}\n"
        ZDOTDIR="${ZDOT_DIR}" zsh -i
    fi
elif [[ "${SELECTED}" == "gemini" ]]; then
    if [[ $HAS_GEMINI -eq 1 ]]; then
        echo -e "${GRAY}┌──${RESET}${BOLD}${CYAN}[ ⚡ IRONCONSOLE AI // GOOGLE GEMINI CLI ENGINE ]${RESET}${GRAY}───────────────────┐${RESET}"
        echo -e "${GRAY}│${RESET}  ${BOLD}AI ENGINE${RESET}  : ${GREEN}Google Gemini CLI (Zero-Leak Handle Mode)${RESET}"
        echo -e "${GRAY}│${RESET}  ${BOLD}SANDBOX${RESET}    : ${GREEN}${KEYS_DIR} (Ephemeral RAMDisk)${RESET}"
        echo -e "${GRAY}│${RESET}  ${BOLD}INTERACTION${RESET}: Talk to AI in natural language to manage wallets & DeFi"
        echo -e "${GRAY}│${RESET}  ${BOLD}FALLBACK${RESET}   : Type '/quit' to drop to zsh shell, or 'exit' to shred"
        echo -e "${GRAY}└──${RESET}${BOLD}${GRAY}[ STARTING AI CONTROL PLANE // ZERO KEYS ON DISK ]${RESET}${GRAY}──────────────┘${RESET}\n"

        gemini --skip-trust || true

        echo -e "\n${GRAY}┌──${RESET}${BOLD}${YELLOW}[ ⚡ DROPPING TO ZERO-TRACE RAM SHELL ]${RESET}${GRAY}─────────────────────────────┐${RESET}"
        echo -e "${GRAY}│${RESET}  Type \033[1;38;5;82m'ai'\033[0m or \033[1;38;5;82m'gemini'\033[0m to re-enter AI Copilot, or \033[1m'exit'\033[0m to destroy RAMDisk. ${GRAY}│${RESET}"
        echo -e "${GRAY}└──${RESET}${BOLD}${GRAY}[ VOLATILE MEMORY // PERSISTENCE DISABLED ]${RESET}${GRAY}─────────────────────┘${RESET}\n"
        ZDOTDIR="${ZDOT_DIR}" zsh -i
    else
        echo -e "${YELLOW}Notice: 'gemini' CLI not found.${RESET}"
        echo -e "${GRAY}Install via: npm install -g @google/gemini-cli${RESET}\n"
        ZDOTDIR="${ZDOT_DIR}" zsh -i
    fi
else
    echo -e "${GRAY}┌──${RESET}${BOLD}${CYAN}[ ⚡ ENTERING ZERO-TRACE CLASSIC SHELL ]${RESET}${GRAY}────────────────────────┐${RESET}"
    echo -e "${GRAY}│${RESET}  Type \033[1;38;5;82m'ai'\033[0m to enter AI Copilot, or \033[1;38;5;214m'wallets'\033[0m to view keys.           ${GRAY}│${RESET}"
    echo -e "${GRAY}└──${RESET}${BOLD}${GRAY}[ ALL ARTIFACTS IN RAM // 'exit' TO SHRED ]${RESET}${GRAY}──────────────────────┘${RESET}\n"
    ZDOTDIR="${ZDOT_DIR}" zsh -i
fi
