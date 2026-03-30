---
description: "Create a Sprint contract and dispatch an agent"
allowed-tools: ["Read", "Write", "Edit", "Bash", "Glob", "Grep", "Agent"]
argument-hint: "<objective> [--agent gemini|codex|opus] [--research]"
---

# /selfmodel:sprint

Interactive Sprint creation and agent dispatch.

## Flow

1. **Load Context**: Read team.json, plan.md (if exists), active contracts
2. **Determine Sprint Details**: From plan or ask user (Objective, Deliverables, AC)
3. **Route to Agent**: Load `{baseDir}/references/dispatch-rules.md`, auto-route by keywords
4. **Create Contract**: Increment sprint number, write to `contracts/active/sprint-<N>.md`
5. **Write Inbox Task**: Create `.selfmodel/inbox/<agent>/sprint-<N>.md`
6. **Create Worktree**: For CLI agents use git-worktree, for Opus use Agent tool isolation
7. **Dispatch**: Execute per dispatch-rules.md CLI templates
8. **Output**: Sprint number, agent, contract path, worktree path, status

Remind user: run `/selfmodel:review` after agent completes.
