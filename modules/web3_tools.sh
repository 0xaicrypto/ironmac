#!/usr/bin/env bash
#
# IronMac - Web3 Tools Module
# Curated developer and trader package installer via Homebrew
#

set -euo pipefail

BOLD="\033[1m"
GREEN="\033[32m"
CYAN="\033[36m"
YELLOW="\033[33m"
RESET="\033[0m"

echo ""
echo -e "${CYAN}${BOLD}=== [4/4] IronMac Curated Web3 Tools Installer ===${RESET}"

if ! command -v brew >/dev/null 2>&1; then
    echo -e "${YELLOW}Homebrew not detected. Please install Homebrew first from https://brew.sh${RESET}"
    exit 0
fi

echo "Select your workstation profile:"
echo "  1) 🔒 Security Essentials (GnuPG, Pinentry, LuLu outbound firewall)"
echo "  2) ⚡ Web3 Developer (Foundry, Starkli, Rust, Node, pnpm, GnuPG)"
echo "  3) 🪙 Trader / Degen (Brave Browser, Ledger Live, LuLu)"
echo "  4) 👛 Open-Source CLI Wallets Only (Foundry cast for EVM + Starkli for Starknet)"
echo "  0) Skip tools installation"
echo ""

read -rp "Enter choice [1-4, 0]: " profile_choice

case "${profile_choice}" in
    1)
        echo "Installing Security Essentials..."
        brew install gnupg pinentry-mac || true
        brew install --cask lulu || true
        echo -e "${GREEN}✓ Security essentials installed.${RESET}"
        ;;
    2)
        echo "Installing Web3 Developer Toolchain..."
        brew install node pnpm rustup-init gnupg || true
        if ! command -v cast >/dev/null 2>&1; then
            echo "Installing Foundry (cast, forge)..."
            curl -L https://foundry.paradigm.xyz | bash || true
            "$HOME/.foundry/bin/foundryup" || true
        fi
        if ! command -v starkli >/dev/null 2>&1; then
            echo "Installing Starkli (Starknet CLI wallet)..."
            curl -fsSL https://get.starkli.sh | sh || true
            "$HOME/.starkli/bin/starkliup" || true
        fi
        echo -e "${GREEN}✓ Web3 developer toolchain ready.${RESET}"
        ;;
    3)
        echo "Installing Trader / Degen Essentials..."
        brew install --cask brave-browser ledger-live lulu || true
        echo -e "${GREEN}✓ Trader essentials installed.${RESET}"
        ;;
    4)
        echo "Installing Open-Source CLI Wallets (EVM + Starknet)..."
        if ! command -v cast >/dev/null 2>&1; then
            echo "Installing Foundry (cast wallet)..."
            curl -L https://foundry.paradigm.xyz | bash || true
            if [[ -x "$HOME/.foundry/bin/foundryup" ]]; then
                "$HOME/.foundry/bin/foundryup" || true
            fi
        fi
        if ! command -v starkli >/dev/null 2>&1; then
            echo "Installing Starkli (Starknet wallet)..."
            curl -fsSL https://get.starkli.sh | sh || true
            if [[ -x "$HOME/.starkli/bin/starkliup" ]]; then
                "$HOME/.starkli/bin/starkliup" || true
            fi
        fi
        echo -e "${GREEN}✓ EVM (cast) & Starknet (starkli) CLI wallets installed.${RESET}"
        ;;
    0|*)
        echo "Tool installation skipped."
        ;;
esac

echo ""
