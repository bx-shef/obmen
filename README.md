# obmen.bx-shef.by

> Last reviewed: 2026-09-25

Static site about the 1C ↔ website exchange via RabbitMQ: a presentation for the
engineer, a work plan for the 1C contractor, and both as print-ready PDFs.

- `site/index.html` — presentation (responsive, keyboard navigation)
- `site/plan.html` — work plan with an interactive acceptance checklist
- `/files/*.pdf` — A4, optimised for black-and-white printing; rendered from
  `print/` during the Docker build, not stored in git
- `/files/og.png`, `/files/og-plan.png` — Open Graph share cards (1200×630) for
  the two pages, rendered from `print/og.html` the same way

Same delivery scheme as [`client-bank-alfa-by`](https://github.com/bx-shef/client-bank-alfa-by):
**GHCR + Watchtower behind the shared nginx-proxy** (TLS via Let's Encrypt).

## Local preview

```bash
docker compose up --build      # http://localhost:8082
```

## Pipeline

| Trigger | Runs |
|---|---|
| Pull request → `main` | `ci`: local link check, image build (PDFs and OG cards rendered from `print/`, `nginx -t`), container smoke test (200s, security headers, PDFs, `og:image`), no push |
| Push to `main` | `ci` → `deploy`: push `ghcr.io/bx-shef/obmen:latest` and `:sha-<short>` |
| Manual run (`workflow_dispatch`) | same as push; `deploy` runs only when started on `main` |

Watchtower on the server polls GHCR (~5 min) and swaps the container, so a
merge to `main` reaches production without a manual step. Check the preview
locally before merging.

## Server (one-time)

Order matters:

1. Merge to `main` and wait for the green `deploy` job — until then
   `ghcr.io/bx-shef/obmen:latest` does not exist and `up` fails to pull.
2. Make the GHCR package **public** (Packages → obmen → Package settings →
   Change visibility). Otherwise the server and Watchtower need
   `docker login ghcr.io` with a token that has `read:packages`.
3. Point DNS `A obmen.bx-shef.by` to the server — **before** the first `up`,
   otherwise acme cannot issue the certificate.
4. Run the commands below.

Prerequisites already on the host: `proxy-net`, nginx-proxy + acme-companion,
one Watchtower with `--label-enable`. HSTS is not set by this container (it only
sees plain http); it belongs to the shared nginx-proxy.

```bash
mkdir -p /home/bitrix/obmen && cd /home/bitrix/obmen
curl -fsSL -O https://raw.githubusercontent.com/bx-shef/obmen/main/docker-compose.prod.yml
cat > .env <<'ENV'
DOMAIN=obmen.bx-shef.by
LETSENCRYPT_EMAIL=you@example.com
ENV
docker compose -f docker-compose.prod.yml up -d
```

Replace `you@example.com` with a real mailbox: Let's Encrypt sends expiry
warnings there. If it is left empty, acme-companion falls back to its own
default (if any) configured on the host.

### Verify

```bash
docker ps --filter name=obmen              # STATUS: Up … (healthy)
curl -sI https://obmen.bx-shef.by/         # 200 + Content-Security-Policy
curl -sI https://obmen.bx-shef.by/files/1c-rabbitmq-plan.pdf   # 200
```

The certificate may take a minute after the first `up`; if https fails, check
the acme-companion logs on the host.

### Rollback

Every deploy also pushes an immutable `:sha-<short>` tag (list: Packages →
obmen → versions). Pin one via `.env` and recreate the container:

```bash
echo 'IMAGE_TAG=sha-abc1234' >> .env
docker compose -f docker-compose.prod.yml up -d
```

Watchtower keeps watching the pinned tag, which never changes, so the site stays
on it. After the fix is merged, delete the `IMAGE_TAG` line and run `up -d`
again to return to `latest`.

`docker-compose.prod.yml` is not updated by Watchtower — after changing it,
re-run the `curl` above and `up -d`.

## Updating content

Edit files in `site/` and `print/`, open a PR, merge. The PDFs are rebuilt on
every image build, so a merged change always ships with matching PDFs.

The PDFs come from **separate print sources**, not from the web pages:

| PDF (served at) | Source | Layout |
|---|---|---|
| `/files/1c-rabbitmq-presentation.pdf` | `print/presentation.html` | A4 landscape, 5 slides |
| `/files/1c-rabbitmq-plan.pdf` | `print/plan.html` | A4 portrait, page numbers in footer |
| `/files/og.png`, `/files/og-plan.png` | `print/og.html` (`#plan` for the plan card) | 1200×630 PNG, `og:image` of `index.html` / `plan.html` |

⚠ The text exists twice — in `site/*.html` and in `print/*.html`. A content
change must be made in both. The OG cards carry short standalone titles: update
`print/og.html` when a page title or description changes. Messengers cache previews, so a
changed card may show up only after the cache expires (or via the Facebook
Sharing Debugger / Telegram @WebpageBot). File names are fixed in `print/render.py`; keep
them, the pages link to them.

How the PDFs are built: the first `Dockerfile` stage runs `print/render.py` on
`mcr.microsoft.com/playwright/python:v1.56.0-noble` (pinned by digest), the
nginx stage copies the result into `/files/`. Every CI run uploads the rendered
PDFs as the `pdf` artifact (Actions → run → Artifacts) — look there to review
how a change renders, since the PDFs are not in the PR diff.

The image tag and `print/requirements.txt` must name the same Playwright
version — each release bundles its own Chromium, and a mismatch fails the
build. Dependabot skips this image, so bump both by hand in one PR (tag,
digest, requirements) when a Playwright release matters.

Trade-off: every image build now pulls from `mcr.microsoft.com` and PyPI. If
either is down, CI and the deploy fail; the site already running keeps
serving the previous image.

To look at a PDF before pushing, render it locally (writes `site/files/*.pdf`,
ignored by git) or run `docker compose up --build`:

```bash
pip install -r print/requirements.txt
python -m playwright install chromium
python print/render.py   # writes site/files/*.pdf
```

Fonts are static instances of OFL fonts in `print/fonts/` (licences next to them):
Chromium embeds variable fonts as Type 3, which printer drivers rasterise.
Symbol glyphs missing from these fonts (✕, ✓) fall back to a system font, so a
local render can differ slightly from the one built in Docker.
