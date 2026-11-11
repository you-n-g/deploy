#!/usr/bin/env python3
"""Find interactive AI pane roots in one bounded /proc traversal."""

import os
from pathlib import Path
import re
import sys


def process_info(pid):
    proc = Path("/proc") / str(pid)
    try:
        stat = (proc / "stat").read_text()
        argv = (proc / "cmdline").read_bytes().split(b"\0")
    except (FileNotFoundError, ProcessLookupError):
        return None  # The process exited during the snapshot.
    name = stat.split(" (", 1)[1].rsplit(") ", 1)[0]
    argv = [os.fsdecode(arg) for arg in argv if arg]
    return name, argv


def is_broker(argv, broker):
    program = os.path.basename(argv[0]) if argv else ""
    argument = os.path.basename(argv[1]) if len(argv) > 1 else ""
    return program == broker or (program == "node" and argument == broker)


def agent_name(name, argv):
    # Same Gemini entry-point rule as process.sh's procfs and snapshot paths.
    if name not in ("node", "MainThread") or not argv or os.path.basename(argv[0]) != "node":
        return name
    arguments = iter(argv[1:])
    entry = next((arg for arg in arguments if not arg.startswith("-")), "")
    if (entry == "gemini" or entry.endswith("/bin/gemini")
            or entry.endswith("/@google/gemini-cli/bundle/gemini.js")):
        return "gemini"
    return name


def ai_pane_pids(roots, pattern, broker):
    roots = set(roots)
    for root in roots:
        queue = [root]
        visited = set()
        while queue:
            pid = queue.pop()
            if pid in visited or (pid != root and pid in roots):
                continue
            visited.add(pid)
            process = process_info(pid)
            if process is None:
                continue
            name, argv = process
            # A broker's agents belong to the service. Another branch of the
            # same pane may still contain an interactive agent, so keep it.
            if is_broker(argv, broker):
                continue
            if pattern.search(agent_name(name, argv)):
                yield root
                break  # Background tools beneath this agent cannot add a pane.
            children = Path("/proc") / str(pid) / "task" / str(pid) / "children"
            try:
                queue.extend(int(child) for child in children.read_text().split())
            except (FileNotFoundError, ProcessLookupError):
                if not children.parent.exists():
                    continue
                raise RuntimeError("{} is missing; kernel lacks CONFIG_PROC_CHILDREN".format(children))


if __name__ == "__main__":
    pattern = re.compile(sys.argv[1])
    broker = sys.argv[2]
    for pid in ai_pane_pids((int(pid) for pid in sys.stdin.read().split()), pattern, broker):
        print(pid)
