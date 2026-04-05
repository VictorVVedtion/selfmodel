---
name: selfmodel
description: |
  Multi-AI agent team orchestration framework. Leader (Opus) orchestrates Gemini, Codex, and Opus agents
  via Sprint contracts, worktree isolation, independent evaluation, and E2E verification.
  Use when: "selfmodel", "multi-agent", "sprint", "dispatch agent", "team orchestration",
  "quality review", "worktree workflow", or when the project has a .selfmodel/ directory.
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep, Agent]
version: 3.0.0
---

# selfmodel — Multi-AI Agent Team Orchestration

A self-evolving AI agent team framework where the Leader (Claude Opus) orchestrates
specialized agents via Sprint contracts, worktree isolation, and independent quality gates.

## Sub-Commands

| Command | Purpose |
|---------|---------|
| `/selfmodel:init` | Initialize selfmodel in any project |
| `/selfmodel:sprint` | Create contract + dispatch agent |
| `/selfmodel:review` | Evaluate + E2E verify + merge/reject |
| `/selfmodel:status` | View team, sprints, and quality trends |
| `/selfmodel:plan` | Create/update multi-phase orchestration plan |
| `/selfmodel:loop` | Auto-orchestration loop (plan-driven) |

## Core Architecture

```
Leader (Opus 4.6) ─── orchestrate + arbitrate only, NEVER implement
  |
  |── Frontend Colleague (Gemini CLI)     ── UI/UX/CSS/components
  |── Backend Intern (Codex CLI)          ── single-file backend/utils
  |── Senior Fullstack (Opus Agent)       ── multi-file/complex systems
  |── Researcher (Gemini CLI, read-only)  ── investigation + Google Search
  |── Evaluator (Opus/Gemini, read-only)  ── independent quality audit
  └── E2E Verifier (Opus, read-only)      ── runtime AC verification
```

## Iron Rules

1. **Never Fallback** — 500 lines if correct > 100 lines shortcut
2. **Never Mock** — Real data only. No placeholders. EVER.
3. **Never Lazy** — No TODO, every try has complete catch
4. **Best Taste** — Naming reads like prose, architecture is screenshot-worthy
5. **Infinite Time** — Quality > efficiency. Research deeply, deliver best.
6. **True Artist** — Code is signed artwork

## Leader Constraints

- **No Implementation** — Leader orchestrates, reviews, arbitrates. NEVER writes code.
- **No Self-Review** — Implementer != Evaluator. Always independent review.
- **File Buffer Only** — Complex prompts written to `.selfmodel/inbox/`, CLI references files.
- **No Interactive** — `CI=true GIT_TERMINAL_PROMPT=0 timeout <N> <cmd>`. No `yes |`.
- **Worktree Only** — All agent code changes in isolated worktrees. Main stays clean.

## Workflow Summary

```
1. Create Sprint contract    → .selfmodel/contracts/active/sprint-<N>.md
2. Write inbox task          → .selfmodel/inbox/<agent>/sprint-<N>.md
3. Create worktree           → isolated branch sprint/<N>-<agent>
4. Agent implements          → commits in worktree
5. Quick Scan (30s)          → check 10 auto-reject triggers
6. Evaluator + E2E (parallel)→ independent quality + runtime verification
7. Merge verdict             → ACCEPT/REVISE/REJECT
8. Act                       → merge | feedback | redo
```

## On-Demand References

Load from `{baseDir}/references/` as needed:

| When | Load |
|------|------|
| Creating Sprint contracts | `references/sprint-template.md` |
| Routing tasks to agents | `references/dispatch-rules.md` |
| Reviewing Sprint deliverables | `references/quality-gates.md` |
| Running independent evaluation | `references/evaluator-prompt.md` |
| E2E runtime verification | `references/e2e-protocol.md` |
| Research tasks | `references/research-protocol.md` |
| Large project automation | `references/orchestration-loop.md` |
| Context/session management | `references/context-protocol.md` |
| Iron Rules + anti-patterns | `references/iron-rules.md` |
| Team roles + decision matrix | `references/team-roles.md` |
| Past learnings | `references/lessons-learned.md` |

## Directory Structure (per project)

```
project/
├── CLAUDE.md                          # Lightweight router → skill references
└── .selfmodel/
    ├── contracts/{active,archive}/    # Sprint contracts
    ├── inbox/{gemini,codex,opus,research,evaluator,e2e}/
    ├── hooks/                         # Hook scripts (copied from skill)
    ├── artifacts/                     # E2E verification evidence
    ├── reviews/                       # Evaluation verdicts
    └── state/
        ├── team.json                  # Agent roster + stats
        ├── next-session.md            # Session handoff
        ├── plan.md                    # Orchestration plan (optional)
        ├── quality.jsonl              # Score history
        └── hook-intercepts.log        # Auto-logged violations
```
