#!/usr/bin/env python3

import re
import subprocess
import sys
from typing import List, Match, Tuple


PANE_FORMAT = "#{pane_index}\t#{pane_id}\t#{pane_left}"
LEAF_PATTERN = re.compile(r"(\d+x\d+,\d+,\d+,)(\d+)")


class LayoutError(RuntimeError):
    pass


def tmux_output(*args: str) -> str:
    result = subprocess.run(
        ["tmux", *args],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        universal_newlines=True,
    )
    if result.returncode != 0:
        detail = result.stderr.strip() or "tmux command failed"
        raise LayoutError(f"{' '.join(args)}: {detail}")
    return result.stdout.rstrip("\n")


def tmux_run(*args: str) -> None:
    tmux_output(*args)


def pane_rows(window_id: str) -> List[Tuple[int, str, int]]:
    rows = []
    for line in tmux_output("list-panes", "-t", window_id, "-F", PANE_FORMAT).splitlines():
        parts = line.split("\t")
        if len(parts) != 3 or not parts[1].startswith("%"):
            raise LayoutError(f"unexpected list-panes row: {line}")
        rows.append((int(parts[0]), parts[1][1:], int(parts[2])))
    if not rows:
        raise LayoutError(f"window has no panes: {window_id}")
    return rows


def layout_checksum(layout: str) -> int:
    checksum = 0
    for byte in layout.encode("ascii"):
        checksum = (checksum >> 1) + ((checksum & 1) << 15)
        checksum = (checksum + byte) & 0xFFFF
    return checksum


def move_max_index_to_main(layout: str, max_pane_id: str, main_pane_id: str) -> str:
    _, separator, body = layout.partition(",")
    if not separator:
        raise LayoutError(f"unexpected window layout: {layout}")

    replacements = 0

    def replace_leaf(match: Match[str]) -> str:
        nonlocal replacements
        pane_id = match.group(2)
        if pane_id == max_pane_id:
            pane_id = main_pane_id
            replacements += 1
        elif pane_id == main_pane_id:
            pane_id = max_pane_id
            replacements += 1
        return match.group(1) + pane_id

    body = LEAF_PATTERN.sub(replace_leaf, body)
    if replacements != 2:
        raise LayoutError(
            f"expected max and main pane ids once each in layout; replaced {replacements} leaves"
        )
    return f"{layout_checksum(body):04x},{body}"


def select_layout(target: str) -> None:
    window_id = tmux_output("display-message", "-p", "-t", target, "#{window_id}")
    tmux_run("select-layout", "-t", window_id, "main-vertical-mirrored")

    panes = pane_rows(window_id)
    max_pane_id = max(panes, key=lambda row: row[0])[1]
    main_pane_id = max(panes, key=lambda row: row[2])[1]
    if max_pane_id != main_pane_id:
        current_layout = tmux_output("display-message", "-p", "-t", window_id, "#{window_layout}")
        custom_layout = move_max_index_to_main(current_layout, max_pane_id, main_pane_id)
        tmux_run("select-layout", "-t", window_id, custom_layout)

    window_width = int(tmux_output("display-message", "-p", "-t", window_id, "#{window_width}"))
    side_width = min(80, window_width * 30 // 100)
    main_width = window_width - side_width - 1  # One column separates the two pane columns.
    tmux_run("resize-pane", "-t", f"%{max_pane_id}", "-x", str(main_width))


def main() -> int:
    target = sys.argv[1] if len(sys.argv) > 1 else ""
    try:
        select_layout(target)
    except LayoutError as error:
        message = f"max-index main layout: {error}"
        subprocess.run(["tmux", "display-message", message], check=False)
        print(message, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
