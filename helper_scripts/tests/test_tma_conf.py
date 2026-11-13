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

from textual.widgets import OptionList, Static, TabbedContent

TMA_CONF_PATH = Path(__file__).resolve().parents[1] / "bin/tma-conf"
loader = SourceFileLoader("tma_conf", str(TMA_CONF_PATH))
conf = module_from_spec(spec_from_loader(loader.name, loader))
sys.modules[loader.name] = conf
loader.exec_module(conf)


class TmaConfTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="tma-conf-test-", dir="/tmp")
        self.addCleanup(self.temp.cleanup)
        self.socket = str(Path(self.temp.name) / "tmux.sock")
        self.tmux_bin = shutil.which("tmux")
        subprocess.run([self.tmux_bin, "-S", self.socket, "-f", "/dev/null", "new-session", "-d", "-s", "test", "sleep 600"], check=True)
        self.addCleanup(lambda: subprocess.run([self.tmux_bin, "-S", self.socket, "kill-server"], stderr=subprocess.DEVNULL))
        self.env = dict(os.environ, TMUX=f"{self.socket},0,0")
        self.env.pop("TMUX_AI_TOOL", None)

    def tmux(self, *args: str) -> str:
        return subprocess.check_output([self.tmux_bin, "-S", self.socket, *args], text=True).strip()

    def cli(self, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run([str(TMA_CONF_PATH), *args], env=self.env, capture_output=True, text=True)

    def test_cli_sets_and_reads_default_agent_including_pi(self):
        self.tmux("set-environment", "-g", "-r", "TMUX_AI_TOOL")
        shown = dict(line.split("\t") for line in self.cli("--show").stdout.splitlines())
        self.assertEqual(shown["default-agent"], "codex")

        result = self.cli("--set", "default-agent", "pi")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "default-agent\tpi")
        self.assertEqual(self.tmux("show-environment", "-g", "TMUX_AI_TOOL"), "TMUX_AI_TOOL=pi")

        result = self.cli("--set", "default-agent", "codex")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "default-agent\tcodex")
        self.assertEqual(self.tmux("show-environment", "-g", "TMUX_AI_TOOL"), "TMUX_AI_TOOL=codex")

        bad = self.cli("--set", "default-agent", "unknown")
        self.assertNotEqual(bad.returncode, 0)
        self.assertIn("default-agent", bad.stderr)

    async def test_tui_switches_to_default_agent_tab_and_selects_pi(self):
        self.tmux("set-environment", "-g", "-r", "TMUX_AI_TOOL")
        with patch.dict(os.environ, {"TMUX": f"{self.socket},0,0"}):
            app = conf.TmaConf()
            async with app.run_test(size=(120, 45)) as pilot:
                await pilot.press("3")
                self.assertEqual(app.query_one(TabbedContent).active, "default-agent")
                options = app.query_one("#default-agent-choices", OptionList)
                self.assertEqual(options.get_option_at_index(options.highlighted).id, "codex")
                await pilot.press("down", "right")
                self.assertEqual(self.tmux("show-environment", "-g", "TMUX_AI_TOOL"), "TMUX_AI_TOOL=pi")
                self.assertIn("tmux env TMUX_AI_TOOL", str(app.query_one("#default-agent-status", Static).content))


if __name__ == "__main__":
    unittest.main()
