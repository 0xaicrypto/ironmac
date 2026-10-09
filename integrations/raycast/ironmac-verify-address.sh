#!/usr/bin/env bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Verify Crypto Address (EIP-55)
# @raycast.mode fullOutput
# @raycast.packageName IronMac

# Optional parameters:
# @raycast.icon 🔍
# @raycast.argument1 { "type": "text", "placeholder": "Address (0x... / Solana Base58 / Bitcoin)" }
# @raycast.description Validate cryptocurrency recipient addresses against EIP-55 checksum and vanity poisoning

ADDR="${1:-}"

if [[ -z "$ADDR" ]]; then
    echo "Error: Please supply a cryptocurrency address to verify."
    exit 1
fi

echo "=========================================================="
echo "          🔍  IronMac Address Integrity Verifier          "
echo "=========================================================="
echo ""
echo "Input Address: $ADDR"
echo ""

# EVM Check
if [[ "$ADDR" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
    echo "Detected Chain: EVM (Ethereum / Base / Mantle / Arbitrum / Polygon / BSC)"
    
    # Calculate EIP-55 Checksum
    CHECKSUMMED=$(node -e '
        const c = require("node:crypto");
        const a = process.argv[1].toLowerCase().replace(/^0x/,"");
        const h = c.createHash("keccak-256").update(a).digest("hex");
        console.log("0x" + a.split("").map((x,i) => parseInt(h[i],16)>=8 ? x.toUpperCase() : x).join(""));
    ' "$ADDR" 2>/dev/null || true)

    if [[ -n "$CHECKSUMMED" ]]; then
        if [[ "$ADDR" == "$CHECKSUMMED" ]]; then
            echo "Checksum Status: [✓ VALID] Valid EIP-55 Mixed-Case Checksum."
        elif [[ "$ADDR" == "0x${(L)ADDR#0x}" || "$ADDR" == "0x${(U)ADDR#0x}" ]]; then
            echo "Checksum Status: [⚠️ WARNING] Address is valid hex, but lacks EIP-55 mixed-case checksum!"
            echo "Suggested Checksum Address: $CHECKSUMMED"
        else
            echo "Checksum Status: [❌ CORRUPTED / INVALID] EIP-55 Checksum Mismatch!"
            echo "Expected Checksum Address : $CHECKSUMMED"
            echo "Risk: Possible address-poisoning spoof or copy-paste corruption."
        fi
    fi

    if [[ "$ADDR" =~ ^0x0{6,} ]]; then
        echo ""
        echo "🚨 POISONING WARNING: High vanity prefix (6+ leading zeros) detected!"
        echo "Verify the full address against transfer spoof attacks."
    fi
    exit 0
fi

# Solana Check
if [[ "$ADDR" =~ ^[1-9A-HJ-NP-Za-km-z]{32,44}$ ]]; then
    echo "Detected Chain: Solana"
    echo "Format Status : [✓ VALID] Valid Base58 Solana public key format (32-44 characters)."
    exit 0
fi

# Bitcoin Check
if [[ "$ADDR" =~ ^(1|3|bc1)[a-zA-HJ-NP-Z0-9]{25,62}$ ]]; then
    echo "Detected Chain: Bitcoin"
    echo "Format Status : [✓ VALID] Valid Bitcoin address format (Legacy / SegWit / Taproot)."
    exit 0
fi

echo "Format Status : [❌ INVALID] Does not match recognized EVM, Solana, or Bitcoin address format."
exit 1
