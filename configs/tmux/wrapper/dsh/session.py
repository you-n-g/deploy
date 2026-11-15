#!/usr/bin/env python3
"""Resolve live DSH session locks held open in /proc/<pid>/fd."""

from collections import deque
import os
from pathlib import Path
import re
import sys

SESSION_LOCK_RE = re.compile(r'^(/.+/sessions)/[^/]+/([0-9a-fA-F-]{36})/session\.lock$')


def find_session_locks(root_pid, proc_root=Path('/proc')):
    queue = deque([int(root_pid)])
    seen = set()
    locks = {}
    while queue:
        pid = queue.popleft()
        if pid in seen:
            continue
        seen.add(pid)
        fd_dir = proc_root / str(pid) / 'fd'
        try:
            entries = list(fd_dir.iterdir())
        except (FileNotFoundError, PermissionError, ProcessLookupError):
            entries = []
        for entry in entries:
            try:
                target = os.readlink(str(entry))
            except OSError:
                continue
            match = SESSION_LOCK_RE.match(target)
            if match:
                sessions_root, session_id = match.group(1), match.group(2)
                locks[session_id] = sessions_root
        children = proc_root / str(pid) / 'task' / str(pid) / 'children'
        try:
            queue.extend(int(child) for child in children.read_text().split())
        except (FileNotFoundError, ProcessLookupError):
            continue
    return sorted((sid, root) for sid, root in locks.items())


def main():
    if len(sys.argv) != 3 or sys.argv[1] not in ('id', 'locks'):
        sys.exit('usage: session.py <id|locks> PID')
    mode, pid = sys.argv[1], sys.argv[2]
    proc_root = Path(os.environ.get('TMA_PROC_ROOT', '/proc'))
    locks = find_session_locks(pid, proc_root)
    if not locks:
        sys.stderr.write('No active DSH session lock found under PID {}\n'.format(pid))
        sys.exit(1)
    if mode == 'locks':
        for sid, root in locks:
            print('{}\t{}'.format(sid, root))
        return
    if len(locks) != 1:
        sys.stderr.write('Multiple DSH session locks under PID {}\n'.format(pid))
        sys.exit(1)
    print(locks[0][0])


if __name__ == '__main__':
    main()
