#!/usr/bin/env bash
# Hand the images embedded in the vault's msg.md to the AI in PANE. Claude Code
# here cannot paste an image (its Ctrl+V reads this headless server's clipboard),
# so the user pastes the screenshot into msg.md in Obsidian, LiveSync brings the
# file over, and this types the file paths into PANE's prompt (no Enter).
#
# Each image is moved out of the vault into ~/tmp/claude-images/ -- Claude reads
# it from there once the prompt is sent -- and its embed is removed from msg.md
# (a line left empty goes too), so the next run sees only new images.
# Embeds: Obsidian's ![[name.png]] (found by name anywhere in the vault) and
# Markdown's ![alt](path) (relative to the vault). prefix + t m.
#
# usage: insert_msg_images.sh PANE
set -euo pipefail

pane="${1:?usage: insert_msg_images.sh PANE}"
vault="${LEARN_MSG_DIR:-$HOME/vaults/livesync-headless}"
msg="$vault/msg.md"
out_dir="$HOME/tmp/claude-images"
fail() { tmux display-message "msg 图片：$1"; exit 1; }

[[ -f "$msg" ]] || fail "$msg 不存在"
mkdir -p "$out_dir"

# One python pass: find the embeds, resolve and move the files, rewrite msg.md,
# print the new paths. Nothing changes unless every image resolves.
errors="$(mktemp)"
trap 'rm -f "$errors"' EXIT
paths="$(python3 - "$vault" "$msg" "$out_dir" 2>"$errors" <<'EOF'
import os, re, shutil, sys, time
vault, msg, out_dir = sys.argv[1:]
text = open(msg, encoding="utf-8").read()
IMAGE = (".png", ".jpg", ".jpeg", ".gif", ".webp", ".bmp")
embeds = []  # (matched text, file it points to)
for m in re.finditer(r"!\[\[([^\]|#]+)(?:[|#][^\]]*)?\]\]|!\[[^\]]*\]\(([^)\s]+)\)", text):
    target = (m.group(1) or m.group(2)).strip()
    if target.startswith(("http://", "https://")) or not target.lower().endswith(IMAGE):
        continue
    embeds.append((m.group(0), target))
if not embeds:
    sys.exit(3)
found, missing = [], []
for raw, target in embeds:
    path = os.path.join(vault, target)
    if not os.path.isfile(path):
        name = os.path.basename(target)
        hits = [os.path.join(d, name) for d, _, files in os.walk(vault)
                if name in files and "/.obsidian" not in d and "/.livesync" not in d]
        path = max(hits, key=os.path.getmtime) if hits else ""
    (found if path else missing).append((raw, path or target))
if missing:
    print("找不到（可能还没同步过来）：" + "、".join(t for _, t in missing), file=sys.stderr)
    sys.exit(4)
stamp = time.strftime("%Y%m%d-%H%M%S")
moved = []
for i, (raw, path) in enumerate(found):
    dest = os.path.join(out_dir, f"{stamp}-{i}-{os.path.basename(path).replace(' ', '_')}")
    shutil.move(path, dest)
    moved.append(dest)
# Drop each embed; a line that held only embeds goes with them.
raws = [raw for raw, _ in found]
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
)" || case $? in
  3) fail "msg.md 里没有图片" ;;
  *) fail "$(tail -n 1 "$errors")" ;;
esac

tmux set-buffer -b msg-images "$paths "
tmux paste-buffer -p -d -b msg-images -t "$pane"
