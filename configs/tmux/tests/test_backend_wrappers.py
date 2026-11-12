"""Backend extension, dispatch semantics and framework integration."""

import importlib.util
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
import unittest


TMUX_DIR = Path(__file__).resolve().parents[1]
WRAPPERS = TMUX_DIR / "wrapper"


class BackendWrapperTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="tma-wrapper-test-", dir="/tmp")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.wrappers = self.root / "wrapper"
        shutil.copytree(str(WRAPPERS), str(self.wrappers))
        extra = self.wrappers / "example"
        extra.mkdir()
        (extra / "backend.sh").write_text('''
tma_example_headless_command() { printf 'cat > %q' "$3"; }
''')
        self.env = dict(os.environ, TMA_WRAPPER_ROOT=str(self.wrappers))

    def call(self, *args):
        return subprocess.run(["bash", str(WRAPPERS / "dispatch.sh"), *args],
                              env=self.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                              universal_newlines=True)

    def start_tmux(self):
        socket = str(self.root / "socket")
        tmux_bin = shutil.which("tmux")
        def tmux(*args):
            return subprocess.check_output([tmux_bin, "-S", socket, *args], universal_newlines=True).strip()
        binary = self.root / "example"
        binary.symlink_to("/bin/sleep")
        tmux("-f", "/dev/null", "new-session", "-d", "-s", "test", str(binary) + " 600")
        self.addCleanup(lambda: subprocess.run([tmux_bin, "-S", socket, "kill-server"], stderr=subprocess.DEVNULL))
        pane = tmux("display-message", "-p", "-t", "test:", "#{pane_id}")
        self.env.update(TMUX=socket + ",0,0", TMUX_PANE=pane,
                        AI_AGENT_STATE_LOG=str(self.root / "state.log"),
                        AI_AGENT_PROMPT_LOG=str(self.root / "prompts.jsonl"))
        tmux("set-option", "-p", "-t", pane, "@ai_agent_attribute", "test")
        return tmux, pane

    def test_new_directory_uses_shared_defaults_without_framework_changes(self):
        self.assertIn("example", self.call("--list").stdout.splitlines())
        result = self.call("example", "launch_command", "custom model", "")
        self.assertEqual(result.returncode, 0, result.stderr)
        script = 'example() { printf "%s\\n" "$TMUX_AI_MODEL"; }; ' + result.stdout
        actual = subprocess.check_output(["zsh", "-f", "-c", script], universal_newlines=True)
        self.assertEqual(actual.strip(), "custom model")

    def test_failure_in_backend_override_does_not_execute_default(self):
        (self.wrappers / "example/backend.sh").write_text(
            'tma_example_launch_command() { echo "backend failed" >&2; return 23; }\n')
        result = self.call("example", "launch_command", "", "")
        self.assertEqual(result.returncode, 23)
        self.assertEqual(result.stdout, "")
        self.assertIn("backend failed", result.stderr)

    def test_missing_capability_and_unknown_backend_fail_explicitly(self):
        result = self.call("example", "fork_command", "1", "%0", "1")
        self.assertEqual(result.returncode, 69)
        self.assertIn("does not support fork_command", result.stderr)
        self.assertEqual(self.call("missing", "launch_command", "", "").returncode, 64)
        self.assertEqual(self.call("../example", "command").returncode, 64)

    def test_model_and_effort_are_preserved_as_arguments(self):
        for backend, option in [("codex", "-c"), ("claude", "--effort")]:
            result = self.call(backend, "launch_command", 'model $(false)', "high")
            self.assertEqual(result.returncode, 0, result.stderr)
            script = backend + 'r() { printf "%s\\0" "$TMUX_AI_MODEL" "$@"; }; ' + result.stdout
            output = subprocess.check_output(["zsh", "-f", "-c", script]).decode().split("\0")[:-1]
            self.assertEqual(output[0], 'model $(false)')
            self.assertEqual(output[1], option)
        self.assertEqual(self.call("gemini", "launch_command", "", "high").returncode, 69)

    def test_default_headless_preserves_stdin_and_propagates_cli_failure(self):
        # A plain zsh avoids the user's interactive rc and model/network access.
        zsh = self.root / "zsh"
        zsh.write_text('#!/bin/sh\nshift\nexec ' + shlex.quote(shutil.which("zsh")) + ' -f -c "$1"\n')
        zsh.chmod(0o755)
        env = dict(self.env, PATH=str(self.root) + os.pathsep + os.environ["PATH"])
        result = subprocess.run(["bash", str(WRAPPERS / "dispatch.sh"), "example", "headless", "%0"],
                                input="a multiline\nprompt\n", env=env, universal_newlines=True,
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "a multiline\nprompt\n")
        (self.wrappers / "example/backend.sh").write_text(
            "tma_example_headless_command() { printf 'exit 17'; }\n")
        result = subprocess.run(["bash", str(WRAPPERS / "dispatch.sh"), "example", "headless", "%0"],
                                env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        self.assertEqual(result.returncode, 17)
        # A caller testing the result in `if` disables Bash's implicit errexit
        # inside functions; failure still must propagate unchanged.
        result = subprocess.run(["bash", "-c",
            'source "$1"; if tma_call example headless %0; then exit 0; else exit "$?"; fi',
            "test", str(WRAPPERS / "dispatch.sh")], env=env,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        self.assertEqual(result.returncode, 17)

    def test_native_backend_is_visible_in_both_detection_paths(self):
        tmux, pane = self.start_tmux()
        pid = tmux("display-message", "-p", "-t", pane, "#{pane_pid}")
        script = 'source "$1"; _find_ai_pid "$2"; _find_ai_pid "$2" "$(_ai_process_snapshot)"; _ai_pane_rows -a'
        output = subprocess.check_output(["bash", "-c", script, "test", str(TMUX_DIR / "ai/lib.sh"), pid],
                                         env=self.env, universal_newlines=True).splitlines()
        self.assertTrue(output[0].endswith(" example"), output)
        self.assertTrue(output[1].endswith(" example"), output)
        self.assertEqual(output[2].split("\t")[3], pane)

    def test_new_backend_launches_through_framework_and_missing_relocate_leaves_panes(self):
        tmux, pane = self.start_tmux()
        tmux("set-environment", "-g", "TMUX_AI_TOOL", "")
        self.assertEqual(self.call("default", "selected_backend").stdout.strip(), "codex")
        tmux("set-environment", "-g", "TMUX_AI_TOOL", "example")
        (self.wrappers / "example/backend.sh").write_text(
            'tma_example_launch_command() { tma_default_launch_command "$1" "$2" 600; }\n')
        # Execute the generated command without loading the user's zsh rc.
        zsh = self.root / "zsh"
        zsh.write_text('#!/bin/sh\nshift\nexec /bin/bash -c "$1"\n')
        zsh.chmod(0o755)
        tmux("set-environment", "-g", "PATH", str(self.root) + os.pathsep + os.environ["PATH"])
        subprocess.check_call(["bash", str(TMUX_DIR / "ai/new_ai_pane.sh"), "stacked", pane], env=self.env)
        panes = tmux("list-panes", "-t", "test:", "-F", "#{pane_id}")
        self.assertEqual(len(panes.splitlines()), 2)
        result = subprocess.run(["bash", str(TMUX_DIR / "script/split_to_float.sh"), pane],
                                env=self.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                universal_newlines=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("does not support relocate", result.stderr)
        self.assertEqual(tmux("list-panes", "-t", "test:", "-F", "#{pane_id}"), panes)

    def test_codex_and_claude_wrapper_hooks_preserve_turn_events(self):
        tmux, pane = self.start_tmux()
        payload = json.dumps(dict(prompt="wrapper migration", session_id="session", cwd=str(self.root)))
        for hook in [WRAPPERS / "codex/hook.sh", WRAPPERS / "claude/hook.sh"]:
            for event, running in [("init", "0"), ("running", "1"), ("pretool", "1"), ("stop", "0")]:
                result = subprocess.run(["bash", str(hook), event], input=payload,
                                        env=self.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                        universal_newlines=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(tmux("show-option", "-pqv", "-t", pane, "@ai_agent_running"), running)
            self.assertEqual(tmux("show-option", "-pqv", "-t", pane, "@ai_agent_unread"), "1")
        prompts = [json.loads(line) for line in (self.root / "prompts.jsonl").read_text().splitlines()]
        self.assertEqual([row["prompt"] for row in prompts], ["wrapper migration"] * 2)

    def test_legacy_hook_paths_still_serve_sessions_with_cached_commands(self):
        tmux, pane = self.start_tmux()
        payload = json.dumps(dict(hook_event_name="BeforeAgent", prompt="cached hook",
                                  session_id="session", cwd=str(self.root)))
        for backend, arguments in [("claude", ["running"]), ("gemini", [])]:
            subprocess.check_call([str(TMUX_DIR / "script/track_ai_agent_state.sh"), "init", pane],
                                  env=self.env)
            hook = TMUX_DIR / "script" / (backend + "_agent_state_hook.sh")
            result = subprocess.run(["bash", str(hook)] + arguments, input=payload,
                                    env=self.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                    universal_newlines=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(tmux("show-option", "-pqv", "-t", pane, "@ai_agent_running"), "1")
            self.assertTrue(tmux("show-option", "-gqv", "@ai_agent_event_source").startswith(backend + "-hook:"))

    def test_backend_tui_rules_are_isolated(self):
        footer = "Working (esc to cancel, 15s)"
        self.assertIn("gemini-running", self.call("gemini", "tui_state", footer).stdout)
        self.assertEqual(self.call("example", "tui_state", footer).stdout, "")
        self.assertEqual(self.call("codex", "tui_state", footer).stdout, "")

class ClaudeConfigMigrationTest(unittest.TestCase):
    def test_legacy_path_migrates_hooks_idempotently_without_removing_custom_settings(self):
        spec = importlib.util.spec_from_file_location(
            "config_claude", str(TMUX_DIR.parent / "llm/config_claude.py"))
        config = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(config)
        custom = {"type": "command", "command": "custom-hook"}
        settings = {"model": "custom-model", "statusLine": {"command": "custom-status"}, "hooks": {
            "Stop": [{"matcher": "*", "hooks": [custom, {
                "type": "command", "command": "bash ~/deploy/configs/tmux/script/claude_agent_state_hook.sh stop"
            }, {"type": "command", "command": "bash ~/deploy/configs/tmux/wrapper/claude/hook.sh stop"}]}]}}
        config.install_agent_hooks(settings)
        first = json.dumps(settings, sort_keys=True)
        config.install_agent_hooks(settings)
        self.assertEqual(json.dumps(settings, sort_keys=True), first)
        self.assertEqual(settings["hooks"]["Stop"][0]["hooks"], [custom])
        self.assertEqual(len(settings["hooks"]["Stop"]), 2)
        self.assertEqual(settings["model"], "custom-model")
        self.assertEqual(settings["statusLine"], {"command": "custom-status"})


if __name__ == "__main__":
    unittest.main()
