"""Stop with a watch-target wakeup preserves unread, on a private tmux server."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import unittest


TMUX_DIR = Path(__file__).resolve().parents[1]
TRACKER = str(TMUX_DIR / "script/track_ai_agent_state.sh")


class BackgroundStateTest(unittest.TestCase):
    def tmux(self, *args):
        return subprocess.check_output(
            [self.tmux_bin, "-S", self.socket, *args], universal_newlines=True
        ).strip()

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="tmux-background-test-")
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        self.tmux_bin = shutil.which("tmux")
        self.socket = str(root / "socket")
        self.tmux("-f", "/dev/null", "new-session", "-d", "-s", "test", "/bin/sh")
        self.addCleanup(lambda: subprocess.run(
            [self.tmux_bin, "-S", self.socket, "kill-server"], stderr=subprocess.DEVNULL
        ))
        self.pane = self.tmux("display-message", "-p", "-t", "test:", "#{pane_id}")
        self.trace = root / "states.txt"
        self.env = dict(
            os.environ,
            TMUX=self.socket + ",0,0",
            TMUX_PANE=self.pane,
            PATH=str(root) + os.pathsep + os.environ["PATH"],
            AI_AGENT_STATE_LOG=str(root / "state.log"),
            AI_AGENT_PROMPT_LOG=str(root / "prompts.jsonl"),
            AI_AGENT_STATE_SOURCE="codex-hook:stop",
            AI_AGENT_PROMPT="",
            TEST_TMUX_BIN=self.tmux_bin,
            TEST_PANE=self.pane,
            TEST_TRACE=str(self.trace),
            TEST_WATCH_PANE=self.pane,
        )
        # Stub only the external process listing; never launch a real wakeup
        # that could submit input to a pane on the user's tmux server.
        ps = root / "ps"
        ps.write_text('#!/bin/sh\nprintf "123 bash /test/run-wakeup.sh --pane %s\\n" "$TEST_WATCH_PANE"\n')
        ps.chmod(0o755)
        # Observe what a concurrent status tracker can see after each write.
        tmux = root / "tmux"
        tmux.write_text('''#!/bin/sh
set -e
"$TEST_TMUX_BIN" "$@"
case "$1" in
  set-option|set)
    "$TEST_TMUX_BIN" display-message -p -t "$TEST_PANE" \\
      '#{@ai_agent_running}|#{@ai_agent_background}' >>"$TEST_TRACE"
    ;;
esac
''')
        tmux.chmod(0o755)
        for key, value in {
            "@ai_agent_running": "1",
            "@ai_agent_unread": "0",
            "@ai_agent_attribute": "test task",
        }.items():
            self.option(key, value)

    def option(self, name, value):
        self.tmux("set-option", "-p", "-t", self.pane, name, value)

    def state(self):
        return self.tmux(
            "display-message", "-p", "-t", self.pane,
            "#{@ai_agent_running}|#{@ai_agent_background}|#{@ai_agent_unread}",
        )

    def track(self, state="idle"):
        subprocess.check_call([TRACKER, state, self.pane], env=self.env, cwd=self.temp.name)

    def test_unseen_stop_with_wakeup_is_background_and_unread(self):
        self.track()
        self.assertEqual(self.state(), "0|1|1")

    def test_transition_never_looks_idle_while_wakeup_is_pending(self):
        self.track()
        states = self.trace.read_text().splitlines()
        self.assertTrue(states)
        self.assertTrue(all(r == "1" or b == "1" for r, b in (s.split("|") for s in states)), states)

    def test_muted_stop_with_wakeup_stays_read(self):
        self.option("@ai_agent_muted", "1")
        self.track()
        self.assertEqual(self.state(), "0|1|0")

    def test_visible_stop_with_wakeup_stays_read(self):
        client = subprocess.Popen(
            [self.tmux_bin, "-S", self.socket, "-C", "attach-session", "-t", "test"],
            stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        self.addCleanup(client.wait, 5)
        self.addCleanup(client.stdin.close)
        deadline = time.monotonic() + 5
        while self.tmux("display-message", "-p", "-t", self.pane, "#{session_attached}") == "0":
            self.assertLess(time.monotonic(), deadline)
            time.sleep(0.05)
        self.track()
        self.assertEqual(self.state(), "0|1|0")

    def test_native_background_uses_the_same_unread_rule(self):
        self.track("background")
        self.assertEqual(self.state(), "0|1|1")

    def test_stop_without_wakeup_returns_to_idle(self):
        self.env["TEST_WATCH_PANE"] = "%999999"
        self.option("@ai_agent_background", "1")
        self.track()
        self.assertEqual(self.state(), "0||1")


if __name__ == "__main__":
    unittest.main()
