"""Symmetric 1-to-1 pane bonding (@bond_pane), jumping, push/pull, and cleanup."""

import fcntl
import os
from pathlib import Path
import pty
import shutil
import struct
import subprocess
import tempfile
import termios
import time
import unittest


TMUX_DIR = Path(__file__).resolve().parents[1]
BOND = str(TMUX_DIR / "script/bond_pane.sh")
LIB = str(TMUX_DIR / "ai/lib.sh")


class BondPaneTest(unittest.TestCase):
    def tmux(self, *args):
        return subprocess.check_output(
            [self.tmux_bin, "-S", self.socket, *args], universal_newlines=True
        ).strip()

    def wait_for(self, predicate, timeout=5):
        deadline = time.monotonic() + timeout
        while not predicate():
            self.assertLess(time.monotonic(), deadline, "bond action did not reach expected state")
            time.sleep(0.03)

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="tmux-bond-test-", dir="/tmp")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.socket = str(self.root / "socket")
        self.tmux_bin = shutil.which("tmux")
        self.tmux("-f", "/dev/null", "new-session", "-d", "-s", "work", "-x", "120", "-y", "40", "/bin/sh")
        self.addCleanup(lambda: subprocess.run(
            [self.tmux_bin, "-S", self.socket, "kill-server"], stderr=subprocess.DEVNULL
        ))
        self.a = self.tmux("display-message", "-p", "-t", "work:", "#{pane_id}")
        self.b = self.tmux("new-window", "-t", "work:", "-n", "agent-b", "-P", "-F", "#{pane_id}", "/bin/sh")
        self.tmux("new-session", "-d", "-s", "other", "-x", "120", "-y", "40", "/bin/sh")
        self.c = self.tmux("display-message", "-p", "-t", "other:", "#{pane_id}")
        self.env = dict(os.environ, TMUX=self.socket + ",0,0")

        master, slave = pty.openpty()
        fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 120, 0, 0))
        self.master = master
        self.client_proc = subprocess.Popen(
            [self.tmux_bin, "-S", self.socket, "attach-session", "-t", "work"],
            stdin=slave, stdout=slave, stderr=slave,
            env=dict(self.env, TERM="xterm-256color"),
        )
        os.close(slave)
        self.addCleanup(self._close_client)
        self.wait_for(lambda: bool(self.tmux("list-clients", "-F", "#{client_name}")))
        self.client = self.tmux("list-clients", "-F", "#{client_name}").splitlines()[0]

    def _close_client(self):
        if self.client_proc.poll() is None:
            self.client_proc.terminate()
            try:
                self.client_proc.wait(timeout=3)
            except subprocess.TimeoutExpired:
                self.client_proc.kill()
                self.client_proc.wait(timeout=3)
        os.close(self.master)

    def bond_cmd(self, subcmd, *args, check=True):
        return subprocess.run(
            ["bash", BOND, subcmd, "-S", self.socket, *args],
            env=self.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            universal_newlines=True, check=check,
        )

    def bond_of(self, pane):
        return self.tmux("show-option", "-pqv", "-t", pane, "@bond_pane")

    def active_pane(self):
        return self.tmux("display-message", "-p", "-c", self.client, "#{pane_id}")

    def test_symmetric_bond_rebond_jump_and_unbond(self):
        # Self-bond is rejected loudly.
        bad = self.bond_cmd("set", self.a, self.a, check=False)
        self.assertNotEqual(bad.returncode, 0)
        self.assertEqual(self.bond_of(self.a), "")

        # Bond a <-> b and toggle focus back and forth across sessions/windows.
        self.bond_cmd("set", self.a, self.b)
        self.assertEqual(self.bond_of(self.a), self.b)
        self.assertEqual(self.bond_of(self.b), self.a)
        self.assertEqual(self.bond_cmd("target", "--format", "target", self.a).stdout.strip(), "work:1.0")

        self.tmux("switch-client", "-c", self.client, "-t", self.a)
        self.bond_cmd("jump", "--client", self.client, self.a)
        self.assertEqual(self.active_pane(), self.b)
        self.bond_cmd("jump", "--client", self.client, self.b)
        self.assertEqual(self.active_pane(), self.a)

        # Re-bonding a <-> c detaches b cleanly so b has no dangling half-bond.
        self.bond_cmd("set", self.a, self.c)
        self.assertEqual(self.bond_of(self.a), self.c)
        self.assertEqual(self.bond_of(self.c), self.a)
        self.assertEqual(self.bond_of(self.b), "")

        self.bond_cmd("jump", "--client", self.client, self.a)
        self.assertEqual(self.active_pane(), self.c)

        # Unbonding clears both sides.
        self.bond_cmd("unbond", self.c)
        self.assertEqual(self.bond_of(self.a), "")
        self.assertEqual(self.bond_of(self.c), "")
        self.assertNotEqual(self.bond_cmd("jump", "--client", self.client, self.a, check=False).returncode, 0)

    def test_push_and_pull_type_capture_requests_without_enter(self):
        self.bond_cmd("set", self.a, self.c)
        self.tmux("switch-client", "-c", self.client, "-t", self.a)

        # Push from a -> c types a's capture request into c and switches client to c.
        self.bond_cmd("push", "--client", self.client, self.a)
        self.assertEqual(self.active_pane(), self.c)
        self.wait_for(lambda: f"pane {self.a}）的内容" in self.tmux("capture-pane", "-Jp", "-t", self.c))
        self.assertNotIn("not found", self.tmux("capture-pane", "-Jp", "-t", self.c))

        # Pull in a types c's capture request into a while keeping focus unchanged.
        self.tmux("switch-client", "-c", self.client, "-t", self.a)
        self.bond_cmd("pull", self.a)
        self.assertEqual(self.active_pane(), self.a)
        self.wait_for(lambda: f"pane {self.c}）的内容" in self.tmux("capture-pane", "-Jp", "-t", self.a))

    def test_closed_partner_cleans_up_automatically(self):
        self.bond_cmd("set", self.a, self.b)
        self.tmux("kill-pane", "-t", self.b)
        res = self.bond_cmd("target", self.a, check=False)
        self.assertNotEqual(res.returncode, 0)
        self.assertEqual(self.bond_of(self.a), "")

        # cleanup subcommand also sweeps stale bonds across all panes.
        d = self.tmux("new-window", "-t", "work:", "-P", "-F", "#{pane_id}", "/bin/sh")
        self.bond_cmd("set", self.a, d)
        self.tmux("kill-pane", "-t", d)
        self.bond_cmd("cleanup")
        self.assertEqual(self.bond_of(self.a), "")

    def test_last_visited_bonding_and_fzf_picker_badge(self):
        # Load jump-history so visits are recorded.
        jh_conf = (TMUX_DIR / "jump-history.conf").read_text().replace(
            "~/deploy/configs/tmux/script/jump_history.py",
            str(TMUX_DIR / "script/jump_history.py"),
        )
        subprocess.run([self.tmux_bin, "-S", self.socket, "source-file", "-"],
                       input=jh_conf, universal_newlines=True, check=True)
        self.tmux("switch-client", "-c", self.client, "-t", self.c)
        time.sleep(0.15)
        self.tmux("switch-client", "-c", self.client, "-t", self.b)
        time.sleep(0.15)
        self.tmux("switch-client", "-c", self.client, "-t", self.a)
        time.sleep(0.15)

        # `last` bonds with `b`; `last --other-session` bonds with `c`.
        self.bond_cmd("last", self.client, self.a)
        self.assertEqual(self.bond_of(self.a), self.b)
        self.bond_cmd("last", "--other-session", self.client, self.a)
        self.assertEqual(self.bond_of(self.a), self.c)

        # Spawn a fake codex process in `c` so _ai_pane_fzf_list shows `[pane %X bonded]`.
        fake_ai = self.root / "codex"
        fake_ai.symlink_to("/bin/sleep")
        self.tmux("respawn-pane", "-k", "-t", self.c, str(fake_ai) + " 600")
        out = subprocess.check_output(
            ["bash", "-c", 'source "$1"; _ai_pane_rows -a | _ai_pane_fzf_list "work:0.0"', "test", LIB],
            env=self.env, universal_newlines=True,
        )
        self.assertIn(f"pane {self.c} bonded", out)

    def test_unbonded_tmux_menu_actions_show_message_without_jumping_or_view_mode(self):
        self.tmux("switch-client", "-c", self.client, "-t", self.a)
        for subcmd, extra in [("jump", ["--client", self.client]),
                              ("push", ["--client", self.client]),
                              ("pull", [])]:
            res = self.bond_cmd(subcmd, "--tmux-menu", *extra, self.a)
            self.assertEqual(res.returncode, 0)
            self.assertEqual(res.stdout, "")
            self.assertEqual(res.stderr, "")
            self.assertEqual(self.active_pane(), self.a)
            self.assertEqual(self.tmux("display-message", "-p", "-t", self.a, "#{pane_in_mode}"), "0")

        # Also exercise real `tmux run-shell` as bound in `prefix + k -> b` so
        # tmux itself verifies no view-mode (black screen) or jump happens.
        self.tmux("run-shell", f"{BOND} jump -S {self.socket} --tmux-menu --client {self.client} {self.a}")
        time.sleep(0.15)
        self.assertEqual(self.active_pane(), self.a)
        self.assertEqual(self.tmux("display-message", "-p", "-t", self.a, "#{pane_in_mode}"), "0")
        self.assertIn("尚未绑定目标", self.tmux("show-messages"))

    def test_menu_dynamically_displays_current_bond_unbonded_state_and_other_pairs(self):
        # 1. Unbonded state: shows "○ 未绑定", "-当前未绑定", and disables `(u)nbond`.
        unbonded_menu = self.bond_cmd("menu", "--dry-run", self.client, self.a).stdout
        self.assertIn("○ 未绑定", unbonded_menu)
        self.assertIn("-当前未绑定：", unbonded_menu)
        self.assertIn("-(u)nbond    解除当前绑定（当前未绑定）", unbonded_menu)

        # 2. Bond b <-> c (another pair), while `a` is still unbonded -> `a`'s menu lists `b <-> c` under 其它已绑定窗格对!
        self.bond_cmd("set", self.b, self.c)
        with_other = self.bond_cmd("menu", "--dry-run", self.client, self.a).stdout
        self.assertIn("-其它已绑定窗格对", with_other)
        self.assertIn("work:1.0 agent-b", with_other)
        self.assertIn("other:0.0", with_other)

        # 3. Now bond a <-> b (with an @ai_agent_attribute on b) -> `a`'s menu shows green "⇔ 已绑定",
        #    who is bonded, partner's task attribute, and active `(u)nbond 解除与 work:1.0 agent-b 的绑定`.
        self.tmux("set-option", "-pq", "-t", self.b, "@ai_agent_attribute", "调试实验A")
        self.bond_cmd("set", self.a, self.b)
        bonded_menu = self.bond_cmd("menu", "--dry-run", self.client, self.a).stdout
        self.assertIn("⇔ 已绑定", bonded_menu)
        self.assertIn(f"({self.a}) ↔ work:1.0 agent-b ({self.b})", bonded_menu)
        self.assertIn("对方任务：调试实验A", bonded_menu)
        self.assertIn("(u)nbond    解除与 work:1.0 agent-b 的绑定", bonded_menu)

        # 4. prefix+k's native format string dynamically tracks rename, window move, and unbond in 0ms.
        kb_fmt = "#{?#{!=:#{E:@bond_target_fmt},},(b)ond   → #{E:@bond_target_fmt},(b)ond   已绑定的 pane（未绑定）}"
        self.assertEqual(self.tmux("display-message", "-p", "-t", self.a, kb_fmt),
                         "(b)ond   → work:1.0 agent-b")
        self.tmux("rename-window", "-t", self.b, "renamed-target")
        self.tmux("move-window", "-s", self.b, "-t", "work:8")
        self.assertEqual(self.tmux("display-message", "-p", "-t", self.a, kb_fmt),
                         "(b)ond   → work:8.0 renamed-target")
        self.bond_cmd("unbond", self.a)
        self.assertEqual(self.tmux("display-message", "-p", "-t", self.a, kb_fmt),
                         "(b)ond   已绑定的 pane（未绑定）")


if __name__ == "__main__":
    unittest.main()
