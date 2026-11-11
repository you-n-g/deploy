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
    settings.setdefault("context", {}).setdefault("fileName", ["AGENTS.md", "GEMINI.md"])
    auth = settings.setdefault("security", {}).setdefault("auth", {})
    if gateway_env is not None:
        auth["selectedType"] = "gemini-api-key"

    GEMINI_DIR.mkdir(parents=True, exist_ok=True)
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


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--gateway-provider",
        type=Path,
        help="Reuse the gateway URL and token from a Claude provider settings JSON",
    )
    args = parser.parse_args()
    configure(args.gateway_provider)
