#!/usr/bin/env python3
"""Open or refresh one top-right research status viewer per leader pane."""

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import time


def run(*args):
    return subprocess.check_output(args, universal_newlines=True).strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", type=Path)
    parser.add_argument("owner", nargs="?", default=os.environ.get("TMUX_PANE"))
    parser.add_argument("--close", action="store_true", help="close this leader's viewer and exit the mode")
    args = parser.parse_args()
    if not args.owner:
        parser.error("run inside tmux or supply an owner pane")
    for command in ("tmux", "nvim"):
        if not shutil.which(command):
            parser.error("required command not found: " + command)
    owner, columns, rows = run(
        "tmux", "display-message", "-p", "-t", args.owner,
        "#{pane_id} #{window_width} #{window_height}",
    ).split()
    viewer = None
    for line in run("tmux", "list-panes", "-t", owner,
                    "-F", "#{pane_id} #{@research_leader_owner}").splitlines():
        fields = line.split()
        if len(fields) == 2 and fields[1] == owner:
            viewer = fields[0]
            break

    if args.close:
        if viewer:
            run("tmux", "kill-pane", "-t", viewer)
        run("tmux", "set-option", "-p", "-t", owner, "@research_leader_mode", "0")
        print("Research leader mode closed for " + owner)
        return

    report = args.report.resolve(strict=True)
    if not report.is_file() or report.suffix != ".md":
        parser.error("report must be a Markdown file")
    if viewer is None:
        columns, rows = int(columns), int(rows)
        width = min(columns - 2, max(64, min(108, columns // 2)))
        height = min(rows - 2, max(12, min(56, rows // 2)))
        helper = Path.home() / "deploy/configs/tmux/script/new_float_pane.sh"
        config = Path(__file__).resolve().with_name("viewer.lua")
        viewer = run(str(helper), owner, "-d", "-x", str(width), "-y", str(height),
                     "-X", str(columns - width - 1), "-Y", "0", "-c", str(report.parent),
                     "nvim", "-u", str(config), "-i", "NONE")
        run("tmux", "set-option", "-p", "-t", viewer, "@research_leader_owner", owner)

    for _ in range(50):
        socket = run("tmux", "show-options", "-pqv", "-t", viewer, "@research_leader_socket")
        if socket:
            break
        time.sleep(0.1)
    else:
        raise SystemExit("Research viewer did not become ready; inspect " + viewer)

    payload = json.dumps({"report": str(report)}, ensure_ascii=False)
    expression = "luaeval('research_leader_open(_A)', '" + payload.replace("'", "''") + "')"
    run("nvim", "--server", socket, "--remote-expr", expression)
    run("tmux", "set-option", "-p", "-t", owner, "@research_leader_report", str(report))
    run("tmux", "set-option", "-p", "-t", owner, "@research_leader_mode", "1")
    print("Research viewer {}: {}".format(viewer, report))


if __name__ == "__main__":
    main()
