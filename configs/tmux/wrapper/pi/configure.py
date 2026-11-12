#!/usr/bin/env python3
"""Merge the local gateway and defaults into the user's existing Pi config."""

import json
from pathlib import Path
import shlex

from credential import gateway_config


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
    write_json(models_path, models)
    write_json(settings_path, settings)
    print('Pi default: {}/{}; native TMA extension enabled.'.format(provider_id, model_id))


if __name__ == '__main__':
    configure()
