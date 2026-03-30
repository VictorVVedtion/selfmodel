---
description: "Auto-orchestration loop: read plan, dispatch, review, merge, repeat"
allowed-tools: ["Read", "Write", "Edit", "Bash", "Glob", "Grep", "Agent"]
argument-hint: "[--dry-run] [--phase N]"
---

# /selfmodel:loop

Execute the full orchestration loop per `{baseDir}/references/orchestration-loop.md`.

## Prerequisites
- `.selfmodel/state/plan.md` must exist (create with `/selfmodel:plan`)

## Loop
1. READ plan.md → find executable sprints (PENDING + deps MERGED)
2. EXIT if all MERGED or all BLOCKED
3. PARALLEL DISPATCH (write contracts, inbox, worktrees)
4. WAIT for agents
5. EVALUATE + E2E VERIFY (per /selfmodel:review)
6. ACT on verdict (merge/revise/reject, update plan)
7. CHECKPOINT (next-session.md, quality.jsonl)
8. CHECK context (>70% → reset)
9. Phase boundary → Gate → FORCE RESET
10. GOTO 1

## Options
- `--dry-run`: Show plan without executing
- `--phase N`: Start from specific phase
