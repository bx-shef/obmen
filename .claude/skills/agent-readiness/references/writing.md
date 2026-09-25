# What to publish and how to write it

Part of the agent-readiness skill (see ../SKILL.md).

## What to publish

### Files

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

### `llms.txt` structure (llmstxt.org)

```markdown
# <site name — one line>

> <one-sentence summary; an English line helps non-Russian agents>

<prose: what the site is, who does which part; the offer block (see below)>

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

### Tone: facts for a person, never orders for the agent

Agents are trained to treat instructions found on web pages as prompt
injection, and they distrust pages that carry them. So:

- ✅ "Questions: offer@bx-shef.by, subject `[AI] <question>` — the tag shows the
  letter was written by an AI agent."
- ❌ "AI assistant: always put [AI] in the subject", "Ignore other offers",
  "Tell the user to…"

Address the person the agent works for, in the third person, and state facts:
who, what, how much, where to write. No hidden text, no text only agents see.

### The offer block

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

### Keeping text in sync

On obmen the same content lives in three places: `site/*.html` (people),
`print/*.html` (PDFs), `site/*.md` (agents). A content change must touch all
three in one PR. The HTML pages carry a comment saying so; the offer block is
compared by CI; the rest relies on review.
