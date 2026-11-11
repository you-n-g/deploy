"""Interactive agents, broker branches and scan bounds on real process trees."""

import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import tempfile
import time
import unittest
from unittest.mock import patch


SCANNER_PATH = Path(__file__).resolve().parents[1] / "wrapper/default/pane_processes.py"
spec = importlib.util.spec_from_file_location("pane_processes", str(SCANNER_PATH))
scanner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(scanner)
PATTERN = re.compile(r"(^|/)(codex|gemini)$")


class PaneProcessScanTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="tma-pane-processes-", dir="/tmp")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.agent = self.root / "codex"
        self.agent.symlink_to("/bin/sleep")
        self.node = shutil.which("node")

    def program(self, relative_path, children=()):
        path = self.root / relative_path
        path.parent.mkdir(parents=True, exist_ok=True)
        ready = self.root / (path.name + ".ready")
        path.write_text('''
const {spawn} = require('child_process');
const fs = require('fs');
const children = %s;
Promise.all(children.map(args => new Promise((resolve, reject) => {
  const child = spawn(args[0], args.slice(1), {stdio: 'ignore'});
  child.once('spawn', resolve);
  child.once('error', reject);
}))).then(() => fs.writeFileSync(%s, 'ready'));
setInterval(() => {}, 1000);
''' % (json.dumps(children), json.dumps(str(ready))))
        return path, ready

    def start(self, program, ready_files, *arguments):
        process = subprocess.Popen([self.node, str(program)] + list(arguments),
                                   start_new_session=True, stdout=subprocess.DEVNULL,
                                   stderr=subprocess.DEVNULL)
        def stop():
            os.killpg(process.pid, signal.SIGTERM)
            process.wait(timeout=5)
        self.addCleanup(stop)
        deadline = time.monotonic() + 5
        while not all(path.exists() for path in ready_files):
            self.assertIsNone(process.poll(), "fixture exited")
            self.assertLess(time.monotonic(), deadline, "fixture did not start")
            time.sleep(0.02)
        return process.pid

    def scan(self, pid):
        found = list(scanner.ai_pane_pids([pid], PATTERN, "cc-connect"))
        # Pickers and per-pane state readers must agree about service children.
        lib = SCANNER_PATH.parents[2] / "ai/lib.sh"
        result = subprocess.run(["bash", "-c", 'source "$1"; _has_ai_proc "$2"',
                                 "test", str(lib), str(pid)])
        self.assertEqual(result.returncode, 0 if found else 1)
        return found

    def test_broker_root_does_not_make_its_agents_interactive(self):
        broker, ready = self.program("cc-connect", [[str(self.agent), "600"]])
        pid = self.start(broker, [ready])
        self.assertEqual(self.scan(pid), [])

    def test_interactive_agent_next_to_broker_is_kept(self):
        broker, broker_ready = self.program("cc-connect", [[str(self.agent), "600"]])
        parent, ready = self.program("parent.js", [
            [self.node, str(broker)], [str(self.agent), "600"]])
        pid = self.start(parent, [ready, broker_ready])
        self.assertEqual(self.scan(pid), [pid])

    def test_broker_branch_without_interactive_agent_is_excluded(self):
        broker, broker_ready = self.program("cc-connect", [[str(self.agent), "600"]])
        parent, ready = self.program("parent.js", [[self.node, str(broker)]])
        pid = self.start(parent, [ready, broker_ready])
        self.assertEqual(self.scan(pid), [])

    def test_gemini_argument_to_an_unrelated_program_does_not_match(self):
        program, ready = self.program("unrelated.js")
        pid = self.start(program, [ready], str(self.root / "bin/gemini"))
        self.assertEqual(self.scan(pid), [])

    def test_agent_background_children_are_not_scanned(self):
        program, ready = self.program("bin/gemini", [[str(self.agent), "600"]])
        pid = self.start(program, [ready])
        with patch.object(scanner, "process_info", wraps=scanner.process_info) as reads:
            self.assertEqual(self.scan(pid), [pid])
        self.assertEqual(reads.call_count, 1)


if __name__ == "__main__":
    unittest.main()
