#!/usr/bin/env bash
# Audit how a live site serves AI agents (agent-readiness skill, references/audit.md).
# Prints PASS / FAIL / WARN per check; exits 1 if any check fails.
#
#   scripts/agent-audit.sh https://obmen.bx-shef.by [page ...]
#
# Pages default to "/" and "/plan.html". Needs curl and python3 (PNG size).
set -uo pipefail

site=${1:?usage: agent-audit.sh https://site [page ...]}
site=${site%/}
shift
pages=("${@:-/}")
[ $# -gt 0 ] || pages=(/ /plan.html)

fails=0
pass() { printf 'PASS  %s\n' "$*"; }
fail() { printf 'FAIL  %s\n' "$*"; fails=$((fails + 1)); }
warn() { printf 'WARN  %s\n' "$*"; }
ctype() { curl -s -o /dev/null -w '%{content_type}' "$@"; }

# robots.txt: agents acting for a person must not be blocked.
robots=$(curl -fsS "$site/robots.txt" 2>/dev/null || true)
if [ -z "$robots" ]; then
  warn "robots.txt missing (everything allowed)"
else
  python3 - "$robots" <<'PY' && pass "robots.txt allows ChatGPT-User, Claude-User, Perplexity-User" || fail "robots.txt blocks an agent acting for a person"
import sys, urllib.robotparser
rp = urllib.robotparser.RobotFileParser()
rp.parse(sys.argv[1].splitlines())
sys.exit(0 if all(rp.can_fetch(a, "/") for a in ("ChatGPT-User", "Claude-User", "Perplexity-User")) else 1)
PY
fi

# llms.txt: plain text, starts with an H1.
llms=$(curl -fsS "$site/llms.txt" 2>/dev/null || true)
if [ -z "$llms" ]; then
  fail "/llms.txt missing"
else
  [[ "$(ctype "$site/llms.txt")" == text/plain* || "$(ctype "$site/llms.txt")" == text/markdown* ]] \
    && pass "/llms.txt served as text" || fail "/llms.txt content type is $(ctype "$site/llms.txt")"
  head -1 <<<"$llms" | grep -q '^# ' && pass "/llms.txt starts with an H1" || fail "/llms.txt must start with '# '"
fi

for page in "${pages[@]}"; do
  url=$site$page
  html=$(curl -fsS -H 'Accept: text/html' "$url" 2>/dev/null || true)
  [ -n "$html" ] || { fail "$page is not reachable"; continue; }

  # Markdown twin: <link>, served as text/markdown.
  twin=$(grep -oE '<link rel="alternate" type="text/markdown" href="[^"]+"' <<<"$html" | sed -E 's/.*href="//; s/"$//' || true)
  if [ -z "$twin" ]; then
    fail "$page has no <link rel=\"alternate\" type=\"text/markdown\">"
  else
    [[ "$twin" == http* ]] || twin=$site$twin
    [[ "$(ctype "$twin")" == text/markdown* ]] && pass "$page twin $twin is text/markdown" || fail "$page twin $twin is $(ctype "$twin")"
  fi
  grep -q 'rel="describedby" href="/llms.txt"' <<<"$html" && pass "$page links /llms.txt" || warn "$page has no rel=describedby to /llms.txt"

  # HTTP headers and content negotiation.
  headers=$(curl -sI "$url")
  grep -qi '^vary:.*accept' <<<"$headers" && pass "$page sends Vary: Accept" || fail "$page lacks Vary: Accept"
  grep -qi '^link:.*text/markdown' <<<"$headers" && pass "$page sends a Link header to its twin" || warn "$page has no Link header"
  [[ "$(ctype -H 'Accept: text/markdown, */*' "$url")" == text/markdown* ]] \
    && pass "$page returns Markdown for Accept: text/markdown" || fail "$page ignores Accept: text/markdown"
  [[ "$(ctype -H 'Accept: text/html,*/*;q=0.8' "$url")" == text/html* ]] \
    && pass "$page returns HTML to a browser" || fail "$page does not return HTML to a browser"
  [[ "$(ctype -H 'Accept: text/markdown;q=0, text/html' "$url")" == text/html* ]] \
    && pass "$page honours text/markdown;q=0" || fail "$page serves Markdown despite q=0"
  # Checks on the Markdown answer itself, only when there is one.
  md_headers=$(curl -sI -H 'Accept: text/markdown' "$url")
  if grep -qi '^content-type: *text/markdown' <<<"$md_headers"; then
    grep -qi '^content-type:.*charset=utf-8' <<<"$md_headers" && pass "$page Markdown has charset=utf-8" || fail "$page Markdown has no charset"
    grep -qi 'rel="canonical"' <<<"$md_headers" && pass "$page Markdown points to a canonical HTML" || fail "$page Markdown has no rel=canonical"
  fi

  # Open Graph card.
  for tag in 'property="og:image"' 'property="og:image:width"' 'property="og:image:height"' 'property="og:image:alt"' 'name="twitter:card"'; do
    grep -q "<meta $tag" <<<"$html" || fail "$page lacks <meta $tag>"
  done
  img=$(grep -oE '<meta property="og:image" content="[^"]+"' <<<"$html" | sed -E 's/.*content="//; s/"$//' | head -1 || true)
  if [ -n "$img" ]; then
    # Download first: piping into a reader that stops after 24 bytes makes curl
    # fail with SIGPIPE, which pipefail would report as an error.
    tmp=$(mktemp) && trap 'rm -f "$tmp"' EXIT
    if curl -fsS -o "$tmp" "$img" 2>/dev/null; then
      size=$(python3 -c 'import struct,sys
d = open(sys.argv[1], "rb").read(24)
print("%dx%d" % struct.unpack(">II", d[16:24]) if d[:8] == b"\x89PNG\r\n\x1a\n" and len(d) == 24 else "not-a-png")' "$tmp")
    else
      size=unreachable
    fi
    [ "$size" = 1200x630 ] && pass "$page og:image is a 1200x630 PNG" || fail "$page og:image $img is $size"
  fi
done

echo
[ "$fails" -eq 0 ] && echo "All checks passed." || echo "$fails check(s) failed."
[ "$fails" -eq 0 ]
