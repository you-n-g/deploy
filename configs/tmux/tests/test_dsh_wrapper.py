"""DeepSeek Harness (DSH) wrapper configuration, process detection, and session tests."""

import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
import unittest
import yaml


TMUX_DIR = Path(__file__).resolve().parents[1]
WRAPPERS = TMUX_DIR / 'wrapper'
DSH = WRAPPERS / 'dsh'


class DshWrapperTest(unittest.TestCase):
    def call(self, *args, **kwargs):
        env = kwargs.pop('env', os.environ)
        return subprocess.run(
            ['bash', str(WRAPPERS / 'dispatch.sh'), 'dsh', *args],
            env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            universal_newlines=True, **kwargs,
        )

    def test_configure_writes_local_gateway_and_preserves_existing_state(self):
        with tempfile.TemporaryDirectory(prefix='dsh-config-', dir='/tmp') as directory:
            home = Path(directory)
            (home / 'farside').mkdir()
            (home / 'farside/AGENTS.md').write_text('shared instructions\n')
            (home / '.gemini').mkdir()
            (home / '.gemini/.env').write_text(
                'GOOGLE_GEMINI_BASE_URL="https://gateway.example.com/api/llm"\n'
                'GEMINI_API_KEY="gw-secret"\n'
            )
            (home / '.config/llm').mkdir(parents=True)
            (home / '.config/llm/gateways.local.json').write_text(json.dumps({'pi': {
                'provider': 'google-gateway',
                'model': 'gemini-2.5-pro-prio',
                'name': 'Gemini 2.5 Pro Priority',
                'aliases': ['gemini-2.5-pro', 'gemini-2.5-pro-prio'],
            }}))
            (home / '.dsh').mkdir()
            creds_path = home / '.dsh/.credentials.yaml'
            creds_path.write_text('version: 1\nrefs:\n  EXISTING_KEY: keep-me\n')
            creds_path.chmod(0o600)
            (home / '.dsh-tui').mkdir()
            (home / '.dsh-tui/effort.json').write_text('{"effort": "medium"}\n')

            # Omit dsh/pnpm from PATH so unit test does not hit the network.
            fake_bin = home / 'bin'
            fake_bin.mkdir()
            for cmd in ('bash', 'dirname', 'ln', 'mkdir', 'python3'):
                target = shutil.which(cmd)
                if target:
                    (fake_bin / cmd).symlink_to(target)
            env = dict(os.environ, HOME=str(home), DSH_HOME=str(home / '.dsh'), PATH=str(fake_bin))

            subprocess.check_call(['bash', str(DSH / 'install.sh')], env=env, stdout=subprocess.DEVNULL)

            self.assertEqual((home / '.dsh/AGENTS.md').read_text(), 'shared instructions\n')
            self.assertEqual(creds_path.stat().st_mode & 0o777, 0o600)
            creds = yaml.safe_load(creds_path.read_text())
            self.assertEqual(creds['refs']['EXISTING_KEY'], 'keep-me')
            self.assertEqual(creds['refs']['DSH_GATEWAY_API_KEY'], 'gw-secret')

            patch_path = home / '.dsh/cordis.patch.yml'
            self.assertEqual(patch_path.stat().st_mode & 0o777, 0o600)
            patch = yaml.safe_load(patch_path.read_text())
            by_id = {row['id']: row for row in patch if 'id' in row}
            inserts = [item for row in patch if 'insert' in row for item in row['insert']]
            self.assertEqual([item['id'] for item in inserts], ['dsh-tma'])
            self.assertEqual(Path(inserts[0]['name']).resolve(), (DSH / 'tma.mjs').resolve())
            self.assertIs(by_id['credentials']['disabled'], False)
            tfy = by_id['llm-pi-ai']['config']['providers']['google-gateway']
            self.assertEqual(tfy['api'], 'google-generative-ai')
            self.assertEqual(tfy['baseURL'], 'https://gateway.example.com/api/llm/v1beta')
            self.assertEqual([m['id'] for m in tfy['models']], ['gemini-2.5-pro-prio', 'gemini-2.5-pro'])
            default_sel = by_id['agent-default-model']['config']
            self.assertEqual(default_sel, {
                'provider': 'google-gateway',
                'model': 'gemini-2.5-pro-prio',
                'reasoningEffort': 'high',
            })
            # Existing user preference is preserved while missing defaults are seeded.
            self.assertEqual(json.loads((home / '.dsh-tui/effort.json').read_text())['effort'], 'medium')
            self.assertTrue(json.loads((home / '.dsh-tui/onboarding.json').read_text())['completed'])
            self.assertEqual(json.loads((home / '.dsh-tui/permission.json').read_text())['permission'], 'danger-full-access')
            tui_settings = json.loads((home / '.dsh-tui/settings.json').read_text())
            self.assertIs(tui_settings['values']['launchpad'], False)

            # Missing gateway URL fails loudly without leaking the secret.
            (home / '.gemini/.env').write_text('GEMINI_API_KEY="gw-secret"\n')
            failed = subprocess.run(
                ['python3', str(DSH / 'configure.py')], env=env,
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True,
            )
            self.assertNotEqual(failed.returncode, 0)
            self.assertIn('Missing GOOGLE_GEMINI_BASE_URL', failed.stderr)
            self.assertNotIn('gw-secret', failed.stderr)

    def test_launch_resume_tui_state_and_session_lock_resolution(self):
        launch = self.call('launch_command', 'gemini-2.5-pro $(false)', '')
        self.assertEqual(launch.returncode, 0, launch.stderr)
        actual = subprocess.check_output(
            ['zsh', '-f', '-c', 'dsh-tui() { printf "%s\\0%s\\0%s\\0" "$VISUAL" "$DSH_TELEMETRY_DISABLED" "$TMUX_AI_MODEL"; }; ' + launch.stdout]
        ).decode().split('\0')[:-1]
        self.assertTrue(actual[0].endswith('/helper_scripts/bin/vim-fast'), actual)
        self.assertEqual(actual[1], '1')
        self.assertEqual(actual[2], 'gemini-2.5-pro $(false)')

        resume = self.call('resume_command', '323cee5d-dfa4-4370-b5dd-a212abb9126d')
        resumed = subprocess.check_output(
            ['zsh', '-f', '-c', 'dsh-tui() { printf "%s\\0" "$VISUAL" "$DSH_TELEMETRY_DISABLED" "$@"; }; ' + resume.stdout]
        ).decode().split('\0')[:-1]
        self.assertTrue(resumed[0].endswith('/helper_scripts/bin/vim-fast'), resumed)
        self.assertEqual(resumed[1:], ['1', '--resume', '323cee5d-dfa4-4370-b5dd-a212abb9126d'])
        self.assertEqual(self.call('foreground_busy', 'quiet thinking screen').returncode, 0)

        with tempfile.TemporaryDirectory(prefix='dsh-proc-', dir='/tmp') as proc_dir:
            proc = Path(proc_dir)
            (proc / '100/task/100').mkdir(parents=True)
            (proc / '100/fd').mkdir()
            (proc / '100/task/100/children').write_text('200\n')
            (proc / '200/task/200').mkdir(parents=True)
            (proc / '200/task/200/children').write_text('')
            (proc / '200/fd').mkdir()
            sid = '323cee5d-dfa4-4370-b5dd-a212abb9126d'
            lock_target = proc / 'sessions/--work--' / sid / 'session.lock'
            lock_target.parent.mkdir(parents=True)
            lock_target.write_text('')
            (proc / '200/fd/7').symlink_to(lock_target)

            env = dict(os.environ, TMA_PROC_ROOT=str(proc))
            found = self.call('session_id', '100', '%0', env=env)
            self.assertEqual(found.returncode, 0, found.stderr)
            self.assertEqual(found.stdout.strip(), sid)

            missing = self.call('session_id', '999', '%0', env=env)
            self.assertNotEqual(missing.returncode, 0)

    def test_fork_clones_live_session_closes_open_turn_and_filters_subagent_locks(self):
        with tempfile.TemporaryDirectory(prefix='dsh-fork-', dir='/tmp') as directory:
            root = Path(directory)
            sessions_root = root / 'dsh/sessions'
            storages_root = root / 'dsh/storages'
            storages_root.mkdir(parents=True)
            src_id = '11111111-2222-4333-8444-555555555555'
            sub_id = '66666666-7777-4888-9999-aaaaaaaaaaaa'
            (storages_root / 'workspace.json').write_text(json.dumps({
                'unit': {'name': 'workspace', 'version': 2},
                'tables': {'workspaces': {'ws-1': {
                    'path': '/tmp/work', 'title': 'work', 'sessionIds': [src_id],
                }}},
            }))

            seed_script = '''
import { createRequire } from "node:module";
import { execFileSync } from "node:child_process";
import { realpathSync } from "node:fs";
import { dirname, join } from "node:path";

const [sessionsRoot, srcId, subId] = process.argv.slice(1);
const dshBin = realpathSync(execFileSync("sh", ["-c", "command -v dsh"], { encoding: "utf8" }).trim());
const req = createRequire(join(dirname(dshBin), "../package.json"));
const { Context } = await import(req.resolve("@deepseek-ai/cordis"));
const persistencePlugin = await import(req.resolve("@deepseek-ai/dsh-session-persistence-jsonl"));

const ctx = new Context();
const fiber = ctx.plugin(persistencePlugin, { root: sessionsRoot });
await fiber.await();
const p = ctx.get("sessionPersistence");

// Create top-level session left mid-turn (open turn/start without turn/end)
const w = await p.create({
  version: 4, id: srcId, createdAt: 1000,
  cwd: "/tmp/work", isSeeded: false, delegationDepth: 0, agentPreset: "standard",
});
await w.append([
  { type: "user/message", seq: 0, time: 1001, data: { id: "m1", role: "user", source: { kind: "user" }, content: [{ type: "text", text: "hello fork" }] }, surfaceOp: "append" },
  { type: "turn/start", seq: 1, time: 1002, data: { turn: 1 } },
  { type: "step/start", seq: 2, time: 1003, data: { turn: 1, step: 1 } },
]);
await w.flush();
await w.close();

// Also create a child subagent session (delegationDepth: 1) so fork must pick top-level
const sw = await p.create({
  version: 4, id: subId, createdAt: 1004,
  cwd: "/tmp/work", parentSession: srcId, isSeeded: false, delegationDepth: 1,
});
await sw.flush();
await sw.close();
await fiber.dispose();
'''
            subprocess.check_call(['node', '--input-type=module', '-e', seed_script, str(sessions_root), src_id, sub_id])

            proc = root / 'proc'
            (proc / '10/task/10').mkdir(parents=True)
            (proc / '10/task/10/children').write_text('')
            (proc / '10/fd').mkdir()
            for idx, sid in enumerate((src_id, sub_id)):
                lock_file = next(sessions_root.glob('*/{}/session.lock'.format(sid)), None)
                if lock_file is None:
                    session_dir = next(sessions_root.glob('*/{}'.format(sid)))
                    lock_file = session_dir / 'session.lock'
                    lock_file.write_text('')
                (proc / '10/fd' / str(idx + 3)).symlink_to(lock_file)

            env = dict(os.environ, TMA_PROC_ROOT=str(proc))
            forked = self.call('fork_command', '10', '%0', '10', env=env)
            self.assertEqual(forked.returncode, 0, forked.stderr)
            argv = subprocess.check_output(
                ['zsh', '-f', '-c', 'dsh-tui() { printf "%s\\0" "$@"; }; ' + forked.stdout]
            ).decode().split('\0')[:-1]
            self.assertEqual(argv[0], '--resume')
            child_id = argv[1]
            self.assertNotIn(child_id, (src_id, sub_id))

            ws = json.loads((storages_root / 'workspace.json').read_text())
            self.assertIn(child_id, ws['tables']['workspaces']['ws-1']['sessionIds'])

            # Verify forked session closed the open turn and points parentSession at src_id.
            verify_script = '''
import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { execFileSync } from "node:child_process";
import { realpathSync } from "node:fs";
import { dirname, join } from "node:path";

const [sessionsRoot, srcId, childId] = process.argv.slice(1);
const dshBin = realpathSync(execFileSync("sh", ["-c", "command -v dsh"], { encoding: "utf8" }).trim());
const req = createRequire(join(dirname(dshBin), "../package.json"));
const { Context } = await import(req.resolve("@deepseek-ai/cordis"));
const persistencePlugin = await import(req.resolve("@deepseek-ai/dsh-session-persistence-jsonl"));

const ctx = new Context();
const fiber = ctx.plugin(persistencePlugin, { root: sessionsRoot });
await fiber.await();
const p = ctx.get("sessionPersistence");
const r = await p.open(childId, "read");
const { events } = await r.read();
assert.equal(r.header.parentSession, srcId);
assert.equal(r.header.isSeeded, true);
assert.equal(r.inheritedEventCount, 3);
assert.equal(events[3].type, "session/end-seed");
assert.equal(events[events.length - 1].type, "turn/end");
await r.close();
await fiber.dispose();
'''
            subprocess.check_call(['node', '--input-type=module', '-e', verify_script, str(sessions_root), src_id, child_id])

    def test_dsh_tui_process_is_detected_by_procfs_and_pane_scanner(self):
        with tempfile.TemporaryDirectory(prefix='dsh-tmux-', dir='/tmp') as directory:
            root = Path(directory)
            socket = str(root / 'sock')
            fake_bin = root / 'dsh-tui'
            fake_bin.write_text('#!/usr/bin/env python3\nimport time\nopen("/proc/self/comm", "w").write("dsh-tui")\ntime.sleep(60)\n')
            fake_bin.chmod(0o755)
            subprocess.check_call(['tmux', '-S', socket, '-f', '/dev/null', 'new-session', '-d', '-s', 't', str(fake_bin)])
            self.addCleanup(lambda: subprocess.run(['tmux', '-S', socket, 'kill-server'], stderr=subprocess.DEVNULL))
            pane = subprocess.check_output(['tmux', '-S', socket, 'display-message', '-p', '-t', 't:', '#{pane_id}'], universal_newlines=True).strip()
            pid = subprocess.check_output(['tmux', '-S', socket, 'display-message', '-p', '-t', pane, '#{pane_pid}'], universal_newlines=True).strip()
            # Wait briefly for python to write /proc/self/comm
            for _ in range(20):
                out = subprocess.run(
                    ['bash', '-c', 'source "$1"; _find_ai_pid "$2"', 'test', str(TMUX_DIR / 'ai/lib.sh'), pid],
                    stdout=subprocess.PIPE, universal_newlines=True,
                ).stdout.strip()
                if out.endswith(' dsh'):
                    break
                subprocess.run(['sleep', '0.05'])
            self.assertTrue(out.endswith(' dsh'), out)
            rows = subprocess.check_output(
                ['bash', '-c', 'source "$1"; _ai_pane_rows -a', 'test', str(TMUX_DIR / 'ai/lib.sh')],
                env=dict(os.environ, TMUX=socket + ',0,0'), universal_newlines=True,
            )
            self.assertIn(pane, rows)


class DshLifecycleTest(unittest.TestCase):
    def tmux(self, *args):
        return subprocess.check_output(['tmux', '-S', self.socket, *args], universal_newlines=True).strip()

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='dsh-hooks-', dir='/tmp')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.socket = str(self.root / 'socket')
        self.tmux('-f', '/dev/null', 'new-session', '-d', '-s', 'test', 'sleep 600')
        self.addCleanup(lambda: subprocess.run(['tmux', '-S', self.socket, 'kill-server'], stderr=subprocess.DEVNULL))
        self.pane = self.tmux('display-message', '-p', '-t', 'test:', '#{pane_id}')
        self.tmux('set-option', '-p', '-t', self.pane, '@ai_agent_attribute', 'test')
        self.env = dict(
            os.environ,
            TMUX=self.socket + ',0,0',
            TMUX_PANE=self.pane,
            AI_AGENT_STATE_LOG=str(self.root / 'state.log'),
            AI_AGENT_PROMPT_LOG=str(self.root / 'prompts.jsonl'),
        )

    def option(self, name):
        return self.tmux('show-option', '-pqv', '-t', self.pane, name)

    def test_tma_plugin_tracks_running_background_unread_and_ignores_headless(self):
        script = '''
import assert from 'node:assert/strict';
import readline from 'node:readline';
import plugin from %s;

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const listeners = new Map();
let agents = [];
let jobs = [];
let profileName = 'headless';

const makeCtx = () => ({
  get: (key) => {
    if (key === 'profileContext') return { name: profileName };
    if (key === 'agents') return { list: () => agents };
    if (key === 'jobs') return {
      list: (owner) => jobs.filter((j) => j.owner === owner),
      events: { subscribe: () => () => {} },
    };
    return undefined;
  },
  on: (event, fn) => {
    if (!listeners.has(event)) listeners.set(event, []);
    listeners.get(event).push(fn);
    return () => {};
  },
  effect: () => {},
});

const emit = (event, ...args) => {
  for (const fn of listeners.get(event) ?? []) fn(...args);
};

const topSession = { id: 'sess-1', header: { delegationDepth: 0, cwd: process.cwd() } };
const topAgent = { id: 'agent-1', status: 'idle', session: topSession };

for await (const line of readline.createInterface({ input: process.stdin })) {
  const step = line.trim();
  if (step === 'headless') {
    plugin.apply(makeCtx());
    assert.equal(listeners.size, 0);
  } else if (step === 'init') {
    delete process.env.VISUAL;
    profileName = 'dsh-tui';
    agents = [topAgent];
    plugin.apply(makeCtx());
    assert.ok(process.env.VISUAL?.endsWith('/helper_scripts/bin/vim-fast'));
  } else if (step === 'running') {
    emit('session/event', topSession, {
      type: 'user/message',
      data: { source: { kind: 'user' }, content: [{ type: 'text', text: 'run bg sleep' }] },
    });
    topAgent.status = 'running';
    emit('agent/status', { agent: topAgent, status: 'running' });
  } else if (step === 'background') {
    jobs = [{ id: 'job-1', owner: 'agent-1', status: 'running' }];
    topAgent.status = 'idle';
    emit('agent/status', { agent: topAgent, status: 'idle' });
    await sleep(100);
  } else if (step === 'woke_running') {
    jobs = [{ id: 'job-1', owner: 'agent-1', status: 'completed' }];
    topAgent.status = 'running';
    emit('agent/status', { agent: topAgent, status: 'running' });
  } else if (step === 'settled_idle') {
    topAgent.status = 'idle';
    emit('agent/status', { agent: topAgent, status: 'idle' });
    await sleep(100);
  }
  console.log('done:' + step);
}
''' % json.dumps(str(DSH / 'tma.mjs'))

        proc = subprocess.Popen(
            ['node', '--input-type=module', '-e', script],
            env=self.env, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
            stderr=subprocess.PIPE, universal_newlines=True,
        )
        def cleanup():
            proc.stdin.close()
            proc.wait(timeout=5)
            proc.stdout.close()
            proc.stderr.close()
        self.addCleanup(cleanup)

        def run_step(name):
            proc.stdin.write(name + '\n')
            proc.stdin.flush()
            line = proc.stdout.readline()
            if not line:
                self.fail('Node fixture failed: ' + proc.stderr.read())
            self.assertEqual(line.strip(), 'done:' + name)

        run_step('headless')
        self.assertEqual(self.option('@ai_agent_running'), '')

        run_step('init')
        self.assertEqual(self.option('@ai_agent_running'), '0')
        self.assertEqual(self.option('@ai_agent_unread'), '0')

        run_step('running')
        self.assertEqual(self.option('@ai_agent_running'), '1')
        prompts = [json.loads(line) for line in (self.root / 'prompts.jsonl').read_text().splitlines()]
        self.assertEqual([row['prompt'] for row in prompts], ['run bg sleep'])

        run_step('background')
        self.assertEqual(self.option('@ai_agent_running'), '0')
        self.assertEqual(self.option('@ai_agent_background'), '1')
        self.assertEqual(self.option('@ai_agent_unread'), '1')

        run_step('woke_running')
        self.assertEqual(self.option('@ai_agent_running'), '1')
        self.assertEqual(self.option('@ai_agent_background'), '')

        run_step('settled_idle')
        self.assertEqual(self.option('@ai_agent_running'), '0')
        self.assertEqual(self.option('@ai_agent_background'), '')
        self.assertEqual(self.option('@ai_agent_unread'), '1')


if __name__ == '__main__':
    unittest.main()
