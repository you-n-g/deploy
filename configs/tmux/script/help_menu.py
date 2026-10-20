#!/usr/bin/env python3
"""prefix + H: a menu of the prefix keys bound in tmux.conf and jump-history.conf,
one row per key with what it does. Pressing the key in the menu, or picking the
row, runs that binding.

What a key does is its `bind -N` note, the same text tmux's own `prefix + ?`
shows; give every new prefix binding one. The command run is the live binding
from `tmux list-keys`, so the menu always does what the key does now. Keys bound
to the same command as an earlier row (C-m / Enter, the three Alt+Shift+a
spellings) show once.

usage: help_menu.py CLIENT   (the client the menu opens on)
"""

import re
import subprocess
import sys
from pathlib import Path

TMUX_DIR = Path(__file__).resolve().parents[1]
CONF_FILES = [TMUX_DIR / "tmux.conf", TMUX_DIR / "jump-history.conf"]
# bind [-N note] [-r] [-T prefix] KEY ... -- a prefix-table binding.
BIND = re.compile(r"""^\s*bind(?:-key)?\s+(?:-N\s+(?:'[^']*'|"[^"]*")\s+)?(?:-r\s+)?(-T\s+\S+\s+)?(-n\s+)?("[^"]+"|'[^']+'|\S+)\s""")
LIVE = re.compile(r"^bind-key\s+(?:-r\s+)?-T prefix\s+(\S+)\s+(.*)$")
# Not worth a row: this menu itself, Escape (it closes any menu) and the
# User* keys of the Escape shim in jump-history.conf.
SKIP = {"H", "Escape"}


def normal(key):
    """One spelling per key: unquoted, unescaped, modifiers upper-case (c-g -> C-g)."""
    if len(key) > 1 and key[:1] in "\"'" and key[-1:] == key[:1]:
        key = key[1:-1]
    key = re.sub(r"^\\(.)$", r"\1", key)
    return re.sub(r"\b([cms])-", lambda m: m.group(1).upper() + "-", key)


def config_keys():
    """Prefix keys the config files bind, in file order."""
    keys = []
    for conf in CONF_FILES:
        for line in conf.read_text().splitlines():
            match = BIND.match(line)
            if not match or match.group(2) or (match.group(1) and "prefix" not in match.group(1)):
                continue
            key = normal(match.group(3))
            if key not in keys:
                keys.append(key)
    return keys


def tmux_lines(*args):
    return subprocess.run(["tmux", *args], stdout=subprocess.PIPE,
                          universal_newlines=True, check=True).stdout.splitlines()


def main(client):
    commands = {}
    for line in tmux_lines("list-keys", "-T", "prefix"):
        match = LIVE.match(line)
        if match:
            commands[normal(match.group(1))] = match.group(2)
    notes = {}
    for line in tmux_lines("list-keys", "-N", "-T", "prefix"):
        parts = line.split(None, 2)  # "C-b KEY note"
        if len(parts) == 3:
            notes[normal(parts[1])] = parts[2]
    items, shown = [], set()
    for key in config_keys():
        if key in SKIP or key.startswith("User") or key not in commands or commands[key] in shown:
            continue
        shown.add(commands[key])
        # "#" starts a format in menu labels.
        label = f"{key:<7} {notes.get(key, commands[key][:50])}".replace("#", "##")
        items += [label, key, commands[key]]
    subprocess.run(["tmux", "display-menu", "-c", client, "-T", "#[align=centre] 自定义快捷键：prefix + 键 ",
                    "-x", "C", "-y", "C", "--", *items], check=True)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("usage: help_menu.py CLIENT")
    main(sys.argv[1])
