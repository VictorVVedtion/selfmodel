# selfmodel

A self-evolving AI Agent Team — agents that rewrite their own operating manual.

## What is this?

selfmodel is not a framework. It's a **living system** where AI agents design, implement, test, and improve their own collaboration protocols. The team leader (Claude Opus 4.6) orchestrates but never implements. The team members (Gemini, Codex, Opus Agent, Researcher) execute in isolated git worktrees. The system evolves its own processes through measured feedback loops.

**Core thesis**: the best agent team is one that can rewrite its own operating manual.

## Quick Start

```bash
# Initialize selfmodel in an existing project (auto-detects tech stack)
bash scripts/selfmodel.sh adapt

# Initialize a new project from scratch
bash scripts/selfmodel.sh init

# Update playbook and hooks to latest version
bash scripts/selfmodel.sh update

# Show team health dashboard
bash scripts/selfmodel.sh status
```

Requires: `jq` (`brew install jq` on macOS, `apt install jq` on Linux)

## Architecture

Inspired by [Anthropic's Harness Design](https://www.anthropic.com/engineering/harness-design-long-running-apps) and [Karpathy's Autoresearch](https://github.com/karpathy/autoresearch).

```
                    ┌──────────────────────┐
                    │  Leader (Opus 4.6)   │
                    │  Planner +           │
                    │  Orchestrator        │
                    │  Never implements    │
                    │  Never evaluates     │
                    └──────────┬───────────┘
                               │
         ┌─────────────────────┼─────────────────────┐
         │                     │                     │
┌────────▼───────┐    ┌───────▼────────┐    ┌───────▼────────┐
│  Gemini CLI    │    │  Codex CLI     │    │  Opus Agent    │
│  Frontend +    │    │  Backend       │    │  Senior Full-  │
│  Researcher    │    │  Intern        │    │  stack         │
└────────┬───────┘    └───────┬────────┘    └───────┬────────┘
         │                    │                     │
┌────────▼────────────────────▼─────────────────────▼────────┐
│                  Isolated Git Worktrees                     │
│    sprint/1-gemini    sprint/2-codex    sprint/3-opus       │
└─────────────────────────┬──────────────────────────────────┘
                          │
                  ┌───────▼───────┐
                  │  git diff →   │
                  │  Independent  │
                  │  Evaluator    │◄── skeptical prompt
                  │  (isolated)   │    + calibration
                  └───────┬───────┘
                          │
                  ┌───────▼───────┐
                  │  verdict →    │
                  │  Leader acts  │
                  │  mechanically │
                  └───────────────┘
```

### Six-Role Team

| Role | Agent | Model | Responsibility |
|------|-------|-------|----------------|
| **Leader / Orchestrator** | Claude Opus 4.6 | Current session | Orchestrates, plans, arbitrates. Never implements. Never evaluates. |
| **Evaluator** | Opus Agent / Gemini CLI | claude-opus-4-6 / gemini-3.1-pro-preview | Independent quality gate. Skeptical prompt. Isolated context. |
| **Frontend Colleague** | Gemini CLI | gemini-3.1-pro-preview | UI/UX, components, visual design |
| **Backend Intern** | Codex CLI | GPT-5.4 xhigh fast | Utilities, single-file modules |
| **Senior Fullstack** | Opus Agent | claude-opus-4-6 | Complex multi-file, cross-cutting work |
| **Researcher** | Gemini CLI | gemini-3.1-pro-preview | Google Search grounded research. Read-only, no worktree. |

### Key Design Decisions

- **Worktree isolation** — Every agent works in a separate git worktree. No shared state pollution. Leader reviews via `git diff`.
- **Independent evaluation** — Evaluator runs in isolated context with skeptical prompt. Receives only: diff-aware focused diff + sprint contract + calibration. No access to Leader orchestration history.
- **Orchestration loop** — For large projects (10+ sprints), automated loop reads plan file, dispatches agents, dispatches evaluator, acts on verdicts, checkpoints between sprints, resets between phases.
- **File buffer communication** — Complex prompts written to `.selfmodel/inbox/` files, referenced via `@` syntax. No CLI argument escaping nightmares.
- **Two-layer silent execution** — `CI=true GIT_TERMINAL_PROMPT=0 timeout 180 <cmd>`. Zero interactive prompts, zero hangs. Never use `yes |` (causes E2BIG with Gemini CLI sandbox).
- **Atomic commit workflow** — Agents must follow fix → verify → commit cycles. Each independently verifiable change gets its own commit. No monolithic patches.
- **Small batches** — Each agent task completes in 30–60 seconds. No API timeout risks.
- **Research before implementation** — Unknown domains must go through Researcher before any Generator is dispatched.
- **Hooks enforcement** — Claude Code hooks convert CLAUDE.md soft rules into hard constraints (exit 2 = block). Interceptions auto-logged to `state/hook-intercepts.log` for evolution analysis.
- **Agent safety guardrails** — Agents are forbidden from destructive operations (rm -rf, git push, modifying .selfmodel/), installing global dependencies, or calling production APIs.
- **Leader decision principles** — 6 principles (Completeness, Blast Radius, Ship > Perfect, DRY, Explicit > Clever, Bias-toward-action) enable Leader to auto-decide intermediate questions without human escalation.
- **AI Slop detection** — Evaluator penalizes 8 patterns of AI-generated low-quality code (excessive comments, unnecessary abstractions, template error handling, etc.).
- **Adaptive initialization** — `selfmodel init/adapt` auto-detects tech stack and recommends optimal team composition.
- **CLAUDE.md in English** — System instructions in English for higher LLM compliance (~3-4%); user interaction in Chinese via `<interaction_protocol>` tag.
- **Self-evolution** — Every 10 sprints: MEASURE → DIAGNOSE → PROPOSE → EXPERIMENT → EVALUATE → SELECT. Hook interception logs feed into evolution analysis.

## Project Structure

```
selfmodel/
├── CLAUDE.md                          # Operating manual (English instructions)
├── VERSION                            # Semantic version (0.2.0)
├── scripts/
│   ├── selfmodel.sh                   # CLI: init / adapt / update / status
│   └── hooks/                         # Claude Code enforcement hooks
│       ├── session-start.sh           # Auto-inject team state on session start
│       ├── enforce-leader-worktree.sh # Block Leader from editing code directly
│       └── enforce-agent-rules.sh     # Require contract + inbox before agent calls
├── .claude/
│   └── settings.json                  # Hooks configuration
├── .gitignore
└── .selfmodel/
    ├── contracts/                     # Sprint contracts (audit trail)
    │   ├── active/                    # Current sprints
    │   └── archive/                   # Completed sprints
    ├── inbox/                         # Leader → Agent task files (file buffer)
    │   ├── gemini/                    # Frontend tasks
    │   ├── codex/                     # Backend tasks
    │   ├── opus/                      # Fullstack tasks
    │   ├── research/                  # Research queries + reports
    │   └── evaluator/                 # Evaluator eval files
    ├── state/
    │   ├── team.json                  # Team status + metrics + detected stack
    │   ├── next-session.md            # Cross-session handoff
    │   ├── plan.md                    # Orchestration plan (phases + sprints)
    │   ├── quality.jsonl              # Quality scores (append-only)
    │   ├── orchestration.log          # Orchestration loop event log
    │   ├── hook-intercepts.log        # Auto-learned hook interception events
    │   └── evolution.jsonl            # Evolution log
    ├── reviews/                       # Review records
    └── playbook/                      # On-demand loaded rules
        ├── dispatch-rules.md          # Routing matrix + CLI templates
        ├── quality-gates.md           # 5-dimension scoring + AI Slop detection
        ├── research-protocol.md       # Researcher types A/B/C + evaluation
        ├── sprint-template.md         # Contract template (with Task Preamble)
        ├── evaluator-prompt.md        # Independent evaluator protocol
        ├── orchestration-loop.md      # Automated orchestration loop
        ├── context-protocol.md        # Context checkpoint + reset rules
        └── lessons-learned.md         # Accumulated wisdom
```

## Sprint Workflow

```
1. Researcher investigates  → .selfmodel/inbox/research/sprint-N-query.md (if unknown domain)
2. Leader writes contract   → .selfmodel/contracts/active/sprint-N.md
3. Leader writes task file  → .selfmodel/inbox/<agent>/sprint-N.md
4. Create worktree          → git worktree add sprint-N-<agent>
5. Agent executes           → isolated, non-interactive, timeout-protected
6. Leader quick scan        → 10 auto-reject triggers on git diff
7. Evaluator reviews        → independent evaluator (skeptical prompt, isolated context)
8. Leader acts on verdict   → ≥7.0 merge | 5.0-6.9 revise | <5.0 reject & redo
```

## Hooks Enforcement

Three Claude Code hooks convert CLAUDE.md rules into hard constraints:

| Hook | Trigger | Enforces |
|------|---------|----------|
| `session-start.sh` | SessionStart | Auto-inject team.json + next-session.md context |
| `enforce-leader-worktree.sh` | PreToolUse(Write\|Edit) | Leader cannot edit code files directly |
| `enforce-agent-rules.sh` | PreToolUse(Bash) | No gemini/codex calls without contract + inbox |

Bypass for emergencies: `BYPASS_LEADER_RULES=1` or `BYPASS_AGENT_RULES=1`

## Adaptive Initialization

`selfmodel.sh` auto-detects your project's tech stack and recommends the optimal team:

| Project Type | Detection | Team |
|-------------|-----------|------|
| **Fullstack** | React/Vue + Express/Nest | Leader + Researcher + Gemini + Codex + Opus |
| **Frontend** | React/Vue/Svelte only | Leader + Researcher + Gemini + Opus |
| **Backend** | Python/Go/Rust/Express only | Leader + Researcher + Codex + Opus |
| **Library** | No framework signals | Leader + Researcher + Opus |

Detects: Node, TypeScript, Python, Go, Rust, Swift, Ruby, Docker, 12+ frameworks.

## Quality Gates

Every deliverable scored on 5 dimensions (see `playbook/quality-gates.md`):

| Dimension | Weight | Auto-reject if |
|-----------|--------|----------------|
| Functionality | 30% | Acceptance criteria not met |
| Code Quality | 25% | Contains TODO / mock / swallowed exceptions / AI Slop |
| Design Taste | 20% | Generic naming (data/handler/utils) |
| Completeness | 15% | Missing error handling |
| Originality | 10% | Brute-force when elegant solution exists |

**Verdict**: ≥7.0 Accept | 5.0–6.9 Revise | <5.0 Reject & redo

**Diff-aware review**: Evaluator receives only the files listed in Deliverables, not full diff. Peripheral changes are noted but don't drive scoring.

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
