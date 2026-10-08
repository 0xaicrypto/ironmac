#!/usr/bin/env python3
"""
IronMac Anti-AMOS Honeypot Sentry Daemon
Monitors decoy wallet directories and files using native macOS kqueue.
"""

import os
import sys
import time
import signal
import select
import subprocess
from datetime import datetime

LOG_FILE = os.path.expanduser("~/.ironmac/trap.log")
PID_FILE = os.path.expanduser("~/.ironmac/trap.pid")

def log(msg):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    line = f"[{timestamp}] {msg}\n"
    with open(LOG_FILE, "a") as f:
        f.write(line)
        f.flush()
    print(line, end="")

def alert(title, message, sound="Basso"):
    log(f"ALERT: {title} - {message}")
    # Display native macOS desktop notification
    script = f'display notification "{message}" with title "{title}" sound name "{sound}"'
    subprocess.run(["osascript", "-e", script], capture_output=True)

def get_process_info_for_file(filepath):
    try:
        out = subprocess.check_output(["lsof", filepath], stderr=subprocess.DEVNULL).decode()
        lines = out.strip().split("\n")
        if len(lines) > 1:
            return lines[1]
    except Exception:
        pass
    return None

def main():
    if len(sys.argv) < 2:
        print("Usage: trap_sentry.py <path1> [path2 ...]")
        sys.exit(1)

    targets = sys.argv[1:]
    kq = select.kqueue()
    fd_to_path = {}
    ke_list = []

    def add_watch(p):
        if not os.path.exists(p):
            return
        try:
            fd = os.open(p, os.O_RDONLY)
            fd_to_path[fd] = p
            ke = select.kevent(
                fd,
                filter=select.KQ_FILTER_VNODE,
                flags=select.KQ_EV_ADD | select.KQ_EV_CLEAR,
                fflags=(
                    select.KQ_NOTE_WRITE |
                    select.KQ_NOTE_DELETE |
                    select.KQ_NOTE_EXTEND |
                    select.KQ_NOTE_ATTRIB |
                    select.KQ_NOTE_RENAME
                )
            )
            ke_list.append(ke)
        except Exception as e:
            log(f"Error watching {p}: {e}")

    for t in targets:
        if os.path.isdir(t):
            add_watch(t)
            for root, dirs, files in os.walk(t):
                for f in files:
                    add_watch(os.path.join(root, f))
        elif os.path.isfile(t):
            add_watch(t)

    if not ke_list:
        log("No valid decoys found to watch. Exiting.")
        sys.exit(1)

    kq.control(ke_list, 0, 0)
    log(f"IronMac Trap Sentry armed! Watching {len(fd_to_path)} canary targets (directories & decoy files).")

    # Write PID
    os.makedirs(os.path.dirname(PID_FILE), exist_ok=True)
    with open(PID_FILE, "w") as f:
        f.write(str(os.getpid()))

    def handle_exit(signum, frame):
        log("IronMac Trap Sentry stopping.")
        for fd in fd_to_path:
            try: os.close(fd)
            except Exception: pass
        if os.path.exists(PID_FILE):
            os.remove(PID_FILE)
        sys.exit(0)

    signal.signal(signal.SIGINT, handle_exit)
    signal.signal(signal.SIGTERM, handle_exit)

    while True:
        try:
            events = kq.control(None, 5, 2.0)
            for ev in events:
                path = fd_to_path.get(ev.ident, "unknown")
                p_info = get_process_info_for_file(path)
                detail = f"Canary decoy triggered: {os.path.basename(path)}"
                if p_info:
                    detail += f" by {p_info.split()[0]}"
                alert("🚨 IronMac Honeypot Triggered!", detail)
        except Exception as e:
            time.sleep(1)

if __name__ == "__main__":
    main()
