#!/usr/bin/env python3
"""Pin (or unpin) the user's own latest input at the top of the current tmux window.

Reads ~/.cache/tmux-ai-prompts.jsonl from newest to oldest, matching the pane's
current AI session ID (or pane ID) while filtering out TMA agent-to-agent
messages (sender="tma" or ⟦TMA⟧ signatures) and automated hook/watcher prompts.
Falls back to wrapper/history.sh when a resumed session predates the prompt log.

While pinned, the unfocused top float watches the prompt log and updates in
place whenever the user submits a new prompt, ignoring incoming TMA messages.
"""

import argparse
import json
import os
from pathlib import Path
import re
import select
import subprocess
import sys
import termios
import tty
import unicodedata


SCRIPT_DIR = Path(__file__).resolve().parent
TMUX_DIR = SCRIPT_DIR.parent
DEFAULT_LOG = Path.home() / ".cache/tmux-ai-prompts.jsonl"

AUTO_PREFIXES = (
    "<task-notification>",
    "<local-command",
    "<system-reminder>",
    "请关注这个 TMA：",
    "继续watch-target",
    "继续 watch-target",
    "watch-target",
    "watch target",
    "Reply with exactly",
)
SKILL_BLOCK_RE = re.compile(
    r"<skill\s+name=\"([^\"]+)\"[^>]*>.*?</skill>\s*",
    re.DOTALL,
)
HISTORY_HEADER_RE = re.compile(r"^## (user|assistant|context compacted)(?: \(([^)]*)\))?\s*$")

AMBER_BOLD = "\033[38;5;214;1m"
DIM = "\033[2m"
RESET = "\033[0m"


def tmux_cmd(socket):
    return ["tmux", "-S", socket] if socket else ["tmux"]


def run_tmux(socket, *args, check=True):
    return subprocess.run(
        tmux_cmd(socket) + list(args),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        universal_newlines=True,
        check=check,
    )


def cells(text):
    total = 0
    for ch in text:
        if unicodedata.combining(ch):
            continue
        total += 2 if unicodedata.east_asian_width(ch) in "WF" else 1
    return total


def normalize_prompt(raw):
    text = SkillStripper.clean(raw).strip()
    if text.startswith("[Quoted message from") and "\n\n\n" in text:
        text = text.split("\n\n\n", 1)[1].strip()
    return text


class SkillStripper:
    @staticmethod
    def clean(raw):
        def repl(match):
            return "/skill:" + match.group(1) + "\n"
        return SKILL_BLOCK_RE.sub(repl, raw or "")


def is_genuine_user_text(text):
    stripped = text.strip()
    if not stripped:
        return False
    non_empty = [line.strip() for line in stripped.splitlines() if line.strip()]
    if not non_empty:
        return False
    if any(line.startswith("⟦TMA⟧") for line in (non_empty[0], non_empty[-1])) or any(
        line.startswith("⟦TMA⟧") for line in non_empty
    ):
        return False
    if stripped.startswith(AUTO_PREFIXES):
        return False
    if stripped.startswith("/goal") and "你是 developer" in stripped:
        return False
    return True


def iter_jsonl_reverse(path):
    with open(str(path), "rb") as handle:
        handle.seek(0, os.SEEK_END)
        pos = handle.tell()
        carry = b""
        chunk_size = 65536
        while pos > 0:
            read_size = min(chunk_size, pos)
            pos -= read_size
            handle.seek(pos)
            data = handle.read(read_size) + carry
            lines = data.split(b"\n")
            if pos > 0:
                carry = lines[0]
                lines = lines[1:]
            else:
                carry = b""
            for raw in reversed(lines):
                raw = raw.strip()
                if not raw:
                    continue
                try:
                    yield json.loads(raw.decode("utf-8", errors="replace"))
                except ValueError:
                    continue


def resolve_ai_target_and_session(socket, pane):
    env = dict(os.environ)
    if socket:
        env["TMUX"] = socket + ",0,0"
    code = (
        'source "$1"; '
        'pane="$2"; '
        'win="$(tmux display-message -p -t "$pane" "#{window_id}")" || exit 1; '
        'if ! _has_ai_proc "$(tmux display-message -p -t "$pane" "#{pane_pid}")"; then '
        '  alt="$(_find_ai_pane_in_window "$win" 2>/dev/null || true)"; '
        '  [ -z "$alt" ] || pane="$alt"; '
        'fi; '
        'sid="$(_ai_session_id_for_pane "$pane" 2>/dev/null || true)"; '
        'printf "%s\\t%s\\n" "$pane" "$sid"'
    )
    res = subprocess.run(
        ["bash", "-c", code, "pin", str(TMUX_DIR / "ai/lib.sh"), pane],
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        universal_newlines=True,
    )
    if res.returncode == 0 and "\t" in res.stdout:
        target, sid = res.stdout.rstrip("\n").split("\t", 1)
        return target or pane, sid.strip()
    return pane, ""


def format_stamp(ts):
    if not ts:
        return ""
    # "2026-11-15T22:15:39-0600" or "2026-11-15T22:15:39Z" -> "22:15"
    if len(ts) >= 16 and ts[10] == "T":
        return ts[11:16]
    return ts[:16]


def fallback_from_history(socket, pane):
    env = dict(os.environ)
    if socket:
        env["TMUX"] = socket + ",0,0"
    res = subprocess.run(
        ["bash", str(TMUX_DIR / "wrapper/history.sh"), pane],
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        universal_newlines=True,
    )
    if res.returncode != 0 or not res.stdout:
        return None
    blocks = []
    role = None
    ts = ""
    buf = []
    for line in res.stdout.splitlines():
        m = HISTORY_HEADER_RE.match(line)
        if m:
            if role == "user":
                blocks.append((ts, "\n".join(buf)))
            role, ts, buf = m.group(1), m.group(2) or "", []
        elif role is not None:
            buf.append(line)
    if role == "user":
        blocks.append((ts, "\n".join(buf)))
    for block_ts, raw in reversed(blocks):
        cleaned = normalize_prompt(raw)
        if is_genuine_user_text(cleaned):
            return {"time": format_stamp(block_ts), "prompt": cleaned}
    return None


def latest_user_input(socket, pane, log_path):
    target_pane, ai_session_id = resolve_ai_target_and_session(socket, pane)
    if log_path.is_file():
        for row in iter_jsonl_reverse(log_path):
            if row.get("sender", "user") != "user":
                continue
            row_sid = row.get("ai_session_id", "")
            row_pane = row.get("pane", "")
            if ai_session_id:
                matched = (row_sid == ai_session_id) or (not row_sid and row_pane == target_pane)
            else:
                matched = row_pane in (target_pane, pane)
            if not matched:
                continue
            cleaned = normalize_prompt(row.get("prompt", ""))
            if is_genuine_user_text(cleaned):
                return {
                    "pane": target_pane,
                    "time": format_stamp(row.get("time", "")),
                    "prompt": cleaned,
                }
    hist = fallback_from_history(socket, target_pane)
    if hist:
        hist["pane"] = target_pane
        return hist
    return None


def wrap_paragraph(text, width, first_prefix="", rest_indent=""):
    tokens = re.findall(r"\s+|[⺀-鿿＀-￯]|[^\s⺀-鿿＀-￯]+", text)
    lines = []
    prefix = first_prefix
    used = cells(re.sub(r"\033\[[0-9;]*m", "", prefix))
    prefix_w = used
    line = prefix
    has_word = False

    for tok in tokens:
        if tok.isspace():
            if has_word and used + 1 <= width:
                line += " "
                used += 1
            continue
        tok_w = cells(tok)
        if has_word and used + tok_w > width and used > prefix_w:
            lines.append(line.rstrip())
            line = rest_indent
            used = cells(rest_indent)
            prefix_w = used
            has_word = False
        while cells(tok) > width - used and width > used:
            take, w = 0, 0
            for ch in tok:
                cw = cells(ch)
                if w + cw > width - used and take > 0:
                    break
                take += 1
                w += cw
            part, tok = tok[:take], tok[take:]
            line += part
            lines.append(line.rstrip())
            line = rest_indent
            used = cells(rest_indent)
            prefix_w = used
            has_word = False
        line += tok
        used += cells(tok)
        has_word = True

    if has_word or not lines:
        lines.append(line.rstrip())
    return lines


def render_lines(entry, wrap_w):
    stamp = entry.get("time", "")
    badge_plain = "📌 " + (stamp + "  " if stamp else "")
    badge_ansi = AMBER_BOLD + badge_plain + RESET
    indent = " " * cells(badge_plain)
    paragraphs = entry["prompt"].splitlines() or [""]
    out = []
    for idx, para in enumerate(paragraphs):
        if not para.strip():
            if out and out[-1] != "":
                out.append("")
            continue
        if idx == 0 or not out:
            out.extend(wrap_paragraph(para.strip(), wrap_w, badge_ansi, indent))
        else:
            out.extend(wrap_paragraph(para.strip(), wrap_w, indent, indent))
    return out or [badge_ansi]


def scrollbar_extra(socket, window_id):
    sb = run_tmux(socket, "show-options", "-wv", "-t", window_id, "pane-scrollbars", check=False).stdout.strip()
    if not sb:
        sb = run_tmux(socket, "show-options", "-gv", "pane-scrollbars", check=False).stdout.strip()
    if sb != "on":
        return 0
    style = run_tmux(socket, "show-options", "-wv", "-t", window_id, "pane-scrollbars-style", check=False).stdout.strip()
    if not style:
        style = run_tmux(socket, "show-options", "-gv", "pane-scrollbars-style", check=False).stdout.strip()
    w_match = re.search(r"width=(\d+)", style)
    p_match = re.search(r"pad=(\d+)", style)
    return (int(w_match.group(1)) if w_match else 1) + (int(p_match.group(1)) if p_match else 0)


def compute_box(win_w, win_h, sb_extra, entry):
    outer_w = max(24, win_w - 4) if win_w >= 28 else max(12, win_w - 2)
    wrap_w = max(10, outer_w - 3 - sb_extra)
    lines = render_lines(entry, wrap_w)
    max_inner_h = max(4, win_h * 30 // 100)
    if len(lines) > max_inner_h:
        # Reserve 1 top indicator row when scrollable so no content line ever overflows wrap_w.
        inner_h = max_inner_h
    else:
        inner_h = len(lines)
    outer_h = min(win_h, inner_h + 2)
    pos_x = max(0, (win_w - outer_w) // 2)
    pos_y = 0
    return outer_w, outer_h, pos_x, pos_y, lines, outer_h - 2


def existing_pin_in_window(socket, window_id):
    out = run_tmux(
        socket, "list-panes", "-t", window_id,
        "-F", "#{pane_id}\t#{pane_active}\t#{@pinned_last_input}\t#{@pinned_input_owner}",
        check=False,
    ).stdout
    for row in out.splitlines():
        parts = row.split("\t")
        if len(parts) >= 4 and parts[2] == "1":
            return parts[0], parts[1] == "1", parts[3]
    return None, False, ""


def fail(socket, tmux_menu, message):
    run_tmux(socket, "display-message", "-d", "5000", message, check=False)
    if tmux_menu:
        sys.exit(0)
    print(message, file=sys.stderr)
    sys.exit(1)


def cmd_toggle(args):
    info = run_tmux(
        args.socket, "display-message", "-p", "-t", args.pane,
        "#{pane_id}\t#{window_id}\t#{window_width}\t#{window_height}",
        check=False,
    )
    if info.returncode != 0 or not info.stdout.strip():
        fail(args.socket, args.tmux_menu, "pin: 找不到当前 pane")
    pane_id, window_id, win_w_s, win_h_s = info.stdout.strip().split("\t")
    win_w, win_h = int(win_w_s), int(win_h_s)

    pin_pane, pin_active, owner = existing_pin_in_window(args.socket, window_id)
    if pin_pane:
        if pin_active and owner:
            run_tmux(args.socket, "select-pane", "-t", owner, check=False)
        run_tmux(args.socket, "kill-pane", "-t", pin_pane, check=False)
        return 0

    entry = latest_user_input(args.socket, pane_id, args.log)
    if not entry:
        fail(args.socket, args.tmux_menu, "这个窗口还没有你的输入记录（已过滤 TMA 消息）")

    owner_pane = entry["pane"]
    sb_extra = scrollbar_extra(args.socket, window_id)
    outer_w, outer_h, pos_x, pos_y, _, _ = compute_box(win_w, win_h, sb_extra, entry)

    hold_cmd = [
        sys.executable, str(Path(__file__).resolve()), "hold",
        "--log", str(args.log),
    ]
    if args.socket:
        hold_cmd += ["--socket", args.socket]
    hold_cmd.append(owner_pane)

    env = dict(os.environ)
    if args.socket:
        env["TMUX"] = args.socket + ",0,0"
    fp = subprocess.check_output(
        [
            str(SCRIPT_DIR / "new_float_pane.sh"), owner_pane, "-d",
            "-x", str(outer_w), "-y", str(outer_h),
            "-X", str(pos_x), "-Y", str(pos_y),
            *hold_cmd,
        ],
        env=env,
        universal_newlines=True,
    ).strip()
    run_tmux(
        args.socket,
        "set-option", "-pq", "-t", fp, "@pinned_last_input", "1",
        ";", "set-option", "-pq", "-t", fp, "@pinned_input_owner", owner_pane,
        ";", "set-option", "-pq", "-t", fp, "@jump-history-skip", "1",
        ";", "set-option", "-pq", "-t", fp, "pane-border-style", "fg=colour214",
    )
    return 0


def draw_frame(lines, inner_h, scroll, stamp=""):
    if len(lines) <= inner_h:
        sys.stdout.write("\033[?25l\033[2J\033[H" + "\r\n".join(lines))
        sys.stdout.flush()
        return 0
    body_h = max(1, inner_h - 1)
    max_scroll = max(0, len(lines) - body_h)
    scroll = max(0, min(scroll, max_scroll))
    visible = list(lines[scroll : scroll + body_h])
    header = (
        AMBER_BOLD + "📌 " + (stamp + "  " if stamp else "") + RESET
        + DIM + "[{}-{}/{} · j/k 滚动 · q 关闭]".format(
            scroll + 1, scroll + len(visible), len(lines)
        ) + RESET
    )
    sys.stdout.write("\033[?25l\033[2J\033[H" + "\r\n".join([header] + visible))
    sys.stdout.flush()
    return scroll


def cmd_hold(args):
    self_pane = os.environ.get("TMUX_PANE", "")
    owner = args.pane

    def query_geom():
        res = run_tmux(
            args.socket, "display-message", "-p", "-t", owner,
            "#{pane_id}\t#{window_id}\t#{window_width}\t#{window_height}",
            check=False,
        )
        if res.returncode != 0 or not res.stdout.strip():
            return None
        _, wid, ww, wh = res.stdout.strip().split("\t")
        return wid, int(ww), int(wh)

    geom = query_geom()
    if geom is None:
        return 0
    window_id, win_w, win_h = geom
    sb_extra = scrollbar_extra(args.socket, window_id)
    entry = latest_user_input(args.socket, owner, args.log) or {"time": "", "prompt": ""}
    outer_w, outer_h, pos_x, pos_y, lines, inner_h = compute_box(win_w, win_h, sb_extra, entry)
    last_mtime = args.log.stat().st_mtime if args.log.is_file() else None
    last_geom = (win_w, win_h)
    scroll = 0

    fd = sys.stdin.fileno()
    old_tty = termios.tcgetattr(fd) if os.isatty(fd) else None
    try:
        if old_tty is not None:
            tty.setraw(fd)
        sys.stdout.write("\033[?1049h\033[?25l")
        sys.stdout.flush()
        scroll = draw_frame(lines, inner_h, scroll, entry.get("time", ""))
        while True:
            ready, _, _ = select.select([fd], [], [], 1.0)
            if ready:
                data = os.read(fd, 32)
                if not data or data in (b"q", b"\x1b", b"\r", b"\n", b"\x03", b"\x1b[27u"):
                    run_tmux(args.socket, "select-pane", "-t", owner, check=False)
                    return 0
                if data in (b"j", b"\x1b[B"):
                    scroll = draw_frame(lines, inner_h, scroll + 1, entry.get("time", ""))
                elif data in (b"k", b"\x1b[A"):
                    scroll = draw_frame(lines, inner_h, scroll - 1, entry.get("time", ""))
                continue

            geom = query_geom()
            if geom is None:
                return 0
            window_id, win_w, win_h = geom
            cur_mtime = args.log.stat().st_mtime if args.log.is_file() else None
            if cur_mtime != last_mtime or (win_w, win_h) != last_geom:
                last_mtime = cur_mtime
                last_geom = (win_w, win_h)
                updated = latest_user_input(args.socket, owner, args.log)
                if updated:
                    changed_text = updated["prompt"] != entry["prompt"] or updated["time"] != entry["time"]
                    entry = updated
                    new_w, new_h, pos_x, pos_y, lines, inner_h = compute_box(win_w, win_h, sb_extra, entry)
                    if (new_w, new_h) != (outer_w, outer_h) and self_pane:
                        outer_w, outer_h = new_w, new_h
                        run_tmux(
                            args.socket,
                            "resize-pane", "-t", self_pane, "-x", str(outer_w), "-y", str(outer_h),
                            ";", "move-pane", "-t", self_pane, "-X", str(pos_x), "-Y", str(pos_y),
                            check=False,
                        )
                    if changed_text:
                        scroll = 0
                    scroll = draw_frame(lines, inner_h, scroll, entry.get("time", ""))
    finally:
        sys.stdout.write("\033[?25h\033[?1049l")
        sys.stdout.flush()
        if old_tty is not None:
            termios.tcsetattr(fd, termios.TCSADRAIN, old_tty)


def cmd_query(args):
    entry = latest_user_input(args.socket, args.pane, args.log)
    if not entry:
        return 1
    print(json.dumps(entry, ensure_ascii=False))
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="subcmd")
    for name in ("toggle", "hold", "query"):
        p = sub.add_parser(name)
        p.add_argument("--socket", default="")
        p.add_argument("--log", type=Path, default=Path(os.environ.get("AI_AGENT_PROMPT_LOG", str(DEFAULT_LOG))))
        if name == "toggle":
            p.add_argument("--tmux-menu", action="store_true")
        p.add_argument("pane")
    args = parser.parse_args()
    if args.subcmd == "toggle":
        return cmd_toggle(args)
    if args.subcmd == "hold":
        return cmd_hold(args)
    if args.subcmd == "query":
        return cmd_query(args)
    parser.error("subcommand required")


if __name__ == "__main__":
    sys.exit(main())
