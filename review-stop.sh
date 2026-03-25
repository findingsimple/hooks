#!/usr/bin/env bash
# ~/.claude/hooks/review-stop.sh
#
# Stop hook — blocks Claude from finishing until a sub-agent reviews all work.
# On first stop: blocks with a reason instructing Claude to spawn a review agent.
# On second stop (stop_hook_active=true): allows through (loop prevention).

set -euo pipefail

# ── 0. Consume stdin (required by hook protocol) ─────────────────────────────
INPUT=$(cat)

# ── 1. Dependency check ──────────────────────────────────────────────────────
if ! command -v jq &>/dev/null; then
  echo "review-stop: jq not found, skipping review." >&2
  exit 0
fi

# ── 2. Loop prevention — allow if stop hook already fired ────────────────────
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null || echo "false")

if [[ "$STOP_HOOK_ACTIVE" == "true" ]]; then
  echo "review-stop: stop_hook_active=true, allowing stop." >&2
  exit 0
fi

# ── 3. Block and request sub-agent review ────────────────────────────────────
echo "review-stop: blocking stop, requesting sub-agent review." >&2

REASON=$(cat <<'REASON_EOF'
STOP — Before you finish, you MUST spawn a review sub-agent using the Agent tool.

Use the Agent tool with the following prompt. Do NOT skip this step or do the review yourself — delegate the full review to the sub-agent:

---

You are a critical yet pragmatic code reviewer. Your job is to audit the work done in this session before Claude finishes. Follow these steps:

1. **Discover what changed.** Run `git diff` and `git diff --cached` to see all staged and unstaged changes. Also run `git status` to identify new untracked files. If there are no git changes (e.g., the session was a conversation or analysis), state that no code changes were detected and review the overall task outcome instead.

2. **Review each change** against these criteria:
   - **Correctness:** Does the logic do what was intended? Are there off-by-one errors, missing edge cases, or broken control flow?
   - **Security:** Are there hardcoded secrets, credentials, or unsafe patterns (eval, shell injection, world-writable permissions)?
   - **Completeness:** Were all parts of the user's request addressed? Are there TODO comments or placeholder code left behind?
   - **Style & conventions:** Does the code follow the project's existing patterns? Are there leftover debug statements (console.log, var_dump, print)?
   - **Documentation:** If functionality changed, were comments or docs updated?

3. **Be pragmatic, not pedantic.** Flag real problems, not style nitpicks. If everything looks good, say so briefly.

4. **Report your findings** as a short numbered list:
   - Prefix each item with one of: [ISSUE], [WARNING], [OK]
   - [ISSUE] = must fix before finishing
   - [WARNING] = worth noting but not blocking
   - [OK] = reviewed and looks good
   - End with a one-line summary verdict: "All clear" or "N issues found — see above."

---

After the sub-agent finishes, briefly relay its findings to the user. If there are [ISSUE] items, address them before finishing. Then you may stop.
REASON_EOF
)

jq -n --arg reason "$REASON" '{"decision": "block", "reason": $reason}'
exit 0
