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
    def test_install_with_native_xai_default_and_no_gateway(self):
        with tempfile.TemporaryDirectory(prefix='pi-config-', dir='/tmp') as directory:
            home = Path(directory)
            (home / 'farside').mkdir()
            (home / 'farside/AGENTS.md').write_text('shared instructions\n')
            agent = home / '.pi/agent'
            (agent / 'extensions').mkdir(parents=True)
            (agent / 'extensions/gateway.js').symlink_to(PI / 'gateway.js')
            (agent / 'settings.json').write_text(json.dumps({
                'defaultProvider': 'xai', 'defaultModel': 'grok-4.7', 'defaultThinkingLevel': 'medium'}))
            auth = {'xai': {'type': 'api_key', 'key': '!cat /private/xai-key'}}
            (agent / 'auth.json').write_text(json.dumps(auth))
            env = dict(os.environ, HOME=str(home))
            subprocess.check_call(['bash', str(PI / 'install.sh')], env=env, stdout=subprocess.DEVNULL)
            settings = json.loads((agent / 'settings.json').read_text())
            self.assertEqual(settings['defaultProvider'], 'xai')
            self.assertEqual(settings['defaultModel'], 'grok-4.7')
            self.assertEqual(settings['defaultThinkingLevel'], 'medium')
            self.assertEqual(json.loads((agent / 'auth.json').read_text()), auth)
            self.assertEqual((agent / 'extensions/tma.js').resolve(), PI / 'tma.js')
            self.assertEqual((agent / 'extensions/pull.js').resolve(), PI / 'pull.js')
            self.assertFalse((agent / 'extensions/gateway.js').is_symlink())
            self.assertFalse((agent / 'models.json').exists())

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
                'theme': 'dark', 'defaultThinkingLevel': 'medium', 'enabledModels': ['old/*'],
                'packages': ['npm:pi-timing@1.3.0']}))
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
            self.assertEqual(settings['packages'], ['npm:pi-timing@1.3.0', 'npm:pi-web-access'])
            pinned = {'source': 'npm:pi-web-access@0.47.0', 'extensions': []}
            settings['packages'] = [pinned]
            (agent / 'settings.json').write_text(json.dumps(settings))
            subprocess.check_call(['python3', str(PI / 'configure.py')], env=env, stdout=subprocess.DEVNULL)
            self.assertEqual(json.loads((agent / 'settings.json').read_text())['packages'], [pinned])
            models_text = (agent / 'models.json').read_text()
            self.assertNotIn('test-secret', models_text)
            providers = json.loads(models_text)['providers']
            self.assertEqual(providers['old']['apiKey'], 'keep-me')
            gw_provider = providers['google-test']
            self.assertEqual(gw_provider['baseUrl'], 'https://gateway.test/v1beta')
            self.assertEqual(len(gw_provider['models']), 1)
            self.assertEqual(gw_provider['models'][0]['id'], 'gateway-model-test')
            self.assertEqual(gw_provider['models'][0]['contextWindow'], 1048576)
            self.assertEqual(gw_provider['models'][0]['maxTokens'], 65536)
            self.assertEqual(gw_provider['models'][0]['thinkingLevelMap'], {
                'off': None, 'minimal': None, 'low': 'low', 'medium': 'medium',
                'high': 'high', 'xhigh': None, 'max': None})
            key = subprocess.check_output(['bash', '-c', gw_provider['apiKey'][1:]], env=env, universal_newlines=True)
            self.assertEqual(key.strip(), 'test-secret')
            self.assertTrue((agent / 'skills/personal').is_dir())
            self.assertEqual((agent / 'extensions/tma.js').resolve(), PI / 'tma.js')
            self.assertEqual((agent / 'extensions/gateway.js').resolve(), PI / 'gateway.js')
            self.assertEqual((agent / 'extensions/pull.js').resolve(), PI / 'pull.js')
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
                'export let lastContext;\n'
                'export const googleGenerativeAIApi = () => ({streamSimple: (m,c,o) => {lastContext=c; return o;}});')
            script = """
import assert from 'node:assert/strict';
import register from './gateway.mjs';
import { lastContext } from '@earendil-works/pi-ai';
let provider;
register({registerProvider: (name, config) => {assert.equal(name, 'google-test'); provider=config;}});
for (const modelId of ['gateway-alias-test', 'gateway-model-test']) {
  for (const [reasoning, expected] of [['medium','MEDIUM'],['high','HIGH'],['xhigh','HIGH'],[undefined,'LOW']]) {
    const options = provider.streamSimple({id:modelId}, {messages:[]}, {
      reasoning, onPayload: (payload) => ({...payload, preserved:true})
    });
    const result = await options.onPayload({config:{thinkingConfig:{thinkingBudget:8192,includeThoughts:true}}});
    assert.equal(result.config.thinkingConfig.thinkingLevel, expected);
    assert.ok(!('thinkingBudget' in result.config.thinkingConfig));
    assert.ok(result.config.thinkingConfig.includeThoughts);
    assert.ok(result.preserved);
  }
}
const signature = Buffer.from('original tool signature').toString('base64');
const signedCall = {type:'toolCall', id:'call_1', name:'bash', arguments:{command:'pwd'}, thoughtSignature:signature};
for (const [from, to] of [['gateway-alias-test', 'gateway-model-test'], ['gateway-model-test', 'gateway-alias-test']]) {
  const message = {role:'assistant', api:'google-generative-ai', provider:'google-test', model:from, content:[signedCall]};
  const foreignProvider = {...message, provider:'other-provider'};
  const foreignModel = {...message, model:'gemini-2.5-pro'};
  const foreignApi = {...message, api:'other-api'};
  const toolResult = {role:'toolResult', toolCallId:'call_1', content:[{type:'text', text:'/tmp'}]};
  const context = {messages:[message, foreignProvider, foreignModel, foreignApi, toolResult]};
  const original = structuredClone(context);
  provider.streamSimple({id:to, api:message.api, provider:message.provider}, context, {});
  assert.equal(lastContext.messages[0].model, to);
  assert.equal(lastContext.messages[0].content[0].thoughtSignature, signature);
  assert.equal(lastContext.messages[1], foreignProvider);
  assert.equal(lastContext.messages[2], foreignModel);
  assert.equal(lastContext.messages[3], foreignApi);
  assert.equal(lastContext.messages[4], toolResult);
  assert.deepEqual(context, original);
}
const options = {reasoning:'medium'};
assert.equal(provider.streamSimple({id:'gemini-2.5-pro'}, {}, options), options);
"""
            subprocess.check_call(['node', '--input-type=module', '-e', script],
                                  cwd=directory, env=dict(os.environ, HOME=directory))

    def test_pull_extension_merges_other_branch_summary_without_moving_leaf(self):
        pi_pkg = Path(shutil.which('pi')).resolve().parents[2]
        with tempfile.TemporaryDirectory(prefix='pi-pull-', dir='/tmp') as directory:
            root = Path(directory)
            scope = root / 'node_modules/@earendil-works'
            scope.mkdir(parents=True)
            (scope / 'pi-coding-agent').symlink_to(pi_pkg)
            (scope / 'pi-tui').symlink_to(pi_pkg / 'node_modules/@earendil-works/pi-tui')
            shutil.copy(str(PI / 'pull.js'), str(root / 'pull.mjs'))
            shutil.copy(str(PI / 'pull.js'), str(root / 'pull.js'))
            script = """
import assert from 'node:assert/strict';
import register, { collectSiblingBranchLeaves } from './pull.mjs';
import { discoverAndLoadExtensions, initTheme, SessionManager } from '@earendil-works/pi-coding-agent';

initTheme('dark', false);
const loaded = await discoverAndLoadExtensions(['./pull.js'], process.cwd());
assert.deepEqual(loaded.errors, []);
assert.ok(loaded.extensions.some((e) => e.commands.has('pull')));

let command, renderer;
const sent = [], notices = [];
register({
  registerMessageRenderer: (type, fn) => { assert.equal(type, 'branch-pull'); renderer = fn; },
  registerCommand: (name, cfg) => { assert.equal(name, 'pull'); command = cfg; },
  sendMessage: (msg) => sent.push(msg),
});

const sm = SessionManager.inMemory('/tmp');
const rootUser = sm.appendMessage({ role: 'user', content: [{ type: 'text', text: 'shared root' }], timestamp: 1 });
const rootReply = sm.appendMessage({
  role: 'assistant', content: [{ type: 'text', text: 'shared answer' }],
  api: 'openai-responses', provider: 'test', model: 'm', stopReason: 'stop', timestamp: 2,
  usage: { input: 1, output: 1, cacheRead: 0, cacheWrite: 0, totalTokens: 2, cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 } },
});
const olderUser = sm.appendMessage({ role: 'user', content: [{ type: 'text', text: 'older branch A' }], timestamp: 3 });
const olderLeaf = sm.appendMessage({
  role: 'assistant', content: [{ type: 'text', text: 'branch A result' }],
  api: 'openai-responses', provider: 'test', model: 'm', stopReason: 'stop', timestamp: 4,
  usage: { input: 1, output: 1, cacheRead: 0, cacheWrite: 0, totalTokens: 2, cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 } },
});
await new Promise((r) => setTimeout(r, 10));
sm.branch(rootReply);
const otherUser = sm.appendMessage({ role: 'user', content: [{ type: 'text', text: 'explore branch B' }], timestamp: 5 });
const otherLeaf = sm.appendMessage({
  role: 'assistant', content: [
    { type: 'toolCall', id: 'c1', name: 'edit', arguments: { path: 'src/b.py' } },
    { type: 'text', text: 'branch B found speedup' },
  ],
  api: 'openai-responses', provider: 'test', model: 'm', stopReason: 'stop', timestamp: 6,
  usage: { input: 1, output: 1, cacheRead: 0, cacheWrite: 0, totalTokens: 2, cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 } },
});
sm.branch(rootReply);
const mainUser = sm.appendMessage({ role: 'user', content: [{ type: 'text', text: 'stay on main branch' }], timestamp: 7 });
assert.equal(sm.getLeafId(), mainUser);

// Only sibling branch leaves appear (no intermediate nodes like olderUser/otherUser, no active branch nodes).
const candidates = collectSiblingBranchLeaves(sm);
assert.deepEqual(candidates.map((c) => c.leafId), [otherLeaf, olderLeaf]);
assert.equal(candidates[0].merged, false);
assert.equal(candidates[1].merged, false);
assert.ok(candidates[0].title.includes('explore branch B'));
assert.ok(candidates[0].meta.includes('branch B found speedup'));

// Multi-select both sibling leaves via Space + down + Space + Enter:
let step = 0;
const capturedPrompts = [];
await command.handler('focus on speedup', {
  hasUI: true,
  isIdle: () => true,
  model: { id: 'm', provider: 'test', api: 'openai-responses', contextWindow: 128000, maxTokens: 4096, reasoning: false },
  sessionManager: sm,
  modelRegistry: {
    complete: async (_m, context) => {
      const content = context.messages.find((message) => message.role === 'user').content;
      const prompt = typeof content === 'string' ? content : content[0].text;
      capturedPrompts.push(prompt);
      const tag = prompt.includes('explore branch B') ? 'Keep speedup from B' : 'Keep baseline from A';
      return {
        role: 'assistant', api: 'openai-responses', provider: 'test', model: 'm', stopReason: 'stop', timestamp: 8,
        content: [{ type: 'text', text: '## Goal\\n' + tag }],
        usage: { input: 10, output: 5, cacheRead: 0, cacheWrite: 0, totalTokens: 15, cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 } },
      };
    },
  },
  ui: {
    notify: (msg, level) => notices.push([msg, level]),
    custom: async (factory) => {
      step += 1;
      let resolved;
      const done = (v) => { resolved = Promise.resolve(v); };
      const comp = factory({ terminal: { rows: 40 }, requestRender() {} }, { fg: (_c, s) => s, bold: (s) => s }, {}, done);
      if (step === 1) {
        const pickerText = comp.render(100).join('\\n');
        assert.ok(pickerText.includes('explore branch B'));
        assert.ok(pickerText.includes('older branch A'));
        assert.ok(!pickerText.includes('stay on main branch'));
        assert.ok(!pickerText.includes('✓ merged'));
        comp.handleInput(' ');  // select otherLeaf
        comp.handleInput('j');  // move to olderLeaf
        comp.handleInput(' ');  // select olderLeaf
        assert.ok(comp.render(100).join('\\n').includes('2 selected'));
        comp.handleInput('\\r'); // merge both
      }
      while (!resolved) await new Promise((r) => setTimeout(r, 5));
      assert.ok(!process.getActiveResourcesInfo().includes('Timeout'));
      comp?.dispose?.();
      return resolved;
    },
  },
});

assert.equal(sm.getLeafId(), mainUser);
assert.equal(capturedPrompts.length, 2);
assert.ok(capturedPrompts.every((p) => p.includes('Additional focus: focus on speedup') && !p.includes('stay on main branch')));
assert.equal(sent.length, 1);
assert.equal(sent[0].customType, 'branch-pull');
assert.equal(sent[0].display, true);
assert.deepEqual(sent[0].details.fromIds, [otherLeaf, olderLeaf]);
assert.deepEqual(sent[0].details.modifiedFiles, ['src/b.py']);
assert.ok(sent[0].content.includes('Keep speedup from B'));
assert.ok(sent[0].content.includes('Keep baseline from A'));
const rendered = renderer({ ...sent[0], timestamp: Date.now() }, { expanded: true });
assert.ok(rendered.render(80).join('\\n').includes('Keep speedup from B'));

// Once persisted onto the active branch, both pulled leaves (and native /tree branchWithSummary) show ✓ merged.
sm.appendCustomMessageEntry(sent[0].customType, sent[0].content, sent[0].display, sent[0].details);
const afterMerge = collectSiblingBranchLeaves(sm);
assert.deepEqual(afterMerge.map((c) => c.merged), [true, true]);
"""
            subprocess.check_call(['node', '--input-type=module', '-e', script], cwd=directory, timeout=30)


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

    def test_fork_preserves_selected_ancestry_and_keeps_source_independent(self):
        rows = [
            dict(type='session', version=3, id='pi-session', cwd=str(self.root)),
            dict(type='model_change', id='m', parentId=None, provider='google-test', modelId='gateway-alias-test'),
            dict(type='thinking_level_change', id='t', parentId='m', thinkingLevel='high'),
            dict(type='message', id='u', parentId='t', message={'role':'user', 'content':[
                {'type':'text', 'text':'original 中文'}, {'type':'image', 'data':'image-data', 'mimeType':'image/png'}]}),
            dict(type='message', id='a', parentId='u', message={'role':'assistant', 'content':[
                {'type':'toolCall', 'id':'tool', 'name':'read', 'arguments':{'path':'file'}}]}),
            dict(type='message', id='r', parentId='a', message={'role':'toolResult', 'toolCallId':'tool',
                'content':[{'type':'text', 'text':'file contents'}]}),
            dict(type='compaction', id='c', parentId='r', summary='summary', firstKeptEntryId='u'),
            dict(type='label', id='l', parentId='c', targetId='u', label='keep this label'),
            dict(type='message', id='b', parentId='l', message={'role':'assistant', 'content':[{'type':'text','text':'selected'}]}),
            dict(type='message', id='x', parentId='u', message={'role':'assistant', 'content':[{'type':'text','text':'abandoned'}]}),
        ]
        directory = self.root / 'sessions with spaces'
        directory.mkdir()
        path = directory / 'source.jsonl'
        source = ''.join(json.dumps(row) + '\n' for row in rows)
        path.write_text(source)
        self.event('session_start', meta={'transcript_path':str(path), 'leaf_id':'b'})
        args = [str(self.process.pid), self.pane, 'unused-root-pid']
        result = self.call('fork_command', *args)
        self.assertEqual(result.returncode, 0, result.stderr)
        # Exercise Bash quoting in the zsh that actually launches forked panes.
        command = subprocess.check_output(['zsh', '-f', '-c',
            'pi() { printf "%s\\0" "$@"; }; ' + result.stdout]).decode().split('\0')[:-1]
        self.assertEqual(command[0], '--session')
        fork = Path(command[1])
        copied = [json.loads(line) for line in fork.read_text().splitlines()]
        self.assertEqual(fork.parent, directory)
        self.assertNotEqual(copied[0]['id'], 'pi-session')
        self.assertEqual(copied[0]['parentSession'], str(path))
        self.assertEqual(copied[1:], rows[1:-1])
        self.assertEqual(fork.stat().st_mode & 0o777, 0o600)
        self.assertEqual(path.read_text(), source)
        self.assertEqual(json.loads(self.option('@tma_pi_session'))['leaf_id'], 'b')
        # A second fork has its own ID/file and follows a later tree selection.
        self.event('session_tree', meta={'leaf_id':'u'})
        second = self.call('fork_command', *args)
        self.assertEqual(second.returncode, 0, second.stderr)
        second_path = Path(shlex.split(second.stdout)[2])
        second_rows = [json.loads(line) for line in second_path.read_text().splitlines()]
        self.assertNotEqual(second_path, fork)
        self.assertEqual(second_rows[1:], rows[1:4])
        self.assertEqual(path.read_text(), source)

    def test_fork_rejects_wrong_session_and_invalid_ancestry(self):
        path = self.root / 'source.jsonl'
        path.write_text(json.dumps(dict(type='session', id='wrong')) + '\n')
        self.event('session_start', meta={'transcript_path':str(path), 'leaf_id':None})
        args = [str(self.process.pid), self.pane, 'unused']
        failed = self.call('fork_command', *args)
        self.assertNotEqual(failed.returncode, 0)
        self.assertEqual(failed.stdout, '')
        self.assertIn('does not match', failed.stderr)
        path.write_text(json.dumps(dict(type='session', id='pi-session')) + '\n' +
                        json.dumps(dict(type='label', id='cycle', parentId='cycle')) + '\n')
        self.event('session_tree', meta={'leaf_id':'cycle'})
        failed = self.call('fork_command', *args)
        self.assertNotEqual(failed.returncode, 0)
        self.assertIn('Cycle in Pi transcript', failed.stderr)
        self.assertEqual(list(self.root.glob('*.jsonl')), [path])

    def test_model_and_thinking_changes_refresh_the_fork_point(self):
        self.event('session_start', meta={'leaf_id':'original'})
        self.event('model_select', meta={'leaf_id':'new-model'})
        self.assertEqual(json.loads(self.option('@tma_pi_session'))['leaf_id'], 'new-model')
        self.event('thinking_level_select', meta={'leaf_id':'new-effort'})
        self.assertEqual(json.loads(self.option('@tma_pi_session'))['leaf_id'], 'new-effort')

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
