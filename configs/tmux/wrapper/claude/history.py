#!/usr/bin/env python3
"""Export Claude's current session (including a job occupying a parked pane)."""

from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'default'))
from history import export, process_setting, text_content, unique_log


def transcript(pid, session):
    root = Path(process_setting(pid, 'CLAUDE_CONFIG_DIR', str(Path.home() / '.claude')))
    return unique_log((root / 'projects').glob('*/' + session + '.jsonl'), 'Claude session ' + session)


def messages(rows):
    for row in rows:
        if row.get('isSidechain') or row.get('type') not in ('user', 'assistant'):
            continue
        text = text_content(row['message']['content'])
        if text:
            yield row['type'], row.get('timestamp', ''), text


if __name__ == '__main__':
    pid, session, pane, format = sys.argv[1:]
    export(transcript(pid, session), 'claude', session, pane, format, messages)
