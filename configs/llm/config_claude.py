#!/usr/bin/env python3

import json
from pathlib import Path

SETTINGS_PATH = Path.home() / ".claude/settings.json"
REPO_ROOT = Path(__file__).resolve().parents[2]
HOOK_SETTINGS_PATH = REPO_ROOT / "configs/llm/claude/agent-state-hooks.settings.json"
STATUSLINE_SETTINGS_PATH = REPO_ROOT / "configs/llm/claude/statusline.settings.json"
# What marks a hook group as ours, so reinstalling replaces it instead of
# appending a duplicate. Must stay in sync with the commands in
# HOOK_SETTINGS_PATH, which call the wrapper rather than the tracker directly.
HOOK_MARKER = "claude_agent_state_hook.sh"


def load_json(path: Path):
    if not path.exists():
        return {}
    return json.loads(path.read_text())


def install_agent_hooks(settings):
    hook_settings = load_json(HOOK_SETTINGS_PATH)

    settings_hooks = settings.setdefault("hooks", {})
    for event_name, hook_groups in hook_settings["hooks"].items():
        target_groups = settings_hooks.setdefault(event_name, [])
        target_groups[:] = [
            group for group in target_groups
            if not any(
                hook.get("type") == "command"
                and HOOK_MARKER in hook.get("command", "")
                for hook in group.get("hooks", [])
            )
        ]
        target_groups.extend(hook_groups)

    print(f"Installed Claude agent-state hooks into {SETTINGS_PATH}")


def install_statusline(settings):
    # Single top-level key, so unlike the hooks there is nothing to de-duplicate:
    # reinstalling just overwrites whatever was there.
    settings.update(load_json(STATUSLINE_SETTINGS_PATH))
    print(f"Installed Claude statusLine into {SETTINGS_PATH}")


if __name__ == "__main__":
    SETTINGS_PATH.parent.mkdir(parents=True, exist_ok=True)
    settings = load_json(SETTINGS_PATH)
    install_agent_hooks(settings)
    install_statusline(settings)
    SETTINGS_PATH.write_text(json.dumps(settings, indent=2, ensure_ascii=False) + "\n")
