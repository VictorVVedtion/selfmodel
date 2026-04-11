# Changelog

All notable changes to this project will be documented in this file.

## [0.5.0] - 2026-04-11

### Added
- **Depth-First Workflow Enforcement** (`enforce-depth-gate.sh`) — hook-enforced gate blocking dispatch of standard/complex Sprints whose contracts lack real Code Tour + Architecture Context. Complex Sprints MUST complete Phase A (`understanding.md`) before Phase B implementation.
- **Sprint Complexity Field** (`simple | standard | complex`) — determines required contract sections and dispatch protocol. Contracts gained `## Complexity`, `## Code Tour`, `## Architecture Context`, `## Understanding Checkpoint`, `## Files`, and `## Smoke Test` sections.
- **Two-Phase Dispatch** for complex Sprints — Phase A produces `understanding.md` in the worktree, Leader validates, then Phase B implementation begins. Prevents drive-by implementation without codebase comprehension.
- **Deep-Read Mode** — Leader extracts patterns to `.selfmodel/artifacts/` for complex Sprint dependencies, bridging Rule 7 ("no implementation") with the need to understand existing code.
- **Iron Rule 19: Depth Gate** — hook-enforced, blocks dispatch at tool level when standard/complex contracts lack depth content.
- **Iron Rule 20: Self-Dogfood** — selfmodel's own code changes MUST go through Sprint flow. `enforce-leader-worktree.sh` whitelist is a safety net, not a Rule 7 exemption. Only exception: `BYPASS_LEADER_RULES=1` emergency fix, which must be followed by a retroactive audit Sprint in the same session.
- **Hook Drift Test** (`scripts/tests/test-hook-drift.sh`) — extracts canonical heredoc from `scripts/selfmodel.sh` and diffs against live hook files, exits non-zero on drift. Prevents silent hook regression during `selfmodel update`.
- **Retroactive Audit Protocol** — `sprint-R{N}-retroactive.md` contracts for auditing commits that bypassed Sprint flow. First run audited v0.5.0 era (R1-R4) and wrote 4 rows to `quality.jsonl` (mean 6.83/10), archived to `.selfmodel/reviews/retroactive-v0.5.0-audit.{md,json}`.

### Fixed
- **enforce-leader-worktree.sh whitelist regression** (Sprint 7) — R4 (`f0410d7`) silently removed Rules 7/8/9 (LICENSE/VERSION/CHANGELOG, `.github/*`, `assets/*`) during canonical heredoc regen, freezing the release workflow for 3 days. Restored byte-for-byte from `f0410d7^`. First fully compliant dogfood Sprint — scored 9.15/10 vs retroactive mean 6.83 (+2.32 discipline dividend).
- **`generate_playbook()` sprint-template.md overwrite** (R2) — added `if-not-exists` guard matching `dispatch-rules.md`/`quality-gates.md` pattern, preventing depth-gate fields from being wiped on every `selfmodel update`.
- **`.claude/settings.json` hook entry format** (R3) — normalized PreToolUse hook structure.

### Changed
- **Lessons learned protocol** (`.selfmodel/playbook/lessons-learned.md`) — new v0.5.0 retroactive audit entry documenting "why Sprint discipline matters" with quantified +2.32 discipline dividend.

## [0.4.0] - 2026-04-07

### Added
- **Project Wiki** — auto-generated knowledge base at `.selfmodel/wiki/`, woven into existing flows:
  - `selfmodel init` scaffolds wiki with detected module pages and architecture overview
  - Session-start hook injects wiki/index.md into Leader context
  - Sprint contracts gain `## Wiki Impact` section for agent wiki updates
  - Post-merge Step 7.6 detects stale wiki pages from code diffs
  - `selfmodel status` reports wiki health score (pages, staleness, completeness)
  - Inspired by [Karpathy's LLM Wiki pattern](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f)
- **Evolution-to-PR Pipeline** (`selfmodel evolve`) — detect local improvements, classify generalizability, submit upstream PRs:
  - 5 generalizability heuristics (path detection, project name, generic pattern, hook fix, scoring calibration)
  - 4-phase pipeline: DETECT → STAGE → SUBMIT → TRACK
  - Orchestration loop Step 8.5 auto-triggers detection every 10 merged sprints
  - Human approval gate before any PR submission
- **Wiki Protocol** (`wiki-protocol.md`) — page format, update rules, lint rules, auto-sync spec
- **Evolution Protocol** (`evolution-protocol.md`) — full pipeline spec with schema, heuristics, PR template

### Changed
- **CLI consolidated** — smart dashboard as default (`selfmodel` with no args), idempotent init (absorbs adapt), interactive evolve default, two-tier help
- **`selfmodel init`** is now idempotent — safe to re-run on existing projects (runs adapt logic)
- **`selfmodel adapt`** deprecated — prints warning, delegates to `selfmodel init`
- **`selfmodel evolve`** (no flags) runs full interactive pipeline (detect → stage → offer submit), was detect-only
- **`selfmodel`** (no args) shows smart dashboard with next-action suggestion, was help text
- **Help text** split into two tiers: dashboard shows 8-line reference, `--help` shows full detail
- **README** restructured: 3-step quickstart, Terminal vs Claude Code command tables
- Slash commands `/selfmodel:init`, `/selfmodel:status`, `/selfmodel:evolve` marked as convenience (CLI preferred)

### Fixed
- **bash 3.2 compatibility** — replaced `unset 'array[-1]'` (requires bash 4.3+) with portable `_wiki_find_code()` helper for macOS default bash
- **`cmd_evolve` exit vs return** inconsistency — `exit 1` changed to `return 1`

## [0.3.0] - 2026-04-05

### Added
- **Dispatch Gate Hook** (`enforce-dispatch-gate.sh`) — code-enforced triple gate preventing fan-out merge hell:
  - Gate 1: Rolling batch cap (max 3 parallel sprints, configurable)
  - Gate 2: Convergence file gate (shared hot files force serialization)
  - Gate 3: Structural file overlap detection (contract-level, not advisory)
- **Dispatch Config** (`.selfmodel/state/dispatch-config.json`) — JSON config for max_parallel and convergence_files, parsed by hook via jq
- **Delivery Verification** (`scripts/verify-delivery.sh`) — post-delivery audit comparing declared vs actual file modifications
- **Structured Files Section** in Sprint contracts — Creates/Modifies/Out of Scope subsections, machine-parseable by hook
- **Convergence File Management** concept and workflow in dispatch-rules.md
- **Rolling Batch Dispatch** in orchestration-loop.md — dispatch 3, merge 3, dispatch 3 (replaces fan-out)
- Iron Rule 17: **Rolling Batch** — hard cap on parallel sprints, enforced by hook
- Iron Rule 18: **Convergence File Gate** — hot files force serialization, enforced by hook
- Remote update now syncs `scripts/*.sh` (not just `scripts/hooks/*.sh`)

### Fixed
- Fan-out merge hell: 11 parallel sprints with 6+ shared files caused cascading rebase conflicts — now prevented by hook-level enforcement
- Rule 12 (Efficiency First) qualified with rolling batch cap — "maximize throughput" no longer means "dispatch everything at once"

### Changed
- orchestration-loop.md Step 4: PARALLEL DISPATCH → ROLLING BATCH DISPATCH
- dispatch-rules.md: "MUST parallelize" → "MAY parallelize within cap and gates"
- Plan file format gains `Files` per sprint, `## Convergence Files`, `## Dispatch Config`

## [0.2.0] - 2026-04-03

### Added
- Open-source infrastructure: LICENSE (MIT), CODE_OF_CONDUCT.md, GitHub templates, shields badges
- `/rampage` chaos testing skill — 7 user personas x 4 surface engines (WEB, CLI, API, LIB)
- Rampage integration as optional chaos gate in selfmodel pipeline
- Project logo and visual assets (social banner, isolation card, slop comparison)

### Fixed
- Sync skill/references templates with rampage integration
- Move `install.sh` backup outside skills directory (RAMPAGE-004)
- Fix argument handling in `selfmodel.sh`

## [0.1.0] - 2026-03-29

### Added
- Claude Code Skill packaging — install via `bash install.sh`, 6 slash commands
- E2E Agent v2 — atomic acceptance-criteria-driven verification engine
- Independent Evaluator protocol with skeptical prompt and isolated context
- Orchestration loop for large projects (10+ sprints): plan -> dispatch -> review -> merge -> repeat
- Researcher agent role with Google Search grounding (read-only, no worktree)
- `selfmodel update --remote` for upstream sync
- Evaluator calibration anchors and context checkpoint protocol
- Claude Code hooks enforcement (session-start, leader-worktree, agent-rules)
- `selfmodel.sh` CLI with adaptive project initialization and tech stack detection
- 12 engineering best practices integrated from gstack

### Fixed
- Remove `yes |` pipe from all CLI templates — causes `spawn E2BIG` with Gemini sandbox
- Restore calibration examples + cost field lost during worktree copy
- Clean 429 error noise from sprint-4 research report
- Researcher inbox check + archived contract status tracking

### Changed
- Rewrite CLAUDE.md in English for higher LLM instruction compliance (~3-4% improvement)

## [0.0.1] - 2026-03-28

### Added
- Initial selfmodel agent team infrastructure
- 7-role team: Leader, Evaluator, Frontend, Backend, Fullstack, Researcher, E2E Verifier
- Git worktree isolation workflow
- Sprint contract system with 5-dimension quality scoring
- Iron Rules: Never Fallback, Never Mock, Never Lazy, Best Taste, Infinite Time, True Artist
- README with architecture overview and workflow documentation
