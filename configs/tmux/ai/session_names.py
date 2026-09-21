#!/usr/bin/env python3
import json
import os
import re
import subprocess
import sys
from collections import defaultdict, deque
from pathlib import Path
from typing import DefaultDict, Dict, Iterable, List, Optional, Tuple


AI_PROCESS_NAMES = {"claude", "codex"}
SESSION_ID_RE = re.compile(r"[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}")
Process = Tuple[int, str, str]


def read_process(pid: int) -> Optional[Process]:
    try:
        line = Path(f"/proc/{pid}/stat").read_text()
    except FileNotFoundError:
        return None
    _pid_text, rest = line.split(" (", 1)
    comm, fields_text = rest.rsplit(") ", 1)
    fields = fields_text.split()
    ppid = int(fields[1])
    start_time = fields[19]
    return (ppid, comm, start_time)


def process_snapshot(
    roots: Iterable[int],
) -> Tuple[Dict[int, Process], DefaultDict[int, List[int]]]:
    # Only the pane subtrees are needed, and a shared HPC node runs ~10k
    # processes, so walk down from each pane root via /proc/<pid>/task/<pid>/
    # children instead of scanning all of /proc: that scan alone cost ~0.35s
    # of every `prefix A`. The children file needs CONFIG_PROC_CHILDREN, which
    # lib.sh's _find_ai_pid already relies on here.
    processes: Dict[int, Process] = {}
    children: DefaultDict[int, List[int]] = defaultdict(list)
    queue = deque(roots)
    while queue:
        pid = queue.popleft()
        if pid in processes:
            continue
        process = read_process(pid)
        if process is None:
            continue
        processes[pid] = process
        children_path = Path(f"/proc/{pid}/task/{pid}/children")
        try:
            child_text = children_path.read_text()
        except FileNotFoundError:
            if not children_path.parent.exists():
                continue  # exited between stat and children
            raise RuntimeError(f"{children_path} is missing; kernel lacks CONFIG_PROC_CHILDREN")
        child_pids = sorted(int(item) for item in child_text.split())
        children[pid].extend(child_pids)
        queue.extend(child_pids)
    return processes, children


def pane_roots(pane_ids: Iterable[str]) -> Dict[str, int]:
    output = subprocess.check_output(
        ["tmux", "list-panes", "-a", "-F", "#{pane_id}\t#{pane_pid}"],
        universal_newlines=True,
    )
    wanted = set(pane_ids)
    roots = {}
    for line in output.splitlines():
        pane_id, pane_pid = line.split("\t", 1)
        if pane_id in wanted:
            roots[pane_id] = int(pane_pid)
    missing = wanted.difference(roots)
    if missing:
        raise RuntimeError(f"pane does not resolve: {sorted(missing)}")
    return roots


def command_line(pid: int) -> List[str]:
    data = Path(f"/proc/{pid}/cmdline").read_bytes()
    return [item.decode(errors="replace") for item in data.split(b"\0") if item]


def is_under_broker(pid: int, pane_pid: int, processes: Dict[int, Process]) -> bool:
    while pid not in {pane_pid, 1}:
        argv = command_line(pid)
        program = os.path.basename(argv[0]) if argv else ""
        argument = os.path.basename(argv[1]) if len(argv) > 1 else ""
        if program == "cc-connect" or (program == "node" and argument == "cc-connect"):
            return True
        pid = processes[pid][0]
    return False


def ai_process(
    pane_pid: int,
    processes: Dict[int, Process],
    children: DefaultDict[int, List[int]],
) -> Optional[Tuple[int, str]]:
    queue = deque([pane_pid])
    while queue:
        pid = queue.popleft()
        process = processes.get(pid)
        if process is None:
            continue
        name = os.path.basename(process[1])
        if name in AI_PROCESS_NAMES and not is_under_broker(pid, pane_pid, processes):
            return pid, name
        queue.extend(children[pid])
    return None


def codex_session_id(pid: int) -> str:
    # Preserve lib.sh's fd-first resolution: forked sessions keep source ids in
    # argv, while the first UUID-bearing open file identifies the live thread.
    for fd in Path(f"/proc/{pid}/fd").iterdir():
        try:
            target = os.readlink(fd)
        except FileNotFoundError:
            continue
        match = SESSION_ID_RE.search(target)
        if match:
            return match.group(0)

    match = SESSION_ID_RE.search(" ".join(command_line(pid)))
    return match.group(0) if match else ""


def codex_names(session_ids: Iterable[str]) -> Dict[str, str]:
    wanted = {session_id for session_id in session_ids if session_id}
    if not wanted:
        return {}

    index_path = Path(os.environ.get("CODEX_HOME", Path.home() / ".codex")) / "session_index.jsonl"
    names = {}
    with index_path.open() as handle:
        for line in handle:
            record = json.loads(line)
            session_id = record.get("id")
            if session_id in wanted and record.get("thread_name"):
                names[session_id] = record["thread_name"]
    return names


def claude_name(pid: int, pane_id: str, process: Process) -> str:
    config_dir = Path(os.environ.get("CLAUDE_CONFIG_DIR", Path.home() / ".claude"))
    state_path = config_dir / "sessions" / f"{pid}.json"
    if not state_path.exists():
        return ""

    with state_path.open() as handle:
        state = json.load(handle)
    recorded_pane = (state.get("tmux") or "").rpartition(".")[2]
    if recorded_pane and recorded_pane != pane_id:
        raise RuntimeError(f"Claude state pane mismatch for {pane_id}: {recorded_pane}")
    recorded_start = state.get("procStart")
    if recorded_start is not None and str(recorded_start) != process[2]:
        raise RuntimeError(f"Claude state process mismatch for pid {pid}")

    job_id = state.get("parkedJobId")
    if not job_id:
        return state.get("name") or ""
    with (config_dir / "jobs" / job_id / "state.json").open() as handle:
        return json.load(handle).get("name") or ""


def session_names(pane_ids: List[str]) -> Dict[str, str]:
    roots = pane_roots(pane_ids)
    processes, children = process_snapshot(roots.values())
    agents = {
        pane_id: ai_process(pane_pid, processes, children)
        for pane_id, pane_pid in roots.items()
    }
    codex_ids = {
        pane_id: codex_session_id(agent[0])
        for pane_id, agent in agents.items()
        if agent and agent[1] == "codex"
    }
    indexed_names = codex_names(codex_ids.values())

    names = {}
    for pane_id in pane_ids:
        agent = agents[pane_id]
        if not agent:
            names[pane_id] = ""
        elif agent[1] == "codex":
            names[pane_id] = indexed_names.get(codex_ids[pane_id], "")
        else:
            names[pane_id] = claude_name(agent[0], pane_id, processes[agent[0]])
    return names


def sanitize(name: str) -> str:
    return name.replace("\t", " ").replace("\n", " ").replace("|", "¦")


def main() -> None:
    pane_ids = sys.argv[1:]
    names = session_names(pane_ids)
    for pane_id in pane_ids:
        print(f"{pane_id}\t{sanitize(names[pane_id])}")


if __name__ == "__main__":
    main()
