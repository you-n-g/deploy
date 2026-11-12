"""Gemini hooks and node process detection on an isolated tmux server."""

import importlib.util
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
HOOK = str(TMUX_DIR / "wrapper/gemini/hook.sh")
TRACKER = str(TMUX_DIR / "script/track_ai_agent_state.sh")
LIB = str(TMUX_DIR / "ai/lib.sh")


class GeminiHookTest(unittest.TestCase):
    def tmux(self, *args):
        return subprocess.check_output(
            [self.tmux_bin, "-S", self.socket, *args], universal_newlines=True
        ).strip()

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="gemini-hooks-", dir="/tmp")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.tmux_bin = shutil.which("tmux")
        self.socket = str(self.root / "socket")
        entry = self.root / "bin/gemini"
        entry.parent.mkdir()
        entry.write_text("setInterval(() => {}, 1000);\n")
        command = "{} --max-old-space-size=128 {}".format(
            shlex.quote(shutil.which("node")), shlex.quote(str(entry)))
        self.tmux("-f", "/dev/null", "new-session", "-d", "-s", "test", command)
        self.addCleanup(lambda: subprocess.run(
            [self.tmux_bin, "-S", self.socket, "kill-server"], stderr=subprocess.DEVNULL))
        self.pane = self.tmux("display-message", "-p", "-t", "test:", "#{pane_id}")
        self.env = dict(os.environ, TMUX=self.socket + ",0,0", TMUX_PANE=self.pane,
                        AI_AGENT_STATE_LOG=str(self.root / "state.log"),
                        AI_AGENT_PROMPT_LOG=str(self.root / "prompts.jsonl"))
        self.tmux("set-option", "-p", "-t", self.pane, "@ai_agent_attribute", "test")

    def shell(self, code, *args):
        return subprocess.check_output(
            ["bash", "-c", 'source "$1"; shift; ' + code, "test", LIB, *args],
            env=self.env, universal_newlines=True).strip()

    def hook(self, event, **fields):
        payload = dict(hook_event_name=event, session_id="test-session",
                       cwd=str(self.root), **fields)
        result = subprocess.run(["bash", HOOK], input=json.dumps(payload),
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                universal_newlines=True, env=self.env, timeout=15)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), {})

    def option(self, key):
        return self.tmux("show-option", "-pqv", "-t", self.pane, key)

    def test_turn_logs_once_and_unseen_completion_becomes_unread(self):
        self.hook("SessionStart", source="startup")
        self.assertEqual(self.option("@ai_agent_running"), "0")
        self.hook("BeforeAgent", prompt="Explain this task")
        self.assertEqual(self.option("@ai_agent_running"), "1")
        seq = self.tmux("show-option", "-gqv", "@ai_agent_event_seq")
        for event in ["BeforeModel", "BeforeTool", "PreCompress"]:
            self.hook(event)
        self.assertEqual(self.tmux("show-option", "-gqv", "@ai_agent_event_seq"), seq)
        self.hook("AfterAgent", prompt="Explain this task")
        self.assertEqual(self.option("@ai_agent_running"), "0")
        self.assertEqual(self.option("@ai_agent_unread"), "1")
        rows = [json.loads(line) for line in (self.root / "prompts.jsonl").read_text().splitlines()]
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["prompt"], "Explain this task")
        self.assertEqual(rows[0]["ai_session_id"], "test-session")
        self.assertEqual(rows[0]["source"], "gemini-hook:BeforeAgent")
        subprocess.check_call([TRACKER, "visit", self.pane], env=self.env)
        self.assertEqual(self.option("@ai_agent_unread"), "0")
        self.assertEqual(self.option("@ai_agent_running"), "0")

    def test_permission_wait_and_session_end_are_actionable(self):
        self.hook("BeforeAgent", prompt="Write a file")
        self.hook("Notification", notification_type="ToolPermission")
        self.assertEqual(self.option("@ai_agent_running"), "0")
        self.assertEqual(self.option("@ai_agent_unread"), "1")
        self.hook("SessionEnd", reason="exit")
        self.assertEqual(self.option("@ai_agent_running"), "0")

    def test_live_footer_resumes_running_after_permission_without_another_hook(self):
        self.hook("BeforeAgent", prompt="Run a tool")
        self.hook("Notification", notification_type="ToolPermission")
        entry = self.root / "bin/gemini"
        entry.write_text('console.log("Working (esc to cancel, 15s)"); setInterval(() => {}, 1000);\n')
        command = "{} {}".format(shlex.quote(shutil.which("node")), shlex.quote(str(entry)))
        self.tmux("respawn-pane", "-k", "-t", self.pane, command)
        tracker = subprocess.Popen(
            [str(TMUX_DIR / "state-tracker/tui-output.sh"), self.pane],
            env=dict(self.env, TMUX_AI_STATE_TRACKER_LOCK_DIR=str(self.root),
                     TMUX_AI_STATE_TRACKER_INTERVAL="0.05"),
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            deadline = time.monotonic() + 5
            while self.tmux("show-option", "-gqv", "@ai_agent_event_source") != "tui-output:gemini-running":
                self.assertLess(time.monotonic(), deadline)
                time.sleep(0.05)
            self.assertEqual(self.option("@ai_agent_running"), "1")
        finally:
            tracker.terminate()
            tracker.wait(timeout=5)

    def test_continuation_releases_pending_and_publishes_running(self):
        subprocess.check_call([TRACKER, "pending", self.pane, "waiting"], env=self.env)
        self.hook("BeforeModel")
        self.assertEqual(self.option("@ai_agent_pending"), "")
        self.assertEqual(self.option("@ai_agent_running"), "1")
        self.assertEqual(self.tmux("show-option", "-gqv", "@ai_agent_event_state"), "running")

    def test_node_entry_is_found_by_procfs_and_batched_picker(self):
        pid = self.tmux("display-message", "-p", "-t", self.pane, "#{pane_pid}")
        self.assertTrue(self.shell('_find_ai_pid "$1"', pid).endswith(" gemini"))
        self.assertTrue(self.shell('_find_ai_pid "$1" "$(_ai_process_snapshot)"', pid).endswith(" gemini"))
        rows = self.shell("_ai_pane_rows -a").splitlines()
        self.assertIn(self.pane, [row.split("\t")[3] for row in rows])
        # A node program mentioning Gemini as an argument is not Gemini.
        result = subprocess.run(["bash", "-c",
            'source "$1"; _gemini_argv_matches node unrelated.js /usr/bin/gemini',
            "test", LIB], env=self.env)
        self.assertEqual(result.returncode, 1)

    def test_non_tmux_invocation_leaves_pane_alone(self):
        env = dict(self.env)
        env.pop("TMUX")
        env.pop("TMUX_PANE")
        result = subprocess.run(["bash", HOOK], input="{}", env=env,
                                stdout=subprocess.PIPE, universal_newlines=True, check=True)
        self.assertEqual(json.loads(result.stdout), {})
        self.assertEqual(self.option("@ai_agent_running"), "")

    def test_cancel_footer_keeps_live_gemini_from_stale_idle(self):
        self.shell('tma_call gemini foreground_busy "(esc to cancel, 15s)"')


class GeminiConfigTest(unittest.TestCase):
    def test_install_is_idempotent_and_preserves_custom_hooks_and_settings(self):
        spec = importlib.util.spec_from_file_location(
            "config_gemini", str(TMUX_DIR.parent / "llm/config_gemini.py"))
        config = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(config)
        custom = {"type": "command", "command": "my-custom-hook"}
        settings = {
            "model": {"name": "my-model"},
            "context": {"includeDirectories": ["/existing/workspace"]},
            "hooks": {"BeforeAgent": [{"matcher": "*", "hooks": [custom, {
                "type": "command", "command": config.HOOK_COMMAND}, {
                "type": "command", "command": "bash ~/deploy/configs/tmux/script/gemini_agent_state_hook.sh"}]}]},
            "hooksConfig": {"notifications": False},
            "security": {"auth": {"selectedType": "gemini-api-key"}},
        }
        with tempfile.TemporaryDirectory(prefix="gemini-config-", dir="/tmp") as root:
            config.GEMINI_DIR = Path(root) / ".gemini"
            config.GEMINI_DIR.mkdir()
            codex_sessions = Path(root) / ".codex" / "sessions"
            codex_sessions.mkdir(parents=True)
            path = config.GEMINI_DIR / "settings.json"
            path.write_text(json.dumps(settings))
            config.configure()
            first = path.read_text()
            config.configure()
            self.assertEqual(path.read_text(), first)
            result = json.loads(first)
            self.assertTrue((config.GEMINI_DIR / "tmp").is_dir())
            self.assertEqual(result["context"]["includeDirectories"],
                             ["/existing/workspace", str(config.GEMINI_DIR / "tmp"),
                              str(codex_sessions)])
        self.assertEqual(result["model"], settings["model"])
        self.assertEqual(result["security"], settings["security"])
        self.assertFalse(result["hooksConfig"]["notifications"])
        self.assertTrue(result["hooksConfig"]["enabled"])
        self.assertEqual(result["hooks"]["BeforeAgent"][0]["hooks"], [custom])
        self.assertEqual(set(result["hooks"]), set(config.HOOK_EVENTS))
        self.assertEqual(result["agents"]["overrides"]["cli_help"]["modelConfig"]["model"], "inherit")
        self.assertIn("GEMINI_CLI.md", result["context"]["fileName"])


if __name__ == "__main__":
    unittest.main()
