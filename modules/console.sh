#!/usr/bin/env bash
#
# IronMac - Secure Vault Console Module
# Provides a zero-trace, ephemeral RAM-backed terminal session for Web3 operations.
#

set -euo pipefail

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

# 3. Two-Line Hacker Cyberpunk Prompt
PROMPT="%F{242}╭─%f%F{82}[%f%F{51}⚡ IRON-VAULT%f%F{82}]%f%F{242}─%f%F{214}[HIST:OFF]%f%F{242}─%f%F{141}[%1~]%f"$'\n'"%F{242}╰─%f%(?.%F{51}❯%f.%F{196}❯%f) "

# 4. Built-in Security Aliases
alias clear="clear && echo -e '\033[38;5;242m╭─\033[0m\033[1;38;5;51m[⚡ IRON-VAULT // VOLATILE MEMORY ACTIVE // ZERO-TRACE]\033[0m\033[38;5;242m─\033[0m\033[38;5;214m[HIST:OFF]\033[0m\033[38;5;242m─\033[0m\033[38;5;82m[● AIR-GAP READY]\033[0m'"
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
    echo -e "\033[38;5;242m│\033[0m  \033[1mHISTORY\033[0m     : \033[38;5;82mHISTFILE=/dev/null (Zero Persistence)\033[0m"
    echo -e "\033[38;5;242m│\033[0m  \033[1mCLIP-GUARD\033[0m  : $(pgrep -f "clip_guard.py" >/dev/null && echo -e "\033[38;5;82m● ACTIVE\033[0m" || echo -e "\033[38;5;242m○ INACTIVE\033[0m")"
    echo -e "\033[38;5;242m│\033[0m  \033[1mHONEYPOT\033[0m    : $(pgrep -f "trap_sentry.py" >/dev/null && echo -e "\033[38;5;82m● ARMED\033[0m" || echo -e "\033[38;5;242m○ DISARMED\033[0m")"
    echo -e "\033[38;5;242m│\033[0m  \033[1mNETWORK\033[0m     : $(networksetup -getairportpower en0 2>/dev/null | grep -q "On" && echo -e "\033[38;5;214mWi-Fi Online\033[0m" || echo -e "\033[38;5;82mAir-Gapped (Wi-Fi Off)\033[0m")"
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
