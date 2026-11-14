#!/usr/bin/env python3
"""Merge the local gateway and defaults into the user's existing Pi config."""

import json
from pathlib import Path
import re
import shlex

from credential import gateway_config

DEFAULT_PACKAGES = ('npm:pi-web-access',)


def package_key(entry):
    source = entry['source'] if isinstance(entry, dict) else entry
    if source.startswith('npm:'):
        spec = source[4:].strip()
        match = re.match(r'^(@?[^@]+(?:/[^@]+)?)(?:@.+)?$', spec)
        return 'npm:' + (match.group(1) if match else spec)
    return source


def read_json(path):
    return json.loads(path.read_text()) if path.exists() else {}


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + '\n')
    path.chmod(0o600)


def configure():
    gateway = gateway_config()
    local = json.loads((Path.home() / ".config/llm/gateways.local.json").read_text())["pi"]
    provider_id = local["provider"]
    model_id = local["model"]
    directory = Path.home() / '.pi/agent'
    directory.mkdir(parents=True, exist_ok=True)
    models_path = directory / 'models.json'
    settings_path = directory / 'settings.json'
    models = read_json(models_path)
    settings = read_json(settings_path)
    provider = models.setdefault('providers', {}).setdefault(provider_id, {})
    provider.update({
        'baseUrl': gateway['GOOGLE_GEMINI_BASE_URL'].rstrip('/') + '/v1beta',
        'api': 'google-generative-ai',
        'apiKey': '!python3 ' + shlex.quote(str(Path(__file__).resolve().with_name('credential.py'))),
    })
    entries = provider.setdefault('models', [])
    entry = next((entry for entry in entries if entry['id'] == model_id), None)
    if entry is None:
        entry = {'id': model_id}
        entries.append(entry)
    # Configure a 1M shared context window, 64K streaming output limit, and
    # supported thinking levels: https://ai.google.dev/gemini-api/docs/thinking
    entry.update(name=local["name"], reasoning=True, input=['text', 'image'],
                  contextWindow=1048576, maxTokens=65536,
                  thinkingLevelMap={'off': None, 'minimal': None,
                                    'low': 'low', 'medium': 'medium', 'high': 'high',
                                    'xhigh': None, 'max': None})
    settings.update(defaultProvider=provider_id, defaultModel=model_id,
                    defaultThinkingLevel='high', defaultProjectTrust='always')
    if 'enabledModels' in settings and provider_id + '/' + model_id not in settings['enabledModels']:
        settings['enabledModels'].append(provider_id + '/' + model_id)
    packages = settings.setdefault('packages', [])
    existing_packages = {package_key(entry) for entry in packages}
    for package in DEFAULT_PACKAGES:
        if package_key(package) not in existing_packages:
            packages.append(package)
            existing_packages.add(package_key(package))
    write_json(models_path, models)
    write_json(settings_path, settings)
    print('Pi default: {}/{}; native TMA extension enabled.'.format(provider_id, model_id))


if __name__ == '__main__':
    configure()
