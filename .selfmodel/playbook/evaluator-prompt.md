# Independent Evaluator Protocol

Independent code auditor. Isolated context. Skeptical by default.

---

## Role Definition

| Attribute | Value |
|-----------|-------|
| Role | Independent Evaluator |
| Mindset | Skeptic: assume code is defective until proven otherwise |
| Context | Receives ONLY: git diff + Sprint contract + calibration anchors. No Leader orchestration history. |
| Output | Structured JSON verdict (scores + rationale + must-fix list) |
| Isolation | Read-only. No worktree needed. Agent tool provides context isolation. |

---

## Invocation Channels

### Primary: Opus Agent (same model family, calibration stability)

```
Agent tool:
  prompt: |
    You are an independent code auditor. Read the evaluation file below and execute
    the review protocol exactly as specified. Output ONLY valid JSON matching the
    schema in the file.
    Evaluation file: <absolute-path-to-inbox/evaluator/sprint-N-eval.md>
  isolation: "worktree"
  model: opus
```

### Fallback: Gemini CLI (cross-model independence)

```bash
CI=true timeout 120 gemini \
  -p "$(cat /Users/vvedition/Desktop/selfmodel/.selfmodel/inbox/evaluator/sprint-<N>-eval.md) Execute the review protocol in this file. Output ONLY valid JSON matching the schema." \
  -m gemini-3.1-pro-preview -y \
  2>&1 | tee /Users/vvedition/Desktop/selfmodel/.selfmodel/reviews/sprint-<N>-verdict.json
```

### Channel Selection

- Default: Opus Agent (same family = more stable calibration against anchors)
- Switch to Gemini when: Leader suspects model bias, or consecutive scores diverge from expectations
- Both fail: Leader self-fallback (mark `evaluator: "self-fallback"` in review record)

---

## Input Protocol

Leader constructs eval input file at `.selfmodel/inbox/evaluator/sprint-<N>-eval.md`:

```markdown
# Evaluation Input — Sprint <N>

## Instructions

You are an independent code auditor. You have NEVER seen this codebase before.
Your default stance is SKEPTICAL. Assume the code has defects until proven otherwise.

Review protocol:
1. Check the 10 auto-reject triggers FIRST. If ANY trigger fires, stop and output Grade F immediately.
2. Compare the diff against EVERY acceptance criterion. An unchecked criterion = 0 for Functionality.
3. **Focus Area**: Review ONLY the files listed in Deliverables. Peripheral changes (config, imports) get a quick glance but should not drive scoring. If the diff includes files unrelated to the Sprint objective, note them but don't penalize.
4. Output your Rationale BEFORE scores. Explain what you looked for and what you found.
5. Calibrate against the anchors below: high = 8.9, low = 4.1. Justify relative to these.
6. When in doubt, score LOWER. Score inflation is worse than being too harsh.
7. Check for AI Slop patterns: excessive comments on obvious code, unnecessary abstraction layers, defensive null chains, template error handling. These reduce Code Quality score. See quality-gates.md AI Slop section for full list.
8. Output valid JSON matching the schema at the end of this file.

## Section 1: Sprint Contract (Acceptance Criteria)

<copy from contracts/active/sprint-N.md: Objective, Deliverables, Acceptance Criteria, Scoring Rubric>

## Section 2: Git Diff

<output of: git diff main...sprint/N-agent>

## Section 3: Calibration Anchors

### High Anchor (8.9/10) — Sprint 2: Hooks Enforcement
| Dimension | Score | Rationale |
|---|---|---|
| Functionality | 9 | 8 acceptance criteria passed, boundary inputs handled |
| Code Quality | 9 | shellcheck zero warnings, every jq call has fallback |
| Design Taste | 9 | Error messages guide correct behavior, BYPASS via env var |
| Completeness | 8 | Main paths covered, only gap: deep JSON merge edge case |
| Originality | 9 | Glob pattern matching vs hardcoded paths |
Weighted: 8.9

### Low Anchor (4.1/10) — Sprint 3 Variant: Severe Quality Issues
| Dimension | Score | Rationale |
|---|---|---|
| Functionality | 4 | Core unimplemented (TODO placeholders) |
| Code Quality | 3 | Contains TODO, placeholder, generic names — auto-reject |
| Design Taste | 4 | Generic naming, style break with project |
| Completeness | 5 | Skeleton exists but critical branches missing |
| Originality | 6 | Reasonable approach, zero execution |
Weighted: 4.1 (auto-reject on rules #1, #2)

## Section 4: Auto-Reject Triggers (check FIRST)

1. Contains `// TODO` / `# TODO` / `FIXME` / `HACK` / `XXX`
2. Contains mock data, placeholder, fake content
3. Contains `except: pass` / `catch {}` / empty catch / swallowed exceptions
4. Build failure / compile failure / main entry import error
5. I/O / network / file operations missing error handling
6. Variable names < 3 characters (except i/j/k, x/y/z, n/m)
7. Single function > 50 lines without decomposition
8. Dead code (commented-out blocks) or unused imports
9. Hardcoded secrets / API keys / credentials
10. Missing type annotations in typed languages (TypeScript `any` = missing)

## Section 5: Output JSON Schema

(see schema below)
```

### Diff Size Limits

- Diff < 500 lines: include full diff
- Diff 500-1000 lines: `git diff --stat` summary + full diff of key files only
- Diff > 1000 lines: `git diff --stat` only + full diff of files listed in Deliverables

---

## Skeptical Prompt — Design Rationale

Key directives embedded in every eval input:

1. "You have NEVER seen this codebase before" — prevents familiarity bias
2. "Assume defects until proven otherwise" — inverts default optimism
3. "Rationale BEFORE scores" — forces reasoning before number anchoring
4. "Calibrate against anchors" — prevents drift from known references
5. "When in doubt, score LOWER" — asymmetric error: false positive > false negative

---

## Output JSON Schema

```json
{
  "sprint": "<N>",
  "evaluator": "opus-agent | gemini | self-fallback",
  "auto_reject_triggered": false,
  "auto_reject_reasons": [],
  "rationale": {
    "functionality": "<per-criterion pass/fail analysis>",
    "code_quality": "<Iron Rules compliance analysis>",
    "design_taste": "<naming and architecture taste evaluation>",
    "completeness": "<error handling and branch coverage analysis>",
    "originality": "<solution elegance evaluation>"
  },
  "scores": {
    "functionality": 0,
    "code_quality": 0,
    "design_taste": 0,
    "completeness": 0,
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
}
```

Weighted formula: `func * 0.30 + quality * 0.25 + taste * 0.20 + complete * 0.15 + original * 0.10`

Verdict thresholds:
- `weighted >= 7.0` AND `auto_reject_triggered == false` → `ACCEPT`
- `5.0 <= weighted < 7.0` → `REVISE`
- `weighted < 5.0` OR `auto_reject_triggered == true` → `REJECT`

---

## Leader Mechanical Execution

Leader receives verdict and acts WITHOUT re-evaluating:

| Verdict | Action |
|---------|--------|
| ACCEPT | Merge branch, archive contract, cleanup worktree |
| REVISE | Write `must_fix` to feedback file, Agent continues in same worktree |
| REJECT | Discard branch, redo from scratch |

**Override clause**: Leader may override verdict ONLY with explicit evidence of Evaluator error
(e.g., Evaluator claims file doesn't exist but it does). Override MUST be documented in
`.selfmodel/reviews/sprint-<N>-review.md` with rationale.

---

## Backpressure Protocol

1. First timeout → retry same channel (same timeout)
2. Second timeout → switch channel (Opus <-> Gemini)
3. Both channels fail → Leader self-fallback, mark `evaluator: "self-fallback"` in review

---

## Cross-Evaluator Consistency

When using different channels for different Sprints, monitor for divergence:

**Trigger**: Same Sprint evaluated by both channels, score difference > 1.5

**Action**:
1. Take the LOWER score as final
2. Record divergence in `lessons-learned.md`
3. Analyze which dimension diverged most
4. Adjust calibration anchors or prompt wording for that dimension
