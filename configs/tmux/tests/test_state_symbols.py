"""Every place that draws the AI pane state symbols draws all of them.

A new state tends to reach the window list and get missed in the terminal
title or the sequence editor; README.md's "AI pane 状态标识" lists the places.
This catches the gap mechanically: a file that renders one symbol of a family
must render the rest of the family too.
"""

from pathlib import Path
import unittest


TMUX_DIR = Path(__file__).resolve().parents[1]

# symbol -> the symbols that must appear wherever it does
FAMILIES = {
    "◉": ["☀"],  # unread, and unread because released from pending (@ai_agent_woke)
}
# The sequence editor shows states as words, not symbols.
WORD_FILES = {
    "auto-switch/sequence_edit.py": ['"unread"', '"woke"'],
    "auto-switch/sequence.sh": ["AutoSwitchStateUnread", "AutoSwitchStateWoke"],
}


class StateSymbolTest(unittest.TestCase):
    def test_symbol_families_are_complete(self):
        missing = []
        for path in TMUX_DIR.rglob("*"):
            if not path.is_file() or "tests" in path.parts or path.suffix in (".md", ".pyc"):
                continue
            try:
                text = path.read_text()
            except (UnicodeDecodeError, PermissionError):
                continue
            for symbol, family in FAMILIES.items():
                if symbol in text:
                    missing += [f"{path.relative_to(TMUX_DIR)}: {symbol} without {s}" for s in family if s not in text]
        self.assertEqual(missing, [], "see README.md, AI pane 状态标识")

    def test_sequence_editor_knows_every_state(self):
        missing = []
        for name, words in WORD_FILES.items():
            text = (TMUX_DIR / name).read_text()
            missing += [f"{name}: {word}" for word in words if word not in text]
        self.assertEqual(missing, [], "see README.md, AI pane 状态标识")


if __name__ == "__main__":
    unittest.main()
