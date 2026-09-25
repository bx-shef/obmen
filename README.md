# obmen.bx-shef.by

> Last reviewed: 2026-09-25

Static site about the 1C ↔ website exchange via RabbitMQ: a presentation for the
engineer, a work plan for the 1C contractor, and both as print-ready PDFs.

- `site/index.html` — presentation (responsive, keyboard navigation)
- `site/plan.html` — work plan with an interactive acceptance checklist
- `site/files/*.pdf` — A4, optimised for black-and-white printing

Same delivery scheme as `client-bank-alfa-by`: **GHCR + Watchtower behind the
shared nginx-proxy** (TLS via Let's Encrypt).

## Local preview

```bash
docker compose up --build      # http://localhost:8082
```

## Pipeline

| Trigger | Runs |
|---|---|
| Pull request → `main` | `ci`: local link check + image build (`nginx -t` inside), no push |
| Push to `main` | `ci` → `deploy`: push `ghcr.io/bx-shef/obmen:latest` and `:sha-<short>` |

Watchtower on the server polls GHCR (~5 min) and swaps the container.

## Server (one-time)

Prerequisites already on the host: `proxy-net`, nginx-proxy + acme-companion,
one Watchtower with `--label-enable`. DNS `A obmen.bx-shef.by` must point to the
server **before** the first `up`, otherwise acme cannot issue the certificate.

```bash
mkdir -p /home/bitrix/obmen && cd /home/bitrix/obmen
curl -fsSL -O https://raw.githubusercontent.com/bx-shef/obmen/main/docker-compose.prod.yml
cat > .env <<'ENV'
DOMAIN=obmen.bx-shef.by
LETSENCRYPT_EMAIL=you@example.com
ENV
docker compose -f docker-compose.prod.yml up -d
```

The GHCR package must be **public** (Package settings → Change visibility),
otherwise the server and Watchtower need `docker login`.

`docker-compose.prod.yml` is not updated by Watchtower — after changing it,
re-run the `curl` above and `up -d`.

## Updating content

Edit files in `site/`, open a PR, merge. PDFs are committed artifacts: replace
them under the same file names so the links keep working.
