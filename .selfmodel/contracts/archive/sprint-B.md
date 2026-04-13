# Sprint B: Evolution Detection Engine

## Status
ACTIVE

## Agent
opus

## Objective
Implement `cmd_evolve()` in selfmodel.sh with --detect and --status phases, upstream baseline diffing, 5 generalizability heuristics, and orchestration-loop.md Step 8.5 integration.

## Acceptance Criteria
- [ ] `selfmodel evolve --detect` scans playbook/hooks/scripts diffs against upstream baseline, outputs candidate count
- [ ] `selfmodel evolve --detect` writes CANDIDATE entries to `.selfmodel/state/evolution.jsonl` in the documented schema
- [ ] `selfmodel evolve --status` reads evolution.jsonl and displays pipeline status counts by status
- [ ] `selfmodel evolve` (no flags) defaults to --detect behavior
- [ ] `selfmodel evolve --help` shows all flags and usage
- [ ] Upstream baseline logic: checks git remote "upstream" first, falls back to `.selfmodel/state/upstream-baseline.sha`, else "no baseline" message
- [ ] 5 generalizability heuristics implemented: PATH_DETECTION, PROJECT_NAME_DETECTION, GENERIC_PATTERN, HOOK_FIX, SCORING_CALIBRATION
- [ ] Each heuristic produces a 0.0-1.0 score and a reason string
- [ ] Composite generalizability_score is weighted average of applicable heuristics
- [ ] orchestration-loop.md updated with Step 8.5 EVOLUTION CHECK between Step 8 and Step 9
- [ ] Help text in main() updated with evolve subcommand
- [ ] All bash code passes `shellcheck` (no SC warnings)
- [ ] No TODO, no mock data, no placeholder logic

## Context
Sprint A (MERGED) created the protocol document at `.selfmodel/playbook/evolution-protocol.md` and the command def at `commands/evolve.md`. This sprint implements the actual CLI logic.

Reference files (READ these first):
- `/Users/vvedition/Desktop/selfmodel/.selfmodel/playbook/evolution-protocol.md` — Phase 1 DETECT full specification
- `/Users/vvedition/Desktop/selfmodel/scripts/selfmodel.sh` — existing CLI, add cmd_evolve() following same patterns as cmd_update() and cmd_status()
- `/Users/vvedition/Desktop/selfmodel/.selfmodel/playbook/orchestration-loop.md` — insert Step 8.5

### Implementation Guide

**cmd_evolve() structure**:
```bash
cmd_evolve() {
    local target_dir="${1:-.}"
    # Parse flags: --detect, --status, --stage, --submit, --track, --help
    # Route to sub-functions
}
```

**Key functions to add**:
- `evolve_detect()` — Main detection logic
- `evolve_status()` — Read evolution.jsonl, count by status, display
- `evolve_establish_baseline()` — Find upstream baseline (remote → SHA file → error)
- `evolve_scan_diffs()` — Generate diffs for playbook, hooks, scripts
- `evolve_scan_lessons()` — Parse lessons-learned.md for "Result: improved"
- `evolve_scan_intercepts()` — Parse hook-intercepts.log for recurring patterns
- `evolve_score_heuristics()` — Run 5 heuristics on a diff hunk, output score + reason
- `evolve_append_candidate()` — Append JSON entry to evolution.jsonl

**Heuristic implementation**:
Each heuristic is a function that takes a diff and context, returns a score (0.0-1.0) and reason:
- PATH_DETECTION: `grep -E '^\+.*/Users/|^\+.*/home/' diff` → if matches outside example context, score 0.1 (project-specific)
- PROJECT_NAME_DETECTION: extract project name from `basename $(git remote get-url origin .git)`, grep in diff → if matches, score 0.15
- GENERIC_PATTERN: if diff adds new `###` or `##` section without project-specific terms, score 0.8
- HOOK_FIX: if source is hook script AND hook-intercepts.log has related entries, score 0.9
- SCORING_CALIBRATION: if source is quality-gates.md AND quality.jsonl has trend data, score 0.85

**Composite score**: average of all applicable heuristic scores. If PATH or PROJECT_NAME detection fires (project-specific), cap composite at 0.3.

**orchestration-loop.md update**: Insert after line 222 (after Step 8 CHECKPOINT block):
```
  8.5. EVOLUTION CHECK (every 10 MERGED Sprints)
       a. Read team.json → evolution.last_review_sprint
       b. Count MERGED sprints since last review (from quality.jsonl or plan.md)
       c. If count >= 10:
          i.   Run evolution detection (equivalent to selfmodel evolve --detect)
          ii.  Log: phase=<N> event=evolution_detect candidates=<N>
          iii. If candidates > 0: notify user "N evolution candidates. Run /selfmodel:evolve"
          iv.  Update team.json: evolution.last_review_sprint = current_sprint
       d. If count < 10: skip
```

**Status display format**:
```
Evolution Pipeline Status
─────────────────────────
CANDIDATE:                 3
STAGED:                    2
SUBMITTED:                 1
ACCEPTED:                  5
REJECTED_PROJECT_SPECIFIC: 4
─────────────────────────
Last detect: Sprint 30 (2026-04-01)
Next detect: ~Sprint 40
```

## Constraints
- Timeout: 300s (complex shell implementation)
- Atomic commits per logical unit
- Follow existing selfmodel.sh coding style (check_deps, err, info, success helper functions)
- Use jq for JSON operations (already a dependency)

## Files
### Creates
(none)

### Modifies
- `scripts/selfmodel.sh` — add cmd_evolve() + helper functions + main() routing + help text
- `.selfmodel/playbook/orchestration-loop.md` — insert Step 8.5

### Out of Scope
- CLAUDE.md (Sprint D)
- skill/SKILL.md (Sprint D)
- --stage and --submit phases (Sprint C)

## Deliverables
- [ ] `scripts/selfmodel.sh` with working cmd_evolve() (--detect + --status + --help)
- [ ] `.selfmodel/playbook/orchestration-loop.md` with Step 8.5
