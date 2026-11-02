"""Compact AI pane labels, many at once: one python start for a whole list.

ai_label.sh's compact_ai_label starts python per label, which made the terminal
title (print_terminal_title.sh, run on every agent state change, inside Claude's
5 s hook budget) and the pane list summary (auto-switch/format_sequence.py)
slow. Both use this instead; ai_label.sh keeps the one-off shell form.

A label is the pane's @ai_agent_attribute (tmux #[...] styles stripped) cut to
10 display cells, or, without one, "se.on:wi.ow" from the session and window
names.

usage: printf 'SESSION\tWINDOW\tATTRIBUTE\n...' | python3 compact_ai_label.py   (one label per line)
"""

import re
import sys
import unicodedata


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


def compact_label(session, window, attribute):
    attribute = re.sub(r"\s+", " ", re.sub(r"#\[[^]]*\]", "", attribute)).strip()
    return display_prefix(attribute, 10) if attribute else middle(session) + ":" + middle(window)


if __name__ == "__main__":
    for line in sys.stdin:
        session, window, attribute = line.rstrip("\n").split("\t")
        print(compact_label(session, window, attribute))
