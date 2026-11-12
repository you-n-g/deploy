#!/usr/bin/env python3
"""Bind Pi's native session/branch metadata to the live pane process."""

import json
from pathlib import Path
import subprocess
import sys


OPTION = '@tma_pi_session'


def process_start(pid):
    if Path('/proc').is_dir():
        return (Path('/proc') / str(pid) / 'stat').read_text().rsplit(')', 1)[1].split()[19]
    return subprocess.check_output(['ps', '-p', str(pid), '-o', 'lstart='], universal_newlines=True).strip()


def record(pane, pid, payload):
    binding = dict(payload, pid=str(pid), process_start=process_start(pid))
    subprocess.check_call(['tmux', 'set-option', '-p', '-t', pane, OPTION, json.dumps(binding)])


def resolve(pane, pid):
    raw = subprocess.check_output(['tmux', 'show-option', '-pqv', '-t', pane, OPTION], universal_newlines=True)
    if not raw.strip():
        raise ValueError('No Pi session metadata for {}; install the wrapper and /reload Pi'.format(pane))
    binding = json.loads(raw)
    if binding['pid'] != str(pid) or binding['process_start'] != process_start(pid):
        raise ValueError('Stale Pi session metadata for {}; reload the current Pi extension'.format(pane))
    return binding


if __name__ == '__main__':
    operation, pane, pid = sys.argv[1:]
    if operation == 'record':
        record(pane, pid, json.load(sys.stdin))
    elif operation == 'id':
        print(resolve(pane, pid)['session_id'])
    else:
        raise ValueError('Unknown Pi session operation: ' + operation)
