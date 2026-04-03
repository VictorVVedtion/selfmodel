# Changelog

All notable changes to this project will be documented in this file.

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
