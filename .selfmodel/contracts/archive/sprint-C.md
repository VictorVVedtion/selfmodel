# Sprint C: Evolution Stage + Submit Pipeline

## Status
ACTIVE

## Agent
opus

## Objective
Implement --stage (interactive classification) and --submit (human-approved PR creation) phases in cmd_evolve(), plus extend --status with richer display.

## Acceptance Criteria
- [ ] `selfmodel evolve --stage` reads CANDIDATE entries from evolution.jsonl, displays each with diff preview and heuristic recommendation
- [ ] --stage accepts user input per candidate: s(tage) / r(eject) / k(eep) — updates status in evolution.jsonl
- [ ] STAGED candidates produce patch files in `.selfmodel/state/evolution-staging/<evo-id>/patch.diff` + `metadata.json`
- [ ] `selfmodel evolve --submit` reads STAGED entries, displays PR preview, runs pre-checks (shellcheck on .sh patches, path audit for secrets/absolute paths)
- [ ] --submit has explicit human confirmation prompt before gh pr create
- [ ] --submit creates PR via `gh pr create` with evidence-based template (sprint data, quality trends)
- [ ] --submit gracefully handles: no gh CLI, no STAGED entries, gh auth failure, patch apply conflicts
- [ ] `selfmodel evolve --track` queries submitted PRs via `gh pr view`, updates evolution.jsonl status
- [ ] --status display includes: counts by status, last detect/submit timestamps, submitted PR URLs
- [ ] All new bash code passes shellcheck (no new warnings)
- [ ] No TODO, no mock data, no placeholder logic

## Context
Sprint B (MERGED) implemented cmd_evolve() with --detect, --status, --help. The --stage, --submit, --track flags currently print a "not yet implemented" stub. This sprint replaces those stubs with full implementations.

Reference files (READ these first):
- `/Users/vvedition/Desktop/selfmodel/.selfmodel/playbook/evolution-protocol.md` — Phase 2 STAGE, Phase 3 SUBMIT, Phase 4 TRACK full specifications
- `/Users/vvedition/Desktop/selfmodel/scripts/selfmodel.sh` — existing cmd_evolve() and helper functions from Sprint B
- `/Users/vvedition/Desktop/selfmodel/commands/evolve.md` — command definition showing all modes

### Implementation Guide

**evolve_stage()**:
```
1. Read all CANDIDATE entries from evolution.jsonl
2. If none: info "No candidates to stage" + exit
3. For each candidate:
   a. Display: id, category, source_file, summary, generalizability_score, reason
   b. Show abbreviated diff (first 20 lines of the relevant file diff)
   c. Show heuristic recommendation: score >= 0.6 → "Recommend: Stage", < 0.6 → "Recommend: Skip"
   d. Prompt: "[S]tage / [R]eject / [K]eep? "
   e. Read input, update entry status in evolution.jsonl
4. For each STAGED entry:
   a. Create dir: .selfmodel/state/evolution-staging/<evo-id>/
   b. Generate patch.diff: git diff <baseline> -- <source_file>
   c. Write metadata.json: { id, category, summary, evidence, score }
5. Output summary: "N staged, N rejected, N kept"
```

**evolve_submit()**:
```
1. Check gh CLI: command -v gh || error "gh CLI required"
2. Check gh auth: gh auth status || error "gh auth required"
3. Read STAGED entries from evolution.jsonl
4. If none: info "No staged entries" + exit
5. Display PR preview:
   - Title: "feat(evolution): improvements from <project> (<N> changes)"
   - Body: evidence table per entry
6. Pre-checks:
   a. shellcheck on any .sh patches
   b. Scan patches for absolute paths, secrets patterns (API_KEY, TOKEN, PASSWORD, etc.)
   c. If pre-check fails: warn + ask to continue
7. HUMAN CONFIRMATION: prompt "Submit PR to upstream? [y/N]"
8. If confirmed:
   a. Create temp dir, clone upstream (or use existing fork)
   b. Create branch: evolve/<project>-<YYYYMMDD>
   c. Apply patches (git apply)
   d. Commit with conventional format
   e. Push + gh pr create
   f. Update evolution.jsonl entries to SUBMITTED with pr_url
9. Cleanup temp dir
```

**evolve_track()**:
```
1. Read SUBMITTED entries from evolution.jsonl
2. For each with pr_url:
   a. gh pr view <url> --json state
   b. If merged: update to ACCEPTED
   c. If closed: update to REJECTED_UPSTREAM
   d. If open: no change
3. Output summary
```

**--status extension**:
Add to existing evolve_status():
- Submitted PR URLs with current state
- Last detect and submit timestamps from evolution.jsonl

## Constraints
- Timeout: 300s
- Atomic commits per logical unit
- Follow existing selfmodel.sh helper patterns (err, info, success, confirm)
- Use jq for JSON operations
- Interactive prompts use read -r (for --stage and --submit confirmation)

## Files
### Creates
(none — evolution-staging/ dirs created at runtime)

### Modifies
- `scripts/selfmodel.sh` — replace stub implementations with full --stage, --submit, --track logic

### Out of Scope
- CLAUDE.md (Sprint D, already merged)
- .selfmodel/playbook/evolution-protocol.md (Sprint A, already merged)
- orchestration-loop.md (Sprint B, already merged)

## Deliverables
- [ ] `scripts/selfmodel.sh` with working --stage, --submit, --track, and enhanced --status
