#!/usr/bin/env python3
"""Open or refresh one top-right research status viewer per leader pane."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import time


def run(*args):
    return subprocess.check_output(args, universal_newlines=True).strip()


def repository(report):
    return run("git", "-C", str(report.parent), "rev-parse", "--show-toplevel")


def baseline_ref(report):
    key = hashlib.sha256(str(report).encode()).hexdigest()[:24]
    return "refs/research-leader/" + key


def baseline(report):
    result = subprocess.run(
        ["git", "-C", repository(report), "rev-parse", "--verify", "--quiet", baseline_ref(report)],
        stdout=subprocess.PIPE, universal_newlines=True,
    )
    if result.returncode == 1:
        return None
    result.check_returncode()
    return result.stdout.strip()


def checkpoint(report):
    """Snapshot just this report without changing the project branch or index."""
    root = repository(report)
    relative = report.relative_to(root)
    git = ["git", "-C", root]
    blob = subprocess.check_output(git + ["hash-object", "-w", "--stdin"], input=report.read_bytes()).decode().strip()
    entry = "100644 blob {}\t{}\0".format(blob, relative.name)
    tree = subprocess.check_output(git + ["mktree", "-z"], input=entry.encode()).decode().strip()
    for directory in reversed(relative.parts[:-1]):
        entry = "040000 tree {}\t{}\0".format(tree, directory)
        tree = subprocess.check_output(git + ["mktree", "-z"], input=entry.encode()).decode().strip()
    previous = baseline(report)
    if previous and run(*git, "rev-parse", previous + "^{tree}") == tree:
        return previous
    parents = ["-p", previous] if previous else []
    commit = run(*git, "commit-tree", tree, *parents, "-m", "Research note before next update: " + str(relative))
    run(*git, "update-ref", baseline_ref(report), commit, previous or "0" * len(commit))
    return commit


def find_viewer(owner):
    for line in run("tmux", "list-panes", "-t", owner,
                    "-F", "#{pane_id} #{@research_leader_owner}").splitlines():
        fields = line.split()
        if len(fields) == 2 and fields[1] == owner:
            return fields[0]


def assert_saved(viewer, report):
    socket = run("tmux", "show-options", "-pqv", "-t", viewer, "@research_leader_socket")
    expression = "getbufvar(bufnr('{}'), '&modified')".format(str(report).replace("'", "''"))
    if run("nvim", "--server", socket, "--remote-expr", expression) == "1":
        raise SystemExit("Research note has unsaved edits; save or merge them before checkpointing: " + str(report))


def refresh_viewer(socket, report, base):
    payload = json.dumps({"report": str(report), "base": base}, ensure_ascii=False)
    expression = "luaeval('research_leader_open(_A)', '" + payload.replace("'", "''") + "')"
    run("nvim", "--server", socket, "--remote-expr", expression)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", type=Path)
    parser.add_argument("owner", nargs="?", default=os.environ.get("TMUX_PANE"))
    action = parser.add_mutually_exclusive_group()
    action.add_argument("--checkpoint", action="store_true", help="snapshot this report before editing, without touching the project branch or index")
    action.add_argument("--close", action="store_true", help="close this leader's viewer and exit the mode")
    args = parser.parse_args()
    if not args.owner:
        parser.error("run inside tmux or supply an owner pane")
    for command in ("tmux", "nvim"):
        if not shutil.which(command):
            parser.error("required command not found: " + command)
    report = args.report.resolve(strict=True)
    if not report.is_file() or report.suffix != ".md":
        parser.error("report must be a Markdown file")
    owner, columns, rows = run(
        "tmux", "display-message", "-p", "-t", args.owner,
        "#{pane_id} #{window_width} #{window_height}",
    ).split()
    viewer = find_viewer(owner)

    if args.close:
        if viewer:
            run("tmux", "kill-pane", "-t", viewer)
        run("tmux", "set-option", "-p", "-t", owner, "@research_leader_mode", "0")
        print("Research leader mode closed for " + owner)
        return

    if args.checkpoint:
        if viewer:
            assert_saved(viewer, report)
        base = checkpoint(report)
        if not viewer:
            print("Research baseline {}: {}".format(base, report))
            return
    else:
        base = baseline(report)
    if not base:
        parser.error("run --checkpoint before editing this research note")
    if viewer is None:
        columns, rows = int(columns), int(rows)
        width = min(columns - 2, max(64, min(108, columns // 2)))
        height = min(rows - 2, max(12, min(56, rows // 2)))
        helper = Path.home() / "deploy/configs/tmux/script/new_float_pane.sh"
        config = Path(__file__).resolve().with_name("viewer.lua")
        viewer = run(str(helper), owner, "-d", "-x", str(width), "-y", str(height),
                     "-X", str(columns - width - 1), "-Y", "0", "-c", str(report.parent),
                     "env", "RESEARCH_LEADER_VIEWER=" + str(config),
                     "nvim", "-c", "lua dofile(vim.env.RESEARCH_LEADER_VIEWER)")
        run("tmux", "set-option", "-p", "-t", viewer, "@research_leader_owner", owner)

    for _ in range(200):
        socket = run("tmux", "show-options", "-pqv", "-t", viewer, "@research_leader_socket")
        if socket:
            break
        time.sleep(0.1)
    else:
        raise SystemExit("Research viewer did not become ready; inspect " + viewer)

    refresh_viewer(socket, report, base)
    if args.checkpoint:
        print("Research baseline {}: {}".format(base, report))
        return
    run("tmux", "set-option", "-p", "-t", owner, "@research_leader_report", str(report))
    run("tmux", "set-option", "-p", "-t", owner, "@research_leader_mode", "1")
    print("Research viewer {}: {}".format(viewer, report))


if __name__ == "__main__":
    main()
