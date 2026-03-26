# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

This repository contains Claude Code hook scripts — shell scripts that run automatically in response to Claude Code lifecycle events (e.g., PostToolUse). These hooks are referenced from `~/.claude/settings.json` and execute in the Claude Code harness.

## Repository Structure

- `save-plan.sh` — PostToolUse hook for `ExitPlanMode`. Copies the most recently modified plan from `$HOME/.claude/plans/` into an Obsidian vault with YAML front matter and a date-prefixed kebab-case filename derived from the plan's `Plan: ...` title line. Appends a numeric suffix to avoid overwriting same-day duplicates.
- `guard-bash.sh` — PreToolUse hook for `Bash`. Inspects commands against a blocklist of dangerous patterns (recursive deletes, force push to main/master, sudo, fork bombs, etc.) and denies execution with a reason message sent back to Claude. Fail-open design: if parsing fails, the command is allowed.
- **Stop agent hook** — configured directly in `~/.claude/settings.json` as a native `type: "agent"` hook (no shell script). Spawns a sub-agent to review uncommitted code changes before Claude finishes. Skips review when `stop_hook_active` is true (loop prevention) or when no code changes exist.

## Environment Dependencies

- **`OBSIDIAN_PLANS_PATH`** — required env var (set in `~/.zshrc`) pointing to the Obsidian vault directory where plans are saved.
- Plans are read from `$HOME/.claude/plans/*.md`.

## Privacy

Do not include business information or personally identifiable information (PII) in scripts, filenames, directory names, or comments. Use environment variables for any paths or values that could reveal sensitive details.

## Hook Script Conventions

- Scripts use `#!/usr/bin/env bash` with `set -euo pipefail`.
- Hook stdin is consumed via `INPUT=$(cat)` even if unused (required by the hook protocol).
- Errors/status are written to stderr; stdout is reserved for hook protocol output.
- Scripts exit 0 on non-fatal issues (missing files, empty content) to avoid blocking Claude Code.
- Filenames follow the pattern: `YYYY-MM-DD-kebab-case-title.md` (with `-N` suffix for duplicates).
- Filenames are truncated to 80 chars on a whole-word boundary.
- **Use the modern hook output format** to avoid phantom "hook error" labels in the UI (see [#17088](https://github.com/anthropics/claude-code/issues/17088)). The modern format wraps `hookSpecificOutput` with `continue`, `suppressOutput`, and `hookEventName` fields:
  ```json
  {"continue":true,"suppressOutput":true,"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":""}}
  ```

## Testing

No test framework. Validate scripts manually:
```bash
# Syntax check
bash -n save-plan.sh

# Dry run (requires OBSIDIAN_PLANS_PATH and a plan file in ~/.claude/plans/)
echo '{}' | bash save-plan.sh
```
