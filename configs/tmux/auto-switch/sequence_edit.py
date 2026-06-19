#!/usr/bin/env python3
import argparse
import os
import re
import subprocess
import sys
import unicodedata
from pathlib import Path


FIELD_SEP = "\x1f"
PANE_FORMAT = FIELD_SEP.join(
    [
        "#{pane_id}",
        "#{window_id}",
        "#{session_name}",
        "#{window_name}",
        "#{pane_index}",
        "#{pane_current_path}",
        "#{@ai_agent_unread}",
        "#{@ai_agent_running}",
        "#{@ai_agent_background}",
        "#{@ai_agent_pending}",
        "#{@ai_agent_attribute}",
    ]
)
STATE_PREFIXES = ("● ", "⏵ ", "◒ ", "⏸ ", "◉ ", "○ ")


def tmux_output(*args: str) -> str:
    return subprocess.check_output(["tmux", *args], text=True)


def tmux_run(*args: str) -> None:
    subprocess.run(["tmux", *args], check=True)


def strip_tmux_format(text: str) -> str:
    text = re.sub(r"#\[[^\]]*\]", "", text)
    text = re.sub(r"\s+", " ", text)
    return text.strip()


def display_width(text: str) -> int:
    width = 0
    for char in text:
        if unicodedata.east_asian_width(char) in {"F", "W"}:
            width += 2
        else:
            width += 1
    return width


def pad_display(text: str, width: int) -> str:
    return text + " " * max(0, width - display_width(text))


def strip_state_prefix(name: str) -> str:
    while True:
        for prefix in STATE_PREFIXES:
            if name.startswith(prefix):
                name = name[len(prefix) :]
                break
        else:
            return name


def state_label(unread: str, running: str, background: str, pending: str) -> str:
    if pending:
        return "pending"
    if background == "1":
        return "background"
    if running == "1":
        return "running"
    if unread == "1":
        return "unread"
    return "idle"


def pending_reason(pending: str) -> str:
    if pending == "1":
        return "/"
    return pending


def load_panes() -> dict[str, dict[str, str]]:
    rows: dict[str, dict[str, str]] = {}
    output = tmux_output("list-panes", "-a", "-F", PANE_FORMAT)
    for line in output.splitlines():
        parts = line.split(FIELD_SEP, 10)
        if len(parts) != 11 or not parts[0]:
            continue
        (
            pane_id,
            window_id,
            session_name,
            window_name,
            pane_index,
            path,
            unread,
            running,
            background,
            pending,
            attribute,
        ) = parts
        rows[pane_id] = {
            "pane_id": pane_id,
            "window_id": window_id,
            "session_name": session_name,
            "window_name": window_name,
            "pane_index": pane_index,
            "path": path,
            "unread": unread,
            "running": running,
            "background": background,
            "pending": pending,
            "attribute": attribute,
        }
    return rows


def resolve_pane(target: str, panes: dict[str, dict[str, str]]) -> str:
    if target in panes:
        return target
    try:
        pane_id = tmux_output("display-message", "-p", "-t", target, "#{pane_id}").strip()
    except subprocess.CalledProcessError:
        return ""
    return pane_id


def normalize_sequence(ranked: str) -> str:
    panes = load_panes()
    seen: set[str] = set()
    out: list[str] = []
    for candidate in ranked.split():
        resolved = resolve_pane(candidate, panes)
        if not resolved or resolved in seen:
            continue
        seen.add(resolved)
        out.append(resolved)
    return " ".join(out)


def edit_row(row: dict[str, str]) -> dict[str, str]:
    window_name = strip_state_prefix(row["window_name"])
    target = f"{row['session_name']}:{window_name}.{row['pane_index']}"
    state = state_label(row["unread"], row["running"], row["background"], row["pending"])
    attribute = strip_tmux_format(row["attribute"]) or "no attribute"
    return {
        "pane_id": row["pane_id"],
        "target": target,
        "state": state,
        "path": row["path"],
        "pending": pending_reason(row["pending"]),
        "attribute": attribute,
    }


def write_edit_file(ranked: str, output_path: str) -> None:
    panes = load_panes()
    rows: list[dict[str, str]] = []
    for pane in ranked.split():
        if pane not in panes:
            raise SystemExit(f"pane missing from current pane list: {pane}")
        rows.append(edit_row(panes[pane]))

    target_width = max((display_width(row["target"]) for row in rows), default=0)
    state_width = max((display_width(row["state"]) for row in rows), default=0)
    path_width = max((display_width(row["path"]) for row in rows), default=0)
    attribute_width = max((display_width(row["attribute"]) for row in rows), default=0)

    with open(output_path, "w", encoding="utf-8") as file:
        file.write('# Edit auto-switch order. Keep one pane id before "#"; edit Attribute and Pending columns.\n')
        file.write("# Reorder lines to change priority. Delete a line to remove that pane from the sequence.\n")
        file.write("# Vim shortcut: normal-mode q saves and exits.\n")
        file.write("# Vim shortcut: normal-mode Enter saves, exits, and switches to the pane on the current line.\n")
        file.write('# Attribute column updates @ai_agent_attribute; write "no attribute" to clear.\n')
        file.write('# Pending column updates @ai_agent_pending; empty clears it, "/" means no reason was provided.\n')
        file.write("# Earlier columns are informational only. Long lines intentionally do not wrap in vim.\n\n")
        for row in rows:
            file.write(
                f"{row['pane_id']} # "
                f"{pad_display(row['target'], target_width)} | "
                f"{pad_display(row['state'], state_width)} | "
                f"{pad_display(row['path'], path_width)} | "
                f"{pad_display(row['attribute'], attribute_width)} | "
                f"{row['pending']}\n"
            )


def parse_edit_comment(comment: str, line_no: int) -> tuple[str, str]:
    parts = comment.rsplit("|", 2)
    if len(parts) != 3:
        raise SystemExit(f"line {line_no} missing Pending or Attribute column after #: {comment}")
    _, attribute, pending = parts
    return pending.strip(), attribute.strip()


def parse_edit_file(path: str, panes: dict[str, dict[str, str]]) -> tuple[list[str], dict[str, str], dict[str, str]]:
    ranked: list[str] = []
    pending_reasons: dict[str, str] = {}
    attributes: dict[str, str] = {}
    seen: set[str] = set()
    with open(path, encoding="utf-8") as file:
        for line_no, line in enumerate(file, start=1):
            line = line.rstrip("\n")
            before_hash, hash_found, after_hash = line.partition("#")
            before_hash = before_hash.strip()
            if not before_hash:
                continue

            tokens = before_hash.split()
            if len(tokens) != 1:
                raise SystemExit(f"line {line_no} has extra text before #: {line}")

            pane = tokens[0]
            resolved = resolve_pane(pane, panes)
            if not resolved:
                raise SystemExit(f"line {line_no} pane does not resolve: {pane}")
            if not hash_found:
                raise SystemExit(f"line {line_no} missing #: {line}")
            if resolved in seen:
                raise SystemExit(f"line {line_no} duplicate pane: {resolved}")
            if resolved not in panes:
                raise SystemExit(f"line {line_no} pane missing from current pane list: {resolved}")

            seen.add(resolved)
            ranked.append(resolved)
            pending, attribute = parse_edit_comment(after_hash, line_no)
            pending_reasons[resolved] = pending_reason(pending)
            attributes[resolved] = attribute

    if not ranked:
        raise SystemExit("edited sequence is empty")
    return ranked, pending_reasons, attributes


def tmux_option(pane: str, option: str) -> str:
    result = subprocess.run(
        ["tmux", "show-option", "-pv", "-t", pane, option],
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
    )
    if result.returncode != 0:
        return ""
    return result.stdout.rstrip("\n")


def sync_ai_window_name(pane: str) -> None:
    window_id = tmux_output("display-message", "-p", "-t", pane, "#{window_id}").strip()
    current_name = tmux_output("display-message", "-p", "-t", window_id, "#W").rstrip("\n")
    base_name = strip_state_prefix(current_name)

    pending = tmux_option(pane, "@ai_agent_pending")
    background = tmux_option(pane, "@ai_agent_background")
    running = tmux_option(pane, "@ai_agent_running")
    unread = tmux_option(pane, "@ai_agent_unread")

    if pending:
        prefix = "⏸"
    elif background == "1":
        prefix = "◒"
    elif running == "1":
        prefix = "●"
    elif unread == "1":
        prefix = "◉"
    else:
        prefix = "○"

    desired_name = f"{prefix} {base_name}"
    if current_name != desired_name:
        tmux_run("rename-window", "-t", window_id, desired_name)


def apply_edit_file(path: str) -> str:
    panes = load_panes()
    ranked, pending_reasons, attributes = parse_edit_file(path, panes)
    refresh_script = Path.home() / "deploy/configs/tmux/script/refresh_status_lines.sh"

    for pane in ranked:
        changed = False
        new_pending = pending_reasons[pane]
        old_pending = pending_reason(panes[pane]["pending"])
        if old_pending != new_pending:
            if new_pending:
                tmux_run("set-option", "-pq", "-t", pane, "@ai_agent_pending", new_pending)
                tmux_run("set-option", "-pq", "-t", pane, "@ai_agent_running", "0")
                tmux_run("set-option", "-pqu", "-t", pane, "@ai_agent_background")
                tmux_run("set-option", "-pq", "-t", pane, "@ai_agent_unread", "0")
            else:
                tmux_run("set-option", "-pqu", "-t", pane, "@ai_agent_pending")
            sync_ai_window_name(pane)
            changed = True

        new_attribute = attributes[pane]
        if new_attribute == "no attribute":
            new_attribute = ""

        old_attribute = panes[pane]["attribute"]
        if strip_tmux_format(old_attribute) != strip_tmux_format(new_attribute):
            if new_attribute:
                tmux_run("set-option", "-pq", "-t", pane, "@ai_agent_attribute", new_attribute)
            else:
                tmux_run("set-option", "-pqu", "-t", pane, "@ai_agent_attribute")
            changed = True

        if changed:
            subprocess.run([os.fspath(refresh_script), pane], check=True)

    return " ".join(ranked)


def main() -> None:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)

    normalize_parser = subparsers.add_parser("normalize")
    normalize_parser.add_argument("ranked")

    write_parser = subparsers.add_parser("write")
    write_parser.add_argument("ranked")
    write_parser.add_argument("output")

    apply_parser = subparsers.add_parser("apply")
    apply_parser.add_argument("path")

    args = parser.parse_args()
    if args.command == "normalize":
        print(normalize_sequence(args.ranked), end="")
    elif args.command == "write":
        write_edit_file(args.ranked, args.output)
    elif args.command == "apply":
        print(apply_edit_file(args.path), end="")
    else:
        raise SystemExit(f"unknown command: {args.command}")


if __name__ == "__main__":
    main()
