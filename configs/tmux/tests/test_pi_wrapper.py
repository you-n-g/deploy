"""Pi config, native lifecycle and branch-aware exports without model calls."""

import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
import unittest


WRAPPERS = Path(__file__).resolve().parents[1] / 'wrapper'
PI = WRAPPERS / 'pi'


class PiConfigTest(unittest.TestCase):
    def test_install_preserves_user_config_and_reuses_gateway_secret(self):
        with tempfile.TemporaryDirectory(prefix='pi-config-', dir='/tmp') as directory:
            home = Path(directory)
            local = home / ".config/llm"
            local.mkdir(parents=True)
            (local / "gateways.local.json").write_text(json.dumps({"pi": {
                "provider": "google-test", "model": "gateway-model-test", "name": "Test Gateway Model", "aliases": ["gateway-alias-test"]}}))
            (home / '.gemini').mkdir()
            (home / '.gemini/.env').write_text(
                'GOOGLE_GEMINI_BASE_URL="https://gateway.test"\nGEMINI_API_KEY="test-secret"\n')
            (home / 'farside').mkdir()
            (home / 'farside/AGENTS.md').write_text('shared instructions\n')
            agent = home / '.pi/agent'
            (agent / 'skills/personal').mkdir(parents=True)
            (agent / 'settings.json').write_text(json.dumps({
                'theme': 'dark', 'defaultThinkingLevel': 'high', 'enabledModels': ['old/*']}))
            (agent / 'models.json').write_text(json.dumps({'providers': {
                'old': {'apiKey': 'keep-me', 'models': [{'id': 'old-model'}]}}}))
            env = dict(os.environ, HOME=str(home))
            for _ in range(2):
                subprocess.check_call(['bash', str(PI / 'install.sh')], env=env, stdout=subprocess.DEVNULL)
            settings = json.loads((agent / 'settings.json').read_text())
            self.assertEqual(settings['defaultModel'], 'gateway-model-test')
            self.assertEqual(settings['defaultProvider'], 'google-test')
            self.assertEqual(settings['defaultProjectTrust'], 'always')
            self.assertEqual(settings['defaultThinkingLevel'], 'high')
            self.assertEqual(settings['theme'], 'dark')
            self.assertEqual(settings['enabledModels'], ['old/*', 'google-test/gateway-model-test'])
            models_text = (agent / 'models.json').read_text()
            self.assertNotIn('test-secret', models_text)
            providers = json.loads(models_text)['providers']
            self.assertEqual(providers['old']['apiKey'], 'keep-me')
            gw_provider = providers['google-test']
            self.assertEqual(gw_provider['baseUrl'], 'https://gateway.test/v1beta')
            self.assertEqual(len(gw_provider['models']), 1)
            self.assertEqual(gw_provider['models'][0]['id'], 'gateway-model-test')
            key = subprocess.check_output(['bash', '-c', gw_provider['apiKey'][1:]], env=env, universal_newlines=True)
            self.assertEqual(key.strip(), 'test-secret')
            self.assertTrue((agent / 'skills/personal').is_dir())
            self.assertEqual((agent / 'extensions/tma.js').resolve(), PI / 'tma.js')
            self.assertEqual((agent / 'AGENTS.md').read_text(), 'shared instructions\n')
            (home / '.gemini/.env').write_text('GEMINI_API_KEY="test-secret"\n')
            failed = subprocess.run(['python3', str(PI / 'configure.py')], env=env,
                                    stderr=subprocess.PIPE, universal_newlines=True)
            self.assertNotEqual(failed.returncode, 0)
            self.assertIn('Missing GOOGLE_GEMINI_BASE_URL', failed.stderr)
            self.assertNotIn('test-secret', failed.stderr)

    def test_launch_quotes_model_effort_and_resume_id(self):
        command = subprocess.check_output(['bash', str(WRAPPERS / 'dispatch.sh'),
            'pi', 'launch_command', 'model $(false)', 'high', '--name', 'a b'], universal_newlines=True)
        actual = subprocess.check_output(['zsh', '-f', '-c',
            'pi() { printf "%s\\0" "$@"; }; ' + command]).decode().split('\0')[:-1]
        self.assertEqual(actual, ['--model', 'model $(false)', '--thinking', 'high', '--name', 'a b'])
        command = subprocess.check_output(['bash', str(WRAPPERS / 'dispatch.sh'),
            'pi', 'resume_command', 'session $(false)'], universal_newlines=True)
        self.assertEqual(shlex.split(command), ['pi', '--session', 'session $(false)'])

    def test_gateway_adapter_preserves_other_models_and_payload_hooks(self):
        with tempfile.TemporaryDirectory(prefix='pi-gateway-', dir='/tmp') as directory:
            root = Path(directory)
            local = root / '.config/llm'
            local.mkdir(parents=True)
            (local / 'gateways.local.json').write_text(json.dumps({'pi': {
                'provider': 'google-test', 'model': 'gateway-model-test', 'name': 'Test Gateway Model', 'aliases': ['gateway-alias-test']}}))
            shutil.copy(str(PI / 'gateway.js'), str(root / 'gateway.mjs'))
            package = root / 'node_modules/@earendil-works/pi-ai'
            package.mkdir(parents=True)
            (package / 'package.json').write_text('{"type":"module","exports":"./index.js"}')
            (package / 'index.js').write_text(
                'export const googleGenerativeAIApi = () => ({streamSimple: (m,c,o) => o});')
            script = """
import assert from 'node:assert/strict';
import register from './gateway.mjs';
let provider;
register({registerProvider: (name, config) => {assert.equal(name, 'google-test'); provider=config;}});
for (const modelId of ['gateway-alias-test', 'gateway-model-test']) {
  for (const [reasoning, expected] of [['medium','MEDIUM'],['high','HIGH'],['xhigh','HIGH'],[undefined,'LOW']]) {
    const options = provider.streamSimple({id:modelId}, {}, {
      reasoning, onPayload: (payload) => ({...payload, preserved:true})
    });
    const result = await options.onPayload({config:{thinkingConfig:{thinkingBudget:8192,includeThoughts:true}}});
    assert.equal(result.config.thinkingConfig.thinkingLevel, expected);
    assert.ok(!('thinkingBudget' in result.config.thinkingConfig));
    assert.ok(result.config.thinkingConfig.includeThoughts);
    assert.ok(result.preserved);
  }
}
const options = {reasoning:'medium'};
assert.equal(provider.streamSimple({id:'gemini-2.5-pro'}, {}, options), options);
"""
            subprocess.check_call(['node', '--input-type=module', '-e', script],
                                  cwd=directory, env=dict(os.environ, HOME=directory))

class PiLifecycleTest(unittest.TestCase):
    def tmux(self, *args):
        return subprocess.check_output(['tmux', '-S', self.socket, *args], universal_newlines=True).strip()

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='pi-hooks-', dir='/tmp')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.socket = str(self.root / 'socket')
        self.tmux('-f', '/dev/null', 'new-session', '-d', '-s', 'test', 'sleep 600')
        self.addCleanup(lambda: subprocess.run(['tmux', '-S', self.socket, 'kill-server'], stderr=subprocess.DEVNULL))
        self.pane = self.tmux('display-message', '-p', '-t', 'test:', '#{pane_id}')
        self.tmux('set-option', '-p', '-t', self.pane, '@ai_agent_attribute', 'test')
        self.env = dict(os.environ, TMUX=self.socket + ',0,0', TMUX_PANE=self.pane,
                        AI_AGENT_STATE_LOG=str(self.root / 'state.log'),
                        AI_AGENT_PROMPT_LOG=str(self.root / 'prompts.jsonl'))
        script = '''
import extension from %s;
import readline from 'node:readline';
const handlers = new Map();
extension({on: (name, fn) => handlers.set(name, fn)});
let meta = {session_id:'pi-session', transcript_path:'', leaf_id:null, name:''};
let ctx = {hasUI:true, cwd:process.cwd(), idle:true, isIdle:() => ctx.idle,
  sessionManager: {
    getSessionId: () => meta.session_id, getSessionFile:() => meta.transcript_path,
    getLeafId: () => meta.leaf_id, getSessionName: () => meta.name,
  }};
for await (const line of readline.createInterface({input:process.stdin})) {
  const request = JSON.parse(line);
  Object.assign(meta, request.meta);
  Object.assign(ctx, request.context);
  await handlers.get(request.event)?.({type:request.event, ...request.fields}, ctx);
  console.log('done');
}
''' % json.dumps(str(PI / 'tma.js'))
        self.process = subprocess.Popen(['node', '--input-type=module', '-e', script], env=self.env,
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
        def stop():
            self.process.stdin.close()
            self.process.wait(timeout=5)
            self.process.stdout.close()
            self.process.stderr.close()
        self.addCleanup(stop)

    def event(self, event, **request):
        self.process.stdin.write(json.dumps(dict(request, event=event)) + '\n')
        self.process.stdin.flush()
        line = self.process.stdout.readline()
        if not line:
            self.fail('Pi fixture failed: ' + self.process.stderr.read())
        self.assertEqual(line.strip(), 'done')

    def option(self, option):
        return self.tmux('show-option', '-pqv', '-t', self.pane, option)

    def call(self, operation, *args):
        return subprocess.run(['bash', str(WRAPPERS / 'dispatch.sh'), 'pi', operation, *args],
            env=self.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)

    def test_only_settled_marks_complete_and_compaction_failure_clears_running(self):
        self.event('session_start')
        self.event('before_agent_start', fields={'prompt': 'Do the task'}, context={'idle': False})
        self.event('agent_start')
        self.event('agent_end')
        self.assertEqual(self.option('@ai_agent_running'), '1')
        self.assertEqual(self.option('@ai_agent_unread'), '0')
        self.event('session_before_compact')
        self.event('session_compact', fields={'willRetry': True})
        self.assertEqual(self.option('@ai_agent_running'), '1')
        self.event('agent_settled', context={'idle': True})
        self.assertEqual(self.option('@ai_agent_running'), '0')
        self.assertEqual(self.option('@ai_agent_unread'), '1')
        rows = [json.loads(line) for line in (self.root / 'prompts.jsonl').read_text().splitlines()]
        self.assertEqual([row['prompt'] for row in rows], ['Do the task'])
        self.event('session_before_compact')
        self.assertEqual(self.option('@ai_agent_running'), '1')
        self.event('session_compact_failed', fields={'willRetry': False, 'reason': 'manual', 'aborted': True})
        self.assertEqual(self.option('@ai_agent_running'), '0')
        self.event('session_shutdown')
        self.assertEqual(self.option('@tma_pi_session'), '')

    def test_headless_pi_cannot_change_parent_pane(self):
        self.event('session_start', context={'hasUI': False})
        self.event('before_agent_start', fields={'prompt':'headless'})
        self.assertEqual(self.option('@tma_pi_session'), '')
        self.assertEqual(self.option('@ai_agent_running'), '')

    def test_history_keeps_compacted_ancestors_but_excludes_abandoned_branch(self):
        rows = [{'type':'session', 'version':3, 'id':'pi-session'}]
        def message(id, parent, role, text):
            return dict(type='message', id=id, parentId=parent, timestamp='now',
                        message={'role':role, 'content':[{'type':'text','text':text}]})
        rows.extend([
            message('u', None, 'user', 'original request'),
            message('a', 'u', 'assistant', 'abandoned reply'),
            message('b', 'u', 'assistant', 'selected reply'),
            dict(type='compaction', id='c', parentId='b', summary='compressed'),
            message('d', 'c', 'assistant', 'latest answer'),
        ])
        path = self.root / 'session.jsonl'
        source = ''.join(json.dumps(row) + '\n' for row in rows)
        path.write_text(source)
        self.event('session_start', meta={'transcript_path':str(path), 'leaf_id':'d'})
        args = [self.pane, str(self.process.pid)]
        markdown = self.call('history', *args)
        self.assertEqual(markdown.returncode, 0, markdown.stderr)
        self.assertIn('original request', markdown.stdout)
        self.assertIn('selected reply', markdown.stdout)
        self.assertIn('latest answer', markdown.stdout)
        self.assertNotIn('abandoned reply', markdown.stdout)
        self.assertEqual(self.call('history', *args, 'jsonl').stdout, source)
        self.assertEqual(self.call('last_message', *args).stdout.strip(), 'latest answer')
        self.event('session_tree', meta={'leaf_id':'a'})
        self.assertEqual(self.call('last_message', *args).stdout.strip(), 'abandoned reply')
        # Session replacement must not leak a preceding transcript.
        self.event('session_start', meta={'session_id':'new-session', 'transcript_path':'', 'leaf_id':None})
        missing = self.call('history', *args)
        self.assertNotEqual(missing.returncode, 0)
        self.assertIn('has not created a transcript', missing.stderr)
        binding = json.loads(self.option('@tma_pi_session'))
        binding['process_start'] = 'stale'
        self.tmux('set-option', '-p', '-t', self.pane, '@tma_pi_session', json.dumps(binding))
        self.assertIn('Stale Pi session', self.call('history', *args).stderr)


if __name__ == '__main__':
    unittest.main()
