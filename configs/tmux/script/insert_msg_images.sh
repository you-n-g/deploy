#!/usr/bin/env bash
# Hand images from the Obsidian vault to the AI in PANE. Claude Code here cannot
# paste an image (its Ctrl+V reads this headless server's clipboard), so the
# user pastes the screenshot in Obsidian, LiveSync brings the file over, and
# this types the file paths into PANE's prompt (no Enter).
#
# Only images at most max_age (30 min) old count: a screenshot is handed over
# right after it is taken, and an older one is something else -- an embed left
# in msg.md from last time, an attachment of another note.
#
# Every image handed over is moved out of the vault into ~/tmp/claude-images/
# -- Claude reads it from there once the prompt is sent -- so the vault does not
# collect screenshots and the next run sees only new ones.
#
# prefix t m, prefix C-o i: the images embedded in the vault's msg.md. Their
# embeds are removed from msg.md too (a line left empty goes with them); older
# embeds are left as they are. Embeds: Obsidian's ![[name.png]] (looked up by
# name anywhere in the vault) and Markdown's ![alt](path) (relative to the vault).
#
# --last (prefix C-o l): the newest image anywhere in the vault, wherever
# Obsidian put it (an embed of it left in a note then points nowhere).
#
# A failure is reported on the status line. Run from a key, it exits 0 so tmux's
# own "'...' returned 1" does not replace that message.
#
# usage: insert_msg_images.sh [--last] PANE
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/../wrapper/dispatch.sh"

usage="usage: insert_msg_images.sh [--last] PANE"
last=0
[[ "${1:-}" != --last ]] || { last=1; shift; }
pane="${1:?$usage}"
vault="${LEARN_MSG_DIR:-$HOME/vaults/livesync-headless}"
msg="$vault/msg.md"
out_dir="$(tma_call default image_staging_dir)"
max_age=1800
fail() {
  tmux display-message -d 8000 "msg 图片：$1"
  [[ -t 2 ]] && exit 1
  exit 0
}

[[ -d "$vault" ]] || fail "$vault 不存在"
(( last )) || [[ -f "$msg" ]] || fail "$msg 不存在"
mkdir -p "$out_dir"

# One python pass: pick the images, check their age, move them, rewrite msg.md,
# print the new paths. Nothing changes unless every image resolves.
errors="$(mktemp)"
trap 'rm -f "$errors"' EXIT
paths="$(python3 - "$vault" "$msg" "$out_dir" "$max_age" "$last" 2>"$errors" <<'EOF'
import os, re, shutil, sys, time
vault, msg, out_dir, max_age, last = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4]), sys.argv[5] == "1"
IMAGE = (".png", ".jpg", ".jpeg", ".gif", ".webp", ".bmp")
now = time.time()
minutes = max_age // 60
stamp = time.strftime("%Y%m%d-%H%M%S")


def vault_files():
    for d, dirs, files in os.walk(vault):
        dirs[:] = [x for x in dirs if x not in (".obsidian", ".livesync", ".trash", ".git")]
        for name in files:
            yield os.path.join(d, name)


def fresh(path):
    return now - os.path.getmtime(path) <= max_age


def move_out(i, path):
    dest = os.path.join(out_dir, f"{stamp}-{i}-{os.path.basename(path).replace(' ', '_')}")
    shutil.move(path, dest)
    return dest


if last:
    images = [p for p in vault_files() if p.lower().endswith(IMAGE)]
    recent = [p for p in images if fresh(p)]
    if not recent:
        newest = max(images, key=os.path.getmtime, default=None)
        age = f"，最新一张是 {int((now - os.path.getmtime(newest)) // 60)} 分钟前的" if newest else ""
        print(f"vault 里没有 {minutes} 分钟内的图片{age}", file=sys.stderr)
        sys.exit(4)
    print(move_out(0, max(recent, key=os.path.getmtime)))
    sys.exit(0)

text = open(msg, encoding="utf-8").read()
embeds = []  # (matched text, file it points to)
for m in re.finditer(r"!\[\[([^\]|#]+)(?:[|#][^\]]*)?\]\]|!\[[^\]]*\]\(([^)\s]+)\)", text):
    target = (m.group(1) or m.group(2)).strip()
    if target.startswith(("http://", "https://")) or not target.lower().endswith(IMAGE):
        continue
    embeds.append((m.group(0), target))
if not embeds:
    print("msg.md 里没有图片", file=sys.stderr)
    sys.exit(4)
resolved, missing = [], []
for raw, target in embeds:
    path = os.path.join(vault, target)
    if not os.path.isfile(path):
        name = os.path.basename(target)
        hits = [p for p in vault_files() if os.path.basename(p) == name]
        path = max(hits, key=os.path.getmtime) if hits else ""
    (resolved if path else missing).append((raw, path or target))
if missing:
    print("找不到（可能还没同步过来）：" + "、".join(t for _, t in missing), file=sys.stderr)
    sys.exit(4)
resolved = [(raw, path) for raw, path in resolved if fresh(path)]
if not resolved:
    print(f"msg.md 里的图片都不是 {minutes} 分钟内的（旧的嵌入原样保留）", file=sys.stderr)
    sys.exit(4)
moved = [move_out(i, path) for i, (_, path) in enumerate(resolved)]
# Drop each moved embed; a line that held only embeds goes with them.
raws = [raw for raw, _ in resolved]
lines = []
for line in text.split("\n"):
    stripped = line
    for raw in raws:
        stripped = stripped.replace(raw, "")
    if stripped != line and not stripped.strip():
        continue
    lines.append(stripped)
open(msg, "w", encoding="utf-8").write("\n".join(lines))
print(" ".join(moved))
EOF
)" || fail "$(tail -n 1 "$errors")"

tmux set-buffer -b msg-images "$paths "
tmux paste-buffer -p -d -b msg-images -t "$pane"
