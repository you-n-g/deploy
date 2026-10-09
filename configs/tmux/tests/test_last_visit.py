"""@last_visit and the "last AI pane" built on it (\\c<what>l in nvim, prefix M-l).
Runs a private tmux server, not the user's."""

import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest


TMUX_DIR = Path(__file__).resolve().parents[1]
LAST_AI_PANE = str(TMUX_DIR / "ai/last_ai_pane.sh")
UPDATE_LAST_VISIT = str(TMUX_DIR / "script/update_last_visit.sh")


class LastVisitTest(unittest.TestCase):
    def tmux(self, *args):
        return subprocess.check_output(
            ["tmux", "-S", self.socket, *args], universal_newlines=True
        ).strip()

    def wait_for(self, predicate):
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            if predicate():
                return
            time.sleep(0.05)
        self.fail("tmux did not reach the expected state within 5 seconds")

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="tmux-last-visit-test-")
        self.addCleanup(self.temp.cleanup)
        self.socket = self.temp.name + "/socket"
        self.env = dict(os.environ, TMUX=self.socket + ",0,0")
        # A process whose comm is "claude" is what _ai_pane_rows takes for an AI pane.
        fake = Path(self.temp.name) / "claude"
        fake.symlink_to("/bin/sleep")
        self.ai = f"{fake} 600"
        self.tmux("-f", "/dev/null", "new-session", "-d", "-s", "one", "-x", "120", "-y", "40", "/bin/sh")
        self.addCleanup(lambda: subprocess.run(["tmux", "-S", self.socket, "kill-server"],
                                               stderr=subprocess.DEVNULL))
        self.here = self.new_ai_window("one")

    def new_ai_window(self, session):
        return self.tmux("new-window", "-d", "-t", session + ":", "-P", "-F", "#{pane_id}", self.ai)

    def last_ai_pane(self):
        result = subprocess.run([LAST_AI_PANE, "--exclude", self.here], env=self.env,
                                stdout=subprocess.PIPE, universal_newlines=True, cwd=self.temp.name)
        if result.returncode != 0:
            return None
        return self.tmux("display-message", "-p", "-t", result.stdout.strip(), "#{pane_id}")

    def test_unvisited_busy_pane_does_not_outrank_a_visited_one(self):
        visited = self.new_ai_window("one")
        busy = self.new_ai_window("one")
        # Visited a minute ago; the other was never visited but its window just
        # had output, which is what a redrawing TUI looks like.
        self.tmux("set-option", "-p", "-t", visited, "@last_visit", str(int(time.time()) - 60))
        self.tmux("send-keys", "-t", busy, "")
        self.assertEqual(self.last_ai_pane(), visited)

    def test_no_visited_pane_is_an_error(self):
        self.new_ai_window("one")
        self.assertIsNone(self.last_ai_pane())

    def test_selection_nobody_sees_is_not_a_visit(self):
        client = subprocess.Popen(
            ["tmux", "-S", self.socket, "-C", "attach-session", "-t", "one"],
            stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        self.addCleanup(client.wait, 5)
        self.addCleanup(client.stdin.close)
        self.wait_for(lambda: self.tmux("list-clients", "-F", "#{client_pid}") == str(client.pid))

        self.tmux("new-session", "-d", "-s", "two", "/bin/sh")
        hidden = self.new_ai_window("two")
        subprocess.check_call([UPDATE_LAST_VISIT, hidden], env=self.env, cwd=self.temp.name)
        self.assertEqual(self.tmux("show-option", "-pqv", "-t", hidden, "@last_visit"), "")

        shown = self.tmux("list-clients", "-F", "#{pane_id}")
        subprocess.check_call([UPDATE_LAST_VISIT, shown], env=self.env, cwd=self.temp.name)
        self.assertNotEqual(self.tmux("show-option", "-pqv", "-t", shown, "@last_visit"), "")


if __name__ == "__main__":
    unittest.main()
