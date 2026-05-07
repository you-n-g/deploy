#!/usr/bin/env python3

import json
from pathlib import Path

SETTINGS_PATH = Path.home() / ".claude/settings.json"
REPO_ROOT = Path(__file__).resolve().parents[2]
HOOK_SETTINGS_PATH = REPO_ROOT / "configs/llm/claude/agent-state-hooks.settings.json"


def load_json(path: Path):
    if not path.exists():
        return {}
    return json.loads(path.read_text())


def install_agent_hooks():
    SETTINGS_PATH.parent.mkdir(parents=True, exist_ok=True)

    settings = load_json(SETTINGS_PATH)
    hook_settings = load_json(HOOK_SETTINGS_PATH)

    settings_hooks = settings.setdefault("hooks", {})
    for event_name, hook_groups in hook_settings["hooks"].items():
        target_groups = settings_hooks.setdefault(event_name, [])
        target_groups[:] = [
            group for group in target_groups
            if not any(
                hook.get("type") == "command"
                and "track_ai_agent_state.sh" in hook.get("command", "")
                for hook in group.get("hooks", [])
            )
        ]
        target_groups.extend(hook_groups)

    SETTINGS_PATH.write_text(json.dumps(settings, indent=2, ensure_ascii=False) + "\n")
    print(f"Installed Claude agent-state hooks into {SETTINGS_PATH}")


if __name__ == "__main__":
    install_agent_hooks()
