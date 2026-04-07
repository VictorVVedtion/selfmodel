---
description: "View selfmodel team status (prefer CLI: selfmodel)"
allowed-tools: ["Read", "Bash", "Glob"]
---

# /selfmodel:status

Display current selfmodel state.

## Steps

1. Read: team.json, plan.md, active contracts, quality.jsonl, `git worktree list`
2. Output dashboard:
   - Sprint count, session count, detected stack
   - Agent roster: Gemini/Codex/Opus status, sprint count, avg score
   - Active contracts list
   - Worktree list
   - Quality trend (last 5 scores)
   - Plan progress (if plan.md exists)
