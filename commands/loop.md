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
1. PRE-FLIGHT: verify on main, no orphan worktrees, no unmerged DELIVERED
2. READ plan.md → find executable sprints (PENDING + deps MERGED)
3. EXIT if all MERGED or all BLOCKED
4. ROLLING BATCH DISPATCH (capped, overlap-gated):
   - Gate 1: ACTIVE + DELIVERED < max_parallel (dispatch-config.json, default 3)
   - Gate 2: No convergence file conflicts with active sprints
   - Gate 3: No file overlap between active sprints
   - Hook `enforce-dispatch-gate.sh` enforces all gates at tool level
5. WAIT for agents
6. EVALUATE + E2E VERIFY (per /selfmodel:review)
   - Optional: run `scripts/verify-delivery.sh` to audit declared vs actual files
7. ACT on verdict (serial merge by Sprint number, rebase-then-merge)
8. CHECKPOINT (next-session.md, quality.jsonl)
9. CHECK context (>70% → reset)
10. Phase boundary → Gate → FORCE RESET
11. GOTO 1

## Options
- `--dry-run`: Show plan without executing
- `--phase N`: Start from specific phase
