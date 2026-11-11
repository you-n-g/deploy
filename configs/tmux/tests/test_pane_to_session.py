"""Moving a pane to another session preserves its window name and live process."""

import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest


SCRIPT = str(Path(__file__).resolve().parents[1] / "script/pane_to_session.sh")
FLOAT_SCRIPT = str(Path(__file__).resolve().parents[1] / "script/new_float_pane.sh")


class PaneToSessionTest(unittest.TestCase):
    def tmux(self, *args):
        return subprocess.check_output(
            ["tmux", "-S", self.socket, *args], universal_newlines=True
        ).strip()

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="tmux-pane-move-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.socket = str(self.root / "socket")
        self.env = dict(os.environ, TMUX=self.socket + ",0,0",
                        PATH=self.temp.name + os.pathsep + os.environ["PATH"])
        self.name = "ResearchLead⎇ Fabel's simplify"
        self.tmux("-f", "/dev/null", "new-session", "-d", "-s", "source", "-n", self.name,
                  "-x", "120", "-y", "40", "/bin/sh")
        self.addCleanup(lambda: subprocess.run(
            ["tmux", "-S", self.socket, "kill-server"], stderr=subprocess.DEVNULL
        ))
        self.pane = self.tmux("display-message", "-p", "-t", "source:", "#{pane_id}")
        self.pid = self.tmux("display-message", "-p", "-t", self.pane, "#{pane_pid}")
        self.tmux("new-session", "-d", "-s", "destination", "-n", "existing", "/bin/sh")
        self.tmux("new-window", "-d", "-t", "destination:7", "-n", "last", "/bin/sh")
        # Choose from the script's actual session list without an interactive fzf.
        fzf = self.root / "fzf"
        fzf.write_text('#!/bin/sh\nawk -F "\\t" \'$1 == "destination" { print; found=1 } END { exit !found }\'\n')
        fzf.chmod(0o755)
        client = subprocess.Popen(
            ["tmux", "-S", self.socket, "-C", "attach-session", "-t", "destination"],
            stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        self.addCleanup(client.wait, 5)
        self.addCleanup(client.stdin.close)
        deadline = time.monotonic() + 5
        while not self.tmux("list-clients", "-F", "#{client_name}"):
            self.assertLess(time.monotonic(), deadline)
            time.sleep(0.02)
        self.client = self.tmux("list-clients", "-F", "#{client_name}")
        self.tmux("switch-client", "-c", self.client, "-t", self.pane)

    def move(self, mode):
        subprocess.check_call([SCRIPT, self.client, self.pane, mode], env=self.env)
        self.assertEqual(self.tmux("display-message", "-p", "-t", self.pane,
                                   "#{session_name}|#{window_index}|#{window_name}|#{pane_pid}"),
                         "destination|8|{}|{}".format(self.name, self.pid))
        self.assertEqual(self.tmux("list-clients", "-F", "#{pane_id}"), self.pane)
        self.assertEqual(self.tmux("show-option", "-wqv", "-t", self.pane, "automatic-rename"), "off")

    def test_picker_float_does_not_lose_the_source_window_name(self):
        picker = subprocess.check_output(
            [FLOAT_SCRIPT, self.pane, "-d", "-x", "60", "-y", "16", "-X", "1", "-Y", "1", "/bin/sleep 600"],
            env=self.env, universal_newlines=True,
        ).strip()
        self.move("pick")
        self.assertEqual(self.tmux("display-message", "-p", "-t", picker, "#{window_name}"), self.name)

    def test_last_session_from_a_split_preserves_name(self):
        sibling = self.tmux("split-window", "-d", "-t", self.pane, "-P", "-F", "#{pane_id}", "/bin/sh")
        self.move("last")
        self.assertEqual(self.tmux("display-message", "-p", "-t", sibling,
                                   "#{session_name}|#{window_name}"), "source|" + self.name)

    def test_last_pane_move_preserves_name_and_client_attachment(self):
        self.move("last")
        self.assertNotIn("source", self.tmux("list-sessions", "-F", "#{session_name}").splitlines())


if __name__ == "__main__":
    unittest.main()
