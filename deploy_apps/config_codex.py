#!/usr/bin/env -S uv run
# /// script
# dependencies = [
#   "tomlkit",
# ]
# ///

import subprocess
from pathlib import Path
import tomlkit

def get_credentials(fname="gpt.gpg"):
    key_path = Path.home() / "deploy/keys" / fname
    if not key_path.exists():
        print(f"Error: {key_path} not found.")
        return None

    try:
        # Decrypt using gpg
        result = subprocess.run(
            ["gpg", "-q", "--decrypt", str(key_path)],
            capture_output=True,
            text=True,
            check=True
        )
        lines = result.stdout.strip().split("\n")
        if len(lines) < 3:
            print("Error: Decrypted file has fewer than 3 lines.")
            return None

        cred = {
            "api_base": lines[0].strip(),
            "model": lines[1].strip(),
            "api_key": lines[2].strip()
        }

        # Optional extra lines (for additional providers/keys).
        # Current convention in ~/deploy/keys/gpt.gpg:
        # 1) azure api_base
        # 2) model
        # 3) azure api_key
        # 4) xyz api_base (optional)
        # 5) xyz api_key  (optional)
        if len(lines) >= 4:
            cred["xyz_api_base"] = lines[3].strip()
        if len(lines) >= 5:
            cred["xyz_api_key"] = lines[4].strip()

        return cred
    except subprocess.CalledProcessError as e:
        print(f"Error decrypting {key_path}: {e}")
        return None

def update_config_toml(cred):
    config_path = Path.home() / ".codex/config.toml"
    config_path.parent.mkdir(parents=True, exist_ok=True)
    
    if config_path.exists():
        with open(config_path, "r") as f:
            doc = tomlkit.parse(f.read())
    else:
        doc = tomlkit.document()

    # Set top-level fields
    # doc["model"] = cred["model"]
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
    base_url = cred["api_base"].rstrip("/")
    if not base_url.endswith("/openai/v1"):
        base_url = f"{base_url}/openai/v1"
    
    azure["base_url"] = base_url
    azure["env_key"] = "AZURE_OPENAI_API_KEY"
    azure["wire_api"] = "responses"
    
    doc["model_providers"]["azure"] = azure

    # Optional extra provider config.
    if "xyz_api_base" in cred:
        xyz_provider = tomlkit.table()
        xyz_provider["name"] = "xyz"
        xyz_base_url = cred["xyz_api_base"].rstrip("/")
        if not xyz_base_url.endswith("/v1"):
            xyz_base_url = f"{xyz_base_url}/v1"
        xyz_provider["base_url"] = xyz_base_url
        xyz_provider["env_key"] = "XYZ_API_KEY"
        xyz_provider["wire_api"] = "responses"
        doc["model_providers"]["xyz"] = xyz_provider

    # Store additional key under a separate section (Codex ignores unknown sections).
    # This is mainly for local tooling that wants a single config entry point.
    if "xyz_api_key" in cred:
        if "xyz" not in doc:
            doc["xyz"] = tomlkit.table()
        doc["xyz"]["api_key"] = cred["xyz_api_key"]
        if "xyz_api_base" in cred:
            doc["xyz"]["api_base"] = cred["xyz_api_base"]

    with open(config_path, "w") as f:
        f.write(tomlkit.dumps(doc))
    print(f"Updated {config_path}")

def main():
    cred = get_credentials()
    if not cred:
        return

    update_config_toml(cred)

if __name__ == "__main__":
    main()
