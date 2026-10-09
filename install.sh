#!/usr/bin/env bash
#
# IronMac Installer & Instant Security Auditor
# Usage: curl -fsSL https://raw.githubusercontent.com/0xaicrypto/ironmac/main/install.sh | bash
#

set -euo pipefail

BOLD="\033[1m"
GREEN="\033[32m"
CYAN="\033[36m"
YELLOW="\033[33m"
RED="\033[31m"
RESET="\033[0m"

echo -e "${CYAN}${BOLD}"
echo "=========================================================="
echo "          ⚡  IronMac - Web3 Workstation Installer        "
echo "=========================================================="
echo -e "${RESET}"

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo -e "${RED}Error: IronMac is designed exclusively for macOS.${RESET}"
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

chmod +x "${INSTALL_DIR}/bin/ironmac" "${INSTALL_DIR}/modules/"*.sh
if [[ -f "${INSTALL_DIR}/mcp/dist/index.js" ]]; then
    chmod +x "${INSTALL_DIR}/mcp/dist/index.js"
fi

# Link to ~/.local/bin or /usr/local/bin
BIN_DIR="${HOME}/.local/bin"
mkdir -p "${BIN_DIR}"
ln -sf "${INSTALL_DIR}/bin/ironmac" "${BIN_DIR}/ironmac"

echo -e "${GREEN}✓ IronMac core successfully installed to ${BIN_DIR}/ironmac${RESET}\n"

# ------------------------------------------------------------------
# Immediate Security Health Audit
# ------------------------------------------------------------------
echo -e "${CYAN}${BOLD}🔍 Running Immediate Mac Security Health Audit...${RESET}"
bash "${INSTALL_DIR}/modules/audit.sh"

# ------------------------------------------------------------------
# Prompt for Immediate Hardening
# ------------------------------------------------------------------
DO_HARDEN="N"

if [[ -t 0 ]]; then
    read -rp "Would you like IronMac to automatically harden your Mac right now? [y/N]: " DO_HARDEN
elif [[ -c /dev/tty ]]; then
    read -rp "Would you like IronMac to automatically harden your Mac right now? [y/N]: " DO_HARDEN </dev/tty
fi

if [[ "${DO_HARDEN}" =~ ^[Yy]$ ]]; then
    bash "${INSTALL_DIR}/modules/harden.sh" -y
else
    echo -e "\n${YELLOW}Hardening skipped for now. You can run 'ironmac harden' anytime.${RESET}"
fi

# ------------------------------------------------------------------
# Summary & Next Steps
# ------------------------------------------------------------------
echo ""
echo -e "${CYAN}${BOLD}==========================================================${RESET}"
echo -e "${GREEN}${BOLD}🎉 IronMac Setup Complete!${RESET}"
echo -e "${CYAN}${BOLD}==========================================================${RESET}"
echo ""
echo "Essential commands to try right now:"
echo -e "  • ${BOLD}ironmac console${RESET}       -> Launch zero-trace RAM terminal with EVM & Starknet wallets"
echo -e "  • ${BOLD}ironmac vault-browser${RESET} -> Launch isolated DeFi transaction browser"
echo -e "  • ${BOLD}ironmac mcp${RESET}           -> Run Model Context Protocol server for AI Agents (Cursor/Claude)"
echo -e "  • ${BOLD}ironmac audit${RESET}         -> Re-audit your Mac's security posture"
echo -e "  • ${BOLD}ironmac harden${RESET}        -> Re-apply system security baselines"
echo ""
echo "Note: If 'ironmac' is not found, add this to your ~/.zshrc or ~/.bash_profile:"
echo -e "  ${BOLD}export PATH=\"\$HOME/.local/bin:\$PATH\"${RESET}"
echo ""
