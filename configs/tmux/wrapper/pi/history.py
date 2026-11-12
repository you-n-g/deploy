#!/usr/bin/env python3
"""Export Pi's selected branch as text, or its complete original JSONL tree."""

import json
from pathlib import Path
import sys

from session import resolve

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'default'))
from history import export, snapshot, text_content


def messages(rows, leaf):
    entries = {row['id']: row for row in rows if row['type'] != 'session'}
    branch = []
    seen = set()
    while leaf is not None:
        if leaf in seen:
            raise ValueError('Cycle in Pi transcript at ' + leaf)
        seen.add(leaf)
        row = entries[leaf]
        branch.append(row)
        leaf = row['parentId']
    for row in reversed(branch):
        if row['type'] != 'message':
            continue
        message = row['message']
        if message['role'] in ('user', 'assistant'):
            text = text_content(message['content'])
            if text:
                yield message['role'], row['timestamp'], text


if __name__ == '__main__':
    pid, pane, format = sys.argv[1:]
    binding = resolve(pane, pid)
    if not binding['transcript_path']:
        raise ValueError('Pi has not created a transcript for ' + pane)
    path = Path(binding['transcript_path'])
    with path.open() as stream:
        metadata = json.loads(stream.readline())
    if metadata['id'] != binding['session_id']:
        raise ValueError('Pi transcript session does not match the pane binding')
    if format == 'last':
        answers = [text for role, _, text in messages(snapshot(path)[1], binding['leaf_id']) if role == 'assistant']
        if not answers:
            raise ValueError('No assistant text in the current Pi branch')
        print(answers[-1])
    else:
        export(path, 'pi', binding['session_id'], pane, format,
               lambda rows: messages(rows, binding['leaf_id']))
