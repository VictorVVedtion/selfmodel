# Sprint D: Evolution Integration Documentation

## Status
ACTIVE

## Agent
codex

## Objective
Update all documentation and metadata files to reflect the new Evolution-to-PR Pipeline: CLAUDE.md, skill/SKILL.md, README.md, team.json schema.

## Acceptance Criteria
- [ ] CLAUDE.md Evolution section (around L296-308) expanded to include upstream pipeline description
- [ ] CLAUDE.md On-Demand Loading table includes `evolution-protocol.md` entry
- [ ] CLAUDE.md Danger Zones "Requires Human Approval" includes `selfmodel evolve --submit`
- [ ] CLAUDE.md Directory Structure includes `state/evolution-staging/` and `state/evolution.jsonl`
- [ ] skill/SKILL.md sub-commands table includes `evolve` entry
- [ ] README.md documents the evolution pipeline feature (new section or subsection)
- [ ] All changes are documentation only — no code logic changes
- [ ] No TODO, no placeholder text

## Context
Sprint A (MERGED) created:
- `.selfmodel/playbook/evolution-protocol.md` — full protocol document
- `commands/evolve.md` — slash command definition
- `.selfmodel/state/evolution.jsonl` — empty state file

Sprint B (ACTIVE, parallel) is implementing `cmd_evolve()` in selfmodel.sh.

This sprint updates all surrounding documentation to reference the new capability.

Reference files (READ these first):
- `/Users/vvedition/Desktop/selfmodel/CLAUDE.md` — main doc to update
- `/Users/vvedition/Desktop/selfmodel/skill/SKILL.md` — skill metadata
- `/Users/vvedition/Desktop/selfmodel/README.md` — user-facing docs
- `/Users/vvedition/Desktop/selfmodel/.selfmodel/playbook/evolution-protocol.md` — source of truth for feature description

### Specific Changes

**CLAUDE.md — Evolution section (L296-308)**:
Replace the existing 12-line section with expanded version:
```markdown
## Evolution

**Trigger**: Every 10 Sprints completed (auto-detected at orchestration-loop Step 8.5)
**Cycle**: `MEASURE → DIAGNOSE → PROPOSE → EXPERIMENT → EVALUATE → SELECT`
**Pipeline**: `DETECT → STAGE → SUBMIT → TRACK` (for upstream contributions)

1. **MEASURE** — Extract trends from quality.jsonl
2. **DIAGNOSE** — Identify systemic bottlenecks
3. **PROPOSE** — Form improvement hypotheses
4. **EXPERIMENT** — Test in next Sprint cycle
5. **EVALUATE** — Validate with data
6. **SELECT** — Effective → write to lessons-learned.md | Ineffective → discard with record

**Upstream contribution**: Validated improvements (Result: improved) are candidates
for upstream PRs. Run `selfmodel evolve --detect` or `/selfmodel:evolve` to scan.
Human approval required before any PR submission. Full protocol: `playbook/evolution-protocol.md`.

**Skill discovery**: New need → try existing skill → evaluate → keep or discard
```

**CLAUDE.md — On-Demand Loading table (around L242)**:
Add row:
```
| Evolution pipeline + upstream PR | `.selfmodel/playbook/evolution-protocol.md` |
```

**CLAUDE.md — Danger Zones (around L312-317)**:
Add to "Requires Human Approval" list:
```
- Submitting evolution PRs to upstream (`selfmodel evolve --submit`)
```

**CLAUDE.md — Directory Structure (around L329+)**:
Add these lines in the state/ section:
```
    ├── state/evolution.jsonl            # Evolution pipeline entries (append-only)
    ├── state/evolution-staging/         # Staged evolution patches (pre-PR)
```
Note: evolution.jsonl line already exists, just verify it's there. Add evolution-staging/ if missing.

**skill/SKILL.md**: Add evolve to the sub-commands table following the pattern of existing entries.

**README.md**: Add a section about the Evolution Pipeline feature. Keep it concise — 1 paragraph overview + bullet points for the 4 phases + link to `evolution-protocol.md` for details.

## Constraints
- Timeout: 120s
- Documentation only — no code changes
- Preserve existing content, only add/expand

## Files
### Creates
(none)

### Modifies
- `CLAUDE.md`
- `skill/SKILL.md`
- `README.md`

### Out of Scope
- scripts/selfmodel.sh (Sprint B)
- .selfmodel/playbook/evolution-protocol.md (Sprint A, already merged)
- .selfmodel/playbook/orchestration-loop.md (Sprint B)

## Deliverables
- [ ] `CLAUDE.md` with all 4 update points
- [ ] `skill/SKILL.md` with evolve sub-command
- [ ] `README.md` with evolution pipeline section
