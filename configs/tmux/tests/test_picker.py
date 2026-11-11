"""Picker rendering and asynchronous input on a private tmux terminal."""

import os
from pathlib import Path
import pty
import re
import select
import shlex
import shutil
import signal
import subprocess
import tempfile
import time
import unittest


TMUX_DIR = Path(__file__).resolve().parents[1]


class PickerTest(unittest.TestCase):
    def tmux(self, *args):
        return subprocess.check_output([self.tmux_bin, "-S", self.socket, *args],
                                       universal_newlines=True).strip()

    def wait_for(self, predicate):
        deadline = time.monotonic() + 5
        while not predicate():
            self.assertLess(time.monotonic(), deadline, "picker did not finish")
            time.sleep(0.01)

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="tma-picker-test-", dir="/tmp")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.tmpdir = self.root / "tmp"
        self.tmpdir.mkdir()
        self.socket = str(self.root / "socket")
        self.tmux_bin = shutil.which("tmux")
        binary = self.root / "codex"
        binary.symlink_to("/bin/sleep")
        self.panes = []
        for i, name in enumerate(["current", "news", "chosen"]):
            command = "printf 'PREVIEW-{}\\n'; exec {} 600".format(name, shlex.quote(str(binary)))
            if i == 0:
                self.tmux("-f", "/dev/null", "new-session", "-d", "-s", "test",
                          "-x", "160", "-y", "40", command)
                self.addCleanup(lambda: subprocess.run(
                    [self.tmux_bin, "-S", self.socket, "kill-server"], stderr=subprocess.DEVNULL))
                pane = self.tmux("display-message", "-p", "-t", "test:", "#{pane_id}")
            else:
                pane = self.tmux("new-window", "-d", "-P", "-F", "#{pane_id}",
                                 "-t", "test:", "-n", name, command)
            self.panes.append(pane)
        self.tmux("set-option", "-g", "status", "off")
        self.tmux("set-option", "-pq", "-t", self.panes[1], "@ai_agent_unread", "1")
        self.tmux("set-environment", "-g", "TMPDIR", str(self.tmpdir))
        self.focused = self.root / "focused"
        focus_bind = "focus:execute-silent(printf %s {{1}} > {})".format(shlex.quote(str(self.focused)))
        self.tmux("set-environment", "-g", "FZF_DEFAULT_OPTS", "--bind " + shlex.quote(focus_bind))
        self.env = dict(os.environ, TMUX=self.socket + ",0,0", TMUX_PANE=self.panes[0])
        self.master, slave = pty.openpty()
        self.client = subprocess.Popen(
            [self.tmux_bin, "-S", self.socket, "attach-session", "-t", "test:"],
            stdin=slave, stdout=slave, stderr=slave, env=dict(self.env, TERM="xterm-256color"))
        os.close(slave)
        def close_client():
            self.client.terminate()
            self.client.wait(timeout=5)
            os.close(self.master)
        self.addCleanup(close_client)
        self.wait_for(lambda: bool(self.tmux("list-clients", "-F", "#{client_name}")))
        self.output = b""
        self.result = self.root / "result"
        self.status = self.root / "status"
        command = "bash {} -A -i > {}; rc=$?; printf '%s\\n' \"$rc\" > {}".format(
            shlex.quote(str(TMUX_DIR / "ai/get_ai_pane.sh")),
            shlex.quote(str(self.result)), shlex.quote(str(self.status)))
        self.tmux("bind-key", "-T", "prefix", "C-g", "run-shell", command)

    def open_picker(self):
        os.write(self.master, b"\x02\x07")

    def wait_output(self, marker):
        deadline = time.monotonic() + 5
        while marker not in self.output:
            self.assertLess(time.monotonic(), deadline, repr(self.output[-400:]))
            if select.select([self.master], [], [], 0.05)[0]:
                self.output += os.read(self.master, 1048576)

    def completed(self, code):
        self.wait_for(lambda: self.status.exists() and bool(self.status.read_text().strip()))
        self.assertEqual(int(self.status.read_text()), code)

    def wait_focused(self, pane):
        # Terminal redraws can emit only the changed suffix of a preview;
        # observe fzf's actual selection instead of matching raw screen bytes.
        self.wait_for(lambda: self.focused.exists() and self.focused.read_text() == pane)

    def block_scan(self):
        wrappers = self.root / "wrapper"
        shutil.copytree(str(TMUX_DIR / "wrapper"), str(wrappers))
        scanner = wrappers / "default/pane_processes.py"
        self.gate = self.root / "gate"
        os.mkfifo(str(self.gate))
        self.started = self.root / "scan-pid"
        scanner.write_text("import os\nopen({!r}, 'w').write(str(os.getpid()))\n"
                           "with open({!r}) as gate: gate.read()\n".format(
                               str(self.started), str(self.gate)) + scanner.read_text())
        self.tmux("set-environment", "-g", "TMA_WRAPPER_ROOT", str(wrappers))
        def stop_fixture():
            if self.started.exists():
                pid = self.started.read_text()
                cmd = Path("/proc") / pid / "cmdline"
                if cmd.exists() and str(self.root).encode() in cmd.read_bytes():
                    os.kill(int(pid), signal.SIGKILL)
        self.addCleanup(stop_fixture)

    def release_scan(self):
        self.wait_for(self.started.exists)
        with self.gate.open("w") as gate:
            gate.write("go")

    def test_typing_before_scan_finishes_filters_the_loaded_list(self):
        self.block_scan()
        self.open_picker()
        self.wait_output(b"current pane busy")
        os.write(self.master, b"chosen")
        self.release_scan()
        self.wait_focused(self.panes[2])
        os.write(self.master, b"\r")
        self.completed(0)
        self.assertEqual(self.result.read_text().strip(), self.panes[2])

    def test_initial_selection_prefers_unread_over_idle(self):
        self.open_picker()
        self.wait_focused(self.panes[1])
        os.write(self.master, b"\r")
        self.completed(0)
        self.assertEqual(self.result.read_text().strip(), self.panes[1])

    def test_initial_selection_stops_at_first_unread_even_before_news(self):
        self.tmux("set-option", "-pq", "-t", self.panes[2], "@ai_agent_unread", "1")
        self.tmux("set-option", "-pq", "-t", self.panes[2], "@last_visit", "200")
        self.tmux("set-option", "-pq", "-t", self.panes[1], "@last_visit", "100")
        self.open_picker()
        self.wait_focused(self.panes[2])
        os.write(self.master, b"\r")
        self.completed(0)
        self.assertEqual(self.result.read_text().strip(), self.panes[2])

    def test_cancel_during_scan_terminates_reload_and_cleans_temp_files(self):
        self.block_scan()
        self.open_picker()
        self.wait_output(b"current pane busy")
        self.wait_for(self.started.exists)
        pid = self.started.read_text()
        os.write(self.master, b"\x03")
        self.completed(2)
        stat = Path("/proc") / pid / "stat"
        self.wait_for(lambda: not stat.exists() or stat.read_text().rsplit(") ", 1)[1].startswith("Z "))
        self.assertEqual(list(self.tmpdir.iterdir()), [])

    def test_empty_list_returns_no_agent(self):
        self.tmux("set-option", "-g", "@tmuxg-session-blacklist-regex", ".*")
        self.open_picker()
        self.completed(1)

    def test_empty_list_still_closes_after_typing_while_loading(self):
        self.block_scan()
        self.tmux("set-option", "-g", "@tmuxg-session-blacklist-regex", ".*")
        self.open_picker()
        self.wait_output(b"current pane busy")
        os.write(self.master, b"query")
        self.release_scan()
        self.completed(1)

    def test_single_candidate_is_selected_without_input(self):
        for pane in [self.panes[0], self.panes[2]]:
            self.tmux("kill-pane", "-t", pane)
        self.open_picker()
        self.completed(0)
        self.assertEqual(self.result.read_text().strip(), self.panes[1])

    def test_renderer_keeps_state_tags_and_requested_order(self):
        self.tmux("set-option", "-pq", "-t", self.panes[0], "@ai_agent_running", "1")
        self.tmux("set-option", "-pq", "-t", self.panes[1], "@ai_agent_woke", "1")
        self.tmux("set-option", "-pq", "-t", self.panes[1], "@ai_agent_muted", "1")
        self.tmux("set-option", "-pq", "-t", self.panes[2], "@ai_agent_done", "1")
        self.tmux("set-option", "-wq", "-t", self.panes[2], "@tma_created", "1")
        code = 'source "$1"; _ai_pane_rows -a | _ai_pane_fzf_list test:0.0'
        output = subprocess.check_output(["bash", "-c", code, "test", str(TMUX_DIR / "ai/lib.sh")],
                                         env=self.env, universal_newlines=True)
        plain = re.sub(r"\x1b\[[0-9;]*m", "", output).splitlines()
        self.assertEqual([line.split()[0] for line in plain],
                         [self.panes[0], self.panes[2], self.panes[1]])
        self.assertIn("▶", plain[0])
        self.assertIn("[agent]", plain[1])
        for text in ["☀", "[unread]", "[woke]", "[muted]"]:
            self.assertIn(text, plain[2])
        code = 'source "$1"; rows="$(_ai_pane_rows -a)"; printf "%s\\n" "$rows" | cut -f4; printf "%s\\n" "$rows" | AI_PANE_FZF_PRESERVE_ORDER=1 _ai_pane_fzf_list'
        output = subprocess.check_output(["bash", "-c", code, "test", str(TMUX_DIR / "ai/lib.sh")],
                                         env=self.env, universal_newlines=True).splitlines()
        self.assertEqual(output[:3], [line.split()[0] for line in output[3:]])


if __name__ == "__main__":
    unittest.main()
