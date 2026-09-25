# Lessons from obmen

Part of the agent-readiness skill (see ../SKILL.md).

## Lessons from the implementation

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
