#!/usr/bin/env python3
import argparse
import os
import re
import subprocess
import unicodedata
from pathlib import Path
from typing import Dict, List, Set, Tuple


FIELD_SEP = "\t"
# Everything after a line that is exactly this is free-form note text, kept
# verbatim -- including lines that start with '#', which are comments anywhere
# above it. The note travels with the sequence: it lives in NOTE_OPTION while
# the sequence is active, and sequence.sh folds it into the saved snapshot.
NOTE_SEPARATOR = "---"
NOTE_OPTION = "@auto_switch_ranked_panes_note"
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


def tmux_output(*args: str) -> str:
    return subprocess.check_output(["tmux", *args], universal_newlines=True)


def tmux_run(*args: str) -> None:
    subprocess.run(["tmux", *args], check=True)


def read_note() -> str:
    result = subprocess.run(
        ["tmux", "show-option", "-gqv", NOTE_OPTION],
        stdout=subprocess.PIPE,
        universal_newlines=True,
    )
    return result.stdout.strip("\n")


def write_note(note: str) -> None:
    note = note.strip("\n")
    if note:
        tmux_run("set-option", "-gq", NOTE_OPTION, note)
    else:
        subprocess.run(["tmux", "set-option", "-guq", NOTE_OPTION])


def encode_note(note: str) -> str:
    # The saved-snapshot option is one snapshot per line, so a note has to
    # survive as a single field: escape first, then the newlines it contains.
    return note.strip("\n").replace("\\", "\\\\").replace("\t", "\\t").replace("\n", "\\n")


def decode_note(encoded: str) -> str:
    out = []
    index = 0
    while index < len(encoded):
        char = encoded[index]
        if char != "\\" or index + 1 >= len(encoded):
            out.append(char)
            index += 1
            continue
        nxt = encoded[index + 1]
        out.append({"n": "\n", "t": "\t", "\\": "\\"}.get(nxt, "\\" + nxt))
        index += 2
    return "".join(out)


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


def load_panes() -> Dict[str, Dict[str, str]]:
    rows: Dict[str, Dict[str, str]] = {}
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


def load_session_names(pane_ids: List[str]) -> Dict[str, str]:
    if not pane_ids:
        return {}

    helper = Path(__file__).resolve().parent.parent / "ai/session_names.sh"
    output = subprocess.check_output(
        [os.fspath(helper)] + pane_ids,
        universal_newlines=True,
    )
    names: Dict[str, str] = {}
    for line in output.splitlines():
        pane_id, name = line.split(FIELD_SEP, 1)
        names[pane_id] = name
    return names


def resolve_pane(target: str, panes: Dict[str, Dict[str, str]]) -> str:
    if target in panes:
        return target
    try:
        pane_id = tmux_output("display-message", "-p", "-t", target, "#{pane_id}").strip()
    except subprocess.CalledProcessError:
        return ""
    return pane_id


def normalize_sequence(ranked: str) -> str:
    panes = load_panes()
    seen: Set[str] = set()
    out: List[str] = []
    for candidate in ranked.split():
        resolved = resolve_pane(candidate, panes)
        if not resolved or resolved in seen:
            continue
        seen.add(resolved)
        out.append(resolved)
    return " ".join(out)


def edit_row(row: Dict[str, str], session_name: str) -> Dict[str, str]:
    window_name = row["window_name"]
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
        "session_name": session_name or "unnamed",
    }


def write_edit_file(ranked: str, output_path: str, note: str) -> None:
    panes = load_panes()
    session_names = load_session_names(ranked.split())
    rows: List[Dict[str, str]] = []
    for pane in ranked.split():
        if pane not in panes:
            raise SystemExit(f"pane missing from current pane list: {pane}")
        rows.append(edit_row(panes[pane], session_names.get(pane, "")))

    pane_width = max((display_width(row["pane_id"]) for row in rows), default=0)
    target_width = max((display_width(row["target"]) for row in rows), default=0)
    state_width = max((display_width(row["state"]) for row in rows), default=0)
    path_width = max((display_width(row["path"]) for row in rows), default=0)
    attribute_width = max((display_width(row["attribute"]) for row in rows), default=0)
    session_name_width = max((display_width(row["session_name"]) for row in rows), default=0)

    with open(output_path, "w", encoding="utf-8") as file:
        for row in rows:
            file.write(
                f"{pad_display(row['pane_id'], pane_width)} # "
                f"{pad_display(row['target'], target_width)} | "
                f"{pad_display(row['state'], state_width)} | "
                f"{pad_display(row['path'], path_width)} | "
                f"{pad_display(row['attribute'], attribute_width)} | "
                f"{pad_display(row['session_name'], session_name_width)} | "
                f"{row['pending']}\n"
            )
        # Notes come last so the first pane sits on line 1 and NG jumps straight
        # to the Nth pane. parse_edit_file skips comment lines wherever they
        # appear, so this is purely about where the cursor arithmetic starts.
        file.write("\n")
        file.write('# Edit auto-switch order. Keep one pane id before "#"; edit Attribute and Pending columns.\n')
        file.write("# Reorder lines to change priority. Delete a line to remove that pane from the sequence.\n")
        file.write("# Add any AI or ordinary pane with prefix + M-a, or insert its pane id (e.g. %12) on a new line.\n")
        file.write("# A pane-id-only line preserves its existing Attribute and Pending values.\n")
        file.write("# Vim shortcut: normal-mode q saves and exits.\n")
        file.write("# Vim shortcut: normal-mode Enter saves, exits, and switches to the pane on the current line.\n")
        file.write("# Vim shortcut: normal-mode Tab / Shift-Tab jump to the next / previous non-pending pane line.\n")
        file.write('# Attribute column updates @ai_agent_attribute; write "no attribute" to clear.\n')
        file.write("# Session column is the live Codex/Claude display name and is informational only.\n")
        file.write('# Pending column updates @ai_agent_pending; empty clears it, "/" means no reason was provided.\n')
        file.write("# Earlier columns are informational only. Long lines intentionally do not wrap in vim.\n")
        file.write(f'# Everything below the "{NOTE_SEPARATOR}" line is a free-form note saved with this sequence.\n')
        file.write(f"{NOTE_SEPARATOR}\n")
        if note:
            file.write(note.strip("\n") + "\n")


def parse_edit_comment(comment: str, line_no: int) -> Tuple[str, str]:
    parts = comment.rsplit("|", 3)
    if len(parts) != 4:
        raise SystemExit(f"line {line_no} missing Pending, Session, or Attribute column after #: {comment}")
    _, attribute, _session_name, pending = parts
    return pending.strip(), attribute.strip()


def parse_edit_file(
    path: str, panes: Dict[str, Dict[str, str]]
) -> Tuple[List[str], Dict[str, str], Dict[str, str], str]:
    ranked: List[str] = []
    pending_reasons: Dict[str, str] = {}
    attributes: Dict[str, str] = {}
    note_lines: List[str] = []
    seen: Set[str] = set()
    in_note = False
    with open(path, encoding="utf-8") as file:
        for line_no, line in enumerate(file, start=1):
            line = line.rstrip("\n")
            if in_note:
                note_lines.append(line)
                continue
            if line.strip() == NOTE_SEPARATOR:
                in_note = True
                continue
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
            if resolved in seen:
                raise SystemExit(f"line {line_no} duplicate pane: {resolved}")
            if resolved not in panes:
                raise SystemExit(f"line {line_no} pane missing from current pane list: {resolved}")

            seen.add(resolved)
            ranked.append(resolved)
            if hash_found:
                pending, attribute = parse_edit_comment(after_hash, line_no)
            else:
                pending = panes[resolved]["pending"]
                attribute = panes[resolved]["attribute"]
            pending_reasons[resolved] = pending_reason(pending)
            attributes[resolved] = attribute

    return ranked, pending_reasons, attributes, "\n".join(note_lines).strip("\n")


def apply_edit_file(path: str) -> str:
    panes = load_panes()
    ranked, pending_reasons, attributes, note = parse_edit_file(path, panes)
    write_note(note)
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
    subparsers = parser.add_subparsers(dest="command")
    # `required=` kwarg for add_subparsers only exists on Python 3.7+; set the
    # attribute directly so this keeps working on the host's Python 3.6.
    subparsers.required = True

    normalize_parser = subparsers.add_parser("normalize")
    normalize_parser.add_argument("ranked")

    write_parser = subparsers.add_parser("write")
    write_parser.add_argument("ranked")
    write_parser.add_argument("output")
    # Previewing a saved snapshot has to show that snapshot's note, not the
    # note of the sequence that happens to be active.
    write_parser.add_argument("--note", default=None)

    apply_parser = subparsers.add_parser("apply")
    apply_parser.add_argument("path")

    encode_parser = subparsers.add_parser("encode-note")
    encode_parser.add_argument("note")

    decode_parser = subparsers.add_parser("decode-note")
    decode_parser.add_argument("encoded")

    args = parser.parse_args()
    if args.command == "normalize":
        print(normalize_sequence(args.ranked), end="")
    elif args.command == "write":
        note = read_note() if args.note is None else args.note
        write_edit_file(args.ranked, args.output, note)
    elif args.command == "apply":
        print(apply_edit_file(args.path), end="")
    elif args.command == "encode-note":
        print(encode_note(args.note), end="")
    elif args.command == "decode-note":
        print(decode_note(args.encoded), end="")
    else:
        raise SystemExit(f"unknown command: {args.command}")


if __name__ == "__main__":
    main()
