#!/usr/bin/env python3

"""Configure Gemini CLI; optionally reuse an existing gateway credential."""

import argparse
import json
import os
import re
from pathlib import Path


GEMINI_DIR = Path.home() / ".gemini"
def _default_model():
    gateways = Path.home() / ".config/llm/gateways.local.json"
    if gateways.exists():
        model = json.loads(gateways.read_text()).get("gemini", {}).get("model")
        if model:
            return model
    return "gemini-2.5-pro"


DEFAULT_MODEL = _default_model()
HOOK_COMMAND = 'bash "$HOME/deploy/configs/tmux/wrapper/gemini/hook.sh"'
HOOK_EVENTS = (
    "SessionStart", "BeforeAgent", "BeforeModel", "BeforeTool", "PreCompress",
    "AfterAgent", "Notification", "SessionEnd",
)


def install_agent_hooks(settings):
    hooks = settings.setdefault("hooks", {})
    for event in HOOK_EVENTS:
        groups = hooks.setdefault(event, [])
        # Replace only our hooks, preserving other hooks even in mixed groups.
        kept_groups = []
        for group in groups:
            kept = [hook for hook in group["hooks"]
                    if "gemini_agent_state_hook.sh" not in hook.get("command", "")
                    and "/wrapper/gemini/hook.sh" not in hook.get("command", "")]
            if kept:
                kept_groups.append(dict(group, hooks=kept))
        kept_groups.append({"hooks": [{
            "name": "tma-" + event,
            "type": "command",
            "command": HOOK_COMMAND,
            "timeout": 15000,
        }]})
        hooks[event] = kept_groups
    settings.setdefault("hooksConfig", {})["enabled"] = True


def configure(gateway_provider=None):
    gateway_env = None
    if gateway_provider is not None:
        provider = json.loads(gateway_provider.read_text())["env"]
        gateway_env = {
            "GOOGLE_GEMINI_BASE_URL": provider["ANTHROPIC_BASE_URL"],
            "GEMINI_API_KEY": provider["ANTHROPIC_AUTH_TOKEN"],
        }

    settings_path = GEMINI_DIR / "settings.json"
    settings = json.loads(settings_path.read_text()) if settings_path.exists() else {}
    settings.setdefault("model", {}).setdefault("name", DEFAULT_MODEL)
    context = settings.setdefault("context", {})
    names = context.setdefault("fileName", ["AGENTS.md", "GEMINI.md"])
    if isinstance(names, str):
        names = [names]
        context["fileName"] = names
    if "GEMINI_CLI.md" not in names:
        names.append("GEMINI_CLI.md")
    # Gemini scratch files and TMA conversation logs live outside the project.
    # Include their directories so ordinary file paths are workspace-local.
    runtime_dir = GEMINI_DIR / "tmp"
    workspace_dirs = [runtime_dir]
    codex_sessions = GEMINI_DIR.parent / ".codex" / "sessions"
    if codex_sessions.is_dir():
        workspace_dirs.append(codex_sessions)
    included = context.setdefault("includeDirectories", [])
    for directory in workspace_dirs:
        if str(directory) not in included:
            included.append(str(directory))
    # The built-in help agent otherwise selects Flash, which this gateway
    # rejects. Follow the session model, including explicit -m overrides.
    overrides = settings.setdefault("agents", {}).setdefault("overrides", {})
    overrides.setdefault("cli_help", {}).setdefault("modelConfig", {}).setdefault("model", "inherit")
    auth = settings.setdefault("security", {}).setdefault("auth", {})
    if gateway_env is not None:
        auth["selectedType"] = "gemini-api-key"
    install_agent_hooks(settings)

    GEMINI_DIR.mkdir(parents=True, exist_ok=True)
    runtime_dir.mkdir(exist_ok=True)
    if gateway_env is not None:
        env_path = GEMINI_DIR / ".env"
        content = env_path.read_text() if env_path.exists() else ""
        for name, value in gateway_env.items():
            pattern = re.compile(r"^(?:export )?" + name + r"=.*$", re.MULTILINE)
            line = name + "=" + json.dumps(value)
            if pattern.search(content):
                content = pattern.sub(lambda match: line, content)
            else:
                content = content.rstrip("\n") + "\n" + line + "\n"
        fd = os.open(str(env_path), os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "w") as env_file:
            env_file.write(content.lstrip("\n"))
        print("Updated gateway credentials in {} (0600)".format(env_path))

    settings_path.write_text(json.dumps(settings, indent=2, ensure_ascii=False) + "\n")
    print("Updated {} (model: {})".format(settings_path, settings["model"]["name"]))
    print("Installed Gemini TMA state hooks")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--gateway-provider",
        type=Path,
        help="Reuse the gateway URL and token from a Claude provider settings JSON",
    )
    args = parser.parse_args()
    configure(args.gateway_provider)
