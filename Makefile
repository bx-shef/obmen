.PHONY: build-local prod-up prod-down prod-pull prod-redeploy logs ps self-update compose-update help

# Shortcuts for the server and local preview. See README "Server (one-time)".
# Production targets run next to docker-compose.prod.yml and .env on the server
# (/home/bitrix/obmen) — the repository itself is not there.

COMPOSE := docker compose -f docker-compose.prod.yml
# Branch or tag that self-update / compose-update download from.
REF ?= main
RAW := https://raw.githubusercontent.com/bx-shef/obmen/$(REF)

# ─── Local ───────────────────────────────────────────────────────────

## Build the image (PDFs and OG cards included) and serve it on :8082
build-local:
	docker compose up --build

# ─── Production (on the server) ──────────────────────────────────────
# The shared host-wide Watchtower updates the container on its own (~5 min
# after a deploy); these targets are for doing it by hand.

## Start / update the container
prod-up:
	$(COMPOSE) up -d

## Stop the container
prod-down:
	$(COMPOSE) down

## Download the latest image without restarting
prod-pull:
	$(COMPOSE) pull

## Update right now, without waiting for Watchtower
prod-redeploy:
	$(COMPOSE) pull && \
	$(COMPOSE) up -d && \
	docker image prune -f

## Follow the container log (Ctrl+C to exit)
logs:
	$(COMPOSE) logs -f app

## Container state (look for "healthy")
ps:
	$(COMPOSE) ps

# Both update targets download to a mktemp file first, never `curl | sh`: a
# download cut short must not leave a half-written file in place.

## Update this Makefile from the repository (REF=main by default)
#
# The download is checked with a marker every version has (.PHONY and the
# prod-redeploy target), so an older Makefile can always update itself.
self-update:
	@t=$$(mktemp /tmp/Makefile.XXXXXX) && trap 'rm -f "$$t"' EXIT \
	  && curl -fsSL -o "$$t" "$(RAW)/Makefile" \
	  && grep -q '^\.PHONY:' "$$t" \
	  && make -n -f "$$t" prod-redeploy >/dev/null 2>&1 \
	  && { b="./Makefile.bak-$$(date +%Y%m%d-%H%M%S)"; \
	       cp ./Makefile "$$b" && cp "$$t" ./Makefile \
	       && echo "[make] Makefile updated from $(REF), previous copy: $$b"; \
	       make help; }

## Update docker-compose.prod.yml from the repository: shows the diff, CONFIRM=1 applies
#
#   make compose-update              # show what would change
#   make compose-update CONFIRM=1    # replace the file (a backup is kept)
#
# Watchtower does not touch this file, so compose changes reach the server only
# this way. The full diff is printed so a local edit is never lost unseen.
compose-update:
	@t=$$(mktemp /tmp/compose.XXXXXX) && trap 'rm -f "$$t"' EXIT \
	  && curl -fsSL -o "$$t" "$(RAW)/docker-compose.prod.yml" \
	  && docker compose --project-directory . -f "$$t" config -q \
	  && { if diff -u ./docker-compose.prod.yml "$$t" >/dev/null; then \
	         echo "[make] docker-compose.prod.yml already matches $(REF)"; exit 0; fi; \
	       echo "[make] differences from $(REF) (- server, + repository):"; \
	       diff -u ./docker-compose.prod.yml "$$t" | tail -n +3; \
	       if [ "$${CONFIRM:-}" = "1" ]; then \
	         b="./docker-compose.prod.yml.bak-$$(date +%Y%m%d-%H%M%S)"; \
	         cp ./docker-compose.prod.yml "$$b" && cp "$$t" ./docker-compose.prod.yml \
	         && echo "[make] replaced, previous copy: $$b. Apply: make prod-up"; \
	       else echo "[make] preview only. Apply: make compose-update CONFIRM=1"; fi; }

## List targets
help:
	@awk '/^## /{d=substr($$0,4)} \
	      /^[A-Za-z0-9_][A-Za-z0-9_.-]*:/{if(d!=""){printf "  %-16s %s\n", substr($$1,1,length($$1)-1), d; d=""}}' \
	      $(MAKEFILE_LIST)
