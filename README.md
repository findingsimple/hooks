# Claude Code Hooks

Hooks that run automatically in response to Claude Code lifecycle events. Referenced from `~/.claude/settings.json`.

## Hooks

### `save-plan.sh`

**Type:** Command | **Event:** `PostToolUse` → `ExitPlanMode`

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

---

### `guard-bash.sh`

**Type:** Command | **Event:** `PreToolUse` → `Bash`

Inspects Bash commands against a blocklist of dangerous patterns and denies execution with a reason. Fail-open design: if parsing fails, the command is allowed.

**Blocked patterns include:**

- Recursive deletes of root, home, or glob paths (`rm -rf /`, `rm -rf ~`, etc.)
- Force push to main/master
- `git reset --hard`, `git checkout -- .`
- `sudo`, `chmod 777`, fork bombs
- Piping remote scripts to shell (`curl ... | bash`)
- `npm publish` / `npm unpublish`

**Setup:**

Register the hook in `~/.claude/settings.json`:
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/guard-bash.sh"
          }
        ]
      }
    ]
  }
}
```

---

### Review on Stop (agent hook)

**Type:** Agent | **Event:** `Stop`

Spawns a sub-agent to review uncommitted code changes before Claude finishes. The agent:

- Checks `stop_hook_active` to prevent infinite loops
- Skips review if the working tree is clean (no code changes)
- Reviews diffs for correctness, security, completeness, and style
- Returns actionable feedback that the main agent can fix immediately

**Setup:**

Register the hook in `~/.claude/settings.json`:
```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "agent",
            "prompt": "Your review prompt here...",
            "timeout": 120
          }
        ]
      }
    ]
  }
}
```
