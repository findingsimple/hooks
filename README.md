# Claude Code Hooks

Shell scripts that run automatically in response to Claude Code lifecycle events. Referenced from `~/.claude/settings.json`.

## Hooks

### `save-plan.sh`

**Event:** `PostToolUse` → `ExitPlanMode`

Copies the most recently modified plan from `$HOME/.claude/plans/` into an Obsidian vault. The plan is saved with:

- YAML front matter (`created`, `source`)
- Date-prefixed kebab-case filename derived from the plan's `Plan: ...` title line (truncated to 80 chars on a whole-word boundary)
- Numeric suffix (`-1`, `-2`, ...) to avoid overwriting same-day duplicates
- Fallback to a timestamp-based filename if no title is found
- Handles filenames with spaces and special characters safely

**Setup:**

1. Add the env var to `~/.zshrc`:
   ```bash
   export OBSIDIAN_PLANS_PATH="/path/to/your/obsidian/vault/Plans"
   ```

2. Register the hook in `~/.claude/settings.json`:
   ```json
   {
     "hooks": {
       "PostToolUse": [
         {
           "matcher": "ExitPlanMode",
           "hooks": [
             {
               "type": "command",
               "command": "~/.claude/hooks/save-plan.sh"
             }
           ]
         }
       ]
     }
   }
   ```

3. Restart your shell and Claude Code.
