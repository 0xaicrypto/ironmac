#!/usr/bin/env python3
"""
IronMac Clipboard Guard Daemon
1. Detects silent address substitution trojans (EVM, Solana, BTC).
2. Auto-wipes private keys and seed phrases after a 30-second TTL.
"""

import os
import re
import sys
import time
import signal
import subprocess
from datetime import datetime

PID_FILE = os.path.expanduser("~/.ironmac/clip_guard.pid")
LOG_FILE = os.path.expanduser("~/.ironmac/clip_guard.log")

# Regex Patterns for Blockchain Data
RE_EVM_ADDR = re.compile(r"^0x[a-fA-F0-9]{40}$")
RE_BTC_ADDR = re.compile(r"^(bc1|[13])[a-zA-HJ-NP-Z0-9]{25,39}$")
RE_SOL_ADDR = re.compile(r"^[1-9A-HJ-NP-za-km-z]{32,44}$")
RE_PRIVATE_KEY = re.compile(r"^(0x)?[a-fA-F0-9]{64}$")

def log(msg):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    line = f"[{timestamp}] {msg}\n"
    with open(LOG_FILE, "a") as f:
        f.write(line)
        f.flush()
    print(line, end="")

def notify(title, message, sound="Basso"):
    log(f"NOTIFY: {title} - {message}")
    script = f'display notification "{message}" with title "{title}" sound name "{sound}"'
    subprocess.run(["osascript", "-e", script], capture_output=True)

def get_clipboard():
    try:
        p = subprocess.Popen(["pbpaste"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        out, _ = p.communicate(timeout=1.0)
        return out.decode("utf-8", errors="ignore").strip()
    except Exception:
        return ""

def set_clipboard(text):
    try:
        p = subprocess.Popen(["pbcopy"], stdin=subprocess.PIPE, stderr=subprocess.DEVNULL)
        p.communicate(input=text.encode("utf-8"), timeout=1.0)
    except Exception:
        pass

def is_mnemonic(text):
    words = text.strip().split()
    if len(words) in (12, 18, 24):
        # All words must be alphabetic
        if all(w.isalpha() and w.islower() for w in words):
            return True
    return False

def get_address_type(text):
    if RE_EVM_ADDR.match(text):
        return "EVM"
    if RE_BTC_ADDR.match(text):
        return "Bitcoin"
    if RE_SOL_ADDR.match(text) and not text.startswith("0x") and not text.isdigit():
        return "Solana"
    return None

def main():
    os.makedirs(os.path.dirname(PID_FILE), exist_ok=True)
    with open(PID_FILE, "w") as f:
        f.write(str(os.getpid()))

    log("IronMac Clipboard Guard daemon started.")

    def handle_exit(signum, frame):
        log("IronMac Clipboard Guard stopping.")
        if os.path.exists(PID_FILE):
            os.remove(PID_FILE)
        sys.exit(0)

    signal.signal(signal.SIGINT, handle_exit)
    signal.signal(signal.SIGTERM, handle_exit)

    last_clipboard = get_clipboard()
    last_addr_type = get_address_type(last_clipboard)
    last_addr_val = last_clipboard if last_addr_type else None
    last_addr_time = time.time() if last_addr_type else 0

    pending_wipe_text = None
    pending_wipe_deadline = 0

    while True:
        try:
            time.sleep(0.5)
            curr = get_clipboard()

            now = time.time()

            # 1. Handle Pending Wipe Deadline (TTL Auto-Purge)
            if pending_wipe_text and now >= pending_wipe_deadline:
                if curr == pending_wipe_text:
                    set_clipboard("")
                    notify("🛡️ IronMac Clip-Guard", "Sensitive private key/seed automatically purged from clipboard.", sound="Purr")
                pending_wipe_text = None

            # Skip if clipboard hasn't changed
            if curr == last_clipboard:
                continue

            # Clipboard content changed!
            curr_addr_type = get_address_type(curr)

            # Check 1: Address Swap Attack (Fast silent substitution)
            if last_addr_type and curr_addr_type and last_addr_type == curr_addr_type:
                time_diff = now - last_addr_time
                if 0.05 <= time_diff <= 2.5 and curr != last_addr_val:
                    notify("🚨 ADDRESS SWAP DETECTED!",
                           f"Possible clipboard hijacker! {curr_addr_type} address changed rapidly ({time_diff:.1f}s)",
                           sound="Basso")
                    log(f"ALERT: Potential clipboard hijack: '{last_addr_val}' replaced with '{curr}'")

            # Check 2: Sensitive Secret Copied (Private Key or Mnemonic)
            if RE_PRIVATE_KEY.match(curr):
                notify("⚠️ Sensitive Key in Clipboard", "Private key detected. Auto-wiping clipboard in 30 seconds.", sound="Sosumi")
                pending_wipe_text = curr
                pending_wipe_deadline = now + 30.0
                log("Sensitive private key detected in pasteboard. TTL set to 30s.")
            elif is_mnemonic(curr):
                notify("⚠️ Mnemonic Seed in Clipboard", "Seed phrase detected. Auto-wiping clipboard in 30 seconds.", sound="Sosumi")
                pending_wipe_text = curr
                pending_wipe_deadline = now + 30.0
                log("Mnemonic seed phrase detected in pasteboard. TTL set to 30s.")
            else:
                # If user copied something else, cancel pending wipe
                if pending_wipe_text and curr != pending_wipe_text:
                    pending_wipe_text = None

            # Update state
            last_clipboard = curr
            last_addr_type = curr_addr_type
            if curr_addr_type:
                last_addr_val = curr
                last_addr_time = now
            else:
                last_addr_val = None

        except Exception as e:
            time.sleep(1)

if __name__ == "__main__":
    main()
