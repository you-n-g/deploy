"""Float geometry and real continuous keystrokes on a private tmux server.

Put tmux 3.8 first on PATH to run the integration cases.
"""

import errno
import fcntl
import importlib.util
import os
from pathlib import Path
import pty
import shlex
import struct
import subprocess
import sys
import tempfile
import termios
import threading
import time
import unittest


TMUX_DIR = Path(__file__).resolve().parents[1]
SCRIPT = TMUX_DIR / "script/float_position.py"
spec = importlib.util.spec_from_file_location("float_position", str(SCRIPT))
position = importlib.util.module_from_spec(spec)
spec.loader.exec_module(position)


class GeometryTest(unittest.TestCase):
    def test_odd_sized_window_allocates_the_remainder_to_right_and_bottom(self):
        rect, axes = position.geometry((121, 41), (1, 1, 20, 10), ("-", "-"), "l")
        self.assertEqual(rect, (61, 1, 59, 39))
        rect, _ = position.geometry((121, 41), rect, axes, "j")
        self.assertEqual(rect, (61, 21, 59, 19))

    def test_repeating_corner_direction_expands_to_its_half(self):
        for horizontal in "hl":
            for vertical in "kj":
                for repeat in (horizontal, vertical):
                    with self.subTest(horizontal=horizontal, vertical=vertical, repeat=repeat):
                        rect, axes = (1, 1, 20, 10), ("-", "-")
                        for action in (horizontal, vertical, repeat):
                            rect, axes = position.geometry((120, 40), rect, axes, action)
                        expected = position.geometry((120, 40), (1, 1, 20, 10), ("-", "-"), repeat)
                        self.assertEqual((rect, axes), expected)

    def test_clip_keeps_a_fully_visible_float_unchanged(self):
        rect = (8, 4, 35, 12)
        self.assertEqual(position.geometry((120, 40), rect, ("h", "k"), "C"),
                         (rect, ("-", "-")))

    def test_tiny_snap_region_is_an_explicit_error(self):
        with self.assertRaisesRegex(ValueError, "窗口太小"):
            position.geometry((5, 5), (1, 1, 2, 2), ("-", "-"), "h")


class FloatPositionTest(unittest.TestCase):
    def tmux(self, *args):
        return subprocess.check_output(["tmux", "-S", self.socket] + list(args),
                                       universal_newlines=True).strip()

    def wait_for(self, predicate):
        deadline = time.monotonic() + 5
        while not predicate():
            self.assertLess(time.monotonic(), deadline, "float position did not reach expected state")
            time.sleep(0.02)

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="tmux-float-position-", dir="/tmp")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.socket = str(self.root / "socket")
        self.tmux("-f", "/dev/null", "new-session", "-d", "-s", "test",
                  "-x", "120", "-y", "40", "sleep 600")
        self.addCleanup(lambda: subprocess.run(["tmux", "-S", self.socket, "kill-server"],
                                               stderr=subprocess.DEVNULL))
        if "[-X x-position]" not in self.tmux("list-commands"):
            self.skipTest("requires tmux 3.8; put it first on PATH")
        self.tmux("set-option", "-g", "status", "off")
        self.base = self.tmux("display-message", "-p", "-t", "test:", "#{pane_id}")
        self.tmux("split-window", "-d", "-h", "-t", self.base, "sleep 600")
        self.env = dict(os.environ, TMUX=self.socket + ",0,0")
        self.received = self.root / "received"
        probe = self.root / "probe.py"
        probe.write_text("import os, tty\ntty.setraw(0)\n"
                         "with open({!r}, 'wb', buffering=0) as output:\n"
                         "    while True: output.write(os.read(0, 1024))\n".format(str(self.received)))
        command = shlex.quote(sys.executable) + " " + shlex.quote(str(probe))
        self.pane = subprocess.check_output(
            [str(TMUX_DIR / "script/new_float_pane.sh"), self.base,
             "-x", "30", "-y", "10", "-X", "60", "-Y", "10", command],
            env=self.env, universal_newlines=True).strip()
        self.wait_for(self.received.exists)
        self.pid = self.tmux("display-message", "-p", "-t", self.pane, "#{pane_pid}")
        self.original_tiled = self.tiled()
        self.tmux("set-option", "-pq", "-t", self.pane, "@test-marker", "keep")
        config = (TMUX_DIR / "float-position.conf").read_text().replace(
            "~/deploy/configs/tmux/script/float_position.py", shlex.quote(str(SCRIPT)))
        subprocess.run(["tmux", "-S", self.socket, "source-file", "-"],
                       input=config, universal_newlines=True, check=True)
        self.tmux("set-option", "-s", "user-keys[900]", "\x1b[27u")
        self.tmux("bind-key", "-T", "root", "User900", "send-keys", "Escape")

    def tiled(self):
        return self.tmux("list-panes", "-t", "test:", "-f", "#{!:#{pane_floating_flag}}",
                         "-F", "#{pane_id}:#{pane_left}:#{pane_top}:#{pane_width}:#{pane_height}")

    def rect(self):
        return tuple(map(int, self.tmux("display-message", "-p", "-t", self.pane,
                                       "#{pane_left} #{pane_top} #{pane_width} #{pane_height}").split()))

    def action(self, action, pane=None, check=True):
        return subprocess.run([sys.executable, str(SCRIPT), "--socket", self.socket,
                               pane or self.pane, action], env=self.env, check=check,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)

    def assert_preserved(self):
        self.assertEqual(self.tiled(), self.original_tiled)
        self.assertEqual(self.tmux("display-message", "-p", "-t", self.pane,
                                   "#{pane_pid} #{@test-marker} #{pane_floating_flag} #{pane_active}"),
                         self.pid + " keep 1 1")

    def attach(self):
        master, slave = pty.openpty()
        fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 120, 0, 0))
        client = subprocess.Popen(["tmux", "-S", self.socket, "attach-session", "-t", "test:"],
                                  stdin=slave, stdout=slave, stderr=slave,
                                  env=dict(self.env, TERM="xterm-256color"))
        os.close(slave)

        self.output = bytearray()

        def drain():
            try:
                while True:
                    chunk = os.read(master, 65536)
                    if not chunk:
                        break
                    self.output.extend(chunk)
            except OSError as error:
                if error.errno != errno.EIO:
                    raise

        reader = threading.Thread(target=drain, daemon=True)
        reader.start()

        def cleanup():
            client.terminate()
            client.wait(timeout=5)
            reader.join(timeout=2)
            os.close(master)

        self.addCleanup(cleanup)
        self.wait_for(lambda: str(client.pid) in self.tmux("list-clients", "-F", "#{client_pid}").splitlines())
        return master

    def test_snap_axes_compose_and_center_resets_them(self):
        self.action("begin")
        for action, expected in [("h", (1, 1, 58, 38)), ("k", (1, 1, 58, 18)),
                                 ("l", (61, 1, 58, 18)), ("j", (61, 21, 58, 18)),
                                 ("c", (31, 11, 58, 18)), ("k", (1, 1, 118, 18))]:
            self.action(action)
            self.assertEqual(self.rect(), expected)
            self.assert_preserved()

    def test_clip_after_window_shrink_resizes_only_oversized_dimensions(self):
        self.action("h")
        self.tmux("resize-window", "-t", "test:", "-x", "50", "-y", "20")
        self.action("C")
        self.assertEqual(self.rect(), (1, 1, 48, 18))

    def test_clip_moves_offscreen_float_without_resizing_it(self):
        self.tmux("move-pane", "-t", self.pane, "-X", "110", "-Y", "-8")
        self.action("C")
        self.assertEqual(self.rect(), (91, 1, 28, 8))
        self.assert_preserved()

    def test_zoomed_float_can_be_positioned_and_closed_without_losing_server(self):
        self.tmux("resize-pane", "-Z", "-t", self.pane)
        self.action("begin")
        self.action("l")
        self.assertEqual(self.rect(), (61, 1, 58, 38))
        self.assert_preserved()
        self.tmux("kill-pane", "-t", self.pane)
        self.assertEqual(self.tiled(), self.original_tiled)

    def test_tiled_pane_is_rejected_without_changing_layout(self):
        layout = self.tmux("display-message", "-p", "-t", self.base, "#{window_layout}")
        result = self.action("h", self.base, check=False)
        self.assertEqual(result.returncode, 1)
        self.assertIn("请先选中", result.stderr)
        self.assertEqual(self.tmux("display-message", "-p", "-t", self.base, "#{window_layout}"), layout)

    def test_invalid_native_geometry_does_not_partially_change_pane(self):
        result = subprocess.run(["tmux", "-S", self.socket, "resize-pane", "-t", self.pane,
                                 "-x", "0"], stderr=subprocess.PIPE)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.rect(), (61, 11, 28, 8))
        self.assert_preserved()

    def test_native_absolute_and_relative_resizing_keep_tiled_panes_intact(self):
        self.tmux("resize-pane", "-t", self.pane, "-x", "40", "-y", "15")
        self.tmux("resize-pane", "-t", self.pane, "-R", "3")
        self.tmux("resize-pane", "-t", self.pane, "-U", "2")
        self.assertEqual(self.rect(), (61, 9, 41, 15))
        self.assert_preserved()

    def test_other_floating_panes_keep_their_geometry(self):
        other = subprocess.check_output(
            [str(TMUX_DIR / "script/new_float_pane.sh"), self.base, "-d",
             "-x", "15", "-y", "6", "-X", "90", "-Y", "30", "sleep 600"],
            env=self.env, universal_newlines=True).strip()
        self.action("h")
        self.assertEqual(self.tmux("display-message", "-p", "-t", other,
                                   "#{pane_left} #{pane_top} #{pane_width} #{pane_height}"),
                         "91 31 13 4")
        self.assert_preserved()

    def test_scrollbar_space_is_preserved_across_repeated_center_and_clip(self):
        self.tmux("set-option", "-w", "-t", self.pane, "pane-scrollbars", "on")
        for action in ["c", "C", "c", "C"]:
            self.action(action)
            self.assertEqual(self.rect(), (46, 16, 27, 8))

    def open_menu(self, terminal):
        os.write(terminal, b"\x02\x17")
        self.wait_for(lambda: b"Esc / Enter / q" in self.output)

    def menu_running(self):
        return bool(self.tmux("list-panes", "-t", self.pane, "-f", "#{@float_position_target}", "-F", "#{pane_id}"))

    def test_corner_direction_repeats_expand_in_the_open_menu(self):
        terminal = self.attach()
        self.open_menu(terminal)
        for keys, expected in [(b"lkl", (61, 1, 58, 38)), (b"jl", (61, 1, 58, 38)),
                               (b"kk", (1, 1, 118, 18)), (b"hh", (1, 1, 58, 38))]:
            os.write(terminal, keys)
            self.wait_for(lambda: self.rect() == expected)
        self.assertTrue(self.menu_running())
        self.assertEqual(self.received.read_bytes(), b"")

    def test_rapid_keys_compose_then_enter_returns_to_application(self):
        terminal = self.attach()
        os.write(terminal, b"\x02\x17hklj")
        self.wait_for(lambda: self.rect() == (61, 21, 58, 18))
        self.assertEqual(self.received.read_bytes(), b"")
        os.write(terminal, b"c\r")
        self.wait_for(lambda: not self.menu_running())
        os.write(terminal, b"x")
        self.wait_for(lambda: self.received.read_bytes() == b"x")
        self.assertEqual(self.rect(), (31, 11, 58, 18))
        self.assert_preserved()

    def test_kitty_escape_exits_mode_without_leaking_escape(self):
        terminal = self.attach()
        self.open_menu(terminal)
        os.write(terminal, b"h")
        self.wait_for(lambda: self.rect() == (1, 1, 58, 38))
        os.write(terminal, b"\x1b[27u")
        self.wait_for(lambda: not self.menu_running())
        os.write(terminal, b"x")
        self.wait_for(lambda: self.received.read_bytes() == b"x")

    def test_reentering_starts_new_direction_combination_and_plain_escape_exits(self):
        terminal = self.attach()
        self.open_menu(terminal)
        os.write(terminal, b"hk")
        self.wait_for(lambda: self.rect() == (1, 1, 58, 18))
        os.write(terminal, b"\x02\x17l")
        self.wait_for(lambda: self.rect() == (61, 1, 58, 38))
        os.write(terminal, b"\x1b")
        self.wait_for(lambda: not self.menu_running())
        os.write(terminal, b"x")
        self.wait_for(lambda: self.received.read_bytes() == b"x")


if __name__ == "__main__":
    unittest.main()
