# selfmodel

A self-evolving AI Agent Team — agents that rewrite their own operating manual.

## What is this?

selfmodel is not a framework. It's a **living system** where AI agents design, implement, test, and improve their own collaboration protocols. The team leader (Claude Opus 4.6) orchestrates but never implements. The team members (Gemini, Codex, Opus Agent) execute in isolated git worktrees. The system evolves its own processes through measured feedback loops.

**Core thesis**: the best agent team is one that can rewrite its own operating manual.

## Architecture

Inspired by [Anthropic's Harness Design](https://www.anthropic.com/engineering/harness-design-long-running-apps) and [Karpathy's Autoresearch](https://github.com/karpathy/autoresearch).

```
                    ┌─────────────────────┐
                    │   Leader (Opus 4.6)  │
                    │  Planner + Evaluator │
                    │   Never implements   │
                    └──────────┬──────────┘
                               │
              ┌────────────────┼────────────────┐
              │                │                │
     ┌────────▼───────┐ ┌─────▼──────┐ ┌───────▼────────┐
     │  Gemini CLI    │ │ Codex CLI  │ │  Opus Agent    │
     │  Frontend      │ │ Backend    │ │  Senior Full-  │
     │  Colleague     │ │ Intern     │ │  stack         │
     └────────┬───────┘ └─────┬──────┘ └───────┬────────┘
              │                │                │
     ┌────────▼───────────────▼────────────────▼────────┐
     │              Isolated Git Worktrees               │
     │  sprint/001-gemini  sprint/002-codex  sprint/003  │
     └──────────────────────┬───────────────────────────┘
                            │
                    ┌───────▼───────┐
                    │  git diff →   │
                    │  PR Review →  │
                    │  merge/reject │
                    └───────────────┘
```

### Three-Role Separation (Harness Design)

| Role | Agent | Responsibility |
|------|-------|----------------|
| **Planner + Evaluator** | Leader (Opus 4.6) | Writes specs, reviews diffs, scores quality, arbitrates |
| **Generator (Frontend)** | Gemini CLI (gemini-3.1-pro-preview) | UI/UX, components, visual design |
| **Generator (Backend)** | Codex CLI (GPT-5.4 xhigh fast) | Utilities, single-file modules |
| **Generator (Fullstack)** | Opus Agent (claude-opus-4-6) | Complex cross-cutting work |

### Key Design Decisions

- **Worktree isolation** — Every agent works in a separate git worktree. No shared state pollution. Leader reviews via `git diff`.
- **File buffer communication** — Complex prompts written to `.selfmodel/inbox/` files, referenced via `@` syntax. Solves the quote escaping nightmare.
- **Three-layer silent execution** — `yes | CI=true timeout 180 <cmd>`. Zero interactive prompts, zero hangs.
- **Small batches** — Each agent task completes in 30–60 seconds. No API timeout risks.
- **CLAUDE.md as Router** — Core file stays ~200 lines. Detailed rules live in `playbook/` modules, loaded on demand.
- **Self-evolution** — Every 10 sprints: MEASURE → DIAGNOSE → PROPOSE → EXPERIMENT → EVALUATE → SELECT.

## Project Structure

```
selfmodel/
├── CLAUDE.md                          # Operating manual (~200 lines, Router)
├── .gitignore
└── .selfmodel/
    ├── contracts/                     # Sprint contracts (audit trail)
    │   ├── active/                    # Current sprints
    │   └── archive/                   # Completed sprints
    ├── inbox/                         # Leader → Agent task files (file buffer)
    │   ├── gemini/
    │   ├── codex/
    │   └── opus/
    ├── state/
    │   ├── team.json                  # Team status + metrics
    │   ├── next-session.md            # Cross-session handoff
    │   ├── quality.jsonl              # Quality scores (append-only)
    │   └── evolution.jsonl            # Evolution log
    ├── reviews/                       # Review records
    └── playbook/                      # On-demand loaded rules
        ├── dispatch-rules.md          # Routing matrix + CLI templates
        ├── quality-gates.md           # 5-dimension scoring rubric
        ├── sprint-template.md         # Contract template
        └── lessons-learned.md         # Accumulated wisdom
```

## Sprint Workflow

```
1. Leader writes contract    → .selfmodel/contracts/active/sprint-N.md
2. Leader writes task file   → .selfmodel/inbox/<agent>/sprint-N.md
3. Create worktree           → git worktree add sprint-N-<agent>
4. Agent executes            → isolated, non-interactive, timeout-protected
5. Leader reviews diff       → git diff main...sprint/N-<agent>
6. Accept → merge            → contract archived, worktree cleaned
   Reject → feedback         → agent continues in same worktree
```

## Quality Gates

Every deliverable scored on 5 dimensions (see `playbook/quality-gates.md`):

| Dimension | Weight | Auto-reject if |
|-----------|--------|----------------|
| Functionality | 30% | Acceptance criteria not met |
| Code Quality | 25% | Contains TODO / mock / swallowed exceptions |
| Design Taste | 20% | Generic naming (data/handler/utils) |
| Completeness | 15% | Missing error handling |
| Originality | 10% | Brute-force when elegant solution exists |

**Verdict**: ≥7.0 Accept | 5.0–6.9 Revise | <5.0 Reject & redo

## Iron Rules

1. **Never Fallback** — If the right solution needs 500 lines, write 500 lines
2. **Never Mock** — All real data, real endpoints, real content
3. **Never Lazy** — No TODO, no skipped edge cases, no deferred work
4. **Best Taste** — Naming like prose, architecture worth screenshotting
5. **Infinite Time** — Never compromise quality for speed
6. **True Artist** — Every line of code is a signed work of art
7. **Efficiency First** — Parallelize everything that has no dependency

## License

MIT
