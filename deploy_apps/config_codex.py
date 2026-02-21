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
        
        return {
            "api_base": lines[0].strip(),
            "model": lines[1].strip(),
            "api_key": lines[2].strip()
        }
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
    doc["model"] = cred["model"]
    doc["model_provider"] = "azure"
    doc["project_doc_fallback_filenames"] = ["GEMINI.md"]

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
