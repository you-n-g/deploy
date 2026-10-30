"""The one-line summary of a pane sequence: "1:<label> | 2:<label> | ...", or "empty".

sequence.sh's format_sequence pipes `tmux list-panes -a` rows into this, so a
whole sequence costs one tmux call and one python start. Building each label in
bash took about 11 processes per pane (3 s for 38 panes) and made loading a
long saved list slow. A label is the state symbol, the compact label of
script/ai_label.sh (compact_ai_label), then [session:window].

usage: tmux list-panes -a -F '<fields, tab-separated>' | python3 format_sequence.py "RANKED PANE IDS"
fields: pane_id session_name window_name unread running background pending done woke attribute
"""

import re
import sys
import unicodedata


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


def display_prefix(text, max_width):
    used, out = 0, []
    for ch in text:
        w = 0 if unicodedata.combining(ch) else 2 if unicodedata.east_asian_width(ch) in ("F", "W") else 1
        if used + w > max_width:
            break
        out.append(ch)
        used += w
    return "".join(out)


def middle(text):
    return text if len(text) <= 4 else text[:2] + "." + text[-2:]


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
        attribute = re.sub(r"\s+", " ", re.sub(r"#\[[^]]*\]", "", attribute)).strip()
        label = display_prefix(attribute, 10) if attribute else middle(session) + ":" + middle(window)
        symbol = state_symbol(unread, running, background, pending, done, woke)
        out.append("{}:{}{} [{}:{}]".format(len(out) + 1, symbol, label, session, window))
    print(" | ".join(out) or "empty")


main()
