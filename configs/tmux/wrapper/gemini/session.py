#!/usr/bin/env python3
"""Bind native Gemini hook metadata to the live pane process."""

import json
from pathlib import Path
import subprocess
import sys


OPTION = '@tma_gemini_session'


def process_start(pid):
    if Path('/proc').is_dir():
        return (Path('/proc') / str(pid) / 'stat').read_text().rsplit(')', 1)[1].split()[19]
    return subprocess.check_output(['ps', '-p', str(pid), '-o', 'lstart='], universal_newlines=True).strip()


def record(pane, pid, payload):
    # Even an empty path on SessionStart replaces the preceding session. This
    # prevents /clear or /resume from exporting the old conversation.
    binding = dict(pid=str(pid), process_start=process_start(pid),
                   session_id=payload['session_id'],
                   transcript_path=payload.get('transcript_path', ''))
    subprocess.check_call(['tmux', 'set-option', '-p', '-t', pane, OPTION, json.dumps(binding)])


def resolve(pane, pid):
    raw = subprocess.check_output(['tmux', 'show-option', '-pqv', '-t', pane, OPTION], universal_newlines=True)
    if not raw.strip():
        raise ValueError('No Gemini session metadata for {}; let its next native hook run and retry'.format(pane))
    binding = json.loads(raw)
    if binding['pid'] != str(pid) or binding['process_start'] != process_start(pid):
        raise ValueError('Stale Gemini session metadata for {}; waiting for the current process hook'.format(pane))
    return binding


if __name__ == '__main__':
    operation, pane, pid = sys.argv[1:]
    if operation == 'record':
        record(pane, pid, json.load(sys.stdin))
    elif operation == 'id':
        print(resolve(pane, pid)['session_id'])
    else:
        raise ValueError('Unknown Gemini session operation: ' + operation)
