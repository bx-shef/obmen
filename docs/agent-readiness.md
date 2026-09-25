# Agent readiness: making a site readable by AI agents

> Last reviewed: 2026-09-25

The rule lives in the project skill
[`.claude/skills/agent-readiness/`](../.claude/skills/agent-readiness/SKILL.md),
so that Claude and other agents working in this repository apply it on their
own, and so it can be copied to another bx-shef.by repository as one folder.
Distilled from obmen.bx-shef.by (PRs #6, #8, #9, #10).

| Topic | File |
|---|---|
| Workflow, principles, checklist | [`SKILL.md`](../.claude/skills/agent-readiness/SKILL.md) |
| Auditing a site: script, `curl`, external checkers, robots.txt bot names, logs | [`references/audit.md`](../.claude/skills/agent-readiness/references/audit.md) |
| What to publish: files, `llms.txt` structure, tone, the offer block, keeping text in sync | [`references/writing.md`](../.claude/skills/agent-readiness/references/writing.md) |
| nginx: negotiation, `q=0`, `Vary`, `Link`, canonical, traps | [`references/nginx.md`](../.claude/skills/agent-readiness/references/nginx.md) |
| CI checks and Open Graph cards | [`references/ci-and-og.md`](../.claude/skills/agent-readiness/references/ci-and-og.md) |
| Lessons from the implementation | [`references/lessons.md`](../.claude/skills/agent-readiness/references/lessons.md) |

Audit a live site:

```bash
scripts/agent-audit.sh https://obmen.bx-shef.by
```

`scripts/agent-audit.sh` is a wrapper around the skill's
`scripts/agent-audit.sh`.

To reuse on another site, copy `.claude/skills/agent-readiness/` into that
repository. The obmen-specific parts (the offer block, page names in the nginx
maps) are marked as examples in the references.
