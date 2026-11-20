"""External prompt editing blocks until the floating Vim saves, exits or is closed."""

import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
import time
import unittest


TMUX_DIR = Path(__file__).resolve().parents[1]
REPO = TMUX_DIR.parents[1]
VIM = str(REPO / "helper_scripts/bin/vim-fast")
FLOAT = str(TMUX_DIR / "script/run_in_float.sh")
PI_CONFIGURE = str(TMUX_DIR / "wrapper/pi/configure.py")


class FloatEditorTest(unittest.TestCase):
    def tmux(self, *args):
        return subprocess.check_output(
            ["tmux", "-S", self.socket, *args], universal_newlines=True
        ).strip()

    def wait_for(self, predicate):
        deadline = time.monotonic() + 5
        while not predicate():
            self.assertLess(time.monotonic(), deadline, "floating editor did not reach expected state")
            time.sleep(0.03)

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="tmux-float-editor-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.socket = str(self.root / "socket")
        self.tmux("-f", "/dev/null", "new-session", "-d", "-s", "test",
                  "-x", "120", "-y", "40", "/bin/sh")
        self.addCleanup(lambda: subprocess.run(
            ["tmux", "-S", self.socket, "kill-server"], stderr=subprocess.DEVNULL
        ))
        self.pane = self.tmux("display-message", "-p", "-t", "test:", "#{pane_id}")
        self.sentences = self.root / "sentences"
        self.env = dict(os.environ, TMUX=self.socket + ",0,0", TMUX_PANE=self.pane,
                        TMPDIR=self.temp.name, TMA_FAST_SENTENCES=str(self.sentences))
        self.file = self.root / "prompt's $(literal) 中文.md"
        self.file.write_text("draft prompt\n")

    @staticmethod
    def stop(process):
        if process.poll() is None:
            process.terminate()
        process.wait(timeout=5)

    def start(self, command):
        process = subprocess.Popen(command, cwd=self.temp.name, env=self.env,
                                   stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        self.addCleanup(process.stderr.close)
        self.addCleanup(self.stop, process)
        return process

    def floats(self):
        return self.tmux("list-panes", "-t", self.pane, "-f", "#{pane_floating_flag}",
                         "-F", "#{pane_id}").splitlines()

    def start_vim(self, visible="draft prompt"):
        process = self.start([VIM, self.file.name])
        self.wait_for(lambda: len(self.floats()) == 1)
        floating = self.floats()[0]
        self.wait_for(lambda: visible in self.tmux("capture-pane", "-p", "-t", floating))
        return process, floating

    def assert_clean(self):
        self.assertEqual(self.floats(), [])
        self.assertEqual(list(self.root.glob("tmux-float-editor.*")), [])

    def test_zoomed_prompt_opens_small_float_and_returns_only_after_save(self):
        self.tmux("split-window", "-d", "-t", self.pane, "/bin/sh")
        self.tmux("resize-pane", "-Z", "-t", self.pane)
        process, floating = self.start_vim()
        self.assertIsNone(process.poll())
        self.assertEqual(self.tmux("display-message", "-p", "-t", floating,
                                   "#{pane_width}|#{pane_height}|#{pane_active}|#{@jump-history-skip}"),
                         "98|18|1|1")
        self.tmux("send-keys", "-t", floating, "gg^C", "edited prompt", "Escape")
        self.assertEqual(self.file.read_text(), "draft prompt\n")
        self.assertIsNone(process.poll())
        self.tmux("send-keys", "-t", floating, ":wq", "Enter")
        self.assertEqual(process.wait(timeout=5), 0, process.stderr.read().decode())
        self.assertEqual(self.file.read_text(), "edited prompt\n")
        self.assertEqual(self.tmux("display-message", "-p", "-t", "test:", "#{pane_id}"), self.pane)
        self.assert_clean()

    def test_closing_float_unblocks_caller_without_changing_prompt(self):
        process, floating = self.start_vim()
        self.tmux("kill-pane", "-t", floating)
        self.assertNotEqual(process.wait(timeout=5), 0)
        self.assertEqual(self.file.read_text(), "draft prompt\n")
        self.assert_clean()

    def test_command_failure_reaches_external_editor_caller(self):
        process = self.start([FLOAT, self.pane, "/bin/sh", "-c", "exit 7"])
        self.assertEqual(process.wait(timeout=5), 7, process.stderr.read().decode())
        self.assert_clean()

    def test_outside_tmux_keeps_direct_editor_behavior(self):
        env = dict(self.env)
        env.pop("TMUX")
        env.pop("TMUX_PANE")
        subprocess.check_call(
            [VIM, "-es", "-c", "normal! gg0Cdirect edit", "-c", "wq", self.file.name],
            cwd=self.temp.name, env=env,
        )
        self.assertEqual(self.file.read_text(), "direct edit\n")
        self.assert_clean()

    def test_pi_ctrl_g_opens_floating_vim_fast_and_returns_prompt(self):
        pi_bin = shutil.which("pi")
        if not pi_bin:
            self.skipTest("pi CLI is not installed")
        home = self.root / "home"
        (home / ".config/llm").mkdir(parents=True)
        (home / ".config/llm/gateways.local.json").write_text(json.dumps({"pi": {
            "provider": "google-test", "model": "gateway-model-test", "name": "Test Model",
        }}))
        (home / ".gemini").mkdir()
        (home / ".gemini/.env").write_text(
            'GOOGLE_GEMINI_BASE_URL="https://gateway.test"\nGEMINI_API_KEY="test-secret"\n'
        )
        subprocess.check_call(["python3", PI_CONFIGURE], env=dict(self.env, HOME=str(home)),
                              stdout=subprocess.DEVNULL)
        settings = json.loads((home / ".pi/agent/settings.json").read_text())
        self.assertEqual(Path(settings["externalEditor"]).resolve(), Path(VIM).resolve())

        cmd = "HOME={} PI_OFFLINE=1 exec {} --no-extensions --no-skills --no-session".format(
            shlex.quote(str(home)), shlex.quote(pi_bin)
        )
        self.tmux("respawn-pane", "-k", "-t", self.pane, cmd)
        self.wait_for(lambda: "escape interrupt" in self.tmux("capture-pane", "-p", "-t", self.pane))
        self.tmux("send-keys", "-t", self.pane, "initial text")
        self.wait_for(lambda: "initial text" in self.tmux("capture-pane", "-p", "-t", self.pane))

        # Ctrl+G opens vim-fast in a floating pane; normal-mode `q` saves and quits.
        self.tmux("send-keys", "-t", self.pane, "C-g")
        self.wait_for(lambda: len(self.floats()) == 1)
        floating = self.floats()[0]
        self.wait_for(lambda: "initial text" in self.tmux("capture-pane", "-p", "-t", floating))
        self.tmux("send-keys", "-t", floating, "gg^C", "from fastvim popup", "Escape", "q")
        self.wait_for(lambda: self.floats() == [])
        self.wait_for(lambda: "from fastvim popup" in self.tmux("capture-pane", "-p", "-t", self.pane))
        self.assert_clean()

    def test_quit_returns_draft_and_keeps_sentence_list_out_of_prompt(self):
        self.sentences.write_text("# header\n0 saved sentence\n")
        process, floating = self.start_vim()
        self.wait_for(lambda: "saved sentence" in self.tmux("capture-pane", "-p", "-t", floating))
        self.tmux("send-keys", "-t", floating, "gg^C", "hello", "Escape", "q")
        self.assertEqual(process.wait(timeout=5), 0, process.stderr.read().decode())
        self.assertEqual(self.file.read_text(), "hello\n")
        self.assertNotIn("saved sentence", self.file.read_text())
        self.assertNotIn("\u2500", self.file.read_text())
        self.assert_clean()

    def test_number_sends_that_sentence_and_leaves_other_slots(self):
        self.sentences.write_text("3 third sentence\n")
        process, floating = self.start_vim()
        self.wait_for(lambda: "third sentence" in self.tmux("capture-pane", "-p", "-t", floating))
        self.tmux("send-keys", "-t", floating, "3")
        self.assertEqual(process.wait(timeout=5), 0, process.stderr.read().decode())
        self.assertEqual(self.file.read_text(), "third sentence\n")
        self.assertEqual(self.sentences.read_text(), "3 third sentence\n")
        self.assert_clean()

    def test_empty_number_does_not_quit_or_change_prompt(self):
        process, floating = self.start_vim()
        self.wait_for(lambda: "\u2500" in self.tmux("capture-pane", "-p", "-t", floating))
        self.tmux("send-keys", "-t", floating, "4")
        time.sleep(0.2)
        self.assertIsNone(process.poll())
        self.assertEqual(self.file.read_text(), "draft prompt\n")
        self.assertFalse(self.sentences.exists())
        self.tmux("send-keys", "-t", floating, ":q!", "Enter")
        self.assertEqual(process.wait(timeout=5), 0, process.stderr.read().decode())
        self.assert_clean()

    def test_ga_saves_current_line_and_later_number_sends_it(self):
        process, floating = self.start_vim()
        self.wait_for(lambda: "\u2500" in self.tmux("capture-pane", "-p", "-t", floating))
        self.tmux("send-keys", "-t", floating, "gg^C", "remember me", "Escape", "ga", "q")
        self.assertEqual(process.wait(timeout=5), 0, process.stderr.read().decode())
        self.assertEqual(self.file.read_text(), "remember me\n")
        self.assertIn("0 remember me", self.sentences.read_text().splitlines())

        self.file.write_text("other draft\n")
        process, floating = self.start_vim("other draft")
        self.wait_for(lambda: "remember me" in self.tmux("capture-pane", "-p", "-t", floating))
        self.tmux("send-keys", "-t", floating, "0")
        self.assertEqual(process.wait(timeout=5), 0, process.stderr.read().decode())
        self.assertEqual(self.file.read_text(), "remember me\n")
        self.assert_clean()

    def test_editing_a_numbered_line_is_saved_on_quit(self):
        self.sentences.write_text("1 old\n")
        process, floating = self.start_vim()
        self.wait_for(lambda: "1 old" in self.tmux("capture-pane", "-p", "-t", floating))
        self.tmux("send-keys", "-t", floating, "/^1 old", "Enter", "f ", "lC", "new text", "Escape", "q")
        self.assertEqual(process.wait(timeout=5), 0, process.stderr.read().decode())
        self.assertEqual(self.file.read_text(), "draft prompt\n")
        self.assertIn("1 new text", self.sentences.read_text().splitlines())
        self.assert_clean()

    def sentences_env(self, home):
        env = dict(self.env)
        env.pop("TMA_FAST_SENTENCES")
        env.pop("XDG_DATA_HOME", None)
        env["HOME"] = str(home)
        return env

    def test_sentences_link_to_farside_when_repo_exists(self):
        home = self.root / "home"
        farside = home / "farside"
        (farside / ".git").mkdir(parents=True)
        local = home / ".local/share/tma/vim-fast-sentences"
        local.parent.mkdir(parents=True)
        local.write_text("0 kept\n")
        out = subprocess.check_output(
            [VIM, "--resolve-sentences"], env=self.sentences_env(home), text=True).strip()
        target = farside / "vim-fast-sentences"
        self.assertEqual(out, str(target))
        self.assertEqual(target.read_text(), "0 kept\n")
        self.assertTrue(local.is_symlink())
        self.assertEqual(os.readlink(local), str(target))
        again = subprocess.check_output(
            [VIM, "--resolve-sentences"], env=self.sentences_env(home), text=True).strip()
        self.assertEqual(again, str(target))

    def test_sentences_stay_local_without_farside(self):
        home = self.root / "home-no-repo"
        home.mkdir()
        out = subprocess.check_output(
            [VIM, "--resolve-sentences"], env=self.sentences_env(home), text=True).strip()
        local = home / ".local/share/tma/vim-fast-sentences"
        self.assertEqual(out, str(local))
        self.assertFalse(local.exists())
        self.assertFalse((home / "farside").exists())


if __name__ == "__main__":
    unittest.main()
