#!/usr/bin/env -S uv run
# /// script
# dependencies = [
#   "tomlkit",
# ]
# ///

import subprocess
from pathlib import Path
import tomlkit


def get_cred(field, fname="gpt.gpg"):
    """Read one credential field via the shared `get-cred` helper."""
    result = subprocess.run(
        ["get-cred", field, fname],
        capture_output=True, text=True, check=True,
    )
    return result.stdout.strip()


def update_config_toml():
    config_path = Path.home() / ".codex/config.toml"
    config_path.parent.mkdir(parents=True, exist_ok=True)

    if config_path.exists():
        with open(config_path, "r") as f:
            doc = tomlkit.parse(f.read())
    else:
        doc = tomlkit.document()

    # Set top-level fields
    doc["model"] = "gpt-5.2"
    doc["model_provider"] = "azure"
    doc["project_doc_fallback_filenames"] = ["GEMINI.md"]

    # Ensure [sandbox_workspace_write] exists and enable network access
    if "sandbox_workspace_write" not in doc:
        doc["sandbox_workspace_write"] = tomlkit.table()
    doc["sandbox_workspace_write"]["network_access"] = True

    # Ensure [model_providers] exists
    if "model_providers" not in doc:
        doc["model_providers"] = tomlkit.table()

    # Update [model_providers.azure]
    azure = tomlkit.table()
    azure["name"] = "Azure OpenAI"

    # Ensure base_url ends with /openai/v1
    base_url = get_cred("base").rstrip("/")
    if not base_url.endswith("/openai/v1"):
        base_url = f"{base_url}/openai/v1"

    azure["base_url"] = base_url
    azure["env_key"] = "AZURE_OPENAI_API_KEY"
    azure["wire_api"] = "responses"

    doc["model_providers"]["azure"] = azure

    # Optional extra provider (xyz). Convention in ~/deploy/keys/gpt.gpg:
    #   Linux: line 4 = xyz api_base, line 5 = xyz api_key
    #   macOS: line 6 = xyz api_base, line 7 = xyz api_key
    xyz_base = get_cred("xyz_base")
    xyz_key = get_cred("xyz_key")

    if xyz_base:
        xyz_provider = tomlkit.table()
        xyz_provider["name"] = "xyz"
        xyz_base_url = xyz_base.rstrip("/")
        if not xyz_base_url.endswith("/v1"):
            xyz_base_url = f"{xyz_base_url}/v1"
        xyz_provider["base_url"] = xyz_base_url
        xyz_provider["env_key"] = "XYZ_API_KEY"
        xyz_provider["wire_api"] = "responses"
        doc["model_providers"]["xyz"] = xyz_provider

    # Store additional key under a separate section (Codex ignores unknown sections).
    # This is mainly for local tooling that wants a single config entry point.
    if xyz_key:
        if "xyz" not in doc:
            doc["xyz"] = tomlkit.table()
        doc["xyz"]["api_key"] = xyz_key
        if xyz_base:
            doc["xyz"]["api_base"] = xyz_base

    with open(config_path, "w") as f:
        f.write(tomlkit.dumps(doc))
    print(f"Updated {config_path}")


def main():
    update_config_toml()


if __name__ == "__main__":
    main()
