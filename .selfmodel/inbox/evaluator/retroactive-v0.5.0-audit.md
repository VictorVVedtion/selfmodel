# Evaluation Input — Retroactive Audit for v0.5.0 Era (4 commits)

## Instructions

You are an **independent code auditor**. You have NEVER seen this codebase before.
Your default stance is **SKEPTICAL**. Assume the code has defects until proven otherwise.

This is a **retroactive audit**: the 4 commits below were merged directly to `main`
without going through the Sprint → contract → worktree → Evaluator → PR flow that
selfmodel's own rules require. The purpose of this audit is to retroactively score
those commits using the normal 6-dimension rubric, so the project has real
`quality.jsonl` data and knows how much quality was lost by bypassing the process.

### Review protocol (apply to each of the 4 commits independently)

1. Read the commit diff. Use shell:
   ```bash
   git -C /Users/vvedition/Desktop/selfmodel show <sha>
   git -C /Users/vvedition/Desktop/selfmodel show --stat <sha>
   ```
2. Read the retroactive contract in `.selfmodel/contracts/archive/sprint-R<N>-retroactive.md`
   to see the objective, acceptance criteria, and declared Files list.
3. Check the 10 auto-reject triggers FIRST (Section 4 below). If ANY fires, output
   Grade F for that commit and stop scoring its dimensions.
4. Compare the diff against each acceptance criterion. Unchecked criterion = 0 for
   Functionality on that commit.
5. **Focus Area**: review only the files declared in the retroactive contract's
   `## Files` section. Other changes get a glance but should not drive scoring.
6. **Integration Consistency**: these commits are edits to selfmodel's own playbook,
   hooks, and CLI. Check that naming, error handling, and structural style match the
   rest of `scripts/selfmodel.sh`, `scripts/hooks/*.sh`, and `.selfmodel/playbook/*.md`.
   Inconsistencies reduce the Integration Depth score.
7. Output rationale BEFORE scores. Explain what you looked for and what you found.
8. Calibrate against anchors (Section 3): high = 8.9, low = 4.1. Justify relative to these.
9. When in doubt, score LOWER. Score inflation is worse than being too harsh.
10. Check for AI Slop patterns (see Section 5 below).
11. Output **one JSON object per commit**, all four inside a top-level JSON array
    matching the schema in Section 6.

### Critical context: this audit itself carries a rule violation

All four commits were authored by the Leader (opus) directly editing main. That
violates Rule 7 (No Implementation — Leader only orchestrates) and Rule 14/15
(Main Is Truth / Short-Lived Branches). **Do not let this bias your scoring of the
code itself** — we score the diff on its technical merits. But you MAY mention the
process violation in the `rationale` or `should_fix` fields when relevant (e.g.,
"no Evaluator ran before merge" is legitimate `should_fix` feedback).

---

## The 4 commits to audit

| # | SHA (short) | Retroactive Contract | Title |
|---|------|----------|-------|
| R1 | `302f9aa` | `.selfmodel/contracts/archive/sprint-R1-retroactive.md` | v0.5.0 — Depth-First Workflow Enforcement (8 gaps) |
| R2 | `2bfaba0` | `.selfmodel/contracts/archive/sprint-R2-retroactive.md` | selfmodel update preserves sprint-template.md |
| R3 | `dd07f19` | `.selfmodel/contracts/archive/sprint-R3-retroactive.md` | settings.json SessionStart hook format fix |
| R4 | `f0410d7` | `.selfmodel/contracts/archive/sprint-R4-retroactive.md` | team.json regen + leader-worktree hook cleanup |

### Diff size notes (per Diff Size Limits rule)

- R1: 959 +/- 22 lines in 10 files — **>500 threshold**. Start with `git show --stat 302f9aa`.
  Then read full diff of the key files:
  - `scripts/hooks/enforce-depth-gate.sh` (new file, 289 lines — main logic)
  - `.selfmodel/playbook/quality-gates.md` (46 line changes — scoring rubric)
  - `.selfmodel/playbook/sprint-template.md` (65 line changes — template)
  - Skim the rest via stat.
- R2: 4 lines — full diff.
- R3: 9 lines — full diff.
- R4: 23 lines — full diff.

---

## Section 1: Per-Sprint Contracts

Read these from disk. Each has Objective / Acceptance Criteria / Files / Deliverables:

- `/Users/vvedition/Desktop/selfmodel/.selfmodel/contracts/archive/sprint-R1-retroactive.md`
- `/Users/vvedition/Desktop/selfmodel/.selfmodel/contracts/archive/sprint-R2-retroactive.md`
- `/Users/vvedition/Desktop/selfmodel/.selfmodel/contracts/archive/sprint-R3-retroactive.md`
- `/Users/vvedition/Desktop/selfmodel/.selfmodel/contracts/archive/sprint-R4-retroactive.md`

## Section 2: Git Diffs (fetch via shell)

```bash
cd /Users/vvedition/Desktop/selfmodel

# R1 — start with stat, then read key files full
git show --stat 302f9aa
git show 302f9aa -- scripts/hooks/enforce-depth-gate.sh
git show 302f9aa -- .selfmodel/playbook/quality-gates.md
git show 302f9aa -- .selfmodel/playbook/sprint-template.md
git show 302f9aa -- CLAUDE.md
git show 302f9aa -- .selfmodel/playbook/dispatch-rules.md
git show 302f9aa -- .selfmodel/playbook/evaluator-prompt.md
git show 302f9aa -- .selfmodel/playbook/orchestration-loop.md
git show 302f9aa -- scripts/selfmodel.sh

# R2/R3/R4 — small, read full
git show 2bfaba0
git show dd07f19
git show f0410d7
```

## Section 2.5: Integration Context

### Architecture overview

selfmodel is a shell-script + Markdown playbook framework for orchestrating
multi-AI agent teams. Leader (Claude Opus) dispatches Gemini/Codex/Opus worker
Agents via file-buffer contracts. Hooks enforce rules at PreToolUse / SessionStart.
The CLI (`scripts/selfmodel.sh`) installs and updates the framework in target
projects. Playbook files live under `.selfmodel/playbook/` and are loaded
on-demand by the Leader.

### Naming conventions

- Shell functions: `snake_case` (e.g., `generate_playbook`, `detect_upstream_baseline`)
- Shell variables: `lower_snake_case` for local, `UPPER_SNAKE_CASE` for env/exported
- Playbook filenames: `kebab-case.md` (e.g., `dispatch-rules.md`, `quality-gates.md`)
- Hook filenames: `enforce-<what>-<scope>.sh` (e.g., `enforce-dispatch-gate.sh`)
- Sprint contracts: `sprint-<N>.md` where N can be number, letter, or R<N> for retroactive

### Error handling patterns

- Shell: `set -euo pipefail` at top, but scripts do NOT always use it consistently —
  check per-file
- Helper functions `err`, `warn`, `info` colorize and prefix output (defined in
  `scripts/selfmodel.sh` top)
- `jq` calls should have fallback pipes or `-e` flag to avoid silent empty output
- No `--no-verify`, no `yes |` pipes (historical E2BIG bug)
- CI=true + timeout N wrapping on all CLI calls

### Adjacent modules (don't break)

- `scripts/selfmodel.sh`: main CLI; all hooks registered from here
- `scripts/hooks/*.sh`: read by Claude Code hook runtime; schema via `.claude/settings.json`
- `.selfmodel/playbook/*.md`: loaded by Leader on demand; order-independent
- `.selfmodel/state/team.json`: single source of truth for team state; jq-updated
- `skill/scripts/*.sh`: mirror of `scripts/hooks/*.sh` for the install path

---

## Section 3: Calibration Anchors

### High Anchor (8.9/10) — Sprint 2: Hooks Enforcement (reference)

| Dimension | Score | Rationale |
|---|---|---|
| Functionality | 9 | 8 acceptance criteria passed, boundary inputs handled |
| Code Quality | 9 | shellcheck zero warnings, every jq call has fallback |
| Design Taste | 9 | Error messages guide correct behavior, BYPASS via env var |
| Completeness | 8 | Main paths covered, only gap: deep JSON merge edge case |
| Integration Depth | 9 | Perfectly matches selfmodel.sh patterns, reuses err/info/warn helpers |
| Originality | 9 | Glob pattern matching vs hardcoded paths |

**Weighted: 8.9**

### Low Anchor (4.1/10) — Sprint 3 Variant: Severe Quality Issues (reference)

| Dimension | Score | Rationale |
|---|---|---|
| Functionality | 4 | Core unimplemented (TODO placeholders) |
| Code Quality | 3 | Contains TODO, placeholder, generic names — auto-reject |
| Design Taste | 4 | Generic naming, style break with project |
| Completeness | 5 | Skeleton exists but critical branches missing |
| Integration Depth | 3 | Style break with existing code, generic naming, no helper reuse |
| Originality | 6 | Reasonable approach, zero execution |

**Weighted: 3.8 (auto-reject on rules #1, #2)**

---

## Section 4: Auto-Reject Triggers (check FIRST for every commit)

1. Contains `// TODO` / `# TODO` / `FIXME` / `HACK` / `XXX`
2. Contains mock data, placeholder, fake content (`Lorem ipsum`, `test@test.com`, `foo/bar`)
3. Contains `except: pass` / `catch {}` / empty catch / swallowed exceptions
4. Build failure / compile failure / main entry import error
5. I/O / network / file operations missing error handling
6. Variable names < 3 chars (except i/j/k, x/y/z, n/m)
7. Single function > 50 lines without decomposition
8. Dead code (commented-out blocks) or unused imports
9. Hardcoded secrets / API keys / credentials
10. Missing type annotations in typed languages (not applicable to shell/markdown)

## Section 5: AI Slop Patterns (deduct from Code Quality)

1. Excessive comments on obvious code
2. Unnecessary abstract class / interface / factory
3. Defensive null-chain guards (`if x !== null && x !== undefined && x !== ""`)
4. Synonym-soup functions (getData / fetchData / retrieveData doing the same)
5. Meaningless abstraction (single-impl interface, single-call helper)
6. Over-explanatory naming (`thisIsTheUserNameFromTheDatabase`)
7. Template catch blocks (all catches are `console.error(err); throw err`)
8. AI flattery in comments ("This function elegantly handles...")

Deduction:
- 1-2 hits → Code Quality -0.5
- 3-4 hits → Code Quality -1.0
- 5+ hits → systemic issue, Code Quality ≤ 6

---

## Section 6: Output JSON Schema

Output a JSON **array** of 4 verdicts, one per commit, in this order: R1, R2, R3, R4.
Each verdict follows the standard schema:

```json
[
  {
    "sprint": "R1",
    "commit_sha": "302f9aa",
    "evaluator": "opus-agent",
    "auto_reject_triggered": false,
    "auto_reject_reasons": [],
    "rationale": {
      "functionality": "<per-criterion pass/fail analysis>",
      "code_quality": "<Iron Rules + AI Slop analysis>",
      "design_taste": "<naming and architecture evaluation>",
      "completeness": "<error handling and branch coverage>",
      "integration_depth": "<pattern matching with existing selfmodel style>",
      "originality": "<solution elegance>"
    },
    "scores": {
      "functionality": 0,
      "code_quality": 0,
      "design_taste": 0,
      "completeness": 0,
      "integration_depth": 0,
      "originality": 0
    },
    "weighted": 0.0,
    "verdict": "ACCEPT | REVISE | REJECT",
    "must_fix": [
      {
        "file": "<path>",
        "line": "<N>",
        "issue": "<description>",
        "severity": "blocker | major | minor"
      }
    ],
    "should_fix": ["<suggestion>"],
    "praise": ["<what was done well>"]
  },
  { "sprint": "R2", "commit_sha": "2bfaba0", ... },
  { "sprint": "R3", "commit_sha": "dd07f19", ... },
  { "sprint": "R4", "commit_sha": "f0410d7", ... }
]
```

### Weighted score formula (verify this)

```
weighted = functionality*0.25 + code_quality*0.20 + design_taste*0.15 + completeness*0.15 + integration_depth*0.15 + originality*0.10
```

### Verdict mapping

- `weighted >= 7.0` → ACCEPT
- `5.0 <= weighted < 7.0` → REVISE
- `weighted < 5.0` → REJECT
- Any auto-reject trigger → REJECT regardless of scores (Grade F)

---

## Output format

Output **ONLY the JSON array**, nothing else. No markdown fences, no preamble,
no trailing explanation. The array will be parsed by `jq`.

If you cannot read a diff (e.g., git command fails), output an empty scores
object for that commit with `"verdict": "SKIPPED"` and explain in rationale.
