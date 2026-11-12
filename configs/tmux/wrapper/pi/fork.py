#!/usr/bin/env python3
"""Clone the pane's selected Pi branch without modifying its live session."""

from datetime import datetime, timezone
import json
from pathlib import Path
import sys
from uuid import uuid4

from session import branch, resolve

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'default'))
from history import snapshot


def fork(pane, pid):
    binding = resolve(pane, pid)
    if not binding['transcript_path']:
        raise ValueError('Pi has not created a transcript for ' + pane)
    source = Path(binding['transcript_path'])
    _, rows = snapshot(source)
    header = rows[0]
    if header['type'] != 'session' or header['id'] != binding['session_id']:
        raise ValueError('Pi transcript session does not match the pane binding')
    selected = branch(rows, binding['leaf_id'])
    session_id = str(uuid4())
    timestamp = datetime.now(timezone.utc).isoformat(timespec='milliseconds').replace('+00:00', 'Z')
    target = source.with_name('{}_{}.jsonl'.format(timestamp.replace(':', '-').replace('.', '-'), session_id))
    header = dict(header, id=session_id, timestamp=timestamp, parentSession=str(source))
    # Pi's --fork copies the whole file and resumes its final entry, which may
    # belong to a different /tree branch. Copy only the bound ancestry instead.
    with target.open('x') as stream:
        target.chmod(0o600)
        for row in [header] + selected:
            stream.write(json.dumps(row, ensure_ascii=False) + '\n')
    return target


if __name__ == '__main__':
    pane, pid = sys.argv[1:]
    print(fork(pane, pid))
