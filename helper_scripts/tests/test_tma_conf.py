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

from textual.widgets import OptionList, SelectionList, TabbedContent

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

    def tmux(self, *args: str) -> str:
        return subprocess.check_output([self.tmux_bin, "-S", self.socket, *args], text=True).strip()

    def cli(self, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run([str(TMA_CONF_PATH), *args], env=self.env, capture_output=True, text=True)

    def test_cli_sets_tma_options_only(self):
        shown = dict(line.split("\t") for line in self.cli("--show").stdout.splitlines())
        self.assertEqual(shown["preview-width"], "full")
        self.assertNotIn("default-agent", shown)

        result = self.cli("--set", "preview-width", "50")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.tmux("show-option", "-gqv", "@auto_switch_preview_width"), "50")

        result = self.cli("--set", "preview-width", "full")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.tmux("show-option", "-gqv", "@auto_switch_preview_width"), "")

    async def test_tui_switches_tabs_and_updates_options(self):
        with patch.dict(os.environ, {"TMUX": f"{self.socket},0,0"}):
            app = conf.TmaConf()
            async with app.run_test(size=(120, 45)) as pilot:
                self.assertEqual([s.tab for s in conf.SETTINGS], ["preview-width", "tma-count"])
                options = app.query_one("#preview-width-choices", OptionList)
                self.assertEqual(options.get_option_at_index(options.highlighted).id, "full")
                await pilot.press("down", "right")
                self.assertEqual(self.tmux("show-option", "-gqv", "@auto_switch_preview_width"), "75")
                await pilot.press("2")
                self.assertEqual(app.query_one(TabbedContent).active, "tma-count")
                self.assertIsInstance(app.query_one("#tma-count-choices"), SelectionList)


if __name__ == "__main__":
    unittest.main()
