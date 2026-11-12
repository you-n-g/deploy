"""External prompt editing blocks until the floating Vim saves, exits or is closed."""

import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest


TMUX_DIR = Path(__file__).resolve().parents[1]
REPO = TMUX_DIR.parents[1]
VIM = str(REPO / "helper_scripts/bin/vim-fast")
FLOAT = str(TMUX_DIR / "script/run_in_float.sh")


class FloatEditorTest(unittest.TestCase):
    def tmux(self, *args):
        return subprocess.check_output(
            ["tmux", "-S", self.socket, *args], universal_newlines=True
        ).strip()

    def wait_for(self, predicate):
        deadline = time.monotonic() + 5
        while not predicate():
            self.assertLess(time.monotonic(), deadline, "floating editor did not reach expected state")
            time.sleep(0.03)

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="tmux-float-editor-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.socket = str(self.root / "socket")
        self.tmux("-f", "/dev/null", "new-session", "-d", "-s", "test",
                  "-x", "120", "-y", "40", "/bin/sh")
        self.addCleanup(lambda: subprocess.run(
            ["tmux", "-S", self.socket, "kill-server"], stderr=subprocess.DEVNULL
        ))
        self.pane = self.tmux("display-message", "-p", "-t", "test:", "#{pane_id}")
        self.env = dict(os.environ, TMUX=self.socket + ",0,0", TMUX_PANE=self.pane,
                        TMPDIR=self.temp.name)
        self.file = self.root / "prompt's $(literal) 中文.md"
        self.file.write_text("draft prompt\n")

    @staticmethod
    def stop(process):
        if process.poll() is None:
            process.terminate()
        process.wait(timeout=5)

    def start(self, command):
        process = subprocess.Popen(command, cwd=self.temp.name, env=self.env,
                                   stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        self.addCleanup(process.stderr.close)
        self.addCleanup(self.stop, process)
        return process

    def floats(self):
        return self.tmux("list-panes", "-t", self.pane, "-f", "#{pane_floating_flag}",
                         "-F", "#{pane_id}").splitlines()

    def start_vim(self):
        process = self.start([VIM, self.file.name])
        self.wait_for(lambda: len(self.floats()) == 1)
        floating = self.floats()[0]
        self.wait_for(lambda: "draft prompt" in self.tmux("capture-pane", "-p", "-t", floating))
        return process, floating

    def assert_clean(self):
        self.assertEqual(self.floats(), [])
        self.assertEqual(list(self.root.glob("tmux-float-editor.*")), [])

    def test_zoomed_prompt_opens_small_float_and_returns_only_after_save(self):
        self.tmux("split-window", "-d", "-t", self.pane, "/bin/sh")
        self.tmux("resize-pane", "-Z", "-t", self.pane)
        process, floating = self.start_vim()
        self.assertIsNone(process.poll())
        self.assertEqual(self.tmux("display-message", "-p", "-t", floating,
                                   "#{pane_width}|#{pane_height}|#{pane_active}|#{@jump-history-skip}"),
                         "100|20|1|1")
        self.tmux("send-keys", "-t", floating, "gg0C", "edited prompt", "Escape")
        self.assertEqual(self.file.read_text(), "draft prompt\n")
        self.assertIsNone(process.poll())
        self.tmux("send-keys", "-t", floating, ":wq", "Enter")
        self.assertEqual(process.wait(timeout=5), 0, process.stderr.read().decode())
        self.assertEqual(self.file.read_text(), "edited prompt\n")
        self.assertEqual(self.tmux("display-message", "-p", "-t", "test:", "#{pane_id}"), self.pane)
        self.assert_clean()

    def test_closing_float_unblocks_caller_without_changing_prompt(self):
        process, floating = self.start_vim()
        self.tmux("kill-pane", "-t", floating)
        self.assertNotEqual(process.wait(timeout=5), 0)
        self.assertEqual(self.file.read_text(), "draft prompt\n")
        self.assert_clean()

    def test_command_failure_reaches_external_editor_caller(self):
        process = self.start([FLOAT, self.pane, "/bin/sh", "-c", "exit 7"])
        self.assertEqual(process.wait(timeout=5), 7, process.stderr.read().decode())
        self.assert_clean()

    def test_outside_tmux_keeps_direct_editor_behavior(self):
        env = dict(self.env)
        env.pop("TMUX")
        env.pop("TMUX_PANE")
        subprocess.check_call(
            [VIM, "-es", "-c", "normal! gg0Cdirect edit", "-c", "wq", self.file.name],
            cwd=self.temp.name, env=env,
        )
        self.assertEqual(self.file.read_text(), "direct edit\n")
        self.assert_clean()


if __name__ == "__main__":
    unittest.main()
