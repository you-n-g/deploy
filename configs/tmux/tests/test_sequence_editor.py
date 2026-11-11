"""Sequence preparation against a private tmux server, including edit races."""

import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


TMUX_DIR = Path(__file__).resolve().parents[1]


class SequenceEditorTest(unittest.TestCase):
    def tmux(self, *args):
        return subprocess.check_output(
            [self.tmux_bin, "-S", self.socket, *args], universal_newlines=True).strip()

    def helper(self, *args):
        return subprocess.check_output(
            [sys.executable, str(TMUX_DIR / "auto-switch/sequence_edit.py"), *args],
            env=self.env, universal_newlines=True)

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="tma-sequence-editor-", dir="/tmp")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.socket = str(self.root / "socket")
        self.tmux_bin = shutil.which("tmux")
        self.tmux("-f", "/dev/null", "new-session", "-d", "-s", "test", "sleep 600")
        self.addCleanup(lambda: subprocess.run(
            [self.tmux_bin, "-S", self.socket, "kill-server"], stderr=subprocess.DEVNULL))
        self.first = self.tmux("display-message", "-p", "-t", "test:", "#{pane_id}")
        self.second = self.tmux("new-window", "-d", "-P", "-F", "#{pane_id}",
                                "-t", "test:", "-n", "ordinary", "sleep 600")
        self.ranked = self.first + " " + self.second
        self.tmux("set-option", "-g", "@auto_switch_ranked_panes", self.ranked)
        self.env = dict(os.environ, TMUX=self.socket + ",0,0", TMUX_PANE=self.first,
                        XDG_STATE_HOME=str(self.root / "state"))
        self.output = self.root / "sequence"

    def test_prepare_normalizes_and_preserves_content_and_focus(self):
        self.tmux("set-option", "-g", "@auto_switch_ranked_panes",
                  self.second + " " + self.first + " " + self.second)
        self.tmux("set-option", "-g", "@auto_switch_ranked_panes_note", "备注\n# keep this")
        self.tmux("set-option", "-pq", "-t", self.first, "@ai_agent_attribute", "正在处理")
        self.tmux("set-option", "-pq", "-t", self.first, "@ai_agent_pending", "等结果")
        self.tmux("set-option", "-pq", "-t", self.second, "@ai_agent_unread", "1")
        prepared = self.helper("prepare", str(self.output), self.first).splitlines()
        normalized = self.second + " " + self.first
        self.assertEqual(prepared, [normalized, "2", self.first])
        self.assertEqual(self.tmux("show-option", "-gqv", "@auto_switch_ranked_panes"), normalized)
        content = self.output.read_text()
        for text in ["正在处理", "等结果", "unread", "ordinary", "备注\n# keep this"]:
            self.assertIn(text, content)
        reference = self.root / "reference"
        self.helper("write", normalized, str(reference))
        self.assertEqual(content, reference.read_text())

    def test_focus_uses_ranked_sibling_when_current_pane_is_not_in_sequence(self):
        sibling = self.tmux("split-window", "-d", "-P", "-F", "#{pane_id}",
                           "-t", self.second, "sleep 600")
        self.assertEqual(self.helper("prepare", str(self.output), sibling),
                         self.ranked + "\n2\n\n")

    def test_empty_sequence_opens_at_first_line_and_keeps_note(self):
        self.tmux("set-option", "-g", "@auto_switch_ranked_panes", "")
        self.tmux("set-option", "-g", "@auto_switch_ranked_panes_note", "empty list note")
        self.assertEqual(self.helper("prepare", str(self.output)), "\n1\n\n")
        self.assertIn("empty list note", self.output.read_text())

    def test_unchanged_edit_preserves_updates_that_arrive_while_editor_is_open(self):
        self.helper("prepare", str(self.output), self.first)
        baseline = self.root / "baseline"
        baseline.write_text(self.output.read_text())
        changed_order = self.second + " " + self.first
        self.tmux("set-option", "-g", "@auto_switch_ranked_panes", changed_order)
        self.tmux("set-option", "-g", "@auto_switch_ranked_panes_note", "new note")
        self.tmux("set-option", "-pq", "-t", self.first, "@ai_agent_pending", "new wait")
        result = self.helper("apply", str(self.output), "--base", str(baseline))
        self.assertEqual(result, changed_order)
        self.assertEqual(self.tmux("show-option", "-gqv", "@auto_switch_ranked_panes_note"), "new note")
        self.assertEqual(self.tmux("show-option", "-pqv", "-t", self.first, "@ai_agent_pending"), "new wait")


if __name__ == "__main__":
    unittest.main()
