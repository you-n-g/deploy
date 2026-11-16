"""Direct jump to next unread AI pane (prefix + k u)."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "script/switch_to_next_unread.sh"


class SwitchToNextUnreadTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="tmux-next-unread-", dir="/tmp")
        self.addCleanup(self.temp.cleanup)
        self.socket = str(Path(self.temp.name) / "tmux.sock")
        self.tmux_bin = shutil.which("tmux")
        subprocess.run(
            [self.tmux_bin, "-S", self.socket, "-f", "/dev/null", "new-session", "-d", "-s", "work", "-n", "cur", "sleep 600"],
            check=True,
        )
        self.addCleanup(
            lambda: subprocess.run([self.tmux_bin, "-S", self.socket, "kill-server"], stderr=subprocess.DEVNULL)
        )
        self.cur = self.tmux("display-message", "-p", "-t", "work:0.0", "#{pane_id}")
        self.env = dict(os.environ, TMUX="{},0,0".format(self.socket), TMUX_PANE=self.cur)

    def tmux(self, *args):
        return subprocess.check_output(
            [self.tmux_bin, "-S", self.socket, *args], universal_newlines=True
        ).strip()

    def make_window(self, session, name, unread=True, last_visit=None, tma_created=None):
        pane = self.tmux("new-window", "-d", "-t", "{}:".format(session), "-n", name, "-P", "-F", "#{pane_id}", "sleep 600")
        if unread:
            self.tmux("set-option", "-pq", "-t", pane, "@ai_agent_unread", "1")
        if last_visit is not None:
            self.tmux("set-option", "-pq", "-t", pane, "@last_visit", str(last_visit))
        if tma_created is not None:
            self.tmux("set-option", "-wq", "-t", pane, "@tma_created", str(tma_created))
        return pane

    def jump(self, current=None):
        args = [str(SCRIPT), "--client", "", current or self.cur]
        return subprocess.run(
            args, env=self.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True, check=True
        )

    def active_pane(self, session="work"):
        return self.tmux("display-message", "-p", "-t", "{}:".format(session), "#{pane_id}")

    def test_prefers_ranked_then_recent_user_then_agent_and_skips_outranked_states(self):
        agent = self.make_window("work", "sub-agent", last_visit=999, tma_created=1)
        older = self.make_window("work", "older-user", last_visit=100, tma_created=0)
        newer = self.make_window("work", "newer-user", last_visit=300)
        ranked2 = self.make_window("work", "ranked-2", last_visit=50)
        ranked1 = self.make_window("work", "ranked-1", last_visit=10)

        # States that outrank unread must be skipped; background+unread must still be eligible.
        pending = self.make_window("work", "parked", last_visit=1000)
        self.tmux("set-option", "-pq", "-t", pending, "@ai_agent_pending", "等 %1")
        running = self.make_window("work", "busy", last_visit=1000)
        self.tmux("set-option", "-pq", "-t", running, "@ai_agent_running", "1")
        done = self.make_window("work", "finished", last_visit=1000)
        self.tmux("set-option", "-pq", "-t", done, "@ai_agent_done", "1")
        bg_unread = self.make_window("work", "bg-turn-done", last_visit=200)
        self.tmux("set-option", "-pq", "-t", bg_unread, "@ai_agent_background", "1")

        self.tmux("set-option", "-gq", "@auto_switch_ranked_panes", "{} {} {}".format(pending, ranked1, ranked2))

        # 1. Ranked user panes in sequence order (skipping pending).
        self.jump()
        self.assertEqual(self.active_pane(), ranked1)
        self.tmux("set-option", "-pq", "-t", ranked1, "@ai_agent_unread", "0")

        self.jump(ranked1)
        self.assertEqual(self.active_pane(), ranked2)
        self.tmux("set-option", "-pq", "-t", ranked2, "@ai_agent_unread", "0")

        # 2. Unranked user panes by @last_visit desc (including background+unread).
        self.jump(ranked2)
        self.assertEqual(self.active_pane(), newer)
        self.tmux("set-option", "-pq", "-t", newer, "@ai_agent_unread", "0")

        self.jump(newer)
        self.assertEqual(self.active_pane(), bg_unread)
        self.tmux("set-option", "-pq", "-t", bg_unread, "@ai_agent_unread", "0")

        self.jump(bg_unread)
        self.assertEqual(self.active_pane(), older)
        self.tmux("set-option", "-pq", "-t", older, "@ai_agent_unread", "0")

        # 3. @tma_created=1 only after all user unread panes are gone.
        self.jump(older)
        self.assertEqual(self.active_pane(), agent)

    def test_respects_orchestrator_filter_and_session_blacklist(self):
        orch = self.make_window("work", "orchestrator", last_visit=500)
        subprocess.run(
            [self.tmux_bin, "-S", self.socket, "new-session", "-d", "-s", "hidden", "-n", "sec", "sleep 600"],
            check=True,
        )
        hidden_pane = self.tmux("display-message", "-p", "-t", "hidden:0.0", "#{pane_id}")
        self.tmux("set-option", "-pq", "-t", hidden_pane, "@ai_agent_unread", "1")
        self.tmux("set-option", "-pq", "-t", hidden_pane, "@last_visit", "900")
        self.tmux("set-option", "-gq", "@tmuxg-session-blacklist-regex", "^hidden$")

        # Orchestrator hidden -> skipped; no other eligible unread pane -> stays on self.cur.
        self.tmux("set-option", "-gq", "@tmuxg-show-orchestrator", "off")
        self.jump()
        self.assertEqual(self.active_pane(), self.cur)

        # Orchestrator shown -> jumps to it.
        self.tmux("set-option", "-gq", "@tmuxg-show-orchestrator", "on")
        self.jump()
        self.assertEqual(self.active_pane(), orch)


if __name__ == "__main__":
    unittest.main()
