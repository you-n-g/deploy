"""Pinning the user's latest input at the top of a window while ignoring TMA messages."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import unittest


TMUX_DIR = Path(__file__).resolve().parents[1]
PIN_SCRIPT = str(TMUX_DIR / "script/pin_last_input.py")


class PinLastInputTest(unittest.TestCase):
    def tmux(self, *args):
        return subprocess.check_output(
            [self.tmux_bin, "-S", self.socket, *args], universal_newlines=True
        ).strip()

    def wait_for(self, predicate, timeout=5):
        deadline = time.monotonic() + timeout
        while not predicate():
            self.assertLess(time.monotonic(), deadline, "pin_last_input did not reach expected state")
            time.sleep(0.04)

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="tmux-pin-input-test-", dir="/tmp")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.socket = str(self.root / "socket")
        self.log = self.root / "prompts.jsonl"
        self.tmux_bin = shutil.which("tmux")
        self.tmux("-f", "/dev/null", "new-session", "-d", "-s", "work", "-x", "120", "-y", "40", "/bin/sh")
        self.addCleanup(lambda: subprocess.run(
            [self.tmux_bin, "-S", self.socket, "kill-server"], stderr=subprocess.DEVNULL
        ))
        self.pane = self.tmux("display-message", "-p", "-t", "work:", "#{pane_id}")
        self.env = dict(os.environ, TMUX=self.socket + ",0,0", AI_AGENT_PROMPT_LOG=str(self.log))

    def append_row(self, prompt, sender="user", pane=None, time_str="2026-11-15T22:15:00-0600"):
        row = {
            "time": time_str,
            "pane": pane or self.pane,
            "target": "work:0.0",
            "window": "main",
            "sender": sender,
            "prompt": prompt,
        }
        with self.log.open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(row, ensure_ascii=False) + "\n")

    def pin_cmd(self, subcmd, *args, check=True):
        return subprocess.run(
            [sys.executable, PIN_SCRIPT, subcmd, "--socket", self.socket, "--log", str(self.log), *args],
            env=self.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            universal_newlines=True, check=check,
        )

    def pinned_panes(self):
        out = self.tmux("list-panes", "-t", "work:", "-f", "#{==:#{@pinned_last_input},1}", "-F", "#{pane_id}")
        return out.splitlines() if out else []

    def test_filters_out_tma_and_automated_prompts(self):
        self.append_row("My real instruction to the agent.", sender="user", time_str="2026-11-15T21:00:00-0600")
        self.append_row("⟦TMA⟧ worker.0 → main.0\n\nSub-agent finished batch 1.", sender="tma")
        self.append_row("/goal keep going\n\n⟦TMA⟧ orchestrator.0 → main.0", sender="user")
        self.append_row("请关注这个 TMA：work:1.0（worker）已经停下来并有新的更新。", sender="user")
        self.append_row("<task-notification>\n<status>completed</status>", sender="user")
        self.append_row("watch-target 第3轮轮询", sender="user")
        self.append_row("Other pane's prompt", sender="user", pane="%999999")

        res = self.pin_cmd("query", self.pane)
        data = json.loads(res.stdout)
        self.assertEqual(data["prompt"], "My real instruction to the agent.")
        self.assertEqual(data["time"], "21:00")

    def test_toggle_pins_unfocused_top_float_auto_updates_on_user_input_and_unpins(self):
        # Empty history via tmux run-shell shows a status message without view-mode or float.
        self.tmux("run-shell", "{} {} toggle --socket {} --log {} --tmux-menu {}".format(
            sys.executable, PIN_SCRIPT, self.socket, self.log, self.pane
        ))
        time.sleep(0.15)
        self.assertEqual(self.pinned_panes(), [])
        self.assertEqual(self.tmux("display-message", "-p", "-t", self.pane, "#{pane_in_mode}"), "0")

        # Record a 1-line user prompt + a trailing TMA message; toggle ON.
        self.append_row("Check holdout metrics first.", sender="user", time_str="2026-11-15T22:10:00-0600")
        self.append_row("⟦TMA⟧ worker.0 → main.0\n\nIgnore this TMA update.", sender="tma")
        self.pin_cmd("toggle", "--tmux-menu", self.pane)
        self.wait_for(lambda: len(self.pinned_panes()) == 1)
        fp = self.pinned_panes()[0]

        # Unfocused, at the very top of the window, exact 1-row inner height, zero scrollback.
        meta = self.tmux("display-message", "-p", "-t", fp,
                         "#{pane_active}|#{pane_top}|#{pane_height}|#{history_size}|#{@jump-history-skip}")
        self.assertEqual(meta, "0|1|1|0|1")
        self.assertEqual(self.tmux("display-message", "-p", "-t", self.pane, "#{pane_active}"), "1")
        self.wait_for(lambda: "Check holdout metrics first." in self.tmux("capture-pane", "-p", "-t", fp))
        self.assertNotIn("Ignore this TMA update", self.tmux("capture-pane", "-p", "-t", fp))

        # Another incoming TMA message does NOT replace the pinned user input;
        # a new multi-line human input updates the text AND expands height automatically.
        time.sleep(1.05)
        self.append_row("⟦TMA⟧ worker.1 → main.0\n\nAnother agent report.", sender="tma")
        time.sleep(1.2)
        self.assertIn("Check holdout metrics first.", self.tmux("capture-pane", "-p", "-t", fp))

        self.append_row("Line one of new plan.\nLine two of new plan.\nLine three of new plan.",
                        sender="user", time_str="2026-11-15T22:20:00-0600")
        self.wait_for(lambda: "Line three of new plan." in self.tmux("capture-pane", "-p", "-t", fp), timeout=5)
        self.assertEqual(self.tmux("display-message", "-p", "-t", fp, "#{pane_height}|#{history_size}"), "3|0")

        # Toggle again unpins cleanly.
        self.pin_cmd("toggle", "--tmux-menu", self.pane)
        self.wait_for(lambda: self.pinned_panes() == [])


if __name__ == "__main__":
    unittest.main()
