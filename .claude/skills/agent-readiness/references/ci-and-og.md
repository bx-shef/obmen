# CI checks and Open Graph cards

Part of the agent-readiness skill (see ../SKILL.md).

## CI checks

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
  required OG / Twitter tags (see "Open Graph images" below) are present.

The same step also checks the rest of the site: security headers on the HTML,
200 for every asset, PDF, `robots.txt` and `sitemap.xml`, 404 for an unknown
path.

Write negative tests when adding a check: break the input on purpose and make
sure the step fails with a readable `::error::`.

## Open Graph images

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
