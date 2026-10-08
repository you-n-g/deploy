"""Floating panes go through script/new_float_pane.sh, which keeps tmux 3.7b's
zoomed-window crash away. Runs a private tmux server, not the user's."""

import os
from pathlib import Path
import re
import subprocess
import tempfile
import time
import unittest


TMUX_DIR = Path(__file__).resolve().parents[1]
REPO = TMUX_DIR.parents[1]
SCRIPT = str(TMUX_DIR / "script/new_float_pane.sh")
NEW_PANE = re.compile(r"\bnew-pane\b")


class NoDirectNewPaneTest(unittest.TestCase):
    def test_only_the_helper_calls_new_pane(self):
        offenders = []
        for top in ("configs", "helper_scripts"):
            for path in (REPO / top).rglob("*"):
                if not path.is_file() or path.suffix == ".md" or "tests" in path.parts \
                        or path == Path(SCRIPT):
                    continue
                try:
                    text = path.read_text()
                except (UnicodeDecodeError, PermissionError):
                    continue
                for number, line in enumerate(text.splitlines(), 1):
                    code = line.strip()
                    if code.startswith("#") or "@pet-new-pane-key" in code:
                        continue
                    if NEW_PANE.search(code):
                        offenders.append(f"{path.relative_to(REPO)}:{number}: {code}")
        self.assertEqual(offenders, [], "create floating panes with script/new_float_pane.sh")


class NewFloatPaneTest(unittest.TestCase):
    def tmux(self, *args):
        return subprocess.check_output(
            ["tmux", "-S", self.socket, *args], universal_newlines=True
        ).strip()

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="tmux-float-test-")
        self.addCleanup(self.temp.cleanup)
        self.socket = self.temp.name + "/socket"
        # A crash in these tests would otherwise drop a core file into the cwd.
        self.tmux("-f", "/dev/null", "new-session", "-d", "-s", "t", "-x", "120", "-y", "40", "/bin/sh")
        self.addCleanup(lambda: subprocess.run(["tmux", "-S", self.socket, "kill-server"],
                                               stderr=subprocess.DEVNULL))
        self.base = self.tmux("display-message", "-p", "-t", "t:", "#{pane_id}")
        self.tmux("split-window", "-d", "-t", self.base, "/bin/sh")
        self.tmux("resize-pane", "-Z", "-t", self.base)

    def run_script(self, *args):
        return subprocess.run(
            [SCRIPT, *args], universal_newlines=True, stdout=subprocess.PIPE,
            env=dict(os.environ, TMUX=self.socket + ",0,0"), cwd=self.temp.name,
        )

    def floats(self):
        return self.tmux("list-panes", "-t", "t:", "-f", "#{pane_floating_flag}", "-F", "#{pane_id}").split()

    def zoomed(self):
        return self.tmux("display-message", "-p", "-t", "t:", "#{window_zoomed_flag}") == "1"

    def test_zoomed_window_is_unzoomed_and_closing_the_float_is_safe(self):
        result = self.run_script(self.base, "-d", "-x", "30", "-y", "8", "-X", "1", "-Y", "1", "sleep 0.5")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(self.floats(), [result.stdout.strip()])
        self.assertFalse(self.zoomed())
        # The float exits by itself; on the buggy path this kills the server.
        time.sleep(1.5)
        self.assertEqual(self.floats(), [])
        self.tmux("resize-pane", "-Z", "-t", self.base)
        self.assertTrue(self.zoomed())

    def test_skip_if_zoomed_creates_nothing(self):
        result = self.run_script("--skip-if-zoomed", self.base, "-d", "-x", "30", "-y", "8",
                                 "-X", "1", "-Y", "1", "sleep 5")
        self.assertEqual(result.returncode, 3)
        self.assertEqual(self.floats(), [])
        self.assertTrue(self.zoomed())

    def test_zoomed_message_creates_nothing_and_shows_the_text(self):
        result = self.run_script("--zoomed-message", "hello zoom", self.base, "-d", "-x", "30",
                                 "-y", "8", "-X", "1", "-Y", "1", "sleep 5")
        self.assertEqual(result.returncode, 3)
        self.assertEqual(self.floats(), [])
        self.assertTrue(self.zoomed())

    def test_unzoomed_window_gets_the_float(self):
        self.tmux("resize-pane", "-Z", "-t", self.base)
        result = self.run_script("--skip-if-zoomed", self.base, "-d", "-x", "30", "-y", "8",
                                 "-X", "1", "-Y", "1", "sleep 5")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(self.floats(), [result.stdout.strip()])


if __name__ == "__main__":
    unittest.main()
