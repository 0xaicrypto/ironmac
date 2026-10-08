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
if [[ -d "/Applications/Brave Browser.app" ]]; then
    APP_NAME="Brave Browser"
elif [[ -d "/Applications/Google Chrome.app" ]]; then
    APP_NAME="Google Chrome"
fi

if [[ -z "${APP_NAME}" ]]; then
    echo -e "${YELLOW}Neither Brave Browser nor Google Chrome was detected in /Applications.${RESET}"
    echo "You can install Brave via: brew install --cask brave-browser"
    exit 0
fi

PROFILE_PATH="${VAULT_DIR}/Profile"
mkdir -p "${PROFILE_PATH}/Crashpad"

# Create launcher script
LAUNCHER_SCRIPT="${HOME}/.local/bin/ironmac-vault-browser"
mkdir -p "$(dirname "${LAUNCHER_SCRIPT}")"

cat <<EOF > "${LAUNCHER_SCRIPT}"
#!/usr/bin/env bash
# IronMac Isolated Vault Browser Launcher
# Launches a clean, segregated instance via macOS LaunchServices
open -na "${APP_NAME}" --args \\
    --user-data-dir="${PROFILE_PATH}" \\
    --no-first-run \\
    --no-default-browser-check \\
    --disable-crash-reporter \\
    --crash-dumps-dir="${PROFILE_PATH}/Crashpad" \\
    "\$@"
EOF

chmod +x "${LAUNCHER_SCRIPT}"

echo -e "${GREEN}✓ Vault profile directory initialized at:${RESET}"
echo "   ${PROFILE_PATH}"
echo -e "${GREEN}✓ Created isolated launcher:${RESET}"
echo "   ${LAUNCHER_SCRIPT}"
echo ""
echo "To launch your isolated Web3 trading browser, run:"
echo -e "   ${BOLD}ironmac-vault-browser${RESET}"
echo ""
