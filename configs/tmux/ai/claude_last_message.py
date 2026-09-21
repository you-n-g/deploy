#!/usr/bin/env python3
"""Print the latest completed Claude Code response of a running interactive session.

usage: claude_last_message.py CLAUDE_PID

Claude Code has no "copy last response" key like Codex's Ctrl+O, so the text is
taken from the session transcript instead. The pid -> session mapping comes from
~/.claude/sessions/<pid>.json, which Claude Code maintains for every live
interactive session; the transcript lives under ~/.claude/projects/*/<sessionId>.jsonl.

A streamed response is stored as several JSONL rows sharing one message.id, one
content block per row. The output is every text block of the last non-sidechain
assistant message that has one, joined in order.
"""
import glob
import json
import os
import sys


def fail(message):
    print(message, file=sys.stderr)
    sys.exit(1)


def main():
    if len(sys.argv) != 2:
        fail(__doc__.strip().splitlines()[2])
    pid = sys.argv[1]
    config_dir = os.environ.get("CLAUDE_CONFIG_DIR", os.path.expanduser("~/.claude"))

    state_path = os.path.join(config_dir, "sessions", "%s.json" % pid)
    if not os.path.isfile(state_path):
        fail("no Claude session state for pid %s: %s" % (pid, state_path))
    with open(state_path) as fh:
        session_id = json.load(fh)["sessionId"]

    transcripts = glob.glob(os.path.join(config_dir, "projects", "*", "%s.jsonl" % session_id))
    if len(transcripts) != 1:
        fail("expected one transcript for session %s, found %d" % (session_id, len(transcripts)))

    # message.id -> text blocks, plus the id of the last message that had text.
    texts = {}
    last_id = None
    with open(transcripts[0]) as fh:
        for line in fh:
            try:
                row = json.loads(line)
            except ValueError:
                continue
            if row.get("type") != "assistant" or row.get("isSidechain"):
                continue
            message = row["message"]
            content = message.get("content")
            if not isinstance(content, list):
                continue
            for block in content:
                if block.get("type") == "text" and block.get("text", "").strip():
                    texts.setdefault(message["id"], []).append(block["text"])
                    last_id = message["id"]

    if last_id is None:
        fail("session %s has no assistant text yet" % session_id)
    sys.stdout.write("\n\n".join(t.rstrip() for t in texts[last_id]) + "\n")


if __name__ == "__main__":
    main()
