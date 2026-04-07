---
description: "Evolution-to-PR pipeline: detect local improvements, classify, and submit upstream"
allowed-tools: ["Read", "Write", "Edit", "Bash", "Glob", "Grep"]
argument-hint: "[--detect] [--stage] [--stage] [--submit] [--track] [--status]"
---

# /selfmodel:evolve

Run the Evolution-to-PR Pipeline per `{baseDir}/references/evolution-protocol.md`.

## Prerequisites
- Git repo with selfmodel initialized (`.selfmodel/` exists)
- Upstream baseline available (git remote `upstream` or `.selfmodel/state/upstream-baseline.sha`)
- For `--submit`: `gh` CLI authenticated with upstream repo access

## Modes

### Default (no flags)
Run full interactive pipeline: DETECT → STAGE (interactive) → offer SUBMIT.

### `--detect`
Detection only. Scan local diffs against upstream baseline. Append CANDIDATE entries
to `evolution.jsonl`. Read-only except for evolution.jsonl writes. Safe to run anytime.

### `--stage`
Interactive classification. Walk through CANDIDATE entries, display diffs, recommend
classification based on generalizability heuristics. User decides: Stage / Reject / Keep.
Generate patch files for STAGED entries in `.selfmodel/state/evolution-staging/`.

### `--submit`
Create upstream PR from STAGED patches. Pre-submission checks: shellcheck, path audit,
patch applicability. **Requires explicit human approval** before `gh pr create`.

### `--track`
Monitor submitted PRs. Query status via `gh pr view`, update evolution.jsonl entries
to ACCEPTED / REJECTED_UPSTREAM / CONFLICT. Handle CONFLICT by creating SUPERSEDED
entries and new CANDIDATE entries with updated diffs.

### `--status`
Display pipeline status summary without running any phase:
```
Evolution Pipeline Status
─────────────────────────
CANDIDATE:                3
STAGED:                   2
SUBMITTED:                1 (PR #42 open)
ACCEPTED:                 5
REJECTED_PROJECT_SPECIFIC: 4
REJECTED_UPSTREAM:        0
CONFLICT:                 0
SUPERSEDED:               1
─────────────────────────
Last detect: Sprint 30 (2026-04-01)
Last submit: Sprint 20 (2026-03-15)
```

## Pipeline Steps

1. **DETECT**: Compare local playbook/hooks/scripts against upstream baseline.
   Sources: playbook diffs, hook diffs, script diffs, validated lessons (Result: improved),
   hook intercept patterns, quality trends. Output: CANDIDATE entries in evolution.jsonl.

2. **STAGE**: Interactive classification. Each CANDIDATE presented with diff preview
   and heuristic recommendation. User decides: [S]tage / [R]eject / [K]eep / [E]dit.
   STAGED entries produce patches in `.selfmodel/state/evolution-staging/<evo-id>/`.

3. **SUBMIT**: Human-approved PR creation. Pre-checks (shellcheck, path audit, patch
   applicability) → PR preview → human approval gate → `gh pr create`. PR template
   includes evidence table from evolution.jsonl entries.

4. **TRACK**: Monitor submitted PRs. ACCEPTED / REJECTED_UPSTREAM / CONFLICT.
   CONFLICT triggers SUPERSEDE flow: old entry marked, new CANDIDATE created.

## Generalizability Heuristics

Five heuristics score each candidate (0.0 to 1.0):

1. **PATH_DETECTION** — Absolute paths outside examples → project-specific
2. **PROJECT_NAME_DETECTION** — Project name in logic/strings → project-specific
3. **GENERIC_PATTERN** — New section without project nouns → generalizable
4. **HOOK_FIX** — Hook change + intercept log false positives → generalizable
5. **SCORING_CALIBRATION** — Threshold change + quality.jsonl trend → generalizable

## Safety Rules

- Human MUST approve before any PR submission (SUBMIT has mandatory gate)
- Detection is read-only (only writes evolution.jsonl)
- Never submit project-specific paths, names, or credentials
- All .sh patches must pass shellcheck
- evolution.jsonl is append-only (no deletions)
- Upstream conflict → SUPERSEDE, never force push

## State Files

| File | Purpose |
|------|---------|
| `.selfmodel/state/evolution.jsonl` | All evolution entries (append-only) |
| `.selfmodel/state/evolution-staging/<evo-id>/` | Patch files for STAGED entries |
| `.selfmodel/state/upstream-baseline.sha` | Upstream reference point |
| `.selfmodel/state/team.json` → `evolution` | Persistent counters and timestamps |
