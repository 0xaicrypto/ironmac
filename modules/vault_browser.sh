#!/usr/bin/env bash
#
# IronMac - Vault Browser Module
# Creates an isolated, sandboxed profile for Web3 wallets and DeFi interactions.
#

set -euo pipefail

BOLD="\033[1m"
GREEN="\033[32m"
CYAN="\033[36m"
YELLOW="\033[33m"
RESET="\033[0m"

echo ""
echo -e "${CYAN}${BOLD}=== [3/4] IronMac Vault Browser Isolation ===${RESET}"
echo "Creates a clean, dedicated browser profile completely isolated from your daily browsing."
echo "This prevents Infostealers (like AMOS) and untrusted extensions from accessing your wallet sessions."
echo ""

VAULT_DIR="${HOME}/Library/Application Support/IronMacVault"
mkdir -p "${VAULT_DIR}"

APP_NAME=""
APP_PATH=""
if [[ -d "/Applications/Brave Browser.app" ]]; then
    APP_NAME="Brave Browser"
    APP_PATH="/Applications/Brave Browser.app"
elif [[ -d "/Applications/Google Chrome.app" ]]; then
    APP_NAME="Google Chrome"
    APP_PATH="/Applications/Google Chrome.app"
elif [[ -d "${HOME}/Applications/Brave Browser.app" ]]; then
    APP_NAME="Brave Browser"
    APP_PATH="${HOME}/Applications/Brave Browser.app"
elif [[ -d "${HOME}/Applications/Google Chrome.app" ]]; then
    APP_NAME="Google Chrome"
    APP_PATH="${HOME}/Applications/Google Chrome.app"
fi

if [[ -z "${APP_PATH}" ]]; then
    echo -e "${YELLOW}Neither Brave Browser nor Google Chrome was detected in /Applications.${RESET}"
    echo "You can install Brave via: brew install --cask brave-browser"
    exit 0
fi

PROFILE_PATH="${VAULT_DIR}/Profile"
mkdir -p "${PROFILE_PATH}/Crashpad"

# Function to clean up stale singleton lock if the previous browser process died
cleanup_stale_lock() {
    local lock_file="${PROFILE_PATH}/SingletonLock"
    if [[ -L "${lock_file}" ]]; then
        local target
        target="$(readlink "${lock_file}" 2>/dev/null || true)"
        local pid="${target##*-}"
        if [[ -n "${pid}" ]] && [[ "${pid}" =~ ^[0-9]+$ ]]; then
            if ! ps -p "${pid}" >/dev/null 2>&1; then
                rm -f "${PROFILE_PATH}/SingletonLock" "${PROFILE_PATH}/SingletonSocket" "${PROFILE_PATH}/SingletonCookie" 2>/dev/null || true
            fi
        fi
    fi
}

cleanup_stale_lock

# Create launcher script
LAUNCHER_SCRIPT="${HOME}/.local/bin/ironmac-vault-browser"
mkdir -p "$(dirname "${LAUNCHER_SCRIPT}")"

cat <<EOF > "${LAUNCHER_SCRIPT}"
#!/usr/bin/env bash
# IronMac Isolated Vault Browser Launcher
# Launches a clean, segregated instance via macOS LaunchServices

PROFILE_DIR="${PROFILE_PATH}"

# Clean dead singleton lock before launching
if [[ -L "\${PROFILE_DIR}/SingletonLock" ]]; then
    LOCK_TARGET="\$(readlink "\${PROFILE_DIR}/SingletonLock" 2>/dev/null || true)"
    LOCK_PID="\${LOCK_TARGET##*-}"
    if [[ -n "\${LOCK_PID}" ]] && [[ "\${LOCK_PID}" =~ ^[0-9]+$ ]]; then
        if ! ps -p "\${LOCK_PID}" >/dev/null 2>&1; then
            rm -f "\${PROFILE_DIR}/SingletonLock" "\${PROFILE_DIR}/SingletonSocket" "\${PROFILE_DIR}/SingletonCookie" 2>/dev/null || true
        fi
    fi
fi

TARGET_URL="\${1:-https://alphanalyzor.trade}"
if [[ \$# -gt 0 ]]; then
    shift
fi

open -na "${APP_PATH}" --args \\
    --user-data-dir="\${PROFILE_DIR}" \\
    --no-first-run \\
    --no-default-browser-check \\
    --disable-crash-reporter \\
    --crash-dumps-dir="\${PROFILE_DIR}/Crashpad" \\
    "\${TARGET_URL}" "\$@"

# Ensure window is activated to foreground
open -a "${APP_PATH}" 2>/dev/null || true
EOF

chmod +x "${LAUNCHER_SCRIPT}"

echo -e "${GREEN}✓ Vault profile directory initialized at:${RESET}"
echo "   ${PROFILE_PATH}"
echo -e "${GREEN}✓ Isolated launcher ready:${RESET}"
echo "   ${LAUNCHER_SCRIPT}"
echo ""

# Handle init-only mode (used by setup wizard)
if [[ "${1:-}" == "--init-only" || "${1:-}" == "--setup-only" ]]; then
    echo -e "${GREEN}✓ Vault browser profile setup complete.${RESET}"
    exit 0
fi

TARGET_URL="${1:-https://alphanalyzor.trade}"
echo -e "${CYAN}Launching isolated Vault Browser (${TARGET_URL})...${RESET}"
exec "${LAUNCHER_SCRIPT}" "$@"
