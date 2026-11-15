#!/usr/bin/env python3
"""Configure DeepSeek Harness (DSH) from local gateway settings."""

import json
import os
from pathlib import Path
import yaml


def gateway_env():
    path = Path.home() / '.gemini/.env'
    values = {}
    for line in path.read_text().splitlines():
        key, sep, value = line.partition('=')
        if sep and key in ('GOOGLE_GEMINI_BASE_URL', 'GEMINI_API_KEY'):
            values[key] = json.loads(value)
    for key in ('GOOGLE_GEMINI_BASE_URL', 'GEMINI_API_KEY'):
        if not values.get(key):
            raise ValueError('Missing {} in {}'.format(key, path))
    return values


def write_private(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd = os.open(str(path), os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, 'w') as handle:
        handle.write(text)
    path.chmod(0o600)


def update_credentials(path, api_key):
    doc = {}
    if path.exists():
        loaded = yaml.safe_load(path.read_text())
        if loaded is not None:
            if not isinstance(loaded, dict):
                raise ValueError('Invalid DSH credentials file: {}'.format(path))
            doc = loaded
    doc['version'] = 1
    refs = doc.setdefault('refs', {})
    if not isinstance(refs, dict):
        raise ValueError('Invalid refs mapping in {}'.format(path))
    refs['DSH_GATEWAY_API_KEY'] = api_key
    write_private(path, yaml.safe_dump(doc, default_flow_style=False, allow_unicode=True))


def build_models(local):
    default_id = local['model']
    default_name = local['name']
    ids = [default_id]
    for alias in local.get('aliases', []):
        if alias not in ids:
            ids.append(alias)
    models = []
    for model_id in ids:
        models.append({
            'id': model_id,
            'name': default_name if model_id == default_id else model_id,
            'contextWindow': 1048576,
            'maxTokens': 65536,
            'reasoningEfforts': {
                'low': 'low',
                'medium': 'medium',
                'high': 'high',
            },
        })
    return models


def seed_json_if_absent(path, payload):
    if path.exists():
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2) + '\n')


def ensure_tui_settings(path):
    doc = {'version': 1, 'values': {}}
    if path.exists():
        loaded = json.loads(path.read_text())
        if isinstance(loaded, dict):
            doc = loaded
    values = doc.setdefault('values', {})
    if not isinstance(values, dict):
        values = {}
        doc['values'] = values
    # Boot straight into Chat (PromptInput) instead of Launchpad so Ctrl+G
    # external editor works immediately from the first prompt.
    values.setdefault('launchpad', False)
    write_private(path, json.dumps(doc, indent=2, ensure_ascii=False) + '\n')


def configure():
    gateway = gateway_env()
    local = json.loads((Path.home() / '.config/llm/gateways.local.json').read_text())['pi']
    provider_id = local['provider']
    display_name = local.get('provider_name', provider_id)
    default_model = local['model']
    base_url = gateway['GOOGLE_GEMINI_BASE_URL'].rstrip('/') + '/v1beta'

    dsh_home = Path(os.environ.get('DSH_HOME') or (Path.home() / '.dsh'))
    dsh_home.mkdir(parents=True, exist_ok=True)
    update_credentials(dsh_home / '.credentials.yaml', gateway['GEMINI_API_KEY'])

    tma_plugin = str(Path(__file__).resolve().with_name('tma.mjs'))
    patch = [
        {'id': 'credentials', 'disabled': False},
        {
            'id': 'llm-pi-ai',
            'config': {
                'providers': {
                    provider_id: {
                        'displayName': display_name,
                        'apiKeyEnv': 'DSH_GATEWAY_API_KEY',
                        'api': 'google-generative-ai',
                        'baseURL': base_url,
                        'models': build_models(local),
                    },
                },
            },
        },
        {
            'id': 'agent-default-model',
            'config': {
                'provider': provider_id,
                'model': default_model,
                'reasoningEffort': 'high',
            },
        },
        {
            'insert': [
                {'id': 'dsh-tma', 'name': tma_plugin},
            ],
        },
    ]
    write_private(
        dsh_home / 'cordis.patch.yml',
        yaml.safe_dump(patch, default_flow_style=False, allow_unicode=True),
    )

    tui_dir = Path.home() / '.dsh-tui'
    seed_json_if_absent(tui_dir / 'onboarding.json', {'completed': True, 'version': 1})
    seed_json_if_absent(tui_dir / 'permission.json', {'permission': 'danger-full-access'})
    seed_json_if_absent(tui_dir / 'effort.json', {'effort': 'high'})
    ensure_tui_settings(tui_dir / 'settings.json')
    print('DSH default: {}/{} (high); native TMA plugin enabled.'.format(provider_id, default_model))


if __name__ == '__main__':
    configure()
