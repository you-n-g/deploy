"""Stale-running timeout must not clear a live turn after a same-second redraw."""

import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
import time
import unittest


TMUX_DIR = Path(__file__).resolve().parents[1]
TRACK_STATE = str(TMUX_DIR / "script/track_ai_agent_state.sh")
TRACK_OUTPUT = str(TMUX_DIR / "state-tracker/tui-output.sh")


class StaleRunningStateTest(unittest.TestCase):
    def tmux(self, *args):
        return subprocess.check_output(
            [self.tmux_bin, "-S", self.socket, *args], universal_newlines=True
        ).strip()

    def wait_for(self, predicate, timeout=6):
        deadline = time.monotonic() + timeout
        while not predicate():
            self.assertLess(time.monotonic(), deadline, "timed out waiting for tracker")
            time.sleep(0.02)

    @staticmethod
    def stop(process):
        if process.poll() is None:
            process.terminate()
        process.wait(timeout=5)

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="tmux-stale-running-test-", dir="/tmp")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.tmux_bin = shutil.which("tmux")
        self.socket = str(self.root / "socket")
        self.tmux("-f", "/dev/null", "new-session", "-d", "-s", "test",
                  "-x", "120", "-y", "40", "/bin/sh")
        self.addCleanup(lambda: subprocess.run(
            [self.tmux_bin, "-S", self.socket, "kill-server"], stderr=subprocess.DEVNULL
        ))
        self.pane = self.tmux("display-message", "-p", "-t", "test:", "#{pane_id}")
        (self.root / "codex").symlink_to("/bin/sleep")
        self.loop_ticks = self.root / "loop-ticks"
        sleep_wrapper = self.root / "sleep"
        sleep_wrapper.write_text(
            '#!/bin/sh\n[ "$1" != 0.6 ] || echo x >> "$TEST_LOOP_TICKS"\nexec /bin/sleep "$@"\n'
        )
        sleep_wrapper.chmod(0o755)
        self.state_log = self.root / "state.log"
        self.env = dict(
            os.environ,
            TMUX=self.socket + ",0,0",
            TMUX_PANE=self.pane,
            PATH=str(self.root) + os.pathsep + os.environ["PATH"],
            AI_AGENT_STATE_LOG=str(self.state_log),
            AI_AGENT_PROMPT_LOG=str(self.root / "prompts.jsonl"),
            AI_AGENT_PROMPT="",
            TMUX_AI_STATE_TRACKER_LOCK_DIR=self.temp.name,
            TMUX_AI_STATE_TRACKER_INTERVAL="0.6",
            TMUX_AI_STATE_TRACKER_RUNNING_IDLE_AFTER="1",
            TMUX_AI_STATE_TRACKER_CAPTURE_EVERY="60",
            TEST_LOOP_TICKS=str(self.loop_ticks),
        )
        self.tmux("set-option", "-p", "-t", self.pane, "@ai_agent_attribute", "test")

    def tick_count(self):
        return len(self.loop_ticks.read_text().splitlines()) if self.loop_ticks.exists() else 0

    def option(self, name):
        return self.tmux("show-option", "-pqv", "-t", self.pane, name)

    @staticmethod
    def align_to_fresh_second():
        start = int(time.time())
        while int(time.time()) == start:
            time.sleep(0.005)
        return int(time.time())

    def start_tracker(self):
        process = subprocess.Popen(
            [TRACK_OUTPUT, self.pane], env=self.env,
            stdout=subprocess.DEVNULL, stderr=subprocess.PIPE,
        )
        self.addCleanup(process.stderr.close)
        self.addCleanup(self.stop, process)
        return process

    def test_same_second_working_footer_repaint_is_not_marked_stale_idle(self):
        ready = self.root / "paint-working"
        script = self.root / "driver.sh"
        script.write_text(
            "#!/bin/sh\n"
            "{codex} 600 &\n"
            "printf 'Commentary line while footer is temporarily absent\\n'\n"
            "while [ ! -e {ready} ]; do /bin/sleep 0.01; done\n"
            "printf 'Working (14m 16s • esc to interrupt)\\n› Ask Codex to do anything\\n'\n"
            "wait\n".format(
                ready=shlex.quote(str(ready)),
                codex=shlex.quote(str(self.root / "codex")),
            )
        )
        script.chmod(0o755)

        subprocess.check_call([TRACK_STATE, "running", self.pane], env=self.env)
        sec = self.align_to_fresh_second()
        self.tmux("respawn-pane", "-k", "-t", self.pane, str(script))
        tracker = self.start_tracker()
        # Wait for the tracker to capture the mid-redraw commentary frame in `sec`.
        self.wait_for(lambda: self.tick_count() >= 1)
        ready.touch()
        self.wait_for(lambda: "esc to interrupt" in self.tmux("capture-pane", "-p", "-t", self.pane))
        self.assertEqual(int(self.tmux("display-message", "-p", "-t", self.pane, "#{window_activity}")), sec)

        # Advance several tracker ticks past RUNNING_IDLE_AFTER=1s.
        self.wait_for(lambda: self.tick_count() >= 4, timeout=8)
        self.assertIsNone(tracker.poll(), "output tracker exited unexpectedly")
        self.assertEqual(self.option("@ai_agent_running"), "1")
        self.assertNotIn("stale-running-idle", self.state_log.read_text())

    def test_same_second_goal_continuation_resumes_running_without_waiting_capture_every(self):
        ready = self.root / "paint-goal"
        script = self.root / "driver-goal.sh"
        script.write_text(
            "#!/bin/sh\n"
            "{codex} 600 &\n"
            "printf '› Ask Codex to do anything\\n'\n"
            "while [ ! -e {ready} ]; do /bin/sleep 0.01; done\n"
            "printf 'Working (1s • esc to interrupt)\\nPursuing goal (5m)\\n'\n"
            "wait\n".format(
                ready=shlex.quote(str(ready)),
                codex=shlex.quote(str(self.root / "codex")),
            )
        )
        script.chmod(0o755)

        subprocess.check_call([TRACK_STATE, "init", self.pane], env=self.env)
        sec = self.align_to_fresh_second()
        self.tmux("respawn-pane", "-k", "-t", self.pane, str(script))
        self.start_tracker()
        self.wait_for(lambda: self.tick_count() >= 1)
        ready.touch()
        self.wait_for(lambda: "Pursuing goal" in self.tmux("capture-pane", "-p", "-t", self.pane))
        self.assertEqual(int(self.tmux("display-message", "-p", "-t", self.pane, "#{window_activity}")), sec)

        # Must recover on the next second's settled capture, not CAPTURE_EVERY=60s.
        self.wait_for(
            lambda: self.tmux("show-option", "-gqv", "@ai_agent_event_source") == "tui-output:goal-running",
            timeout=4,
        )
        self.assertEqual(self.option("@ai_agent_running"), "1")

    def test_genuine_interrupt_without_working_footer_becomes_idle_after_timeout(self):
        script = self.root / "driver-interrupted.sh"
        script.write_text(
            "#!/bin/sh\n"
            "printf 'Conversation interrupted\\n› Ask Codex to do anything\\n'\n"
            "exec {} 600\n".format(shlex.quote(str(self.root / "codex")))
        )
        script.chmod(0o755)

        self.tmux("respawn-pane", "-k", "-t", self.pane, str(script))
        subprocess.check_call([TRACK_STATE, "running", self.pane], env=self.env)
        self.start_tracker()
        self.wait_for(lambda: self.option("@ai_agent_running") == "0", timeout=5)
        self.assertIn("source=tui-output:stale-running-idle", self.state_log.read_text())


if __name__ == "__main__":
    unittest.main()
