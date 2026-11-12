#!/usr/bin/env python3
"""Reuse the Gemini gateway credential without copying it into Pi's config."""

import json
from pathlib import Path


def gateway_config():
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


if __name__ == '__main__':
    # Invoked only by Pi's !command credential resolver; do not run for logging.
    print(gateway_config()['GEMINI_API_KEY'])
