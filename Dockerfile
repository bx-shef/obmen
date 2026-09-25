# Stage 1: render the print PDFs from print/, so every deploy ships PDFs that
# match their sources (the PDFs are build output, not committed files).
# The image tag pins Chromium; keep it equal to the version in
# print/requirements.txt — each Playwright release bundles its own Chromium.
FROM mcr.microsoft.com/playwright/python:v1.56.0-noble AS pdf
WORKDIR /src
COPY print/requirements.txt print/
RUN pip install --no-cache-dir --break-system-packages -r print/requirements.txt
COPY print/ print/
RUN python print/render.py

# Stage 2: static site. nginx-unprivileged runs as the non-root `nginx` user
# and listens on :8080.
FROM nginxinc/nginx-unprivileged:1.31-alpine AS runner
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY site/ /usr/share/nginx/html/
COPY --from=pdf /src/site/files/ /usr/share/nginx/html/files/
# Validate the final config at build time, so a syntax error fails the PR
# docker-build instead of surfacing only on the server.
RUN nginx -t
EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]
