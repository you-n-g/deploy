#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["textual>=8.2,<9"]
# ///

from importlib.machinery import SourceFileLoader
from importlib.util import module_from_spec, spec_from_loader
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from textual.widgets import OptionList, TabbedContent

loader = SourceFileLoader("llm_conf", str(Path(__file__).resolve().parents[1] / "bin/llm-conf"))
conf = module_from_spec(spec_from_loader(loader.name, loader))
loader.exec_module(conf)


class ProviderChoicesTests(unittest.TestCase):
    def test_missing_and_empty_directory_allow_inherit(self):
        with tempfile.TemporaryDirectory() as directory:
            providers = Path(directory) / "providers"
            with patch.object(conf, "CLAUDER_PROVIDER_DIR", providers):
                self.assertEqual([value for value, _ in conf.clauder_provider_choices()], ["inherit"])
                self.assertFalse(providers.exists())
                providers.mkdir()
                self.assertEqual([value for value, _ in conf.clauder_provider_choices()], ["inherit"])

    def test_valid_provider_is_still_listed(self):
        with tempfile.TemporaryDirectory() as directory:
            providers = Path(directory)
            (providers / "example.json").write_text('{"model":"example-model","env":{"ANTHROPIC_BASE_URL":"https://example.com"}}')
            with patch.object(conf, "CLAUDER_PROVIDER_DIR", providers):
                choices = conf.clauder_provider_choices()
            self.assertEqual([value for value, _ in choices], ["example", "inherit"])
            self.assertIn("example-model", choices[0][1])

    def test_malformed_provider_still_reports_error(self):
        with tempfile.TemporaryDirectory() as directory:
            providers = Path(directory)
            (providers / "broken.json").write_text('{')
            with patch.object(conf, "CLAUDER_PROVIDER_DIR", providers):
                with self.assertRaisesRegex(conf.ToolError, "cannot read.*broken.json"):
                    conf.clauder_provider_choices()

    def test_existing_file_is_not_treated_as_empty_directory(self):
        with tempfile.TemporaryDirectory() as directory:
            providers = Path(directory) / "providers"
            providers.write_text("not a directory")
            with patch.object(conf, "CLAUDER_PROVIDER_DIR", providers):
                with self.assertRaisesRegex(conf.ToolError, "not a directory"):
                    conf.clauder_provider_choices()


class StartupTests(unittest.IsolatedAsyncioTestCase):
    async def test_missing_providers_does_not_block_other_settings_tabs(self):
        def tmux_read(*args, **kwargs):
            self.assertIn(args[0], {"show-option", "show-environment"})
            return subprocess.CompletedProcess(["tmux", *args], 0, stdout="", stderr="")

        with tempfile.TemporaryDirectory() as directory:
            with patch.object(conf, "CLAUDER_PROVIDER_DIR", Path(directory) / "providers"), patch.object(conf, "run_tmux", side_effect=tmux_read):
                app = conf.ProviderApp("%test", "test", conf.STATIC_CHOICES + (("inherit", "inherit"),), conf.clauder_provider_choices())
                async with app.run_test(size=(120, 45)) as pilot:
                    self.assertEqual(app.query_one("#providers", OptionList).option_count, 5)
                    await pilot.press("2")
                    self.assertEqual(app.query_one(TabbedContent).active, "clauder-tab")
                    self.assertEqual(app.query_one("#clauder-providers", OptionList).option_count, 1)
                    await pilot.press("5")
                    self.assertEqual(app.query_one(TabbedContent).active, "lm-progress-tab")


if __name__ == "__main__":
    unittest.main()
