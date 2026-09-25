#!/usr/bin/env bash
# Wrapper: the audit lives in the agent-readiness skill so it travels with it.
exec "$(dirname "$0")/../.claude/skills/agent-readiness/scripts/agent-audit.sh" "$@"
