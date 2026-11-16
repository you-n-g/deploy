#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["textual>=8.2,<9"]
# ///

from importlib.machinery import SourceFileLoader
from importlib.util import module_from_spec, spec_from_loader
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from textual.widgets import OptionList, SelectionList, Static, TabbedContent

CONF_TMA_PATH = Path(__file__).resolve().parents[1] / "bin/conf-tma"
loader = SourceFileLoader("conf_tma", str(CONF_TMA_PATH))
conf = module_from_spec(spec_from_loader(loader.name, loader))
sys.modules[loader.name] = conf
loader.exec_module(conf)


class ConfTmaTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="conf-tma-test-", dir="/tmp")
        self.addCleanup(self.temp.cleanup)
        self.socket = str(Path(self.temp.name) / "tmux.sock")
        self.tmux_bin = shutil.which("tmux")
        env = dict(os.environ)
        env.pop("TMUX_AI_TOOL", None)
        subprocess.run([self.tmux_bin, "-S", self.socket, "-f", "/dev/null", "new-session", "-d", "-s", "test", "sleep 600"], env=env, check=True)
        self.addCleanup(lambda: subprocess.run([self.tmux_bin, "-S", self.socket, "kill-server"], stderr=subprocess.DEVNULL))
        self.env = dict(env, TMUX=f"{self.socket},0,0")

    def tmux(self, *args: str) -> str:
        return subprocess.check_output([self.tmux_bin, "-S", self.socket, *args], text=True).strip()

    def cli(self, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run([str(CONF_TMA_PATH), *args], env=self.env, capture_output=True, text=True)

    def test_cli_sets_options_env_and_orchestrator_switches(self):
        shown = dict(line.split("\t") for line in self.cli("--show").stdout.splitlines())
        self.assertEqual(shown["preview-width"], "full")
        self.assertEqual(shown["show-orchestrator"], "on")
        self.assertEqual(shown["send-to-orchestrator"], "on")
        self.assertEqual(shown["ai-tool"], "codex")
        self.assertEqual(shown["lm-progress"], "off")

        # Numeric 1/0 written by Ctrl-O in fzf or apply_status_lines.sh is understood too.
        self.tmux("set-option", "-g", "@tmuxg-show-orchestrator", "0")
        shown = dict(line.split("\t") for line in self.cli("--show").stdout.splitlines())
        self.assertEqual(shown["show-orchestrator"], "off")

        result = self.cli("--set", "show-orchestrator", "on")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.tmux("show-option", "-gqv", "@tmuxg-show-orchestrator"), "")

        result = self.cli("--set", "show-orchestrator", "off")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.tmux("show-option", "-gqv", "@tmuxg-show-orchestrator"), "off")

        result = self.cli("--set", "ai-tool", "dsh")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.tmux("show-environment", "-g", "TMUX_AI_TOOL"), "TMUX_AI_TOOL=dsh")

        result = self.cli("--set", "lm-progress", "top20")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.tmux("show-option", "-gqv", "@lm_progress"), "top20")

        result = self.cli("--set", "lm-progress", "off")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.tmux("show-option", "-gqv", "@lm_progress"), "")

        # Legacy @lm_progress=1 maps to mean.
        self.tmux("set-option", "-g", "@lm_progress", "1")
        shown = dict(line.split("\t") for line in self.cli("--show").stdout.splitlines())
        self.assertEqual(shown["lm-progress"], "mean")

    async def test_tui_switches_tabs_and_updates_options(self):
        with patch.dict(os.environ, {"TMUX": f"{self.socket},0,0"}):
            app = conf.TmaConf()
            async with app.run_test(size=(120, 45)) as pilot:
                self.assertEqual(
                    [s.tab for s in conf.SETTINGS],
                    ["preview-width", "tma-count", "orchestrator", "ai-tool", "lm-progress"],
                )
                options = app.query_one("#preview-width-choices", OptionList)
                self.assertEqual(options.get_option_at_index(options.highlighted).id, "full")
                await pilot.press("down", "right")
                self.assertEqual(self.tmux("show-option", "-gqv", "@auto_switch_preview_width"), "75")

                await pilot.press("2")
                self.assertEqual(app.query_one(TabbedContent).active, "tma-count")
                self.assertIsInstance(app.query_one("#tma-count-choices"), SelectionList)

                await pilot.press("3")
                self.assertEqual(app.query_one(TabbedContent).active, "orchestrator")
                orch_switches = app.query_one("#orchestrator-choices", SelectionList)
                self.assertEqual(set(orch_switches.selected), {"show-orchestrator", "send-to-orchestrator"})
                await pilot.press("space")
                self.assertEqual(self.tmux("show-option", "-gqv", "@tmuxg-show-orchestrator"), "off")

                await pilot.press("4")
                self.assertEqual(app.query_one(TabbedContent).active, "ai-tool")
                ai_tools = app.query_one("#ai-tool-choices", OptionList)
                self.assertIn("dsh", [ai_tools.get_option_at_index(i).id for i in range(ai_tools.option_count)])
                await pilot.press("down", "right")
                self.assertEqual(self.tmux("show-environment", "-g", "TMUX_AI_TOOL"), "TMUX_AI_TOOL=pi")
                self.assertIn("tmux env TMUX_AI_TOOL", str(app.query_one("#ai-tool-status", Static).content))

                await pilot.press("5")
                self.assertEqual(app.query_one(TabbedContent).active, "lm-progress")
                await pilot.press("down", "right")
                self.assertEqual(self.tmux("show-option", "-gqv", "@lm_progress"), "mean")


if __name__ == "__main__":
    unittest.main()
