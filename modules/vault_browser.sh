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

# Detect available browsers (Brave preferred for privacy, Google Chrome as fallback)
BROWSER_BIN=""
BROWSER_NAME=""

if [[ -d "/Applications/Brave Browser.app" ]]; then
    BROWSER_BIN="/Applications/Brave Browser.app/Contents/MacOS/Brave Browser"
    BROWSER_NAME="Brave Browser"
elif [[ -d "/Applications/Google Chrome.app" ]]; then
    BROWSER_BIN="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
    BROWSER_NAME="Google Chrome"
fi

if [[ -z "${BROWSER_BIN}" ]]; then
    echo -e "${YELLOW}Neither Brave Browser nor Google Chrome was detected in /Applications.${RESET}"
    echo "You can install Brave via: brew install --cask brave-browser"
    exit 0
fi

PROFILE_PATH="${VAULT_DIR}/Profile"
mkdir -p "${PROFILE_PATH}"

# Create launcher script
LAUNCHER_SCRIPT="${HOME}/.local/bin/ironmac-vault-browser"
mkdir -p "$(dirname "${LAUNCHER_SCRIPT}")"

cat <<EOF > "${LAUNCHER_SCRIPT}"
#!/usr/bin/env bash
# IronMac Isolated Vault Browser Launcher
exec "${BROWSER_BIN}" \\
    --user-data-dir="${PROFILE_PATH}" \\
    --no-first-run \\
    --no-default-browser-check \\
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
