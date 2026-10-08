#!/usr/bin/env bash
#
# IronMac - Harden Module
# Applies macOS security baselines and network stealth
#

set -euo pipefail

BOLD="\033[1m"
GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
RESET="\033[0m"

echo ""
echo -e "${CYAN}${BOLD}=== [2/4] IronMac System Hardening Baseline ===${RESET}"
echo "This will configure security settings on your Mac."
echo "Note: Administrative privileges (sudo) may be required for system settings."
echo ""

FORCE_YES="${1:-}"

if [[ "${FORCE_YES}" == "-y" || "${FORCE_YES}" == "--yes" ]]; then
    confirm="y"
else
    if [[ -t 0 ]]; then
        read -rp "Proceed with baseline hardening? [y/N]: " confirm
    elif [[ -c /dev/tty ]]; then
        read -rp "Proceed with baseline hardening? [y/N]: " confirm </dev/tty
    else
        echo "Non-interactive environment detected. Use 'ironmac harden -y' to force apply."
        exit 0
    fi
fi

if [[ ! "${confirm}" =~ ^[Yy]$ ]]; then
    echo "Hardening skipped."
    exit 0
fi

# 1. Enable Application Firewall
echo -e "\n${BOLD}[1/5] Enabling Application Firewall...${RESET}"
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on >/dev/null
echo -e "${GREEN}✓ Firewall enabled.${RESET}"

# 2. Enable Stealth Mode (Ignore ICMP ping requests)
echo -e "\n${BOLD}[2/5] Enabling Stealth Mode...${RESET}"
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on >/dev/null
echo -e "${GREEN}✓ Stealth mode enabled (stealth against network scanning).${RESET}"

# 3. Disable Guest Account
echo -e "\n${BOLD}[3/5] Disabling Guest User login...${RESET}"
sudo defaults write /Library/Preferences/com.apple.loginwindow GuestEnabled -bool NO 2>/dev/null || true
echo -e "${GREEN}✓ Guest login disabled.${RESET}"

# 4. Require Password Immediately on Sleep / Screen Lock
echo -e "\n${BOLD}[4/5] Requiring password immediately upon screen lock...${RESET}"
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0
echo -e "${GREEN}✓ Screen lock set to require password immediately.${RESET}"

# 5. Disable Remote Apple Events
echo -e "\n${BOLD}[5/5] Disabling Remote Apple Events...${RESET}"
sudo systemsetup -setremoteappleevents off 2>/dev/null || true
echo -e "${GREEN}✓ Remote Apple Events disabled.${RESET}"

echo ""
echo -e "${GREEN}${BOLD}🎉 System hardening baseline applied successfully!${RESET}"
echo ""
