"""Native history exports work independently of tmux scrollback and active screen."""

import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
import time
import unittest


WRAPPER = Path(__file__).resolve().parents[1] / 'wrapper'
SESSION = '11111111-1111-4111-8111-111111111111'
OTHER_SESSION = '22222222-2222-4222-8222-222222222222'


def message(role, text):
    return {'type': 'response_item', 'timestamp': '2026-11-11T00:00:00Z', 'payload': {
        'type': 'message', 'role': role, 'content': [{'type': 'input_text', 'text': text}]}}


@unittest.skipUnless(Path('/proc/self/fd').is_dir() and shutil.which('tmux'), 'Linux tmux integration')
class HistoryExportTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='tma-history-test-', dir='/tmp')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.socket = str(self.root / 'socket')
        self.env = dict(os.environ, TMUX=self.socket + ',0,0')
        self.config = self.root / 'config with spaces'
        self.script = self.root / 'fake-agent.py'
        self.script.write_text('''
import ctypes, json, os, pathlib, signal, sys
backend, transcript, ready, config, session = sys.argv[1:]
ctypes.CDLL(None).prctl(15, backend.encode(), 0, 0, 0)
stream = open(transcript)
if backend == 'claude':
    sessions = pathlib.Path(config) / 'sessions'
    sessions.mkdir(parents=True)
    (sessions / (str(os.getpid()) + '.json')).write_text(json.dumps({
        'sessionId': session, 'tmux': 'test:@0.' + os.environ['TMUX_PANE'],
        'procStart': pathlib.Path('/proc/self/stat').read_text().split()[21]
    }))
pathlib.Path(ready).write_text(str(os.getpid()))
while True:
    signal.pause()
''')

    def tmux(self, *args):
        return subprocess.check_output(['tmux', '-S', self.socket] + list(args),
                                       universal_newlines=True).strip()

    def start(self, backend='codex', rows=None):
        if rows is None:
            rows = [message('user', 'question before compaction'),
                    {'type': 'event_msg', 'payload': {'type': 'user_message', 'message': 'question before compaction'}},
                    message('assistant', '早期回答'),
                    {'type': 'response_item', 'payload': {'type': 'function_call', 'name': 'test_tool', 'arguments': '{}'}},
                    {'type': 'compacted', 'payload': {'message': 'compaction summary'}},
                    message('user', 'question after compaction'),
                    message('assistant', 'latest answer')]
        directory = self.root / 'logs with spaces $(literal)' if backend != 'claude' else self.config / 'projects' / 'project'
        directory.mkdir(parents=True)
        name = 'rollout-2026-11-11T00-00-00-' + SESSION + '.jsonl' if backend == 'codex' else SESSION + '.jsonl'
        self.log = directory / name
        self.log.write_text(''.join(json.dumps(row, ensure_ascii=False) + '\n' for row in rows))
        ready = self.root / 'ready'
        argv = ['env', 'CLAUDE_CONFIG_DIR=' + str(self.config), 'python3', str(self.script),
                backend, str(self.log), str(ready), str(self.config), SESSION]
        self.pane = self.tmux('-f', '/dev/null', 'new-session', '-d', '-s', 'test', '-P', '-F', '#{pane_id}',
                              ' '.join(shlex.quote(arg) for arg in argv))
        self.addCleanup(lambda: subprocess.run(['tmux', '-S', self.socket, 'kill-server'], stderr=subprocess.DEVNULL))
        deadline = time.monotonic() + 5
        while not ready.exists():
            self.assertLess(time.monotonic(), deadline, 'fake process did not start')
            time.sleep(0.05)
        self.pid = ready.read_text()
        # There is deliberately no conversation text on the screen or in history.
        self.assertEqual(self.tmux('capture-pane', '-p', '-S', '-', '-t', self.pane), '')

    def export(self, format='markdown'):
        return subprocess.run(['bash', str(WRAPPER / 'history.sh'), self.pane, format], env=self.env,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)

    def test_codex_keeps_pre_compaction_history_without_event_duplicates(self):
        self.start()
        result = self.export()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.count('question before compaction'), 1)
        self.assertIn('早期回答', result.stdout)
        self.assertIn('compaction summary', result.stdout)
        self.assertIn('latest answer', result.stdout)
        self.assertNotIn('test_tool', result.stdout)
        self.assertIn(str(self.log.resolve()), result.stdout)

    def test_jsonl_is_the_exact_source_including_tools_and_unknown_records(self):
        self.start(rows=[message('user', '请检查'),
                         {'type': 'unknown_future_record', 'payload': {'nested': [1, 2]}},
                         {'type': 'response_item', 'payload': {'type': 'function_call_output', 'output': 'original tool result'}}])
        result = self.export('jsonl')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, self.log.read_text())

    def test_legacy_event_only_logs_are_readable(self):
        self.start(rows=[{'type': 'event_msg', 'payload': {'type': 'user_message', 'message': 'legacy question'}},
                         {'type': 'event_msg', 'payload': {'type': 'agent_message', 'message': 'legacy answer'}}])
        result = self.export()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('legacy question', result.stdout)
        self.assertIn('legacy answer', result.stdout)

    def test_incomplete_record_is_an_error_not_a_partial_success(self):
        self.start()
        with self.log.open('a') as stream:
            stream.write('{"type":')
        result = self.export('jsonl')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, '')
        self.assertIn('invalid JSON', result.stderr)

    def test_claude_uses_target_config_and_retains_streamed_text_blocks(self):
        self.start('claude', rows=[
            {'type': 'user', 'message': {'content': 'Claude question'}},
            {'type': 'assistant', 'message': {'id': 'answer', 'content': [{'type': 'text', 'text': 'first block'}]}},
            {'type': 'assistant', 'message': {'id': 'answer', 'content': [{'type': 'text', 'text': 'second block'}]}},
            {'type': 'user', 'message': {'content': [{'type': 'tool_result', 'content': 'tool payload'}]}}
        ])
        result = self.export()
        self.assertEqual(result.returncode, 0, result.stderr)
        for text in ('Claude question', 'first block', 'second block'):
            self.assertIn(text, result.stdout)
        self.assertNotIn('tool payload', result.stdout)
        self.assertEqual(self.export('jsonl').stdout, self.log.read_text())

    def test_claude_parked_pane_exports_the_job_on_screen(self):
        self.start('claude', rows=[{'type': 'user', 'message': {'content': 'parked parent'}}])
        state_path = self.config / 'sessions' / (self.pid + '.json')
        state = json.loads(state_path.read_text())
        state['parkedJobId'] = 'job123'
        state_path.write_text(json.dumps(state))
        job = self.config / 'jobs' / 'job123'
        job.mkdir(parents=True)
        (job / 'state.json').write_text(json.dumps({'resumeSessionId': OTHER_SESSION}))
        (self.log.parent / (OTHER_SESSION + '.jsonl')).write_text(json.dumps({
            'type': 'user', 'message': {'content': 'visible background job'}}) + '\n')
        result = self.export()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('visible background job', result.stdout)
        self.assertNotIn('parked parent', result.stdout)

    def test_missing_or_ambiguous_transcript_is_explicit(self):
        self.start('claude', rows=[])
        alternate = self.config / 'projects' / 'other-project'
        alternate.mkdir()
        duplicate = alternate / self.log.name
        duplicate.write_text('')
        result = self.export()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('found 2', result.stderr)
        duplicate.unlink()
        self.log.unlink()
        result = self.export()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('found 0', result.stderr)

    def test_unimplemented_backend_does_not_export_the_screen(self):
        self.start('gemini')
        result = self.export()
        self.assertEqual(result.returncode, 69, result.stderr)
        self.assertIn('does not support history', result.stderr)
        self.assertEqual(result.stdout, '')


if __name__ == '__main__':
    unittest.main()
