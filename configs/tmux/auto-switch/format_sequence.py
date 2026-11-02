"""The one-line summary of a pane sequence: "1:<label> | 2:<label> | ...", or "empty".

sequence.sh's format_sequence pipes `tmux list-panes -a` rows into this, so a
whole sequence costs one tmux call and one python start. Building each label in
bash took about 11 processes per pane (3 s for 38 panes) and made loading a
long saved list slow. A label is the state symbol, the compact label
(script/compact_ai_label.py), then [session:window].

usage: tmux list-panes -a -F '<fields, tab-separated>' | python3 format_sequence.py "RANKED PANE IDS"
fields: pane_id session_name window_name unread running background pending done woke attribute
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "script"))
from compact_ai_label import compact_label  # noqa: E402


def state_symbol(unread, running, background, pending, done, woke):
    if pending:
        return "⏸ "
    if background == "1" and unread == "1":
        return "◓ "
    if background == "1":
        return "◒ "
    if running == "1":
        return "● "
    if done == "1":
        return "✓ "
    if unread == "1" and woke == "1":
        return "☀ "
    if unread == "1":
        return "◉ "
    return "○ "


def main():
    ranked = sys.argv[1].split()
    panes = {}
    for line in sys.stdin:
        fields = line.rstrip("\n").split("\t")
        panes[fields[0]] = fields[1:]
    out = []
    for pane in ranked:
        if pane not in panes:  # gone since; format_sequence skips dead panes too
            continue
        session, window, unread, running, background, pending, done, woke, attribute = panes[pane]
        label = compact_label(session, window, attribute)
        symbol = state_symbol(unread, running, background, pending, done, woke)
        out.append("{}:{}{} [{}:{}]".format(len(out) + 1, symbol, label, session, window))
    print(" | ".join(out) or "empty")


main()
