"""Status-bar unread/running/background counts respect @tma_created=0 vs 1."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


TMUX_DIR = Path(__file__).resolve().parents[1]
PRINT_STATUS = str(TMUX_DIR / "script/print_ai_status.sh")


class AiStatusCountTest(unittest.TestCase):
    def tmux(self, *args):
        return subprocess.check_output(
            [self.tmux_bin, "-S", self.socket, *args], universal_newlines=True
        ).strip()

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="tmux-ai-status-test-", dir="/tmp")
        self.addCleanup(self.temp.cleanup)
        self.socket = str(Path(self.temp.name) / "socket")
        self.tmux_bin = shutil.which("tmux")
        self.tmux("-f", "/dev/null", "new-session", "-d", "-s", "work", "sleep 600")
        self.addCleanup(lambda: subprocess.run(
            [self.tmux_bin, "-S", self.socket, "kill-server"], stderr=subprocess.DEVNULL
        ))
        self.env = dict(os.environ, TMUX=self.socket + ",0,0")

    def status(self):
        return subprocess.check_output(["bash", PRINT_STATUS], env=self.env, universal_newlines=True).strip()

    def make_unread_window(self, name, tma_created=None):
        pane = self.tmux("new-window", "-t", "work:", "-n", name, "-P", "-F", "#{pane_id}", "sleep 600")
        self.tmux("set-option", "-pq", "-t", pane, "@ai_agent_running", "0")
        self.tmux("set-option", "-pq", "-t", pane, "@ai_agent_unread", "1")
        self.tmux("set-option", "-pq", "-t", pane, "@ai_agent_attribute", name)
        if tma_created is not None:
            self.tmux("set-option", "-wq", "-t", pane, "@tma_created", str(tma_created))
        return pane

    def test_restored_zero_tma_created_still_counts_as_user_unread(self):
        p_unset = self.make_unread_window("user-unset", tma_created=None)
        p_zero = self.make_unread_window("user-restored-zero", tma_created=0)
        p_agent = self.make_unread_window("agent-child", tma_created=1)

        # Default @status_count_tma_unread=off: both user windows count (!2), agent window does not.
        self.assertEqual(self.status(), "!2")

        # Ranking one of the two unread user windows turns the count mixed-orange; ranking both turns it red.
        self.tmux("set-option", "-gq", "@auto_switch_ranked_panes", p_zero)
        self.assertEqual(self.status(), "#[fg=colour214]!2#[fg=cyan]")
        self.tmux("set-option", "-gq", "@auto_switch_ranked_panes", p_unset + " " + p_zero)
        self.assertEqual(self.status(), "#[fg=colour196]!2#[fg=cyan]")

        # Enabling @status_count_tma_unread includes the @tma_created=1 window as well (!3).
        self.tmux("set-option", "-gq", "@status_count_tma_unread", "on")
        self.assertEqual(self.status(), "#[fg=colour214]!3#[fg=cyan]")
        self.assertNotEqual(p_agent, "")

    def test_pending_or_done_pane_is_not_counted_as_unread(self):
        p_pend = self.make_unread_window("parked", tma_created=0)
        self.tmux("set-option", "-pq", "-t", p_pend, "@ai_agent_pending", "waiting")
        p_done = self.make_unread_window("finished", tma_created=0)
        self.tmux("set-option", "-pq", "-t", p_done, "@ai_agent_done", "1")
        self.assertEqual(self.status(), "0")


if __name__ == "__main__":
    unittest.main()
