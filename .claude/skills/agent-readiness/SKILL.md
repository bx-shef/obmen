---
name: agent-readiness
description: Make a website readable by AI agents and audit how well it already is — llms.txt, hand-written Markdown twins of pages (.md), the HTML link rel="alternate" type="text/markdown", nginx content negotiation on Accept text/markdown, Link/Vary/canonical headers, robots.txt rules for AI bots (GPTBot, ClaudeBot, Claude-User, ChatGPT-User, PerplexityBot), Open Graph share cards, and the CI checks that keep all of it working. Use this whenever someone wants AI assistants, LLMs or agents to read, understand, cite or order from a site, asks about llms.txt or "markdown for agents", wants prices/contacts/offers written for AI, wants to check or improve a site's "AI indexing" / AI visibility, or edits nginx to serve Markdown — even if they don't say "agent readiness". Also for Russian requests such as "чтобы ИИ читали сайт", "разметка для ИИ-агентов", "ИИ-индексация", "сделать llms.txt", "проверить сайт для нейросетей". Distilled from obmen.bx-shef.by.
---

# Agent readiness

> Last reviewed: 2026-09-25

Make a site easy for an AI agent to read on a person's behalf, and prove it
with checks. Worked example: obmen.bx-shef.by (repo `bx-shef/obmen`).

## Who this is for (set expectations first)

- The audience is **agents working for a person** — Claude Code, Cursor,
  Copilot, Codex, in-product assistants — who land on one URL and must answer
  "how does it work / what does it cost / whom do I write to".
- **Search bots mostly ignore `llms.txt`**; Google has said it doesn't use it.
  Don't promise SEO gains.
- Markdown is typically 80–95% smaller than the HTML of the same page, so an
  agent reads more of the substance in the same context.

## Workflow

1. **Audit the live site.** Run
   `.claude/skills/agent-readiness/scripts/agent-audit.sh <site> [pages]`
   (PASS/FAIL per check, non-zero exit on failure). Details, manual
   `curl` commands, external checkers, robots.txt bot names and logging:
   `references/audit.md`.
2. **Write the agent-facing text** — `/llms.txt` and a hand-written `.md` twin
   per important page, with one shared offer block (contractor, prices,
   discount, contact). Structure, tone and the offer block:
   `references/writing.md`.
3. **Link it** from each page's `<head>`:
   `<link rel="alternate" type="text/markdown" href="/page.md">` and
   `<link rel="describedby" href="/llms.txt">`.
4. **Configure nginx** — `.md` MIME type, negotiation on
   `Accept: text/markdown` (honour `q=0`, anchor the URI), `Vary: Accept`,
   `Link` headers, `rel="canonical"` back to the HTML, charset and gzip:
   `references/nginx.md`.
5. **Add an Open Graph card** per page (1200×630 PNG, full tag set) and the
   **CI checks** with a negative test for each: `references/ci-and-og.md`.
6. **Ship through the normal PR and review; the owner approves the merge**
   that deploys it — don't push or deploy on your own. Once it is live
   (Watchtower: ~5 minutes), **run the audit again** against the live site.

`references/lessons.md` lists traps we hit along the way (pipefail, Docker
cache dates, Makefile self-update, deploy timing). Skim it before step 4–5.

## Principles

- **Facts for a person, never orders for the agent.** Agents are trained to
  treat instructions found on web pages as prompt injection and distrust such
  pages. Write "questions: offer@…, subject `[AI] <question>`", not "AI: always
  do X". No hidden text, nothing only agents can see.
- **Write the Markdown by hand.** Keep facts (tables, lists, names, numbers),
  drop layout and marketing. It is a short twin, not a conversion.
- **One source for commercial terms.** Contractor, prices, discount and contact
  live in one block, identical in every file that carries it, compared by CI.
  Other pages link to `llms.txt` instead of copying it.
- **Don't guess.** Legal names, tax IDs, requisites URLs, bot names and action
  SHAs come from their source (the company's site, vendor docs,
  `git ls-remote`). Ask the owner for prices and terms; never invent them.
- **Every check gets a negative test.** Break the input on purpose and confirm
  the check fails with a readable message.

## Checklist

1. `robots.txt` does not block agents acting for a person (`ChatGPT-User`,
   `Claude-User`, `Perplexity-User`).
2. `/llms.txt`: H1, one-line summary, prose with the offer block before the
   first H2, H2 sections that are link lists, `## Optional`.
3. A hand-written `.md` twin for every important page; absolute URLs; no
   punctuation glued to a URL; facts, not orders. Record where each copy of
   the text lives and keep them in sync.
4. `<link rel="alternate" type="text/markdown">` and
   `<link rel="describedby" href="/llms.txt">` in every page's `<head>`.
5. nginx: `.md` type; negotiation with `q=0` and anchored URI; `Vary: Accept`;
   `Link` headers; canonical; `text/markdown` in `charset_types` and
   `gzip_types`.
6. Open Graph card per page: 1200×630 PNG, `og:image` (absolute),
   `og:image:type/width/height/alt`, `twitter:card`, `twitter:image`.
7. CI: the checks in `references/ci-and-og.md`, each with a negative test.
8. After deploy: `.claude/skills/agent-readiness/scripts/agent-audit.sh <site>`
   passes on the live site.
