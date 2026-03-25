# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

This repository contains Claude Code hook scripts — shell scripts that run automatically in response to Claude Code lifecycle events (e.g., PostToolUse). These hooks are referenced from `~/.claude/settings.json` and execute in the Claude Code harness.

## Repository Structure

- `save-plan.sh` — PostToolUse hook for `ExitPlanMode`. Copies the most recently modified plan from `$HOME/.claude/plans/` into an Obsidian vault with YAML front matter and a date-prefixed kebab-case filename derived from the plan's `Plan: ...` title line. Appends a numeric suffix to avoid overwriting same-day duplicates.

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

## Testing

No test framework. Validate scripts manually:
```bash
# Syntax check
bash -n save-plan.sh

# Dry run (requires OBSIDIAN_PLANS_PATH and a plan file in ~/.claude/plans/)
echo '{}' | bash save-plan.sh
```
