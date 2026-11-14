#!/usr/bin/env python3
"""Position the current floating pane without replacing its process."""

import argparse
import curses
import json
import os
from pathlib import Path
import subprocess
import sys


AXES_OPTION = "@float_position_axes"


def find_pane(cell, pane_id):
    """Read the full layout cell, including scrollbar space."""
    if cell.get("I") == pane_id:
        return cell
    for child in cell.get("c", []):
        found = find_pane(child, pane_id)
        if found is not None:
            return found
    return None


def geometry(window, rect, axes, action):
    """Return content geometry, leaving room for the float's outer border."""
    win_w, win_h = window
    x, y, width, height = rect
    horizontal, vertical = axes
    if win_w < 3 or win_h < 3:
        raise ValueError("窗口太小，放不下浮窗和边框")

    if action in "hjkl":
        if action in "hl":
            if horizontal == action:
                vertical = "-"
            horizontal = action
        else:
            if vertical == action:
                horizontal = "-"
            vertical = action
        left = win_w // 2 if horizontal == "l" else 0
        right = win_w // 2 if horizontal == "h" else win_w
        top = win_h // 2 if vertical == "j" else 0
        bottom = win_h // 2 if vertical == "k" else win_h
        if right - left < 3 or bottom - top < 3:
            raise ValueError("窗口太小，无法停靠到这个区域")
        return (left + 1, top + 1, right - left - 2, bottom - top - 2), (horizontal, vertical)

    width, height = min(width, win_w - 2), min(height, win_h - 2)
    if action == "c":
        x, y = (win_w - width) // 2, (win_h - height) // 2
    else:  # C: move only as far as needed; shrink only an oversized pane.
        x = max(1, min(x, win_w - width - 1))
        y = max(1, min(y, win_h - height - 1))
    return (x, y, width, height), ("-", "-")


def apply_action(tmux, pane, action):
    if action == "begin":
        commands = tmux("list-commands")
        move = next(line for line in commands.splitlines() if line.startswith("move-pane "))
        if "[-X x-position]" not in move:
            raise ValueError("浮窗定位需要 tmux 3.8 或更新版本的 server")

    # A zoomed floating pane reports pane_floating_flag=0 until unzoomed.
    if tmux("display-message", "-p", "-t", pane, "#{window_zoomed_flag}") == "1":
        tmux("resize-pane", "-Z", "-t", pane)
    fields = tmux("display-message", "-p", "-t", pane,
                  "#{pane_floating_flag} #{window_width} #{window_height} "
                  "#{pane_id} #{window_layout}").split(maxsplit=4)
    floating, win_w, win_h, pane_id, layout = fields
    if floating != "1":
        raise ValueError("请先选中要调整的浮窗")
    # The layout includes scrollbar space; pane_width does not. Using the
    # latter would shrink a float on every center/clip with scrollbars on.
    cell = find_pane(json.loads(layout)["L"], pane_id)
    if cell is None:
        raise ValueError("无法从 tmux 布局读取浮窗的完整尺寸")
    width, height, x, y = (cell[key] for key in ("w", "h", "x", "y"))

    if action == "begin":
        tmux("set-option", "-pq", "-t", pane, AXES_OPTION, "- -")
    else:
        axes = (tmux("show-option", "-pqv", "-t", pane, AXES_OPTION) or "- -").split()
        rect, axes = geometry((int(win_w), int(win_h)), (x, y, width, height), axes, action)
        x, y, width, height = rect
        # tmux 3.8 takes the outer rectangle (including the border).
        tmux("resize-pane", "-t", pane, "-x", str(width + 2), "-y", str(height + 2),
             ";", "move-pane", "-t", pane, "-X", str(x - 1), "-Y", str(y - 1))
        tmux("set-option", "-pq", "-t", pane, AXES_OPTION, " ".join(axes))


def position_menu(screen, tmux, pane):
    """Keep one popup open so rapid keystrokes are read in order."""
    curses.curs_set(0)
    curses.raw()
    lines = [
        "h  左半屏       l  右半屏",
        "k  上半屏       j  下半屏",
        "",
        "c  居中         C  收回窗口",
        "",
        "连续方向键可组合为角落",
        "角落重复方向键回到半屏",
        "",
        "Esc / Enter / q  完成",
    ]
    screen.erase()
    for row, line in enumerate(lines):
        screen.addstr(row, 1, line)
    screen.refresh()
    while True:
        key = screen.get_wch()
        if key in ("\x1b", "\n", "\r", "q"):
            return
        if isinstance(key, str) and key in "hjklcC":
            apply_action(tmux, pane, key)
        elif key == "\x17":  # prefix Ctrl-W again starts a fresh combination.
            apply_action(tmux, pane, "begin")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--socket", required=True)
    parser.add_argument("--client")
    parser.add_argument("pane")
    parser.add_argument("action", choices=["begin", "menu", "h", "j", "k", "l", "c", "C"])
    args = parser.parse_args()

    def tmux(*command):
        result = subprocess.run(["tmux", "-S", args.socket] + list(command),
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                universal_newlines=True, check=True)
        return result.stdout.strip()

    try:
        if args.action == "menu":
            sess_id, win_id = tmux("display-message", "-p", "-t", args.pane,
                                   "#{session_id} #{window_id}").split()
            try:
                curses.wrapper(position_menu, tmux, args.pane)
            finally:
                tmux("set-hook", "-wu", "-t", win_id, "window-pane-changed[95]",
                     ";", "set-hook", "-u", "-t", sess_id, "session-window-changed[95]",
                     ";", "set-hook", "-gu", "client-session-changed[95]",
                     ";", "select-pane", "-t", args.pane)
        else:
            origin = tmux("show-option", "-pqv", "-t", args.pane, "@float_position_target")
            if origin:
                args.pane = origin
            apply_action(tmux, args.pane, args.action)
            if args.client and not origin:
                sess_id, win_id, win_w, win_h = tmux(
                    "display-message", "-p", "-t", args.pane,
                    "#{session_id} #{window_id} #{window_width} #{window_height}",
                ).split()
                win_w, win_h = int(win_w), int(win_h)
                menu = subprocess.check_output(
                    [str(Path(__file__).with_name("new_float_pane.sh")), args.pane,
                     "-x", "40", "-y", "13", "-X", str(max(0, win_w - 40)),
                     "-Y", str(max(0, win_h - 13)), "-T", "浮窗位置 · 连续按键",
                     sys.executable, __file__, "--socket", args.socket, "--client", args.client,
                     args.pane, "menu"],
                    env=dict(os.environ, TMUX=args.socket + ",0,0"), universal_newlines=True).strip()
                unhook = (
                    "set-hook -wu -t {win} window-pane-changed[95] ; "
                    "set-hook -u -t {sess} session-window-changed[95] ; "
                    "set-hook -gu client-session-changed[95]"
                ).format(win=win_id, sess=sess_id)
                close_menu = unhook + " ; kill-pane -t " + menu
                tmux(
                    "set-option", "-pq", "-t", menu, "@float_position_target", args.pane,
                    ";", "set-option", "-pq", "-t", menu, "@jump-history-skip", "1",
                    ";", "set-hook", "-w", "-t", win_id, "window-pane-changed[95]",
                    'if-shell -F "#{!=:#{pane_id},' + menu + '}" "' + close_menu + '"',
                    ";", "set-hook", "-t", sess_id, "session-window-changed[95]",
                    'if-shell -F "#{!=:#{window_id},' + win_id + '}" "' + close_menu + '"',
                    ";", "set-hook", "-g", "client-session-changed[95]",
                    'if-shell -F "#{&&:#{==:#{client_name},' + args.client + '},#{!=:#{session_id},' + sess_id + '}}" "' + close_menu + '"',
                    ";", "if-shell", "-t", menu, "-F", "#{!:#{&&:#{pane_active},#{window_active}}}", close_menu,
                )
    except (ValueError, subprocess.CalledProcessError) as error:
        message = error.stderr.strip() if isinstance(error, subprocess.CalledProcessError) else str(error)
        print("float_position: " + message, file=sys.stderr)
        if args.client:
            tmux("display-message", "-c", args.client, "-d", "5000", message)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
