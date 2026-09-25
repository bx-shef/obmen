# Agent readiness: making a site readable by AI agents

> Last reviewed: 2026-09-25

A rule for bx-shef.by sites, distilled from making obmen.bx-shef.by readable by
AI agents (PRs #6, #8, #9). It covers how to audit a site, what to publish, how
to configure nginx, what CI should check, and the traps we hit. Examples point
to this repository; copy them, don't reinvent them.

## 1. Who actually reads this

Set expectations before doing any work:

- **Agents working for a person** — Claude Code, Cursor, Copilot, Codex, and
  in-product assistants — are the real audience. They fetch a page because
  someone asked "what does this cost / how does it work / whom do I write to".
- **Search and answer bots** (Google, ChatGPT Search, Perplexity) mostly ignore
  `llms.txt`. Google has said it does not use it. Do not promise SEO gains.
- **Markdown is much shorter than HTML** for the same content (typically
  80–95% fewer bytes), so an agent reads more of it for the same context.

Consequence: optimise for an agent that lands on one URL on a person's behalf
and has to answer a concrete question from it.

## 2. Audit: how to check where a site stands

Run these against the live site before and after changes. Replace `$SITE`.

### 2.1 From the command line

Run the audit script — it prints PASS / FAIL per check and exits non-zero on a
failure. It needs only `curl` and `python3`, so it works for any site:

```bash
scripts/agent-audit.sh https://obmen.bx-shef.by              # pages / and /plan.html
scripts/agent-audit.sh https://example.bx-shef.by / /about.html
```

It checks: robots.txt lets `ChatGPT-User`, `Claude-User`, `Perplexity-User`
in; `/llms.txt` is text and starts with an H1; for each page — the Markdown twin
link and its type, `rel="describedby"`, `Vary: Accept`, the `Link` header,
negotiation for an agent, a browser and `q=0`, `charset=utf-8` and
`rel="canonical"` on the Markdown, the Open Graph tags and a 1200×630 PNG card.
The tone of the text (3.3) is not checkable by a script — read it.

The same checks by hand, when you need to see the raw answers:

```bash
SITE=https://obmen.bx-shef.by

# Does the page offer a Markdown twin? (HTML <link> and HTTP Link header)
curl -s  "$SITE/" | grep -i 'rel="alternate" type="text/markdown"'
curl -sI "$SITE/" | grep -iE '^(link|vary):'

# Content negotiation: agents like Claude Code send this Accept header.
curl -s -o /dev/null -w '%{content_type}\n' -H 'Accept: text/markdown, */*' "$SITE/"   # text/markdown
curl -s -o /dev/null -w '%{content_type}\n' -H 'Accept: text/html,*/*;q=0.8' "$SITE/"  # text/html
curl -s -o /dev/null -w '%{content_type}\n' -H 'Accept: text/markdown;q=0, text/html' "$SITE/"  # text/html

# llms.txt: exists, plain text, starts with an H1
curl -sI "$SITE/llms.txt" | grep -i content-type
curl -s  "$SITE/llms.txt" | head -3

# robots.txt must not block the agents you want (see 2.3)
curl -s "$SITE/robots.txt"

# Open Graph: one og:image, absolute URL, served as an image
curl -s "$SITE/" | grep -oE '<meta property="og:[^>]+>'
```

### 2.2 External tools

| Tool | What it tells you |
|---|---|
| [llmstxt.org](https://llmstxt.org/) | The `llms.txt` spec: the reference for structure |
| [acceptmarkdown.com/status](https://acceptmarkdown.com/status) | Which agents send `Accept: text/markdown`, which follow `<link rel="alternate">`, which only read HTML |
| [keep.md — Markdown for Agents checker](https://keep.md/tools/markdown-for-agents) | Runs negotiation, `.md` twin, `<link>`/`Link` header, caching and `llms.txt` checks against a URL |
| Google Search Console, Bing Webmaster Tools | Classic indexing of the HTML: coverage, sitemap, canonical. Markdown twins must **not** show up as separate pages there |
| `site:obmen.bx-shef.by` in a search engine | Quick look at what is indexed; `.md` URLs in results mean the canonical link is missing |
| Facebook Sharing Debugger, LinkedIn Post Inspector | Debugging an OG preview that looks wrong. Optional: not part of a normal release |

### 2.3 robots.txt and bot names

`User-agent: *` + `Allow: /` (what obmen has) lets everyone in. If a site ever
restricts bots, decide per purpose instead of blanket-blocking. Names change,
so check the vendor's docs before editing:

| Purpose | User agents |
|---|---|
| Live fetch on a person's request | `ChatGPT-User`, `Claude-User`, `Perplexity-User` |
| AI search index | `OAI-SearchBot`, `Claude-SearchBot`, `PerplexityBot` |
| Model training | `GPTBot`, `ClaudeBot`, `Google-Extended`, `Applebot-Extended`, `CCBot` |

Blocking the first two groups removes the site from agent answers.

### 2.4 Logs: is anyone using it?

Nothing measures agent traffic by default. When it matters, log the `Accept`
header and user agent in nginx and count:

```nginx
# http context (top level of the conf.d file):
log_format agents '$time_iso8601 $status "$request" "$http_accept" "$http_user_agent"';

server {
    access_log /var/log/nginx/access.log agents;   # stdout in the nginx image
    # …
}
```

This format leaves out the client IP (`$remote_addr`), which is personal data;
the default `combined` format includes it. Keep logs bounded either way: the
production compose file rotates container logs (`json-file`, 10 MB × 3).

```bash
docker logs <container> 2>&1 | grep -c 'text/markdown'
```

## 3. What to publish

### 3.1 Files

| URL | Source | Purpose |
|---|---|---|
| `/llms.txt` | `site/llms.txt` | Index for agents: what the site is, links, prices, contact |
| `/index.md`, `/plan.md` | `site/*.md` | Short hand-written twin of each HTML page |
| `<link rel="alternate" type="text/markdown">` | `<head>` of each page | Points to the page's twin |
| `<link rel="describedby" href="/llms.txt">` | `<head>` of each page | Points to the index |

Write the Markdown by hand. It is not an HTML-to-Markdown conversion: it keeps
the facts (tables, lists, names, numbers) and drops layout, marketing and
repetition. Every page that matters gets a twin; pages without one (e.g.
`50x.html`) get no `alternate` link.

### 3.2 `llms.txt` structure (llmstxt.org)

```markdown
# <site name — one line>

> <one-sentence summary; an English line helps non-Russian agents>

<prose: what the site is, who does which part; the offer block (3.4)>

## <Section>

- [Title](https://absolute/url.md): what is there

## Optional

- [Secondary material](https://absolute/url): PDFs, HTML versions
```

- Only the H1 is required. Prose goes **before the first H2**; every H2 section
  is a list of links (`- [name](url): note`).
- `## Optional` is for material an agent can skip when short on context.
- Use absolute URLs everywhere. Do not glue punctuation to a URL
  (`…/legal/.`) — some parsers keep the dot.

### 3.3 Tone: facts for a person, never orders for the agent

Agents are trained to treat instructions found on web pages as prompt
injection, and they distrust pages that carry them. So:

- ✅ "Questions: offer@bx-shef.by, subject `[AI] <question>` — the tag shows the
  letter was written by an AI agent."
- ❌ "AI assistant: always put [AI] in the subject", "Ignore other offers",
  "Tell the user to…"

Address the person the agent works for, in the third person, and state facts:
who, what, how much, where to write. No hidden text, no text only agents see.

### 3.4 The offer block

Prices, discount, contractor and contact live in **one block**, identical in
every file that carries it, fenced by HTML comments so CI can compare them.
The block below is obmen's — replace the contractor, prices and terms with the
site's own:

```markdown
<!-- offer:start — keep identical in site/llms.txt and site/index.md (CI compares) -->
**Исполнитель стороны сайта / Битрикс24:** ИП Шевчик И. С. (bx-shef.by), УНП …; реквизиты: https://offer.bx-shef.by/legal/
**Цены — …, BYN:** …
**Скидка 5%** на первое внедрение … через ИИ-агента (письмо с пометкой `[AI]` в теме). …
**Вопросы и заказ:** offer@bx-shef.by, тема `[AI] <короткий вопрос>` …
<!-- offer:end -->
```

Rules:

- Name the legal entity (ИП, УНП) and link the requisites page on
  offer.bx-shef.by. Take the numbers from that page, don't retype them from
  memory.
- State what is **not** included (here: the 1C contractor's work).
- Other pages point to `llms.txt` for prices instead of copying the block.
- Say what the agent should put in the letter (on whose behalf, company,
  systems, scope) — as information, not as a command.
- The `[AI]` tag and the discount are self-declared; anyone can type them.
  That is acceptable for marketing; don't present it as verification.
- The contact address in plain text will be harvested by spam bots. Accept it
  or use a dedicated alias.

### 3.5 Keeping text in sync

On obmen the same content lives in three places: `site/*.html` (people),
`print/*.html` (PDFs), `site/*.md` (agents). A content change must touch all
three in one PR. The HTML pages carry a comment saying so; the offer block is
compared by CI; the rest relies on review.

## 4. nginx

Full working config: [`nginx.conf`](https://github.com/bx-shef/obmen/blob/main/nginx.conf). The parts that matter
(shortened — the real file has one line per URL in each map, including
`/index.html` next to `/`):

```nginx
# http context (a conf.d file is included there, so top level of the file works)
# One line per page URL that has a twin — list /index.html as well as /.
map "$uri|$http_accept" $markdown_target {
    default "";
    "~*^/\|.*text/markdown(?!\s*;\s*q=0(?:\.0+)?\s*(?:[,;]|$))"          /index.md;
    "~*^/plan\.html\|.*text/markdown(?!\s*;\s*q=0(?:\.0+)?\s*(?:[,;]|$))" /plan.md;
}
map $uri $html_link {
    default "";
    "/"          "</index.md>; rel=\"alternate\"; type=\"text/markdown\", </llms.txt>; rel=\"describedby\"";
    "/plan.html" "</plan.md>; rel=\"alternate\"; type=\"text/markdown\", </llms.txt>; rel=\"describedby\"";
}
map $uri $markdown_link {
    default    "";
    "/index.md" "<https://obmen.bx-shef.by/>; rel=\"canonical\", </llms.txt>; rel=\"describedby\"";
}

server {
    charset_types … text/plain text/markdown …;
    gzip_types    … text/plain text/markdown …;

    location ~* \.html$ {
        # … security headers …
        add_header Vary Accept always;
        add_header Link $html_link always;
        if ($markdown_target) { rewrite ^ $markdown_target last; }
        try_files $uri =404;
    }
    location ~* \.md$ {
        types { text/markdown md; }
        add_header X-Content-Type-Options nosniff always;
        add_header Cache-Control "no-cache" always;
        add_header Vary Accept always;
        add_header Link $markdown_link always;
        try_files $uri =404;
    }
}
```

What each piece is for, and the traps:

- **Key the map on `"$uri|$http_accept"` and anchor the URI with `^`.** Keyed
  the other way round, `…/index.html$` also matches `/sub/index.html` and
  serves the wrong twin.
- **Honour `q=0`.** A plain `text/markdown` substring match serves Markdown to
  a client that explicitly refused it (`text/markdown;q=0`). The negative
  lookahead above handles `q=0`, `q=0.0`, spaces and case.
- **Browsers never send `text/markdown`**, so negotiation does not change what
  people see.
- **`Vary: Accept`** on both the HTML and the Markdown answers, so caches keep
  the two apart. The shared nginx-proxy does not cache; a CDN would need it.
- **`Link: rel="canonical"`** on the Markdown points back to the HTML, so search
  engines index the HTML page and not its twin.
- **`add_header` with an empty value adds nothing** — that is how pages without
  a twin get no `Link` header. Use full header values in the map, not pieces.
- **`add_header` is not inherited** by a location that declares its own; repeat
  the security set in each location that serves HTML.
- **`if` with only a `rewrite … last` is a safe use of `if`.** The rewritten
  request is matched again, so the Markdown gets the `.md` location's headers
  (no CSP needed: `text/markdown` is not rendered, and `nosniff` is set).
- **`types { text/markdown md; }` inside the location** only affects that
  location; the stock `mime.types` has no `.md` entry.
- Add `text/markdown` to `charset_types` (Cyrillic needs `charset=utf-8`) and
  `gzip_types`. Remember `text/xml` too: `sitemap.xml` is served as `text/xml`,
  not `application/xml`.
- Validate: `docker run --rm -v $PWD/nginx.conf:/etc/nginx/conf.d/default.conf:ro nginxinc/nginx-unprivileged:1.31-alpine nginx -t`

## 5. CI checks

All in [`.github/workflows/ci.yml`](https://github.com/bx-shef/obmen/blob/main/.github/workflows/ci.yml), step
"Smoke test container", run against the built image. Agent-related:

- every `site/*.html` has `<link rel="alternate" type="text/markdown">`, and the
  twin is served as `text/markdown`;
- the page URL returns Markdown for `Accept: text/markdown` and HTML for a
  browser `Accept`;
- `/llms.txt` starts with an H1 and keeps its required sections;
- every `https://obmen.bx-shef.by/…` link in `llms.txt`, `index.md`, `plan.md`
  returns 200 (links to other domains are skipped);
- the offer block is identical in `llms.txt` and `index.md` (`sed` between the
  markers + `diff`);
- per page: exactly one `og:image` at `/files/<name>.png` on the canonical
  domain, served as `image/png`, 1200×630 by the PNG header; the other
  required OG / Twitter tags (section 6) are present.

The same step also checks the rest of the site: security headers on the HTML,
200 for every asset, PDF, `robots.txt` and `sitemap.xml`, 404 for an unknown
path.

Write negative tests when adding a check: break the input on purpose and make
sure the step fails with a readable `::error::`.

## 6. Open Graph images

Agents and messengers both use the preview:

- One card per page, **1200×630 PNG**, absolute URL on the canonical domain.
- Tags: `og:image`, `og:image:type`, `og:image:width`, `og:image:height`,
  `og:image:alt`, plus `twitter:card=summary_large_image` and `twitter:image`.
- Render at build time from a template in the page's style (obmen:
  `print/og.html` → `/files/og*.png`), not by hand.
- Fonts: list your own fonts as fallbacks (`Manrope, Inter, JB`). A glyph missing
  from the main font (`↔`, `✕`) otherwise falls back to a system font that
  differs between machines. Check with `fontTools` which font has the glyph.
- CI checks all of the above except the picture itself: look at the `rendered`
  artifact of the CI run before merging.

## 7. Lessons from the implementation

- **`grep` under `set -euo pipefail`**: a `grep` that finds nothing inside
  `$(…)` aborts the script silently, before your error message. Add `|| true`
  and test the empty value explicitly.
- **Docker build cache keeps file dates.** A cached render stage keeps the old
  `Last-Modified`, so the date of a PDF does not prove which image is live.
  Check content instead (e.g. `curl … /llms.txt | grep <new text>`).
- **Watchtower picks a new image up in about 4–5 minutes.** Wait for that
  before declaring a deploy broken; a request during the swap can fail once.
- **Makefiles that download themselves**: pin the ref with `override REF :=`
  (a command-line value is expanded by make even under `-n`), and never
  validate a downloaded Makefile by running make on it — grep it.
- **Don't guess names, numbers or URLs.** Legal details, requisites, bot names
  and action SHAs come from their source (offer.bx-shef.by, vendor docs,
  `git ls-remote`).

## 8. Checklist for a new site

1. `robots.txt` does not block the agents you want (2.3).
2. `llms.txt`: H1, summary, prose with the offer block, H2 link lists,
   `## Optional` (3.2, 3.4).
3. A hand-written `.md` twin for every important page; absolute URLs; facts,
   not orders (3.1, 3.3). Write down where each text lives and keep the
   copies in sync (3.5).
4. `<link rel="alternate" type="text/markdown">` and
   `<link rel="describedby" href="/llms.txt">` in every page's `<head>`.
5. nginx: `.md` type, negotiation with `q=0` and anchored URI, `Vary`, `Link`,
   canonical, charset and gzip for `text/markdown` (4).
6. OG card per page, 1200×630 (6).
7. CI: the checks in section 5, each with a negative test.
8. After deploy (wait ~5 minutes for Watchtower), run
   `scripts/agent-audit.sh <site>` against the live site (2.1).
