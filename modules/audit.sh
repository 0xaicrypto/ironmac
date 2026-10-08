#!/usr/bin/env bash
#
# IronMac - Audit Module
# Comprehensive security assessment for macOS
#

set -euo pipefail

BOLD="\033[1m"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
CYAN="\033[36m"
RESET="\033[0m"

echo ""
echo -e "${CYAN}${BOLD}=== [1/4] IronMac Security Health Audit ===${RESET}"
echo "Inspecting macOS security posture against Web3 threat vectors..."
echo ""

SCORE=0
MAX_SCORE=7

# 1. FileVault (Full Disk Encryption)
echo -n "Checking FileVault (Disk Encryption)... "
if fdesetup status 2>/dev/null | grep -q "FileVault is On"; then
    echo -e "${GREEN}✓ ENABLED${RESET}"
    SCORE=$((SCORE + 1))
else
    echo -e "${RED}✗ DISABLED (Critical: Private keys & disk readable if laptop lost)${RESET}"
fi

# 2. Application Firewall
echo -n "Checking macOS Application Firewall... "
FW_STATE=$(/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null || true)
if echo "${FW_STATE}" | grep -q "enabled"; then
    echo -e "${GREEN}✓ ENABLED${RESET}"
    SCORE=$((SCORE + 1))
else
    echo -e "${YELLOW}⚠ DISABLED (Inbound connections not filtered)${RESET}"
fi

# 3. Stealth Mode (Drop ICMP / Ping)
echo -n "Checking Firewall Stealth Mode... "
STEALTH_STATE=$(/usr/libexec/ApplicationFirewall/socketfilterfw --getstealthmode 2>/dev/null || true)
if echo "${STEALTH_STATE}" | grep -q "enabled"; then
    echo -e "${GREEN}✓ ENABLED${RESET}"
    SCORE=$((SCORE + 1))
else
    echo -e "${YELLOW}⚠ DISABLED (Mac responds to network probes on public Wi-Fi)${RESET}"
fi

# 4. Gatekeeper (App Signature Verification)
echo -n "Checking Gatekeeper... "
if spctl --status 2>/dev/null | grep -q "assessments enabled"; then
    echo -e "${GREEN}✓ ENABLED${RESET}"
    SCORE=$((SCORE + 1))
else
    echo -e "${RED}✗ DISABLED (Untrusted binaries can execute without check)${RESET}"
fi

# 5. System Integrity Protection (SIP)
echo -n "Checking System Integrity Protection (SIP)... "
if csrutil status 2>/dev/null | grep -q "enabled"; then
    echo -e "${GREEN}✓ ENABLED${RESET}"
    SCORE=$((SCORE + 1))
else
    echo -e "${RED}✗ DISABLED (Root system files can be modified by malware)${RESET}"
fi

# 6. Remote Login (SSH)
echo -n "Checking Remote Login (SSH)... "
if launchctl print system/com.openssh.sshd 2>&1 | grep -q "state = running"; then
    echo -e "${YELLOW}⚠ RUNNING (Port 22 open for remote access)${RESET}"
else
    echo -e "${GREEN}✓ DISABLED${RESET}"
    SCORE=$((SCORE + 1))
fi

# 7. Guest User Account
echo -n "Checking Guest User Account... "
GUEST_ENABLED=$(defaults read /Library/Preferences/com.apple.loginwindow GuestEnabled 2>/dev/null || echo "1")
if [[ "${GUEST_ENABLED}" == "0" ]]; then
    echo -e "${GREEN}✓ DISABLED${RESET}"
    SCORE=$((SCORE + 1))
else
    echo -e "${YELLOW}⚠ ENABLED (Unauthenticated guest access allowed)${RESET}"
fi

echo ""
echo -e "${BOLD}Security Health Score: ${SCORE}/${MAX_SCORE}${RESET}"
if [[ ${SCORE} -eq ${MAX_SCORE} ]]; then
    echo -e "${GREEN}🎉 Outstanding! Your Mac security baseline is fully hardened.${RESET}"
elif [[ ${SCORE} -ge 5 ]]; then
    echo -e "${YELLOW}Good, but some exposure remains. Run 'ironmac harden' to fix.${RESET}"
else
    echo -e "${RED}Warning: Multiple critical security protections are disabled. Highly recommended to run 'ironmac harden'.${RESET}"
fi
echo ""
