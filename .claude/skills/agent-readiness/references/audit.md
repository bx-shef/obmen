# Auditing a site

Part of the agent-readiness skill (see ../SKILL.md).

## Audit: how to check where a site stands

Run these against the live site before and after changes. Replace `$SITE`.

### From the command line

Run the audit script bundled with this skill — it prints PASS / FAIL per check
and exits non-zero on a failure. It needs only `curl` and `python3`, so it works
for any site (in the obmen repo, `scripts/agent-audit.sh` is a wrapper for it):

```bash
.claude/skills/agent-readiness/scripts/agent-audit.sh https://obmen.bx-shef.by   # pages / and /plan.html
.claude/skills/agent-readiness/scripts/agent-audit.sh https://example.bx-shef.by / /about.html
```

It checks: robots.txt lets `ChatGPT-User`, `Claude-User`, `Perplexity-User`
in; `/llms.txt` is text and starts with an H1; for each page — the Markdown twin
link and its type, `rel="describedby"`, `Vary: Accept`, the `Link` header,
negotiation for an agent, a browser and `q=0`, `charset=utf-8` and
`rel="canonical"` on the Markdown, the Open Graph tags and a 1200×630 PNG card.
The tone of the text (writing.md, "Tone") is not checkable by a script — read it.

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

# robots.txt must not block the agents you want (see "robots.txt and bot names" below)
curl -s "$SITE/robots.txt"

# Open Graph: one og:image, absolute URL, served as an image
curl -s "$SITE/" | grep -oE '<meta property="og:[^>]+>'
```

### External tools

| Tool | What it tells you |
|---|---|
| [llmstxt.org](https://llmstxt.org/) | The `llms.txt` spec: the reference for structure |
| [acceptmarkdown.com/status](https://acceptmarkdown.com/status) | Which agents send `Accept: text/markdown`, which follow `<link rel="alternate">`, which only read HTML |
| [keep.md — Markdown for Agents checker](https://keep.md/tools/markdown-for-agents) | Runs negotiation, `.md` twin, `<link>`/`Link` header, caching and `llms.txt` checks against a URL |
| Google Search Console, Bing Webmaster Tools | Classic indexing of the HTML: coverage, sitemap, canonical. Markdown twins must **not** show up as separate pages there |
| `site:obmen.bx-shef.by` in a search engine | Quick look at what is indexed; `.md` URLs in results mean the canonical link is missing |
| Facebook Sharing Debugger, LinkedIn Post Inspector | Debugging an OG preview that looks wrong. Optional: not part of a normal release |

### robots.txt and bot names

`User-agent: *` + `Allow: /` (what obmen has) lets everyone in. If a site ever
restricts bots, decide per purpose instead of blanket-blocking. Names change,
so check the vendor's docs before editing:

| Purpose | User agents |
|---|---|
| Live fetch on a person's request | `ChatGPT-User`, `Claude-User`, `Perplexity-User` |
| AI search index | `OAI-SearchBot`, `Claude-SearchBot`, `PerplexityBot` |
| Model training | `GPTBot`, `ClaudeBot`, `Google-Extended`, `Applebot-Extended`, `CCBot` |

Blocking the first two groups removes the site from agent answers.

### Logs: is anyone using it?

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
