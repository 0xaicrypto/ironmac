#!/usr/bin/env bash
#
# IronMac Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/0xaicrypto/ironmac/main/install.sh | bash
#

set -euo pipefail

BOLD="\033[1m"
GREEN="\033[32m"
CYAN="\033[36m"
YELLOW="\033[33m"
RESET="\033[0m"

echo -e "${CYAN}${BOLD}"
echo "=========================================================="
echo "          🛡️  IronMac - Web3 Workstation Installer        "
echo "=========================================================="
echo -e "${RESET}"

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo -e "${YELLOW}Error: IronMac is designed exclusively for macOS.${RESET}"
    exit 1
fi

INSTALL_DIR="${HOME}/.ironmac"

echo -e "📦 Cloning / Updating IronMac into ${BOLD}${INSTALL_DIR}${RESET}..."

if [[ -d "${INSTALL_DIR}/.git" ]]; then
    git -C "${INSTALL_DIR}" pull --quiet
else
    rm -rf "${INSTALL_DIR}"
    git clone --depth=1 https://github.com/0xaicrypto/ironmac.git "${INSTALL_DIR}" --quiet
fi

chmod +x "${INSTALL_DIR}/bin/ironmac"

# Link to /usr/local/bin or ~/.local/bin if available
BIN_DIR="${HOME}/.local/bin"
mkdir -p "${BIN_DIR}"
ln -sf "${INSTALL_DIR}/bin/ironmac" "${BIN_DIR}/ironmac"

echo -e "${GREEN}✓ IronMac successfully installed!${RESET}"
echo ""
echo "To get started, add ~/.local/bin to your PATH (if not already present), or run:"
echo -e "  ${BOLD}${INSTALL_DIR}/bin/ironmac${RESET}"
echo ""

# Launch interactive menu directly if running interactively
if [[ -t 0 ]]; then
    exec "${INSTALL_DIR}/bin/ironmac"
fi
