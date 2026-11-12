#!/usr/bin/env python3
"""Replay Gemini's message updates for Markdown; preserve the original JSONL."""

from collections import OrderedDict
import json
from pathlib import Path
import sys

from session import resolve

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'default'))
from history import export


def messages(rows):
    # Match Gemini's append-only recording format: repeated ids replace a
    # message; patches, rewinds and explicit ordering update the conversation.
    current = OrderedDict()
    for row in rows:
        if '$rewindTo' in row:
            ids = list(current)
            index = ids.index(row['$rewindTo']) if row['$rewindTo'] in current else 0
            for key in ids[index:]:
                del current[key]
        elif '$patch' in row:
            patch = row['$patch']
            updates = ([patch] if 'id' in patch else []) + patch.get('updates', [])
            for update in updates:
                if update['id'] in current and 'content' in update:
                    current[update['id']]['content'] = update['content']
            for key in patch.get('removeIds', []):
                current.pop(key, None)
            for key in patch.get('orderIds', []):
                if key in current:
                    current.move_to_end(key)
        elif 'id' in row:
            current[row['id']] = dict(row)
        elif '$set' in row and 'messages' in row['$set']:
            current = OrderedDict((message['id'], dict(message)) for message in row['$set']['messages'])
        elif 'sessionId' in row and 'messages' in row:
            current.update((message['id'], dict(message)) for message in row['messages'])

    for message in current.values():
        if message['type'] not in ('user', 'gemini'):
            continue
        content = message['content']
        if isinstance(content, str):
            text = content
        else:
            parts = []
            for part in content:
                if 'text' in part:
                    parts.append(part['text'])
                elif 'inlineData' in part or 'fileData' in part:
                    parts.append('[attachment; original data is in the JSONL export]')
            text = '\n\n'.join(parts)
        if text:
            role = 'assistant' if message['type'] == 'gemini' else 'user'
            yield role, message.get('timestamp', ''), text


if __name__ == '__main__':
    pid, pane, format = sys.argv[1:]
    binding = resolve(pane, pid)
    if not binding['transcript_path']:
        raise ValueError('Gemini has not created a transcript for ' + pane)
    path = Path(binding['transcript_path'])
    with path.open() as stream:
        metadata = json.loads(stream.readline())
    if metadata['sessionId'] != binding['session_id']:
        raise ValueError('Gemini transcript session does not match the pane binding')
    export(path, 'gemini', binding['session_id'], pane, format, messages)
