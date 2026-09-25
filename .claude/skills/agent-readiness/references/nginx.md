# nginx for Markdown twins

Part of the agent-readiness skill (see ../SKILL.md).

## nginx

Full working config (obmen's — your repository has its own): [`nginx.conf`](https://github.com/bx-shef/obmen/blob/main/nginx.conf). The parts that matter
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
