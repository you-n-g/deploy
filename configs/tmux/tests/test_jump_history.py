"""Exercise real tmux hooks/clients without touching the user's tmux server."""

import json
import errno
import os
from pathlib import Path
import pty
import re
import shlex
import signal
import subprocess
import tempfile
import threading
import time
import unittest


TMUX_DIR = Path(__file__).resolve().parents[1]
SCRIPT = str(TMUX_DIR / "script/jump_history.py")
INSERT_SCRIPT = str(TMUX_DIR / "script/insert_previous_target.sh")


class JumpHistoryTest(unittest.TestCase):
    def tmux(self, *args):
        return subprocess.check_output(
            ["tmux", "-S", self.socket, *args], universal_newlines=True
        ).strip()

    def wait_for(self, predicate):
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            if predicate():
                return
            time.sleep(0.03)
        self.fail("tmux history did not reach expected state within 5 seconds")

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="tmux-jump-test-")
        self.addCleanup(self.temp.cleanup)
        self.socket = self.temp.name + "/socket"
        self.processes = []
        self.tmux("-f", "/dev/null", "new-session", "-d", "-s", "one", "/bin/sh")
        self.addCleanup(self.cleanup_server)
        self.tmux("set-option", "-g", "default-command", "/bin/sh")
        self.a = self.tmux("display-message", "-p", "-t", "one:", "#{session_id}:.#{pane_id}")
        self.b = self.tmux("split-window", "-d", "-t", self.a, "-P", "-F", "#{session_id}:.#{pane_id}")
        self.c = self.tmux("new-window", "-d", "-t", "one:", "-P", "-F", "#{session_id}:.#{pane_id}")
        # Load the actual feature config, resolving paths to this checkout.
        config = (TMUX_DIR / "jump-history.conf").read_text().replace(
            "~/deploy/configs/tmux/script/jump_history.py", SCRIPT
        ).replace("~/deploy/configs/tmux/script/insert_previous_target.sh", INSERT_SCRIPT)
        subprocess.run(["tmux", "-S", self.socket, "source-file", "-"],
                       input=config, universal_newlines=True, check=True)
        self.client = self.attach("one")
        self.wait_for(lambda: self.state(self.client).get("entries") == [self.a])

    def cleanup_server(self):
        self.tmux("kill-server")
        for process, output in self.processes:
            process.wait(timeout=5)
            process.stdin.close()
            output.close()

    def attach(self, session):
        output = tempfile.TemporaryFile()
        process = subprocess.Popen(
            ["tmux", "-S", self.socket, "-C", "attach-session", "-t", session],
            stdin=subprocess.PIPE, stdout=output, stderr=output,
            env=dict(os.environ, TERM="xterm-256color"),
        )
        self.processes.append((process, output))
        self.wait_for(lambda: str(process.pid) in self.tmux("list-clients", "-F", "#{client_pid}").splitlines())
        for row in self.tmux("list-clients", "-F", "#{client_pid}\t#{client_name}").splitlines():
            pid, name = row.split("\t")
            if pid == str(process.pid):
                return name
        self.fail("attached client missing")

    def state(self, client):
        identities = {}
        for row in self.tmux("list-clients", "-F", "#{client_name}\t#{client_pid}:#{client_created}").splitlines():
            name, identity = row.split("\t")
            identities[name] = identity
        raw = self.tmux("show-option", "-gqv", "@jump-history-state")
        return json.loads(raw or "{}").get(identities[client], {})

    def current(self, client):
        for row in self.tmux("list-clients", "-F", "#{client_name}\t#{session_id}:.#{pane_id}").splitlines():
            name, position = row.split("\t")
            if name == client:
                return position
        self.fail("client missing")

    def status(self, client, option="@jump-history-status"):
        # display-message -c chooses the message destination, not the format's
        # client context. Evaluate from the actual control client's command queue.
        pids = dict(row.split("\t") for row in self.tmux(
            "list-clients", "-F", "#{client_name}\t#{client_pid}"
        ).splitlines())
        process, output = next(pair for pair in self.processes if pair[0].pid == int(pids[client]))
        offset = os.fstat(output.fileno()).st_size
        process.stdin.write(('display-message -p "#{E:' + option + '}"\n').encode())
        process.stdin.flush()

        def response():
            text = os.pread(output.fileno(), 65536, offset).decode("utf-8")
            return re.search(r"%begin [^\n]*\n(.*?)\n%end", text, re.S)

        self.wait_for(response)
        return response().group(1)

    def visit(self, target, client=None):
        client = client or self.client
        self.tmux("switch-client", "-c", client, "-t", target)
        self.wait_for(lambda: self.state(client).get("entries", [None])[-1] == target)

    def jump(self, action, expected, client=None):
        client = client or self.client
        subprocess.check_call(["python3", SCRIPT, "--socket", self.socket, action, client])
        self.assertEqual(self.current(client), expected)
        # Drain pending observer hooks to check replay does not erase forward history.
        subprocess.check_call(["python3", SCRIPT, "--socket", self.socket, "record"])

    def test_back_forward_and_new_branch(self):
        self.visit(self.b)
        self.visit(self.c)
        self.jump("back", self.b)
        self.jump("back", self.a)
        self.jump("back", self.a)
        self.jump("forward", self.b)
        self.assertEqual(self.state(self.client),
                         {"entries": [self.a, self.b, self.c], "index": 1,
                          "recent": [self.a, self.b, self.c]})
        self.assertEqual(self.status(self.client), "2/3")
        d = self.tmux("new-window", "-d", "-t", "one:", "-P", "-F", "#{session_id}:.#{pane_id}")
        self.visit(d)
        self.wait_for(lambda: self.status(self.client) == "3/3")
        self.assertEqual(self.state(self.client)["entries"], [self.a, self.b, d])
        self.jump("forward", d)

    def target(self, position):
        return self.tmux("display-message", "-p", "-t", position.split(":.")[1],
                         "#{session_name}:#{window_index}.#{pane_index}")

    def previous(self, client=None):
        return subprocess.check_output(
            ["python3", SCRIPT, "--socket", self.socket, "previous", client or self.client],
            universal_newlines=True,
        ).strip()

    def test_previous_follows_visits_and_jumps(self):
        result = subprocess.run(
            ["python3", SCRIPT, "--socket", self.socket, "previous", self.client],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("no open previously visited pane", result.stderr)
        self.visit(self.b)
        self.visit(self.c)
        self.assertEqual(self.previous(), self.target(self.b))
        # A back jump is a visit too: the pane left behind becomes previous.
        self.jump("back", self.b)
        self.assertEqual(self.previous(), self.target(self.c))
        self.jump("back", self.a)
        self.assertEqual(self.previous(), self.target(self.b))
        self.visit(self.c)
        self.assertEqual(self.previous(), self.target(self.a))
        # A closed previous pane (e.g. a temporary floating pane) falls back to
        # the one left before it; the current pane itself never counts.
        self.tmux("kill-pane", "-t", self.a)
        self.assertEqual(self.previous(), self.target(self.b))
        self.tmux("kill-pane", "-t", self.b)
        result = subprocess.run(
            ["python3", SCRIPT, "--socket", self.socket, "previous", self.client],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("no open previously visited pane", result.stderr)

    def test_insert_previous_target_types_without_enter(self):
        self.visit(self.c)
        self.visit(self.b)
        pane = self.b.split(":.")[1]
        subprocess.check_call([INSERT_SCRIPT, self.socket, self.client, pane])
        expected = "请capture我的Tmux的这个pane[" + self.target(self.c) + "]的内容"
        self.wait_for(lambda: expected in self.tmux("capture-pane", "-p", "-t", pane))
        # No Enter: the text stays on the prompt line, so the shell never runs it.
        self.assertNotIn("not found", self.tmux("capture-pane", "-p", "-t", pane))
        self.assertRegex(self.tmux("list-keys", "-T", "prefix"),
                         r"C-l\s+run-shell .*insert_previous_target.sh ")

    def test_capacity_and_repeated_visits(self):
        self.tmux("set-option", "-g", "@jump-history-limit", "3")
        for target in (self.b, self.c, self.b, self.a):
            self.visit(target)
        self.visit(self.a)
        subprocess.check_call(["python3", SCRIPT, "--socket", self.socket, "record"])
        self.assertEqual(self.state(self.client)["entries"], [self.c, self.b, self.a])
        self.jump("back", self.b)
        self.jump("back", self.c)
        self.jump("back", self.c)

    def test_closed_pane_is_skipped(self):
        self.visit(self.b)
        self.visit(self.c)
        self.tmux("kill-pane", "-t", self.b)
        self.jump("back", self.a)
        self.jump("forward", self.c)

    def test_cross_session_rename_and_window_reindex(self):
        self.tmux("new-session", "-d", "-s", "two", "/bin/sh")
        target = self.tmux("display-message", "-p", "-t", "two:", "#{session_id}:.#{pane_id}")
        self.visit(target)
        self.tmux("rename-session", "-t", "one", "renamed")
        self.tmux("rename-window", "-t", self.a, "renamed-window")
        self.tmux("move-window", "-s", self.a, "-t", "renamed:9")
        self.jump("back", self.a)
        self.jump("forward", target)

    def test_background_selection_does_not_record(self):
        hidden = self.tmux("split-window", "-d", "-t", self.c, "-P", "-F", "#{session_id}:.#{pane_id}")
        self.tmux("select-pane", "-t", hidden)
        subprocess.check_call(["python3", SCRIPT, "--socket", self.socket, "record"])
        self.assertEqual(self.state(self.client)["entries"], [self.a])
        # Changing a visible pane by select-pane (also used by mouse selection)
        # must be observed, even without a switch-client command.
        self.tmux("select-pane", "-t", self.b)
        self.wait_for(lambda: self.state(self.client).get("entries") == [self.a, self.b])

    def test_clients_have_independent_cursors(self):
        self.tmux("new-session", "-d", "-s", "two", "/bin/sh")
        other = self.attach("two")
        other_start = self.current(other)
        self.wait_for(lambda: self.state(other).get("entries") == [other_start])
        self.visit(self.b)
        self.visit(self.c)
        self.jump("back", self.b)
        self.assertEqual(self.state(other), {"entries": [other_start], "index": 0})
        self.assertEqual(self.current(other), other_start)
        self.assertEqual(self.status(self.client), "2/3")
        self.assertEqual(self.status(other), "1/1")

    def test_bindings_leave_copy_paste_intact(self):
        keys = self.tmux("list-keys", "-T", "prefix")
        lines = {line.split()[3]: line for line in keys.splitlines() if line.startswith("bind-key ") and " -r " not in line}
        self.assertIn("copy-mode", lines["["])
        self.assertIn("paste-buffer", lines["]"])
        self.assertRegex(keys, r"Escape\s+switch-client -T root")
        self.assertRegex(keys, r"C-\]\s+run-shell .*jump_history.py .* forward ")

    def test_repeated_keys_escape_and_timeout(self):
        self.visit(self.b)
        self.visit(self.c)
        self.tmux("send-keys", "-K", "-c", self.client, "C-b", "C-[", "C-[")
        self.wait_for(lambda: self.current(self.client) == self.a)
        self.tmux("send-keys", "-K", "-c", self.client, "C-]")
        self.wait_for(lambda: self.current(self.client) == self.b)
        self.assertIn("colour46", self.status(self.client, "@jump-history-waiting"))
        self.tmux("send-keys", "-K", "-c", self.client, "Escape")
        self.assertEqual(self.tmux("list-clients", "-F", "#{client_key_table}"), "root")
        self.assertEqual(self.current(self.client), self.b)
        self.assertNotIn("colour46", self.status(self.client, "@jump-history-waiting"))
        self.tmux("send-keys", "-K", "-c", self.client, "C-b", "Escape")
        self.assertEqual(self.tmux("list-clients", "-F", "#{client_key_table}"), "root")
        self.assertEqual(self.current(self.client), self.b)
        self.tmux("send-keys", "-K", "-c", self.client, "C-b", "C-[")
        self.wait_for(lambda: self.current(self.client) == self.a)
        time.sleep(1.1)
        self.assertIn("colour46", self.status(self.client, "@jump-history-waiting"))
        self.tmux("send-keys", "-K", "-c", self.client, "C-]")
        self.wait_for(lambda: self.current(self.client) == self.b)
        # More than two seconds from the first jump, but less than two since
        # changing direction: the repeat deadline and indicator must be renewed.
        time.sleep(1.1)
        self.assertIn("colour46", self.status(self.client, "@jump-history-waiting"))
        self.wait_for(lambda: self.tmux("list-clients", "-F", "#{client_key_table}") == "root")
        self.assertNotIn("colour46", self.status(self.client, "@jump-history-waiting"))

    def test_repeat_across_sessions(self):
        self.tmux("new-session", "-d", "-s", "two", "/bin/sh")
        target = self.tmux("display-message", "-p", "-t", "two:", "#{session_id}:.#{pane_id}")
        self.visit(self.b)
        self.visit(target)
        self.tmux("send-keys", "-K", "-c", self.client, "C-b", "C-[", "C-[")
        self.wait_for(lambda: self.current(self.client) == self.a)
        self.tmux("send-keys", "-K", "-c", self.client, "C-]", "C-]")
        self.wait_for(lambda: self.current(self.client) == target)

    def test_kitty_escape_bytes_do_not_leak(self):
        received = Path(self.temp.name) / "received"
        probe = Path(self.temp.name) / "probe.py"
        probe.write_text(
            "import os, pathlib, tty\n"
            "tty.setraw(0)\n"
            "with pathlib.Path({!r}).open('wb', buffering=0) as f:\n"
            "    while True: f.write(os.read(0, 1024))\n".format(str(received))
        )
        target = self.tmux("new-window", "-d", "-t", "one:", "-P", "-F",
                           "#{session_id}:.#{pane_id}", "python3 " + shlex.quote(str(probe)))
        self.tmux("set-option", "-s", "escape-time", "10")
        self.tmux("set-option", "-g", "assume-paste-time", "0")
        child, terminal = pty.fork()
        if child == 0:
            os.execvpe("tmux", ["tmux", "-S", self.socket, "attach-session", "-t", "one"],
                       dict(os.environ, TERM="xterm-256color"))

        def drain():
            try:
                while os.read(terminal, 65536):
                    pass
            except OSError as error:
                if error.errno != errno.EIO:
                    raise

        reader = threading.Thread(target=drain, daemon=True)
        reader.start()
        try:
            self.wait_for(lambda: str(child) in self.tmux("list-clients", "-F", "#{client_pid}").splitlines())
            client = dict(row.split("\t") for row in self.tmux(
                "list-clients", "-F", "#{client_pid}\t#{client_name}"
            ).splitlines())[str(child)]
            self.visit(target, client)
            self.wait_for(received.exists)

            def table():
                return self.tmux("display-message", "-p", "-c", client, "-t", target,
                                 "#{client_key_table}")

            os.write(terminal, b"\x02")
            self.wait_for(lambda: table() == "prefix")
            os.write(terminal, b"\x1b[27u")
            self.wait_for(lambda: table() == "root")
            os.write(terminal, b"x")
            self.wait_for(lambda: received.read_bytes().endswith(b"x"))
            self.assertEqual(received.read_bytes(), b"x")

            # Outside prefix, the application must get exactly one real Esc.
            os.write(terminal, b"\x1b[27u")
            self.wait_for(lambda: received.read_bytes() != b"x")
            self.assertEqual(received.read_bytes(), b"x\x1b")

            # Reverse direction repeatedly without another prefix; none of the
            # navigation keys or final Escape may leak into the application.
            os.write(terminal, b"\x02")
            self.wait_for(lambda: table() == "prefix")
            steps = [(b"\x1b[91;5u", self.a), (b"\x1b[93;5u", target),
                     (b"\x1b[91;5u", self.a), (b"\x1d", target)]
            for key, destination in steps * 2:
                time.sleep(0.12)
                os.write(terminal, key)
                self.wait_for(lambda: self.current(client) == destination)
                self.assertEqual(table(), "prefix")
            os.write(terminal, b"\x1b[27u")
            self.wait_for(lambda: table() == "root")
            os.write(terminal, b"y")
            self.wait_for(lambda: received.read_bytes().endswith(b"y"))
            self.assertEqual(received.read_bytes(), b"x\x1by")
        finally:
            os.kill(child, signal.SIGTERM)
            os.waitpid(child, 0)
            reader.join(timeout=1)
            os.close(terminal)


if __name__ == "__main__":
    unittest.main()
