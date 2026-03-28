---
name: cr
description: >
  Fetch web page content via Firecrawl (JS-rendered) and return clean Markdown; prefer this first because it can render JavaScript.
metadata:
  short-description: JS-rendered web scraping to Markdown
---

# `cr` (Firecrawl, JS-rendered)

Use this skill whenever the user gives you a URL and wants the page content (reading/summarizing/extracting), **especially** for JS-heavy pages (e.g. WeChat articles) where `curl`/static fetchers often miss the rendered text.

## Default behavior (important)

- **Prefer `cr` first** for webpage extraction because it can render JavaScript.
- Only fall back to a static fetcher if Firecrawl is unavailable or the user explicitly asks you not to use it.

## How to run

If `cr` is on `$PATH`:

- `cr <url>`

If not on `$PATH`, use the full path:

- `~/deploy/helper_scripts/bin/cr <url>`

### Useful flags (for JS-heavy pages)

- Wait for client-side render: `cr --wait-for 8000 <url>`
    - If it takes some time to render the page, you can use `--wait-for` to wait for the page to be rendered before scraping.

If `cr` is implemented via `uv` in the current environment and fails on cache initialization, re-run it with temporary cache directories:

- `XDG_CACHE_HOME=/tmp/.cache UV_CACHE_DIR=/tmp/.uv-cache cr <url>`
- `XDG_CACHE_HOME=/tmp/.cache UV_CACHE_DIR=/tmp/.uv-cache cr --wait-for 8000 <url>`

The command prints Markdown to stdout. Use that output as the source text for downstream summarization or extraction.

## Troubleshooting

If you see an error like “Firecrawl is not reachable at http://localhost:3002” (or the scrape hangs/fails), start the local Firecrawl service:

- `bash ~/deploy/deploy_apps/firecrawl.sh`
  - The user must run this command, so remind them to run it.

Then re-run `cr`.

If `cr` fails with an error about initializing `~/.cache/uv`, use:

- `XDG_CACHE_HOME=/tmp/.cache UV_CACHE_DIR=/tmp/.uv-cache cr <url>`

If the output looks like an unrendered shell / consent page / “enable JavaScript”, it’s usually one of:

- The renderer isn’t running (Playwright service down) → restart Firecrawl (`docker compose up` in `~/apps/firecrawl`).
- The site blocks headless browsers (common on Google properties) → self-hosted Firecrawl may not bypass it; try the cloud API or export the content from a real browser session.
