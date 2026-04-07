<p align="center">
  <img src="assets/logo.png" alt="selfmodel logo" width="120">
</p>

<h1 align="center">selfmodel</h1>

<p align="center">
  <strong>A self-evolving AI Agent Team — agents that rewrite their own operating manual.</strong>
</p>

<p align="center">
  <a href="https://github.com/VictorVVedtion/selfmodel/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square" alt="MIT License"></a>
  <img src="https://img.shields.io/badge/version-0.4.0-green.svg?style=flat-square" alt="Version 0.4.0">
  <img src="https://img.shields.io/badge/agents-7_roles-8B5CF6.svg?style=flat-square" alt="7-Role Agent Team">
  <img src="https://img.shields.io/badge/isolation-git_worktree-D97706.svg?style=flat-square" alt="Git Worktree Isolation">
  <img src="https://img.shields.io/badge/platform-Claude_Code-000000.svg?style=flat-square&logo=anthropic" alt="Claude Code">
  <a href="https://github.com/VictorVVedtion/selfmodel/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/VictorVVedtion/selfmodel/ci.yml?style=flat-square&label=CI" alt="CI"></a>
</p>

---

## What is this?

selfmodel is not a framework. It's a **living system** where AI agents design, implement, test, and improve their own collaboration protocols. The team leader (Claude Opus 4.6) orchestrates but never implements. The team members (Gemini, Codex, Opus Agent, Researcher, E2E Verifier) execute in isolated git worktrees. The system evolves its own processes through measured feedback loops.

**Core thesis**: the best agent team is one that can rewrite its own operating manual.

## Quick Start

### 1. Install

```bash
git clone https://github.com/VictorVVedtion/selfmodel.git
cd selfmodel && bash install.sh
```

If `selfmodel` isn't found after install, open a new terminal or run `source ~/.zshrc`.

### 2. Setup

```bash
cd your-project
selfmodel init
```

### 3. Build

In Claude Code:

```
/selfmodel:loop
```

## Commands

### Terminal (Setup & Maintenance)

| Command | Description |
|---------|-------------|
| `selfmodel` | Smart dashboard — status + next action |
| `selfmodel init [dir]` | Setup or update project (idempotent) |
| `selfmodel update [--remote]` | Sync playbook from upstream |
| `selfmodel evolve` | Contribute improvements upstream |
| `selfmodel --help` | Full command reference |

### Claude Code (Team Orchestration)

| Command | Description |
|---------|-------------|
| `/selfmodel:plan` | Create multi-phase project plan |
| `/selfmodel:sprint` | Create and dispatch a Sprint |
| `/selfmodel:review` | Review a delivered Sprint |
| `/selfmodel:loop` | Auto-orchestration (plan → dispatch → review → merge) |

> **Tip**: Use `selfmodel` in terminal for status. Use `/selfmodel:loop` in Claude Code for orchestration.

## Update

```bash
selfmodel update --remote
```

Use `selfmodel update --remote --version v0.3.0` to pin a specific release.
Re-run `bash install.sh` to refresh the Claude Code slash commands.
If `selfmodel` is not in PATH, use `bash /path/to/selfmodel/scripts/selfmodel.sh update --remote`.

## Requirements

- `jq` (`brew install jq` on macOS, `apt install jq` on Linux)
- Claude Code CLI installed (`~/.claude/` exists)

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
            ┌─────────────┼─────────────┐
            │                           │
    ┌───────▼───────┐           ┌───────▼───────┐
    │  git diff →   │           │  E2E Agent    │
    │  Independent  │           │ (Opus/Gemini) │
    │  Evaluator    │  skepti   │  Runtime      │
    │  (isolated)   │  cal      │  verification │
    └───────┬───────┘           └───────┬───────┘
            │                           │
            └─────────┬─────────────────┘
                      │ merge verdicts
              ┌───────▼───────┐
              │  verdict →    │
              │  Leader acts  │
              │  mechanically │
              └───────────────┘
```

### Full Pipeline

```
Sprint contract
     │
     ▼
Agent (worktree)  ─── fix → verify → commit (atomic)
     │
     ▼
┌────────────────────────────┐
│ Quick Scan (10 auto-reject │
│ triggers on git diff)      │
└────────────┬───────────────┘
             │ pass
     ┌───────┴───────┐
     ▼               ▼
Evaluator         E2E Agent v2
(code quality)    (runtime AC verification)
     │               │
     └───────┬───────┘
             ▼
      Merge verdicts
             │
             ▼ (optional, user-facing sprints)
      🌊 /rampage
      (chaos testing: 7 personas × 4 surface engines)
             │
             ▼
      Final verdict → ACCEPT / REVISE / REJECT
```

### Seven-Role Team

| Role | Agent | Model | Responsibility |
|------|-------|-------|----------------|
| **Leader / Orchestrator** | Claude Opus 4.6 | Current session | Orchestrates, plans, arbitrates. Never implements. Never evaluates. |
| **Evaluator** | Opus Agent / Gemini CLI | claude-opus-4-6 / gemini-3.1-pro-preview | Independent quality gate. Skeptical prompt. Isolated context. |
| **Frontend Colleague** | Gemini CLI | gemini-3.1-pro-preview | UI/UX, components, visual design |
| **Backend Intern** | Codex CLI | GPT-5.4 xhigh fast | Utilities, single-file modules |
| **Senior Fullstack** | Opus Agent | claude-opus-4-6 | Complex multi-file, cross-cutting work |
| **Researcher** | Gemini CLI | gemini-3.1-pro-preview | Google Search grounded research. Read-only, no worktree. |
| **E2E Verifier** | Opus Agent / Gemini CLI | claude-opus-4-6 / gemini-3.1-pro-preview | Runtime verification. Read-only, parallel with Evaluator. |

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
- **Dispatch gate (v0.3.0)** — Hook-enforced triple gate prevents fan-out merge hell: (1) rolling batch cap — max 3 parallel sprints, (2) convergence file gate — shared hot files force serialization, (3) structural file overlap — contracts with shared files cannot be active simultaneously. Configured via `dispatch-config.json`, enforced by `enforce-dispatch-gate.sh`.
- **Agent safety guardrails** — Agents are forbidden from destructive operations (rm -rf, git push, modifying .selfmodel/), installing global dependencies, or calling production APIs.
- **Leader decision principles** — 6 principles (Completeness, Blast Radius, Ship > Perfect, DRY, Explicit > Clever, Bias-toward-action) enable Leader to auto-decide intermediate questions without human escalation.
- **AI Slop detection** — Evaluator penalizes 8 patterns of AI-generated low-quality code (excessive comments, unnecessary abstractions, template error handling, etc.).
- **Adaptive initialization** — `selfmodel init/adapt` auto-detects tech stack and recommends optimal team composition.
- **E2E atomic verification (v2)** — E2E Agent v2 uses acceptance criteria as the atomic unit of verification. Each AC from the sprint contract becomes one atomic verification with one command, one expected result, and one piece of evidence. Implicit ACs (build, tests, security) are auto-generated. Dependencies between atoms enable precise root-cause identification: if build fails, downstream AC atoms are BLOCKED (not FAIL). Supports flaky detection, historical delta, and artifact management.
- **CLAUDE.md in English** — System instructions in English for higher LLM compliance (~3-4%); user interaction in Chinese via `<interaction_protocol>` tag.
- **Self-evolution** — Every 10 sprints: MEASURE → DIAGNOSE → PROPOSE → EXPERIMENT → EVALUATE → SELECT. Hook interception logs feed into evolution analysis.
- **Chaos testing (/rampage)** — "Be Water" philosophy. 4 surface engines (WEB, CLI, API, LIB) × 7 user personas (Impatient, Confused, Explorer, Multitasker, Edge Case, Abandoner, Speedrunner). Maps all user journeys, then walks each with chaotic behaviors. Advisory quality gate after E2E pass.

## Evolution Pipeline

Every 10 completed sprints, selfmodel can turn validated local process improvements into upstream contributions through the Evolution Pipeline. It scans local diffs and lessons learned for reusable changes, stages only generalizable patches, and records pipeline state in `.selfmodel/state/evolution.jsonl`. Run `/selfmodel:evolve` for the guided workflow; full protocol: [`.selfmodel/playbook/evolution-protocol.md`](.selfmodel/playbook/evolution-protocol.md).

- **DETECT** — Compare local playbook, hook, script, and lessons-learned changes against the upstream baseline to create CANDIDATE entries.
- **STAGE** — Interactively classify candidates, strip project-specific details, and generate patch files in `.selfmodel/state/evolution-staging/`.
- **SUBMIT** — Package staged patches into an upstream PR after path audits and applicability checks. Human approval is required before any submission.
- **TRACK** — Monitor open PRs and sync ACCEPTED, REJECTED, or CONFLICT states back into `evolution.jsonl`.

### Project Wiki

selfmodel auto-generates and maintains a project knowledge base at `.selfmodel/wiki/`. No separate command — wiki is woven into existing flows:

- **`selfmodel init`** scaffolds wiki with detected module pages and architecture overview
- **Session start hook** injects wiki index into Leader context automatically
- **Sprint contracts** can declare `## Wiki Impact` for pages the agent should update
- **Post-merge** (Step 7.6) detects stale wiki pages from code diffs
- **`selfmodel status`** reports wiki health score (page count, staleness, completeness)

## Chaos Testing: /rampage

`/rampage` is a standalone Claude Code skill that acts as the most chaotic, boundary-pushing user imaginable. It finds bugs that systematic QA never catches: race conditions, state corruption, navigation traps, input edge cases.

### Philosophy: Be Water

Water doesn't care about the shape of the container. Web pages, CLI tools, API endpoints, SDK libraries... water penetrates everything. It finds every crack.

### Four Surface Engines

| Engine | Target | Cartography | Chaos Behaviors |
|--------|--------|-------------|-----------------|
| 🌐 WEB | Web apps | Browse daemon crawl → journey graph | Navigation, input, timing, state, viewport, keyboard chaos |
| ⌨️ CLI | CLI tools | `--help` parsing → command tree | Argument, stdin, signal, environment, file, concurrency chaos |
| 🔌 API | HTTP endpoints | OpenAPI/source scan → endpoint map | Request, auth, concurrency, path, data chaos |
| 📦 LIB | Libraries/SDKs | Export scan → public API map | Parameter, lifecycle, concurrency, resource, error chaos |

### Seven User Personas

| # | Persona | Drive | Example behaviors |
|---|---------|-------|-------------------|
| ⚡ | The Impatient | Speed over correctness | Rage-clicks, Ctrl+C, doesn't wait |
| 😵 | The Confused | Misunderstands everything | Wrong fields, back-as-undo, wrong flags |
| 🔍 | The Explorer | Boundary curiosity | Tries /admin, every --help, URL manipulation |
| 🔀 | The Multitasker | Everything in parallel | Multi-tab forms, concurrent commands, race conditions |
| 💥 | The Edge Case | Extreme data | Emoji, 10MB stdin, MAX_INT, null bytes |
| 🚪 | The Abandoner | Never finishes | Ctrl+C mid-operation, no cleanup, half-filled forms |
| 🏃 | The Speedrunner | Minimum viable | Keyboard-only, skip optional, minimal args |

### Usage

```bash
# Auto-detect surfaces in current project
/rampage

# Test a specific web app
/rampage https://myapp.com

# Test a CLI tool
/rampage myctl

# Test with specific options
/rampage --intensity berserk --budget 20m --persona confused,explorer

# Integration with selfmodel workflow
/rampage --selfmodel    # Writes verdict to .selfmodel/artifacts/
```

### Output: Resilience Report

Produces a scored report (0-100) with per-dimension breakdown, journey coverage map, findings by persona, and recommended action. Reports saved to `.gstack/rampage-reports/`.

### Selfmodel Integration

Rampage integrates as an optional chaos gate in the selfmodel pipeline (Step 6.5 in orchestration loop, Step 4.7 in quality gates). RAMPAGE FAIL with critical issues upgrades ACCEPT → REVISE.

## Project Structure

```
selfmodel/
├── CLAUDE.md                          # Operating manual (English instructions)
├── VERSION                            # Semantic version (0.3.0)
├── scripts/
│   ├── selfmodel.sh                   # CLI: init / adapt / update / status
│   ├── verify-delivery.sh            # Post-delivery: declared vs actual files audit
│   └── hooks/                         # Claude Code enforcement hooks
│       ├── session-start.sh           # Auto-inject team state on session start
│       ├── enforce-leader-worktree.sh # Block Leader from editing code directly
│       ├── enforce-agent-rules.sh     # Require contract + inbox before agent calls
│       └── enforce-dispatch-gate.sh   # Rolling batch cap + convergence files + overlap
├── .claude/
│   └── settings.json                  # Hooks configuration
├── install.sh                         # Skill installer (→ ~/.claude/skills/)
├── uninstall.sh                       # Skill uninstaller
├── .gitignore
├── .gstack/
│   └── rampage-reports/               # /rampage chaos test reports
└── .selfmodel/
    ├── contracts/                     # Sprint contracts (audit trail)
    │   ├── active/                    # Current sprints
    │   └── archive/                   # Completed sprints
    ├── inbox/                         # Leader → Agent task files (file buffer)
    │   ├── gemini/                    # Frontend tasks
    │   ├── codex/                     # Backend tasks
    │   ├── opus/                      # Fullstack tasks
    │   ├── research/                  # Research queries + reports
    │   ├── evaluator/                 # Evaluator eval files
    │   └── e2e/                       # E2E verification task files
    ├── state/
    │   ├── team.json                  # Team status + metrics + detected stack
    │   ├── dispatch-config.json       # Dispatch gate: max_parallel + convergence_files
    │   ├── next-session.md            # Cross-session handoff
    │   ├── plan.md                    # Orchestration plan (phases + sprints)
    │   ├── quality.jsonl              # Quality scores (append-only)
    │   ├── orchestration.log          # Orchestration loop event log
    │   ├── hook-intercepts.log        # Auto-learned hook interception events
    │   └── evolution.jsonl            # Evolution log
    ├── artifacts/                     # Verification artifacts (E2E + Rampage)
    ├── reviews/                       # Review records
    └── playbook/                      # On-demand loaded rules
        ├── dispatch-rules.md          # Routing matrix + CLI templates
        ├── quality-gates.md           # 5-dimension scoring + AI Slop detection
        ├── research-protocol.md       # Researcher types A/B/C + evaluation
        ├── sprint-template.md         # Contract template (with Task Preamble)
        ├── evaluator-prompt.md        # Independent evaluator protocol
        ├── e2e-protocol-v2.md         # E2E intelligent verification protocol (v2)
        ├── e2e-protocol.md            # E2E v1 protocol (deprecated)
        ├── orchestration-loop.md      # Automated orchestration loop
        ├── context-protocol.md        # Context checkpoint + reset rules
        └── lessons-learned.md         # Accumulated wisdom
```

## Sprint Workflow

```
 1. Researcher investigates   → .selfmodel/inbox/research/sprint-N-query.md (if unknown domain)
 2. Leader writes contract    → .selfmodel/contracts/active/sprint-N.md
 3. Leader writes task file   → .selfmodel/inbox/<agent>/sprint-N.md
 4. Create worktree           → git worktree add sprint-N-<agent>
 5. Agent executes            → isolated, non-interactive, timeout-protected
 6. Leader quick scan         → 10 auto-reject triggers on git diff
 7. Parallel review           → Evaluator (code quality) + E2E Agent v2 (runtime verification)
 8. Leader merges verdicts    → E2E FAIL upgrades ACCEPT→REVISE; build FAIL→REJECT
 9. Chaos gate (optional)     → /rampage --selfmodel (if Sprint has user-facing surfaces)
10. Leader acts on verdict    → ≥7.0 merge | 5.0-6.9 revise | <5.0 reject & redo
```

### Orchestration Loop (/selfmodel:loop)

For large projects with 10+ Sprints, the automated orchestration loop handles the entire lifecycle:

```
plan.md → rolling batch dispatch (max 3 parallel, overlap-gated)
    → wait → evaluate + E2E (parallel) → rampage (optional)
    → serial merge (rebase-then-merge) → checkpoint → phase gate → loop
```

Create a plan with `/selfmodel:plan`, then start the loop with `/selfmodel:loop`. The loop runs until all sprints are MERGED or BLOCKED. Phase boundaries trigger forced context resets.

**Rolling batch** (v0.3.0): dispatch 3 → merge 3 → dispatch 3. Never fan-out all sprints at once. Convergence files (shared hot files like `tools.ts`, `index.ts`) force serialization. All enforced by hook.

## Hooks Enforcement

Four Claude Code hooks convert CLAUDE.md rules into hard constraints:

| Hook | Trigger | Enforces |
|------|---------|----------|
| `session-start.sh` | SessionStart | Auto-inject team.json + next-session.md context |
| `enforce-leader-worktree.sh` | PreToolUse(Write\|Edit) | Leader cannot edit code files directly |
| `enforce-agent-rules.sh` | PreToolUse(Bash) | No gemini/codex calls without contract + inbox |
| `enforce-dispatch-gate.sh` | PreToolUse(Bash) | Rolling batch cap + convergence files + file overlap |

Bypass for emergencies: `BYPASS_LEADER_RULES=1`, `BYPASS_AGENT_RULES=1`, or `BYPASS_DISPATCH_GATE=1`

### Dispatch Gate (v0.3.0)

The dispatch gate hook prevents fan-out merge hell — the scenario where 11 parallel sprints all modify the same files, causing cascading rebase conflicts.

**Three hard gates** (exit 2 = block, cannot bypass without env var):

| Gate | Check | Config |
|------|-------|--------|
| **Parallel cap** | ACTIVE + DELIVERED contracts ≤ max | `dispatch-config.json` → `max_parallel` (default 3) |
| **Convergence files** | No two active sprints modify the same hot file | `dispatch-config.json` → `convergence_files[]` |
| **File overlap** | No shared files between active sprint contracts | Sprint contract `## Files` section |

Configure per-project:
```bash
# .selfmodel/state/dispatch-config.json
{
  "max_parallel": 3,
  "convergence_files": ["src/tools.ts", "src/exchange/index.ts"]
}
```

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

## CLI Reference

### selfmodel CLI

```
selfmodel                                        Smart dashboard (default)
selfmodel init [directory]                       Setup or update project
selfmodel update [--remote] [--version v0.3.0]  Sync playbook + hooks to latest version
selfmodel status                                 Show team health dashboard
selfmodel evolve                                 Run the evolution pipeline
selfmodel --help                                 Show full command reference
selfmodel --version                              Show version
```

Deprecated alias: `selfmodel adapt [directory]` prints a warning and delegates to `selfmodel init`.

All commands support `--help` for detailed usage where applicable.

If `selfmodel` is not in PATH, use `bash /path/to/selfmodel/scripts/selfmodel.sh` instead.

### Claude Code Slash Commands

| Command | Description |
|---------|-------------|
| `/selfmodel:init` | Initialize selfmodel in current project |
| `/selfmodel:plan` | Create or update a multi-phase orchestration plan |
| `/selfmodel:sprint` | Create a Sprint contract and dispatch an agent |
| `/selfmodel:review` | Review a delivered Sprint (Quick Scan + Evaluator + E2E + verdict) |
| `/selfmodel:loop` | Auto-orchestration loop (plan → dispatch → review → merge → repeat) |
| `/selfmodel:status` | View team status, active sprints, and quality trends |
| `/rampage` | Chaos testing: map all user journeys, walk each with chaotic personas |

### Install / Uninstall

```bash
# Install (skill + CLI)
git clone https://github.com/VictorVVedtion/selfmodel.git
cd selfmodel && bash install.sh

# Update existing project to latest
selfmodel update --remote

# Uninstall
bash uninstall.sh
```

Backups stored in `~/.claude/.backups/` (not in skills directory).

**What `selfmodel update --remote` syncs** (hot-update, no restart):
- `scripts/hooks/*.sh` — enforcement hooks (including dispatch gate)
- `.selfmodel/playbook/*.md` — all protocol documents
- `scripts/*.sh` — CLI and utility scripts
- `VERSION` — version marker
- `dispatch-config.json` — created if missing (never overwrites existing)

**What requires `bash install.sh` + new session**:
- `~/.claude/skills/selfmodel/` — skill definition (SKILL.md, references)
- `~/.claude/commands/selfmodel/` — slash command definitions

## Iron Rules

1. **Never Fallback** — If the right solution needs 500 lines, write 500 lines
2. **Never Mock** — All real data, real endpoints, real content
3. **Never Lazy** — No TODO, no skipped edge cases, no deferred work
4. **Best Taste** — Naming like prose, architecture worth screenshotting
5. **Infinite Time** — Never compromise quality for speed
6. **True Artist** — Every line of code is a signed work of art
7. **Efficiency First** — Parallelize within rolling batch cap (Rule 17)
8. **Rolling Batch** — Max 3 parallel sprints. Dispatch 3 → merge 3 → dispatch 3. Hook-enforced.
9. **Convergence File Gate** — Shared hot files force serialization. Hook-enforced.

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

This project follows the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md).

## License

[MIT](LICENSE) — Copyright (c) 2026 VictorVVedtion
