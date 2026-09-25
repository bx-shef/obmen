#!/usr/bin/env bash
# Wrapper: the audit lives in the agent-readiness skill so it travels with it.
# readlink -f follows a symlink to this file back into the repository.
here=$(dirname "$(readlink -f "$0")")
exec "$here/../.claude/skills/agent-readiness/scripts/agent-audit.sh" "$@"
