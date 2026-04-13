# Sprint A: Evolution Protocol Foundation

## Status
ACTIVE

## Agent
opus

## Objective
Create the Evolution-to-PR Pipeline protocol document, slash command definition, and initialize the evolution state file.

## Acceptance Criteria
- [ ] `evolution-protocol.md` contains complete protocol with 4 phases (DETECT, STAGE, SUBMIT, TRACK)
- [ ] `evolution-protocol.md` contains full `evolution.jsonl` JSON schema with all fields documented
- [ ] `evolution-protocol.md` contains 5 generalizability heuristics with decision rules
- [ ] `evolution-protocol.md` contains PR template format
- [ ] `evolution-protocol.md` contains integration points table (orchestration-loop, status, update, team.json)
- [ ] `evolution-protocol.md` contains safety rules (human approval, no secrets, append-only)
- [ ] `commands/evolve.md` follows existing command format (see `commands/loop.md` as reference)
- [ ] `skill/references/evolution-protocol.md` is identical copy of playbook version
- [ ] `.selfmodel/state/evolution.jsonl` exists as empty file
- [ ] No TODO, no mock data, no placeholder text

## Context
selfmodel has an Evolution cycle documented in CLAUDE.md (L296-308) but it's not automated. We're building a pipeline that detects local improvements, packages them, and submits PRs to upstream.

Reference files (READ these first):
- `/Users/vvedition/Desktop/selfmodel/CLAUDE.md` (L296-308 for Evolution section, L242 for On-Demand Loading)
- `/Users/vvedition/Desktop/selfmodel/commands/loop.md` (reference format for commands)
- `/Users/vvedition/Desktop/selfmodel/.selfmodel/playbook/orchestration-loop.md` (integration target)
- `/Users/vvedition/Desktop/selfmodel/.selfmodel/playbook/lessons-learned.md` (example of existing learnings)
- `/Users/vvedition/Desktop/selfmodel/.selfmodel/playbook/quality-gates.md` (example of scoring docs)

### evolution.jsonl Schema (implement exactly)

Each line is a JSON object:
```json
{
  "id": "evo-YYYY-MM-DD-NNN",
  "status": "CANDIDATE|STAGED|SUBMITTED|ACCEPTED|REJECTED_PROJECT_SPECIFIC|REJECTED_UPSTREAM|CONFLICT|SUPERSEDED",
  "category": "playbook_patch|hook_improvement|script_fix|new_lesson|new_playbook_page",
  "source_file": "relative path to local modified file",
  "upstream_file": "relative path in upstream repo",
  "summary": "one-line description",
  "description": "detailed explanation of the improvement",
  "evidence": {
    "sprints_affected": [],
    "quality_trend": "string or null",
    "hook_intercepts": 0,
    "lessons_learned_ref": "string or null"
  },
  "heuristic": "path_detection|project_name_detection|generic_pattern|hook_fix|scoring_calibration",
  "generalizability_score": 0.0-1.0,
  "generalizability_reason": "why this is generalizable",
  "diff_stats": "+N -M lines in file.md",
  "detected_at_sprint": 0,
  "detected_at": "ISO8601",
  "staged_at": null,
  "submitted_at": null,
  "pr_url": null,
  "pr_status": null,
  "reviewed_by": null,
  "project_name": "derived from git remote",
  "selfmodel_version": "current version"
}
```

### 5 Generalizability Heuristics (implement exactly)

1. **PATH_DETECTION** — Diff hunk contains absolute paths (/Users/, /home/, project dir) outside example/template context → project-specific
2. **PROJECT_NAME_DETECTION** — Diff hunk references current project name (from git remote or dir name) → project-specific
3. **GENERIC_PATTERN** — New playbook section without project-specific nouns → generalizable
4. **HOOK_FIX** — Hook script change + hook-intercepts.log shows old pattern caused false positives → generalizable
5. **SCORING_CALIBRATION** — quality-gates.md threshold change + quality.jsonl shows trend motivating it → generalizable

### Pipeline Phases (document fully)

**DETECT**: Compare local playbook/hooks/scripts against upstream baseline. Sources: playbook diffs, hook diffs, script diffs, validated lessons (Result: improved), hook intercept patterns, quality trends. Output: CANDIDATE entries in evolution.jsonl.

**STAGE**: Interactive classification. Each CANDIDATE → Generalizable (STAGED) | Project-specific (REJECTED_PROJECT_SPECIFIC) | Skip (stays CANDIDATE). Staged entries produce patches in `.selfmodel/state/evolution-staging/<evo-id>/`.

**SUBMIT**: Human-approved PR creation. Fork upstream → apply patches → local CI check → human approval gate → `gh pr create`. PR template includes evidence table.

**TRACK**: Monitor submitted PRs. ACCEPTED/REJECTED_UPSTREAM/CONFLICT.

### PR Template Format

```markdown
## Summary
Community-discovered improvements from project usage (<project>, <N> sprints).

| # | Category | File | Summary |
|---|----------|------|---------|

## Evidence
Per-improvement sprint data + quality trends.

## Testing
- [ ] shellcheck passes
- [ ] selfmodel status runs
```

### Integration Points Table

| System | How |
|--------|-----|
| orchestration-loop.md Step 8.5 | Auto-detect every 10 MERGED sprints |
| /selfmodel:status | Pipeline status counts |
| selfmodel update --remote | Refreshes upstream baseline |
| team.json evolution section | last_review_sprint, candidate counts |
| CONTRIBUTING.md | Evolution PRs follow same standards |

### Safety Rules

1. Human MUST approve before any PR submission
2. Detection is read-only (only writes evolution.jsonl)
3. Never submit project-specific paths, names, or credentials
4. All patches must pass shellcheck before submission
5. evolution.jsonl is append-only
6. Upstream conflict → SUPERSEDE, never force

## Constraints
- Timeout: 180s
- Atomic commits: one logical change per commit

## Files
### Creates
- `.selfmodel/playbook/evolution-protocol.md`
- `skill/references/evolution-protocol.md`
- `commands/evolve.md`
- `.selfmodel/state/evolution.jsonl`

### Modifies
(none)

### Out of Scope
- scripts/selfmodel.sh (Sprint B)
- CLAUDE.md (Sprint D)
- skill/SKILL.md (Sprint D)

## Deliverables
- [ ] `.selfmodel/playbook/evolution-protocol.md` — complete protocol
- [ ] `skill/references/evolution-protocol.md` — identical copy
- [ ] `commands/evolve.md` — slash command definition
- [ ] `.selfmodel/state/evolution.jsonl` — empty initialized file
