#!/usr/bin/env bash
# ~/.claude/hooks/guard-bash.sh
#
# PreToolUse hook for Bash tool
# Inspects bash commands against a blocklist of dangerous patterns
# and denies execution with a reason message sent back to Claude.
#
# Requires: jq

set -euo pipefail

# ── 0. Consume stdin (required by hook protocol) ──────────────────────────────
INPUT=$(cat)

# ── 1. Extract the command string from hook JSON ──────────────────────────────
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)

if [[ -z "$COMMAND" ]]; then
  # Fail-open: can't parse or empty command — don't block
  echo '{"hookSpecificOutput":{"permissionDecision":"allow"}}'
  exit 0
fi

# ── 2. Dangerous patterns and their reasons ───────────────────────────────────
#    Indexed arrays for bash 3.2 compatibility (macOS default).
PATTERNS=(
  'rm\s+-[^\s]*r[^\s]*\s+(/|~|\*|\.\s*$)'
  'git\s+push\s+.*--force.*(main|master)'
  'git\s+push\s+.*(main|master).*--force'
  'git\s+reset\s+--hard'
  '(^|[\s;|&])sudo\s'
  'chmod\s+777'
  ':\(\)\s*\{'
  '>\s*/dev/sd[a-z]'
  '(^|[\s;|&])mkfs'
  '(^|[\s;|&])dd\s+if='
  'curl\s.*\|\s*(sh|bash)'
  'wget\s.*\|\s*(sh|bash)'
  'git\s+checkout\s+--\s+\.'
  'git\s+restore\s+\.'
  '(^|[\s;|&])npm\s+publish'
  '(^|[\s;|&])npm\s+unpublish'
)

REASONS=(
  "Recursive delete of root, home, or glob"
  "Force push to main/master"
  "Force push to main/master"
  "git reset --hard discards all uncommitted changes"
  "sudo requires explicit user approval"
  "chmod 777 sets world-writable permissions"
  "Fork bomb detected"
  "Writing to raw block device"
  "mkfs formats a filesystem — requires explicit approval"
  "dd disk overwrite — requires explicit approval"
  "Piping remote script to shell is unsafe"
  "Piping remote script to shell is unsafe"
  "git checkout -- . discards all working tree changes"
  "git restore . discards all working tree changes"
  "npm publish requires explicit approval"
  "npm unpublish requires explicit approval"
)

# ── 3. Check command against each pattern ─────────────────────────────────────
for i in "${!PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qE "${PATTERNS[$i]}"; then
    REASON="${REASONS[$i]}"
    echo "guard-bash: BLOCKED — ${REASON}" >&2
    jq -n --arg reason "Blocked: ${REASON}. Ask the user for permission before running this command." \
      '{"hookSpecificOutput":{"permissionDecision":"deny","permissionDecisionReason":$reason}}'
    exit 0
  fi
done

# ── 4. No pattern matched — allow ─────────────────────────────────────────────
echo '{"hookSpecificOutput":{"permissionDecision":"allow"}}'
exit 0
