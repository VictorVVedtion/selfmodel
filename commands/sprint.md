---
description: "Create a Sprint contract and dispatch an agent"
allowed-tools: ["Read", "Write", "Edit", "Bash", "Glob", "Grep", "Agent"]
argument-hint: "<objective> [--agent gemini|codex|opus] [--research]"
---

# /selfmodel:sprint

Interactive Sprint creation and agent dispatch.

## Flow

1. **Load Context**: Read team.json, plan.md (if exists), active contracts, dispatch-config.json
2. **Dispatch Gate Check** (enforced by hook, but Leader should pre-check):
   a. Count active contracts < max_parallel (default 3)
   b. Check new Sprint's Files against convergence_files — conflict → serialize
   c. Check file overlap with other active contracts — overlap → merge or serialize
3. **Determine Sprint Details**: From plan or ask user (Objective, Files, Deliverables, AC)
4. **Route to Agent**: Load `{baseDir}/references/dispatch-rules.md`, auto-route by keywords
5. **Create Contract**: Increment sprint number, write to `contracts/active/sprint-<N>.md`
   - Contract MUST include structured `## Files` section (Creates/Modifies/Out of Scope)
6. **Write Inbox Task**: Create `.selfmodel/inbox/<agent>/sprint-<N>.md`
7. **Create Worktree**: For CLI agents use git-worktree, for Opus use Agent tool isolation
8. **Dispatch**: Execute per dispatch-rules.md CLI templates
   - Hook `enforce-dispatch-gate.sh` validates gates at tool level (hard block if failed)
9. **Output**: Sprint number, agent, contract path, worktree path, status

Remind user: run `/selfmodel:review` after agent completes.
