# Evolution Protocol

Evolution-to-PR Pipeline: detect local improvements, classify generalizability,
package patches, and submit PRs to upstream selfmodel.

Trigger: Every 10 MERGED Sprints (orchestration-loop.md Step 8.5).
Manual trigger: `/selfmodel:evolve` command.

---

## Pipeline Overview

```
DETECT → STAGE → SUBMIT → TRACK
  │         │        │        │
  │ scan    │ class  │ PR     │ monitor
  │ diffs   │ ify    │ create │ status
  ▼         ▼        ▼        ▼
CANDIDATE  STAGED  SUBMITTED  ACCEPTED/REJECTED
```

Four phases, each with clear input/output boundaries. Detection is fully automated
and read-only. Staging requires interactive classification. Submission requires
human approval. Tracking is passive monitoring.

---

## Phase 1: DETECT

**Purpose**: Compare local playbook, hooks, and scripts against upstream baseline
to discover improvements worth contributing back.

**Trigger conditions**:
- Automatic: orchestration-loop.md Step 8.5 fires every 10 MERGED sprints
- Manual: `/selfmodel:evolve --detect`
- Post-update: after `selfmodel update --remote` refreshes the baseline

**Input sources** (scanned in order):

| Source | What to scan | Signal type |
|--------|-------------|-------------|
| Playbook diffs | `git diff upstream/main -- .selfmodel/playbook/` | Direct improvement |
| Hook diffs | `git diff upstream/main -- .selfmodel/hooks/` or `scripts/*.sh` | Bug fix / enhancement |
| Script diffs | `git diff upstream/main -- scripts/` | Tool improvement |
| Validated lessons | `lessons-learned.md` entries with Result: improved | Proven pattern |
| Hook intercept patterns | `hook-intercepts.log` repeated blocks for same reason | False positive fix |
| Quality trends | `quality.jsonl` systematic score shifts | Calibration data |

**Detection algorithm**:

```
1. Establish upstream baseline:
   a. If git remote "upstream" exists: git fetch upstream && use upstream/main
   b. Else if .selfmodel/state/upstream-baseline.sha exists: use stored SHA
   c. Else: SKIP detection, output "no upstream baseline — run selfmodel update --remote"

2. For each source, generate candidate list:
   a. Playbook/hook/script diffs:
      - git diff <baseline>..HEAD -- <path>
      - For each file with changes, create one CANDIDATE entry
   b. Validated lessons:
      - Parse lessons-learned.md for entries with "Result: improved"
      - Cross-reference: if lesson's Action already reflected in a diff, skip (covered by diff)
      - If lesson has no corresponding diff (pure process change), create CANDIDATE
   c. Hook intercept patterns:
      - Parse hook-intercepts.log for repeated blocks (same hook + same reason, 3+ occurrences)
      - If corresponding hook script has a diff: enhance that CANDIDATE's evidence
      - If no diff but pattern is clear: create CANDIDATE with category=hook_improvement
   d. Quality trends:
      - Parse quality.jsonl for systematic shifts (5+ sprints with same dimension trending)
      - If quality-gates.md has threshold changes matching the trend: create CANDIDATE

3. For each candidate, run 5 generalizability heuristics (see below)

4. Write CANDIDATE entries to evolution.jsonl (append-only)

5. Output summary:
   "Detected N candidates: X playbook patches, Y hook fixes, Z new lessons"
```

**Output**: CANDIDATE entries in `evolution.jsonl`. Detection is read-only except
for appending to evolution.jsonl.

---

## Phase 2: STAGE

**Purpose**: Interactive classification of CANDIDATE entries. Human and Leader
collaborate to decide which improvements are generalizable.

**Trigger**: `/selfmodel:evolve --stage` or automatic after DETECT when candidates exist.

**Classification flow**:

```
For each CANDIDATE in evolution.jsonl (sorted by generalizability_score DESC):

  1. Display summary:
     [evo-2026-04-06-001] playbook_patch  score=0.85
     .selfmodel/playbook/quality-gates.md
     "Added AI Slop detection scoring rubric with 8 patterns"

  2. Show diff preview:
     git diff <baseline>..HEAD -- <source_file> | head -40

  3. Leader recommends classification based on heuristics:
     - score >= 0.7 → recommend STAGE
     - score < 0.3  → recommend REJECT_PROJECT_SPECIFIC
     - 0.3 <= score < 0.7 → recommend manual review

  4. User decides:
     [S]tage  → status=STAGED, generate patch
     [R]eject → status=REJECTED_PROJECT_SPECIFIC
     [K]eep   → status=CANDIDATE (revisit later)
     [E]dit   → modify summary/description before staging

  5. For STAGED entries:
     a. Generate patch file:
        git diff <baseline>..HEAD -- <source_file> > \
          .selfmodel/state/evolution-staging/<evo-id>/<filename>.patch
     b. Strip project-specific content from patch:
        - Replace absolute paths with placeholder: /Users/*/project/ → <project-root>/
        - Replace project name with placeholder: <project-name>
        - Flag any remaining project-specific references for manual review
     c. Update evolution.jsonl entry: staged_at=<now>
```

**Output**: STAGED entries in evolution.jsonl, patch files in
`.selfmodel/state/evolution-staging/<evo-id>/`.

---

## Phase 3: SUBMIT

**Purpose**: Create upstream PR from STAGED patches. Requires explicit human approval.

**Trigger**: `/selfmodel:evolve --submit` (never automatic).

**Submission flow**:

```
1. Collect all STAGED entries from evolution.jsonl

2. Group by upstream_file for efficient PR packaging:
   - Multiple changes to same file → single combined patch
   - Unrelated files → can be in same PR if logically cohesive

3. Pre-submission checks:
   a. shellcheck: run shellcheck on all .sh files in staging
      - FAIL → block submission, output errors, user must fix
   b. Path audit: grep for absolute paths, project names, credentials
      - Found → block submission, list violations
   c. Patch applicability: attempt dry-run apply against upstream baseline
      - CONFLICT → mark entries as CONFLICT, user must resolve or SUPERSEDE

4. Generate PR content (see PR Template Format below)

5. HUMAN APPROVAL GATE:
   Display full PR preview (title, body, file list, diff stats)
   "Submit this PR to upstream? [yes/no/edit]"
   - no  → abort, entries stay STAGED
   - edit → user modifies PR content, re-display
   - yes → proceed to submission

6. Submit:
   a. Fork upstream if not already forked
   b. Create branch: evolution/<date>-<short-description>
   c. Apply patches
   d. Commit with evidence-rich message
   e. gh pr create --repo <upstream> --title <title> --body <body>
   f. Update evolution.jsonl entries:
      - status=SUBMITTED
      - submitted_at=<now>
      - pr_url=<gh output>
      - pr_status=open
```

**Output**: SUBMITTED entries in evolution.jsonl, open PR on upstream repo.

---

## Phase 4: TRACK

**Purpose**: Monitor submitted PRs and update local state accordingly.

**Trigger**: `/selfmodel:evolve --track` or automatic during DETECT phase.

**Tracking flow**:

```
1. For each SUBMITTED entry in evolution.jsonl:

   a. Query PR status:
      gh pr view <pr_url> --json state,mergedAt,reviews

   b. Map status:
      - merged  → ACCEPTED, record reviewed_by from PR reviews
      - closed (not merged) → REJECTED_UPSTREAM, record reviewer comments
      - open + changes_requested → stays SUBMITTED, flag for user attention
      - open + approved → stays SUBMITTED (waiting for maintainer merge)
      - conflict detected → CONFLICT (upstream changed target file)

   c. Update evolution.jsonl entry with new status and metadata

2. Handle CONFLICT:
   - If upstream changed the target file after PR submission:
     a. Mark old entry as SUPERSEDED
     b. Create new CANDIDATE with updated diff against new upstream
     c. Output: "evo-2026-04-06-001 superseded — upstream changed target, re-detect needed"

3. Output summary:
   "Tracked N PRs: X accepted, Y rejected, Z pending, W conflicted"
```

**Output**: Updated status in evolution.jsonl.

---

## evolution.jsonl Schema

Path: `.selfmodel/state/evolution.jsonl`

Each line is a single JSON object. File is append-only (new entries appended,
status updates rewrite the specific line via `jq` or equivalent).

```json
{
  "id": "evo-YYYY-MM-DD-NNN",
  "status": "<status>",
  "category": "<category>",
  "source_file": "<relative path>",
  "upstream_file": "<relative path>",
  "summary": "<one-line description>",
  "description": "<detailed explanation>",
  "evidence": {
    "sprints_affected": [],
    "quality_trend": "<string or null>",
    "hook_intercepts": 0,
    "lessons_learned_ref": "<string or null>"
  },
  "heuristic": "<heuristic_name>",
  "generalizability_score": 0.0,
  "generalizability_reason": "<why generalizable or not>",
  "diff_stats": "+N -M lines in file.md",
  "detected_at_sprint": 0,
  "detected_at": "<ISO8601>",
  "staged_at": null,
  "submitted_at": null,
  "pr_url": null,
  "pr_status": null,
  "reviewed_by": null,
  "project_name": "<derived from git remote>",
  "selfmodel_version": "<current version>"
}
```

### Field Reference

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique identifier. Format: `evo-YYYY-MM-DD-NNN` where NNN is zero-padded sequence within the day. Example: `evo-2026-04-06-001` |
| `status` | enum | Lifecycle state. Values: `CANDIDATE`, `STAGED`, `SUBMITTED`, `ACCEPTED`, `REJECTED_PROJECT_SPECIFIC`, `REJECTED_UPSTREAM`, `CONFLICT`, `SUPERSEDED` |
| `category` | enum | Type of improvement. Values: `playbook_patch`, `hook_improvement`, `script_fix`, `new_lesson`, `new_playbook_page` |
| `source_file` | string | Relative path to the locally modified file (from project root). Example: `.selfmodel/playbook/quality-gates.md` |
| `upstream_file` | string | Relative path in the upstream selfmodel repo where the change would apply. Often identical to `source_file` but may differ if local structure diverges |
| `summary` | string | One-line human-readable description of the improvement. Max 120 characters |
| `description` | string | Detailed explanation of what changed, why it matters, and what problem it solves. No length limit |
| `evidence` | object | Supporting data for the improvement (see Evidence sub-schema) |
| `evidence.sprints_affected` | number[] | Sprint numbers where this improvement was relevant or would have prevented issues. Example: `[65, 66, 76]` |
| `evidence.quality_trend` | string\|null | Description of quality score trend that motivated this change. Example: `"code_quality avg dropped from 8.2 to 6.5 over sprints 40-50"`. Null if not trend-driven |
| `evidence.hook_intercepts` | number | Count of hook interceptions related to this improvement. From `hook-intercepts.log`. Zero if not hook-related |
| `evidence.lessons_learned_ref` | string\|null | Reference to lessons-learned.md entry. Example: `"Sprint 65-76: Merge conflicts"`. Null if no linked lesson |
| `heuristic` | enum | Which generalizability heuristic was applied. Values: `path_detection`, `project_name_detection`, `generic_pattern`, `hook_fix`, `scoring_calibration` |
| `generalizability_score` | float | Score from 0.0 (fully project-specific) to 1.0 (fully generalizable). Computed by heuristic rules |
| `generalizability_reason` | string | Human-readable explanation of why the score was assigned. Must reference specific evidence |
| `diff_stats` | string | Git diff statistics. Format: `+N -M lines in <filename>`. Example: `+45 -12 lines in quality-gates.md` |
| `detected_at_sprint` | number | Sprint number at which detection occurred. Derived from current sprint count in team.json |
| `detected_at` | string | ISO 8601 timestamp of detection. Example: `2026-04-06T14:30:00Z` |
| `staged_at` | string\|null | ISO 8601 timestamp of staging. Null until STAGED |
| `submitted_at` | string\|null | ISO 8601 timestamp of PR submission. Null until SUBMITTED |
| `pr_url` | string\|null | GitHub PR URL. Null until SUBMITTED. Example: `https://github.com/org/selfmodel/pull/42` |
| `pr_status` | string\|null | Current PR state. Values: `open`, `merged`, `closed`, `changes_requested`. Null until SUBMITTED |
| `reviewed_by` | string\|null | GitHub username(s) who reviewed the PR. Null until reviewed. Comma-separated for multiple reviewers |
| `project_name` | string | Derived from `git remote get-url origin` — extract repo/org name. Example: `myproject` |
| `selfmodel_version` | string | Version from `VERSION` file at time of detection. Example: `0.3.0` |

### Status Lifecycle

```
CANDIDATE ──┬── STAGED ──── SUBMITTED ──┬── ACCEPTED
            │                           ├── REJECTED_UPSTREAM
            │                           └── CONFLICT ──── SUPERSEDED
            ├── REJECTED_PROJECT_SPECIFIC
            └── (stays CANDIDATE until revisited)
```

Transitions:
- `CANDIDATE → STAGED`: User approves during Stage phase
- `CANDIDATE → REJECTED_PROJECT_SPECIFIC`: User rejects as project-specific
- `STAGED → SUBMITTED`: PR created after human approval
- `SUBMITTED → ACCEPTED`: Upstream merges the PR
- `SUBMITTED → REJECTED_UPSTREAM`: Upstream closes PR without merging
- `SUBMITTED → CONFLICT`: Upstream changed target file, patch no longer applies
- `CONFLICT → SUPERSEDED`: New CANDIDATE created with updated diff
- Any status can stay indefinitely (no forced timeout)

---

## Generalizability Heuristics

Five heuristics evaluate whether a local improvement is worth contributing upstream.
Each heuristic produces a score component and reason. The final `generalizability_score`
is the weighted combination of applicable heuristics.

### Heuristic 1: PATH_DETECTION

**Purpose**: Detect absolute paths that make the change project-specific.

**Rule**: Scan the diff hunks for patterns matching absolute filesystem paths
outside of example blocks or template placeholders.

**Detection patterns**:
- `/Users/<username>/` — macOS home directory
- `/home/<username>/` — Linux home directory
- `/var/`, `/opt/`, `/srv/` followed by project-specific directory names
- Any path containing the project directory name derived from `git rev-parse --show-toplevel`

**Exclusions** (do not flag):
- Paths inside fenced code blocks marked as example/template (` ```example `)
- Paths using placeholder syntax: `<project-root>/`, `$HOME/`, `~/.config/`
- Paths in comments explaining what to replace

**Scoring**:
| Finding | Score impact |
|---------|-------------|
| No absolute paths in diff | +0.0 (neutral, no penalty) |
| Absolute paths only in examples/templates | +0.0 (neutral) |
| 1-2 absolute paths in non-example code | -0.4 (likely project-specific) |
| 3+ absolute paths in non-example code | -0.8 (definitely project-specific) |

**Example**:
```diff
- timeout 180 gemini "@/Users/vvedition/Desktop/myproject/.selfmodel/inbox/gemini/sprint-1.md"
+ timeout 180 gemini "@${WORKTREE}/.selfmodel/inbox/gemini/sprint-1.md"
```
This diff contains `/Users/vvedition/Desktop/myproject/` — a hardcoded path.
Score impact: -0.4. Reason: "diff contains 1 absolute path reference to project directory."

### Heuristic 2: PROJECT_NAME_DETECTION

**Purpose**: Detect references to the current project name that make the change project-specific.

**Rule**: Extract the project name from two sources, then scan diff hunks for occurrences.

**Name extraction**:
```bash
# Source 1: git remote URL
git remote get-url origin 2>/dev/null | sed 's/.*\///' | sed 's/\.git$//'

# Source 2: directory name
basename "$(git rev-parse --show-toplevel)"
```

**Detection**: Case-insensitive search in diff hunks (excluding file path components,
since paths are handled by PATH_DETECTION).

**Exclusions**:
- Project name appearing in a generic context: `"derived from git remote"` is fine
- Project name in CHANGELOG entries (project-specific by nature, but the pattern is generic)

**Scoring**:
| Finding | Score impact |
|---------|-------------|
| No project name references | +0.0 (neutral) |
| Project name only in metadata fields (project_name, CHANGELOG) | +0.0 (neutral) |
| Project name in logic/rules/conditions | -0.5 (likely project-specific) |
| Project name in hardcoded strings/paths | -0.7 (definitely project-specific) |

**Example**:
```diff
+ if [ "$PROJECT" = "vibe-sensei" ]; then
+   SPECIAL_FLAG=true
+ fi
```
Score impact: -0.7. Reason: "diff contains hardcoded project name 'vibe-sensei' in conditional logic."

### Heuristic 3: GENERIC_PATTERN

**Purpose**: Identify new playbook sections, rules, or patterns that contain no
project-specific nouns and are broadly applicable.

**Rule**: If the diff adds a new section (detected by heading markers: `## `, `### `)
or a substantial block (10+ lines) to a playbook file, and that block passes both
PATH_DETECTION and PROJECT_NAME_DETECTION with no penalties, it is a generic pattern.

**Positive signals** (increase score):
- New section with heading that describes a universal concept (e.g., "AI Slop Detection", "Drift Detection")
- References to general software engineering practices, not project-specific workflows
- Uses placeholder variables instead of hardcoded values
- Block is self-contained (does not depend on project-specific sections)

**Scoring**:
| Finding | Score impact |
|---------|-------------|
| New self-contained section, no project references | +0.8 (highly generalizable) |
| New section with minor project context that can be stripped | +0.5 (generalizable with edits) |
| Modification to existing section, generic improvement | +0.6 (likely generalizable) |
| Modification deeply intertwined with project-specific logic | +0.2 (low generalizability) |

**Example**:
Adding an "AI Slop Detection" section to quality-gates.md with 8 universal patterns
and scoring rubric. No project names, no absolute paths.
Score impact: +0.8. Reason: "new self-contained section describing universal code quality patterns."

### Heuristic 4: HOOK_FIX

**Purpose**: Identify hook script changes that fix false positives or improve accuracy,
based on empirical evidence from intercept logs.

**Rule**: A hook script diff qualifies when `hook-intercepts.log` contains entries
showing the old pattern caused incorrect blocks (false positives).

**Evidence requirements**:
- At least 3 intercept log entries for the same hook + same reason pattern
- The diff modifies the matching logic (grep patterns, conditionals, allowlists)
- The fix does not introduce project-specific paths or names

**Scoring**:
| Finding | Score impact |
|---------|-------------|
| Hook fix with 5+ false positive intercepts in log | +0.9 (strong evidence) |
| Hook fix with 3-4 false positive intercepts | +0.7 (moderate evidence) |
| Hook fix with <3 intercepts | +0.3 (weak evidence, may be coincidental) |
| Hook change with no intercept log correlation | +0.1 (speculative) |

**Example**:
`enforce-agent-rules.sh` modified to accept `inbox/research/` directory for gemini agent.
Hook-intercepts.log shows 5 entries: `hook=enforce-agent-rules tool=Bash reason=gemini-no-inbox-file`.
Score impact: +0.9. Reason: "hook fix backed by 5 false positive intercepts; Researcher uses inbox/research/ not inbox/gemini/."

### Heuristic 5: SCORING_CALIBRATION

**Purpose**: Identify quality-gates.md threshold changes that are motivated by
empirical quality data trends.

**Rule**: A threshold change in quality-gates.md qualifies when `quality.jsonl`
shows a systematic trend that motivated the recalibration.

**Evidence requirements**:
- `quality.jsonl` contains 5+ entries showing a consistent pattern in the affected dimension
- The diff modifies scoring thresholds, rubric text, or calibration examples
- The change direction aligns with the observed trend (tightening if scores inflated, loosening if too harsh)

**Scoring**:
| Finding | Score impact |
|---------|-------------|
| Threshold change with 10+ quality entries showing trend | +0.85 (strong calibration) |
| Threshold change with 5-9 quality entries showing trend | +0.65 (moderate calibration) |
| Threshold change with weak/ambiguous trend | +0.3 (speculative) |
| New calibration example based on real sprint data | +0.75 (empirical anchor) |

**Example**:
quality-gates.md adds "AI Slop Detection" scoring penalties. quality.jsonl shows
Code Quality dimension averaged 8.5 over last 10 sprints despite visible slop patterns.
Score impact: +0.85. Reason: "scoring calibration backed by 10-sprint quality trend showing inflated Code Quality scores."

### Score Combination

When multiple heuristics apply (common: GENERIC_PATTERN + PATH_DETECTION):

```
final_score = base_positive + sum(negative_impacts)
```

Where:
- `base_positive` = highest positive score from applicable heuristics (GENERIC_PATTERN, HOOK_FIX, or SCORING_CALIBRATION)
- `negative_impacts` = sum of all negative scores from PATH_DETECTION and PROJECT_NAME_DETECTION

Clamped to [0.0, 1.0].

**Example**: A new playbook section (GENERIC_PATTERN: +0.8) that contains one absolute path
(PATH_DETECTION: -0.4). Final score = 0.8 + (-0.4) = 0.4. Reason incorporates both:
"new generic section (+0.8) but contains 1 absolute path (-0.4); strip path before staging."

---

## PR Template Format

Used in SUBMIT phase when creating upstream PRs.

```markdown
## Summary

Community-discovered improvements from project usage (<project_name>, <N> sprints).

These changes were detected by selfmodel's evolution pipeline, classified as
generalizable by heuristic analysis, and verified against local sprint data.

## Changes

| # | Category | File | Summary | Evidence |
|---|----------|------|---------|----------|
| 1 | <category> | <upstream_file> | <summary> | <sprints_affected>, <quality_trend or hook_intercepts> |
| 2 | ... | ... | ... | ... |

## Per-Change Details

### Change 1: <summary>

**Category**: <category>
**Heuristic**: <heuristic> (score: <generalizability_score>)
**Reason**: <generalizability_reason>

**What changed**:
<description>

**Evidence**:
- Sprints affected: <sprints_affected>
- Quality trend: <quality_trend>
- Hook intercepts: <hook_intercepts>
- Lessons learned ref: <lessons_learned_ref>

**Diff stats**: <diff_stats>

---

(repeat for each change)

## Testing

- [ ] shellcheck passes on all modified .sh files
- [ ] `selfmodel status` runs without errors after applying changes
- [ ] No absolute paths or project-specific names in submitted code
- [ ] Patches apply cleanly to upstream HEAD

## Context

- selfmodel version: <selfmodel_version>
- Detection sprint: <detected_at_sprint>
- Project sprint count: <total_sprints>
- Evolution entries: <count of entries in this PR>
```

---

## Integration Points

| System | Integration | Direction |
|--------|-------------|-----------|
| orchestration-loop.md Step 8.5 | Auto-triggers DETECT phase every 10 MERGED sprints. Leader checks `team.json.evolution.last_review_sprint` and compares to current merged count. If `current - last_review >= 10`, run DETECT | orchestration-loop → evolution |
| `/selfmodel:status` | Displays evolution pipeline status: counts by status (N candidates, M staged, K submitted, J accepted). Reads from `evolution.jsonl` | evolution → status display |
| `selfmodel update --remote` | Refreshes upstream baseline SHA. After update, stores new baseline in `.selfmodel/state/upstream-baseline.sha`. Enables DETECT to compute accurate diffs | update → evolution baseline |
| `team.json` evolution section | Stores persistent state: `last_review_sprint` (sprint number of last DETECT run), `candidate_count`, `staged_count`, `submitted_count`, `accepted_count`. Updated by each phase | evolution ↔ team.json |
| `CONTRIBUTING.md` (upstream) | Evolution PRs follow the upstream project's contributing standards. PR template references CONTRIBUTING.md if it exists | evolution → upstream standards |
| `lessons-learned.md` | DETECT phase scans for entries with `Result: improved` as evolution candidates. ACCEPTED upstream changes are cross-referenced back as validated lessons | lessons-learned ↔ evolution |
| `quality.jsonl` | DETECT phase analyzes quality trends for SCORING_CALIBRATION heuristic. Trend data becomes evidence in evolution entries | quality.jsonl → evolution evidence |
| `hook-intercepts.log` | DETECT phase scans for repeated false positive patterns for HOOK_FIX heuristic. Intercept counts become evidence in evolution entries | hook-intercepts.log → evolution evidence |

### team.json Evolution Section Schema

```json
{
  "evolution": {
    "last_review_sprint": 0,
    "candidate_count": 0,
    "staged_count": 0,
    "submitted_count": 0,
    "accepted_count": 0,
    "rejected_project_specific_count": 0,
    "rejected_upstream_count": 0,
    "last_detect_at": null,
    "last_submit_at": null
  }
}
```

---

## Safety Rules

1. **Human MUST approve before any PR submission** — The SUBMIT phase has a mandatory
   human approval gate. Leader displays the full PR preview and waits for explicit `yes`.
   No automated submission. No "approve all" batch mode.

2. **Detection is read-only** — The DETECT phase only reads from source files, logs,
   and quality data. The only write operation is appending CANDIDATE entries to
   `evolution.jsonl`. No source files are modified during detection.

3. **Never submit project-specific content** — Before PR creation, the pipeline runs
   a mandatory audit for:
   - Absolute filesystem paths (`/Users/`, `/home/`, project root paths)
   - Project name references in logic or hardcoded strings
   - Credentials, API keys, tokens, or secrets
   - Internal team member names or identifiers
   Any finding blocks submission until resolved.

4. **All patches must pass shellcheck before submission** — Every `.sh` file included
   in a PR must pass `shellcheck` with zero warnings. This is enforced in the
   SUBMIT phase pre-submission checks. No override mechanism.

5. **evolution.jsonl is append-only** — New entries are appended. Status updates
   modify existing entries in-place but never delete entries. The full history is
   preserved for audit and trend analysis. Rotation policy: retain all entries
   (per quality-gates.md log maintenance rules).

6. **Upstream conflict means SUPERSEDE, never force** — When an upstream change
   conflicts with a submitted patch:
   - The existing entry transitions to SUPERSEDED status
   - A new CANDIDATE is created with an updated diff against the new upstream state
   - Force push is never used on upstream branches
   - The old PR is closed with a comment explaining the supersession

---

## Directory Structure

```
.selfmodel/
├── state/
│   ├── evolution.jsonl                  # Evolution entries (append-only)
│   ├── evolution-staging/               # Generated during STAGE phase
│   │   └── evo-2026-04-06-001/
│   │       └── quality-gates.md.patch   # Stripped patch file
│   └── upstream-baseline.sha            # Upstream reference SHA
└── playbook/
    └── evolution-protocol.md            # This file
```

---

## Operational Notes

### First-Time Setup

Before evolution can run, the project needs an upstream baseline:

```bash
# Option A: Add upstream remote (preferred)
git remote add upstream <selfmodel-upstream-url>
git fetch upstream

# Option B: Manual baseline (if no upstream remote)
echo "<known-good-sha>" > .selfmodel/state/upstream-baseline.sha
```

### Manual Invocation Examples

```bash
# Full pipeline (interactive)
/selfmodel:evolve

# Detection only (safe, read-only)
/selfmodel:evolve --detect

# Stage candidates (interactive classification)
/selfmodel:evolve --stage

# Submit staged patches (requires human approval)
/selfmodel:evolve --submit

# Track submitted PRs
/selfmodel:evolve --track

# Show pipeline status
/selfmodel:evolve --status
```

### Automatic Invocation

The orchestration loop triggers DETECT automatically at Step 8.5 when the merged
sprint count crosses a 10-sprint boundary. The check:

```
current_merged = count(plan.md sprints with MERGED status)
last_review = team.json.evolution.last_review_sprint
if (current_merged - last_review) >= 10:
    run DETECT phase
    update team.json.evolution.last_review_sprint = current_merged
```

STAGE and SUBMIT are never automatic — they always require user interaction.
