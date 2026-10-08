#!/usr/bin/env bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Scan Secrets in Path
# @raycast.mode fullOutput
# @raycast.packageName IronMac

# Optional parameters:
# @raycast.icon 🔑
# @raycast.argument1 { "type": "text", "placeholder": "Directory to scan (default: current directory)", "optional": true }
# @raycast.description Recursively scan files and directories for unencrypted 64-hex private keys and sensitive env variables

TARGET="${1:-.}"

if [[ ! -e "$TARGET" ]]; then
    echo "Error: Target path not found: $TARGET"
    exit 1
fi

echo "=========================================================="
echo "          🛡️  IronMac Secret Leak Scanner                 "
echo "=========================================================="
echo "Scanning path: $TARGET"
echo ""

python3 -c "
import os, sys, re

target = sys.argv[1]
HEX_KEY_REGEX = re.compile(r'(?:0x)?[0-9a-fA-F]{64}')
SECRET_ENV_REGEX = re.compile(r'(?:PRIVATE_KEY|MNEMONIC|SEED_PHRASE|API_KEY|SECRET)\s*=\s*[\x27\x22]?([^\s\x27\x22]+)[\x27\x22]?', re.IGNORECASE)

findings = []

def scan_file(fpath):
    if fpath.endswith(('.lock', '.min.js', '.png', '.jpg', '.pdf', '.svg', '.bin')):
        return
    try:
        with open(fpath, 'r', encoding='utf-8', errors='ignore') as f:
            for idx, line in enumerate(f, 1):
                clean = line.strip()
                if not clean or clean.startswith('#') or clean.startswith('//'):
                    continue
                if HEX_KEY_REGEX.search(line):
                    findings.append((fpath, idx, '64-HEX Private Key Candidate', clean[:60]))
                elif SECRET_ENV_REGEX.search(line):
                    findings.append((fpath, idx, 'Sensitive Environment Secret', clean[:60]))
    except Exception:
        pass

if os.path.isfile(target):
    scan_file(target)
elif os.path.isdir(target):
    for root, dirs, files in os.walk(target):
        dirs[:] = [d for d in dirs if d not in ('node_modules', '.git', '.ironmac_backup', '__pycache__')]
        for file in files:
            scan_file(os.path.join(root, file))

if not findings:
    print('✓ CLEAN: No plaintext private keys or sensitive variables found.')
else:
    print(f'⚠️  FOUND {len(findings)} EXPOSED SECRET(S):')
    for fpath, line, stype, snippet in findings:
        print(f'  • {fpath}:{line} [{stype}]\n    Snippet: {snippet}...')
    print('\n[!] DO NOT commit or transmit these files. Import keys into encrypted keystores:')
    print('    cast wallet import <name> -i')
" "$TARGET"
