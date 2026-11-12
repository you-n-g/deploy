"""Shared snapshot/export helpers; each backend locates and interprets its log."""

import json
import os
from pathlib import Path
import sys


def process_setting(pid, name, default):
    """Use the target process's configuration, even from a different shell."""
    environ = Path('/proc') / str(pid) / 'environ'
    if environ.exists():
        prefix = name.encode() + b'='
        for entry in environ.read_bytes().split(b'\0'):
            if entry.startswith(prefix):
                return os.fsdecode(entry[len(prefix):])
        return default
    return os.environ.get(name, default)


def unique_log(paths, description):
    paths = sorted(set(path.resolve() for path in paths))
    if len(paths) != 1:
        raise ValueError('Expected one transcript for {}; found {}: {}'.format(
            description, len(paths), ', '.join(str(path) for path in paths)))
    return paths[0]


def snapshot(path):
    # Bound the read at its initial size: a running session can keep appending.
    with path.open('rb') as stream:
        data = stream.read(os.fstat(stream.fileno()).st_size)
    rows = []
    for number, line in enumerate(data.splitlines(), 1):
        if not line.strip():
            continue
        try:
            rows.append(json.loads(line))
        except ValueError as error:
            raise ValueError('{}:{}: invalid JSON; export again if the session is writing: {}'.format(
                path, number, error)) from error
    return data, rows


def text_content(content):
    if isinstance(content, str):
        return content
    parts = []
    for block in content:
        if block.get('type') in ('text', 'input_text', 'output_text'):
            parts.append(block['text'])
        elif block.get('type') in ('image', 'input_image', 'image_url'):
            parts.append('[image; original data is in the JSONL export]')
    return '\n\n'.join(parts)


def export(path, backend, session, pane, format, messages):
    if format not in ('markdown', 'jsonl'):
        raise ValueError('Unsupported history format: ' + format)
    data, rows = snapshot(path)
    if format == 'jsonl':
        sys.stdout.buffer.write(data)
        return
    entries = list(messages(rows))
    lines = ['# TMA conversation: ' + backend, '',
             '- Pane: `{}`'.format(pane), '- Session: `{}`'.format(session),
             '- Source: `{}`'.format(path),
             '- Messages: {}; source records: {}'.format(len(entries), len(rows)), '',
             'Conversation text only. Use the jsonl format for tools and all original records.', '']
    for number, (role, timestamp, text) in enumerate(entries, 1):
        title = '## {}. {}'.format(number, role)
        if timestamp:
            title += ' · ' + timestamp
        lines.extend([title, '', text.rstrip(), ''])
    sys.stdout.write('\n'.join(lines) + '\n')
