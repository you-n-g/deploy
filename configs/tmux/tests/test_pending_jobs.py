"""Pending waits wake correctly and their cancellation never opens tmux view-mode."""

import os
from pathlib import Path
import signal
import subprocess
import tempfile
import time
import unittest


TMUX_DIR = Path(__file__).resolve().parents[1]
PEND = str(TMUX_DIR / "script/pend_until.sh")
TRACK = str(TMUX_DIR / "script/track_ai_agent_state.sh")


class PendingJobsTest(unittest.TestCase):
    def tmux(self, *args):
        return subprocess.check_output(
            ["tmux", "-S", self.socket, *args], env=self.env, universal_newlines=True
        ).strip()

    def wait_for(self, predicate):
        deadline = time.monotonic() + 10
        while not predicate():
            self.assertLess(time.monotonic(), deadline, "pending job did not reach expected state")
            time.sleep(0.05)

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="tmux-pending-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.socket = str(self.root / "socket")
        self.env = dict(
            os.environ, TMUX=self.socket + ",0,0", TEST_PEND_CASE=self.temp.name,
            AI_AGENT_STATE_LOG=str(self.root / "state.log"),
            AI_AGENT_PROMPT_LOG=str(self.root / "prompts.jsonl"), AI_AGENT_PROMPT="",
        )
        self.tmux("-f", "/dev/null", "new-session", "-d", "-s", "test", "/bin/sh")
        self.addCleanup(lambda: subprocess.run(
            ["tmux", "-S", self.socket, "kill-server"], stderr=subprocess.DEVNULL
        ))
        self.pane = self.tmux("display-message", "-p", "-t", "test:", "#{pane_id}")
        self.env["TMUX_PANE"] = self.pane
        self.target = self.tmux("new-window", "-d", "-t", "test:", "-P", "-F", "#{pane_id}",
                                "-n", "target's $literal", "/bin/sleep 600")
        for pane in (self.pane, self.target):
            self.tmux("set-option", "-p", "-t", pane, "@ai_agent_attribute", "test task")
        subprocess.check_call([TRACK, "running", self.target], env=self.env)
        self.process = subprocess.Popen(["/bin/sleep", "600"])
        self.addCleanup(self.stop_target)
        # Detached waits outlive their launcher/server; explicitly clean up
        # only jobs carrying this private server's test marker.
        self.addCleanup(self.stop_runners)

    def stop_target(self):
        if self.process.poll() is None:
            self.process.terminate()
        self.process.wait(timeout=5)

    def runners(self):
        found = []
        rows = subprocess.check_output(
            ["ps", "-u", str(os.getuid()), "-ww", "-o", "pid=,args="], universal_newlines=True
        )
        marker = ("TEST_PEND_CASE=" + self.temp.name).encode()
        for row in rows.splitlines():
            pid, command = row.strip().split(None, 1)
            if PEND not in command or "--expire" not in command:
                continue
            try:
                environ = (Path("/proc") / pid / "environ").read_bytes().split(b"\0")
            except (FileNotFoundError, ProcessLookupError):
                continue
            if marker in environ:
                found.append(int(pid))
        return found

    def stop_runners(self):
        pids = self.runners()
        descendants = []
        for pid in pids:
            children = Path("/proc") / str(pid) / "task" / str(pid) / "children"
            try:
                descendants.extend(int(child) for child in children.read_text().split())
            except (FileNotFoundError, ProcessLookupError):
                continue
        for pid in pids + descendants:
            try:
                os.kill(pid, signal.SIGTERM)
            except ProcessLookupError:
                continue
        self.wait_for(lambda: not self.runners())

    def pend(self, mode="pid", timeout="60s"):
        target = str(self.process.pid) if mode == "pid" else self.target
        subprocess.check_call([PEND, "--timeout", timeout, mode, self.pane, target], env=self.env)

    def pending(self):
        return self.tmux("show-option", "-pqv", "-t", self.pane, "@ai_agent_pending")

    def test_cancelling_each_kind_of_wait_keeps_the_user_pane_out_of_view_mode(self):
        for mode in ("pid", "idle", "done"):
            with self.subTest(mode=mode):
                self.pend(mode)
                self.wait_for(lambda: len(self.runners()) == (2 if mode == "pid" else 1))
                reason = self.pending()
                self.assertTrue(reason)
                self.stop_runners()
                # Let tmux process completed jobs before inspecting its screen.
                self.tmux("run-shell", "true")
                self.assertEqual(self.tmux("display-message", "-p", "-t", self.pane,
                                           "#{pane_in_mode}"), "0")
                self.assertEqual(self.pending(), reason)

    def test_pid_exit_releases_pending(self):
        self.pend()
        self.wait_for(lambda: len(self.runners()) == 2)
        self.stop_target()
        self.wait_for(lambda: self.pending() == "")
        log = (self.root / "state.log").read_text()
        self.assertIn("source=pid-exit-of:{} state=wake".format(self.process.pid), log)

    def test_timeout_releases_pending_while_target_is_alive(self):
        self.pend(timeout="1s")
        self.wait_for(lambda: self.pending() == "")
        self.assertIsNone(self.process.poll())
        self.assertIn("source=pend-timeout state=wake", (self.root / "state.log").read_text())

    def test_old_timeout_cannot_release_a_new_wait(self):
        self.pend(mode="idle", timeout="1s")
        self.wait_for(lambda: len(self.runners()) == 1)
        subprocess.check_call([TRACK, "pending", self.pane, "replacement wait"], env=self.env)
        self.wait_for(lambda: not self.runners())
        self.assertEqual(self.pending(), "replacement wait")


if __name__ == "__main__":
    unittest.main()
