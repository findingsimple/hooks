#!/usr/bin/env bash
# ~/.claude/hooks/save-plan.sh
#
# PostToolUse hook for ExitPlanMode
# Reads the accepted plan from the Claude Code plan file,
# derives the filename from the plan's "Plan: ..." title line, then
# copies the plan to your Obsidian vault.
#
# Required env var in ~/.zshrc:
#   export OBSIDIAN_PLANS_PATH="..."

set -euo pipefail

# ── 0. Check required env var ────────────────────────────────────────────────
if [[ -z "${OBSIDIAN_PLANS_PATH:-}" ]]; then
  echo "save-plan: OBSIDIAN_PLANS_PATH is not set. Add it to ~/.zshrc and restart." >&2
  exit 0
fi

OBSIDIAN_DIR="$OBSIDIAN_PLANS_PATH"

# ── 1. Consume stdin (required by hook protocol, even if unused) ─────────────
INPUT=$(cat)

# ── 2. Find the plan file Claude just wrote ──────────────────────────────────
#    Claude Code writes plans to $HOME/.claude/plans/<session>.md
#    We grab the most recently modified one.
PLAN_FILE=$(find "$HOME/.claude/plans" -maxdepth 1 -name "*.md" -type f -print0 \
  2>/dev/null | xargs -0 ls -t 2>/dev/null | head -n1 || true)

if [[ -z "$PLAN_FILE" ]]; then
  echo "save-plan: no plan file found in ~/.claude/plans, skipping." >&2
  exit 0
fi

PLAN_CONTENT=$(cat "$PLAN_FILE")

if [[ -z "$PLAN_CONTENT" ]]; then
  echo "save-plan: plan file is empty, skipping." >&2
  exit 0
fi

# ── 3. Extract title from "Plan: Some Title" line ────────────────────────────
#    Matches lines like:  Plan: Create code-sherpa agent
#    Falls back to a timestamp if no such line exists.
RAW_TITLE=$(echo "$PLAN_CONTENT" | grep -m1 -iE '^Plan:' | sed 's/^[^:]*:[[:space:]]*//' || true)

if [[ -n "$RAW_TITLE" ]]; then
  # Convert to kebab-case: lowercase, replace spaces/special chars with hyphens
  SMART_NAME=$(echo "$RAW_TITLE" \
    | tr '[:upper:]' '[:lower:]' \
    | sed 's/[^a-z0-9]/-/g' \
    | sed 's/-\{2,\}/-/g' \
    | sed 's/^-//;s/-$//' \
    | cut -c1-80 \
    | sed 's/-[^-]*$//')
else
  echo "save-plan: no 'Plan:' title found, using timestamp." >&2
  SMART_NAME="plan-$(date +%Y%m%d-%H%M%S)"
fi

# ── 4. Build destination path with date prefix ───────────────────────────────
DATE_PREFIX=$(date +%Y-%m-%d)
DEST_FILENAME="${DATE_PREFIX}-${SMART_NAME}.md"
DEST_PATH="${OBSIDIAN_DIR}/${DEST_FILENAME}"

# ── 5. Ensure destination directory exists ───────────────────────────────────
mkdir -p "${OBSIDIAN_DIR}"

# ── 6. Avoid silently overwriting an existing plan ───────────────────────────
if [[ -f "$DEST_PATH" ]]; then
  COUNTER=1
  while [[ -f "${OBSIDIAN_DIR}/${DATE_PREFIX}-${SMART_NAME}-${COUNTER}.md" ]]; do
    ((COUNTER++))
  done
  DEST_FILENAME="${DATE_PREFIX}-${SMART_NAME}-${COUNTER}.md"
  DEST_PATH="${OBSIDIAN_DIR}/${DEST_FILENAME}"
fi

# ── 7. Copy plan, prepending YAML front matter for Obsidian ─────────────────
{
  echo "---"
  echo "created: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "source: claude-code-plan-mode"
  echo "---"
  echo ""
  cat "$PLAN_FILE"
} > "${DEST_PATH}"

echo "save-plan: Plan saved → ${DEST_FILENAME}" >&2

# ── 8. Regenerate Plans/_Index.md ───────────────────────────────────────────
#    Keeps the index current without needing a separate vault-linker run.
#    Same format as vault-linker's generate_plans_index().
INDEX_PATH="${OBSIDIAN_DIR}/_Index.md"
TMP_INDEX="${INDEX_PATH}.tmp"

{
  echo "---"
  echo "type: index"
  echo "scope: plans"
  echo "generated: true"
  echo "---"
  echo ""
  echo "# Plans"
  echo ""
  echo "| Date | Plan |"
  echo "|------|------|"

  # List .md files reverse-sorted (newest first), skip _ prefixed files
  # Use cd + glob to avoid word-splitting on spaces in the iCloud path
  (cd "${OBSIDIAN_DIR}" && ls -1r *.md 2>/dev/null) | while IFS= read -r BASENAME; do
    # Skip index/meta files
    [[ "$BASENAME" == _* ]] && continue

    NAME="${BASENAME%.md}"
    FILE_DATE="${NAME:0:10}"

    # Read first H1 heading for title, fallback to filename
    TITLE=$(grep -m1 '^# ' "${OBSIDIAN_DIR}/${BASENAME}" 2>/dev/null | sed 's/^# //' || true)
    if [[ -z "$TITLE" ]]; then
      TITLE="$NAME"
    fi

    echo "| ${FILE_DATE} | [[${NAME}\\|${TITLE}]] |"
  done

  echo ""
} > "$TMP_INDEX"

mv "$TMP_INDEX" "$INDEX_PATH"
echo "save-plan: Index updated → _Index.md" >&2
