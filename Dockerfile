# Static site: no build step, files are served as committed.
# nginx-unprivileged runs as the non-root `nginx` user and listens on :8080.
FROM nginxinc/nginx-unprivileged:1.31-alpine AS runner
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY site/ /usr/share/nginx/html/
# Validate the final config at build time, so a syntax error fails the PR
# docker-build instead of surfacing only on the server.
RUN nginx -t
EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]
