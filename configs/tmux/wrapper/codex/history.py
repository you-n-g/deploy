#!/usr/bin/env python3
"""Export a live Codex session from its original rollout, including pre-compaction history."""

import os
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'default'))
from history import export, process_setting, snapshot, text_content, unique_log


def transcript(pid, session):
    # The live fd is authoritative for forks and non-default Codex homes.
    descriptors = Path('/proc') / str(pid) / 'fd'
    paths = []
    if descriptors.is_dir():
        for descriptor in descriptors.iterdir():
            try:
                path = Path(os.readlink(str(descriptor)))
            except FileNotFoundError:
                continue  # The target closed this descriptor during the scan.
            if path.name.startswith('rollout-') and path.name.endswith('-' + session + '.jsonl'):
                paths.append(path)
    if paths:
        return unique_log(paths, 'Codex session ' + session)
    # A resumed session may not keep a rollout fd open while idle.
    root = Path(process_setting(pid, 'CODEX_HOME', str(Path.home() / '.codex')))
    for directory in ('sessions', 'archived_sessions'):
        paths.extend((root / directory).glob('**/rollout-*-' + session + '.jsonl'))
    return unique_log(paths, 'Codex session ' + session)


def messages(rows):
    # New Codex versions persist response_item messages without user_message /
    # agent_message events. Prefer those canonical records to avoid duplicates.
    roles = {row['payload']['role'] for row in rows
             if row.get('type') == 'response_item' and row['payload'].get('type') == 'message'}
    for row in rows:
        payload = row.get('payload', {})
        timestamp = row.get('timestamp', '')
        if row.get('type') == 'response_item' and payload.get('type') == 'message':
            role = payload['role']
            if role not in ('user', 'assistant'):
                continue
            text = text_content(payload['content'])
            if payload.get('channel'):
                role += ' (' + payload['channel'] + ')'
            if text:
                yield role, timestamp, text
        elif row.get('type') == 'event_msg' and payload.get('type') in ('user_message', 'agent_message'):
            role = 'user' if payload['type'] == 'user_message' else 'assistant'
            if role not in roles:
                yield role, timestamp, payload['message']
        elif row.get('type') == 'compacted':
            yield 'context compacted', timestamp, payload.get('message', 'Context compacted.')


def last_message(rows):
    # The completion event carries the final answer. Later commentary or an
    # interrupted turn must not replace the last completed response. Reading
    # it also avoids Ctrl+O's terminal clipboard acknowledgement and races
    # with unrelated panes creating tmux buffers.
    for row in reversed(rows):
        payload = row.get('payload', {})
        if row.get('type') == 'event_msg' and payload.get('type') == 'task_complete':
            text = payload.get('last_agent_message')
            if text and text.strip():
                return text
    raise ValueError('No completed Codex response in the current session')


if __name__ == '__main__':
    pid, session, pane, format = sys.argv[1:]
    path = transcript(pid, session)
    if format == 'last':
        print(last_message(snapshot(path)[1]))
    else:
        export(path, 'codex', session, pane, format, messages)
