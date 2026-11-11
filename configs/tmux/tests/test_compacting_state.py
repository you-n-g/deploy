"""Compaction starts auto-switch before UserPromptSubmit, on a private server."""

import json
import os
from pathlib import Path
import pty
import shlex
import shutil
import subprocess
import tempfile
import time
import unittest


TMUX_DIR = Path(__file__).resolve().parents[1]
TRACK_STATE = str(TMUX_DIR / "script/track_ai_agent_state.sh")
TRACK_OUTPUT = str(TMUX_DIR / "state-tracker/tui-output.sh")
WAIT_SUBMIT = str(TMUX_DIR / "auto-switch/wait-until-submitted.sh")
COMPACTING = "• Compacting context (12s • esc to interrupt)"


class CompactingStateTest(unittest.TestCase):
    def tmux(self, *args):
        return subprocess.check_output(
            [self.tmux_bin, "-S", self.socket, *args], universal_newlines=True
        ).strip()

    def wait_for(self, predicate):
        deadline = time.monotonic() + 5
        while not predicate():
            self.assertLess(time.monotonic(), deadline, "timed out waiting for tracker")
            time.sleep(0.02)

    @staticmethod
    def stop(process):
        if process.poll() is None:
            process.terminate()
        process.wait(timeout=5)

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="tmux-compact-test-")
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
        self.env = dict(
            os.environ, TMUX=self.socket + ",0,0", TMUX_PANE=self.pane,
            PATH=str(self.root) + os.pathsep + os.environ["PATH"],
            AI_AGENT_STATE_LOG=str(self.root / "state.log"),
            AI_AGENT_PROMPT_LOG=str(self.root / "prompts.jsonl"), AI_AGENT_PROMPT="",
            TMUX_AI_STATE_TRACKER_LOCK_DIR=self.temp.name,
            TMUX_AI_STATE_TRACKER_INTERVAL="0.05",
            TEST_TMUX_BIN=self.tmux_bin,
            TEST_WAITER_READY=str(self.root / "waiter-ready"),
            TEST_LOOP_DONE=str(self.root / "loop-done"),
        )
        # Synchronize with the real wait-for and tracker loop, without sleeps
        # guessing when either subprocess has started.
        for name, script in {
            "tmux": '#!/bin/sh\n[ "$1" != wait-for ] || touch "$TEST_WAITER_READY"\nexec "$TEST_TMUX_BIN" "$@"\n',
            "sleep": '#!/bin/sh\ntouch "$TEST_LOOP_DONE"\nexec /bin/sleep "$@"\n',
        }.items():
            path = self.root / name
            path.write_text(script)
            path.chmod(0o755)
        (self.root / "codex").symlink_to("/bin/sleep")
        self.tmux("set-option", "-p", "-t", self.pane, "@ai_agent_attribute", "test")
        # A terminal client (not a control client) makes this the user's pane
        # for the production auto-switch waiter.
        master, slave = pty.openpty()
        self.addCleanup(os.close, master)
        client = subprocess.Popen(
            [self.tmux_bin, "-S", self.socket, "attach-session", "-t", "test"],
            stdin=slave, stdout=slave, stderr=slave,
            env=dict(self.env, TERM="xterm-256color"),
        )
        os.close(slave)
        self.addCleanup(self.stop, client)
        self.wait_for(lambda: self.tmux("list-clients", "-F", "#{pane_id}") == self.pane)

    def start_tracker(self, screen):
        fixture = self.root / "screen.txt"
        fixture.write_text(screen + "\n")
        command = "cat {}; exec {} 600".format(
            shlex.quote(str(fixture)), shlex.quote(str(self.root / "codex"))
        )
        self.tmux("respawn-pane", "-k", "-t", self.pane, command)
        process = subprocess.Popen(
            [TRACK_OUTPUT, self.pane], env=self.env,
            stdout=subprocess.DEVNULL, stderr=subprocess.PIPE,
        )
        self.addCleanup(process.stderr.close)
        self.addCleanup(self.stop, process)
        self.wait_for(lambda: (self.root / "loop-done").exists() or process.poll() is not None)
        self.assertIsNone(process.poll(), "output tracker exited")

    def option(self, name):
        return self.tmux("show-option", "-pqv", "-t", self.pane, name)

    def event_seq(self):
        return self.tmux("show-option", "-gqv", "@ai_agent_event_seq")

    def test_compaction_wakes_waiter_and_late_submit_does_not_repeat(self):
        self.tmux("set-option", "-g", "@auto_switch_mode_token", "test-token")
        waiter = subprocess.Popen(
            [WAIT_SUBMIT, "test-token"], env=self.env,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True,
        )
        self.addCleanup(waiter.stdout.close)
        self.addCleanup(waiter.stderr.close)
        self.addCleanup(self.stop, waiter)
        self.wait_for(lambda: (self.root / "waiter-ready").exists())
        self.start_tracker(COMPACTING)
        output, errors = waiter.communicate(timeout=5)
        self.assertEqual(waiter.returncode, 0, errors)
        self.assertEqual(output.strip(), self.pane)
        self.assertEqual(self.option("@ai_agent_running"), "1")
        self.assertEqual(self.event_seq(), "1")
        self.assertEqual(self.tmux("show-option", "-gqv", "@ai_agent_event_source"),
                         "tui-output:compacting")
        subprocess.check_call(
            [TRACK_STATE, "running", self.pane],
            env=dict(self.env, AI_AGENT_STATE_SOURCE="codex-hook:user-prompt-submit",
                     AI_AGENT_PROMPT="Explain the result"),
        )
        self.assertEqual(self.event_seq(), "1")
        rows = (self.root / "prompts.jsonl").read_text().splitlines()
        self.assertEqual([json.loads(row)["prompt"] for row in rows], ["Explain the result"])

    def test_mid_turn_compaction_does_not_publish_another_running_edge(self):
        subprocess.check_call([TRACK_STATE, "running", self.pane], env=self.env)
        seq = self.event_seq()
        self.start_tracker(COMPACTING)
        self.assertEqual(self.option("@ai_agent_running"), "1")
        self.assertEqual(self.event_seq(), seq)

    def test_completed_compaction_is_not_running(self):
        self.start_tracker("• Context compacted · 1m 00s\n› Ask Codex to do anything")
        self.assertNotEqual(self.option("@ai_agent_running"), "1")
        self.assertEqual(self.event_seq(), "")

    def test_mention_with_unrelated_working_footer_is_not_compaction(self):
        self.start_tracker("Compacting context happens before the submit hook.\n"
                           "• Working (12s • esc to interrupt)")
        self.assertNotEqual(self.option("@ai_agent_running"), "1")
        self.assertEqual(self.event_seq(), "")

    def test_pending_compaction_releases_pending_and_emits_running(self):
        subprocess.check_call([TRACK_STATE, "pending", self.pane, "test wait"], env=self.env)
        self.start_tracker(COMPACTING)
        self.assertEqual(self.option("@ai_agent_running"), "1")
        self.assertEqual(self.option("@ai_agent_pending"), "")
        self.assertEqual(self.tmux("show-option", "-gqv", "@ai_agent_event_state"), "running")


if __name__ == "__main__":
    unittest.main()
