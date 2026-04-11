# Evaluation Input — Sprint 9 (VERSION string sync)

## Instructions

You are an **independent code auditor**. You have never seen this codebase in this conversation. Skeptical default. Sprint 9 is a **simple-complexity, string-sync Sprint** — the Agent was instructed to touch exactly 4 files and nothing else. Your job is to verify rule-following, not to judge product design.

### Protocol

1. Check the 10 auto-reject triggers (Section 4) — most will not apply to a pure string change, but confirm nothing sneaked in.
2. Fetch the diff:
   ```bash
   cd /Users/vvedition/Desktop/selfmodel
   git diff main...worktree-agent-accecd4a
   git diff main...worktree-agent-accecd4a --stat
   ```
3. Read the Sprint contract at `/Users/vvedition/Desktop/selfmodel/.selfmodel/contracts/active/sprint-9.md`. Read the inbox task at `/Users/vvedition/Desktop/selfmodel/.selfmodel/inbox/opus/sprint-9.md` — the `### CHANGELOG Entry (Verbatim)` block is the byte-identical reference for the new CHANGELOG insertion.
4. **Scope check** — the diff MUST touch exactly these 4 files and no others:
   - `VERSION`
   - `scripts/selfmodel.sh`
   - `README.md`
   - `CHANGELOG.md`

   Any other file touched → auto-REVISE. Any file under `.selfmodel/` touched → auto-REJECT.

5. **Per-file verification**:
   - `VERSION` — 1-line change, `0.4.0` → `0.5.0`, nothing else
   - `scripts/selfmodel.sh` — 1-line change on line 8, `SELFMODEL_VERSION="0.3.0"` → `SELFMODEL_VERSION="0.5.0"`. Crucially, **line 4034** (`selfmodel update --remote --version v0.3.0`) MUST remain unchanged — it is a CLI usage example, not drift.
   - `README.md` — 1-line change on line 13 only (version badge URL parameter + `alt` text). Lines 83, 190, 280, 358, 373, 430 contain historical `v0.3.0` feature-since markers and usage examples — they MUST remain unchanged.
   - `CHANGELOG.md` — pure insertion of a new `## [0.5.0] - 2026-04-11` section above the existing `## [0.4.0] - 2026-04-07` section. Zero deletions. Zero modifications to the [0.4.0] section.

6. **Verbatim check** — the CHANGELOG [0.5.0] block MUST be byte-for-byte identical to the `### CHANGELOG Entry (Verbatim)` block in `/Users/vvedition/Desktop/selfmodel/.selfmodel/inbox/opus/sprint-9.md`. Use a line-by-line comparison. Any paraphrase, word change, punctuation drift, backtick-to-quote substitution, or whitespace difference → REVISE at minimum. This is the **primary quality signal** of a verbatim Sprint.

   Suggested approach:
   ```bash
   # Extract the [0.5.0] section from the committed CHANGELOG (from the feature branch)
   git show worktree-agent-accecd4a:CHANGELOG.md | awk '/^## \[0.5.0\]/,/^## \[0.4.0\]/' | sed '$d' > /tmp/sprint9-actual.md
   # Extract the verbatim reference from the inbox task
   awk '/^```markdown$/{f=1; next} /^```$/{f=0} f' /Users/vvedition/Desktop/selfmodel/.selfmodel/inbox/opus/sprint-9.md > /tmp/sprint9-reference.md
   diff /tmp/sprint9-actual.md /tmp/sprint9-reference.md
   # Expected: empty output (byte-identical)
   ```

7. **Runtime check** — run `cd /Users/vvedition/Desktop/selfmodel/.claude/worktrees/agent-accecd4a && bash scripts/selfmodel.sh --version`. First line of stdout MUST equal `selfmodel 0.5.0` exactly.

8. **Historical marker preservation** — run `grep -c 'v0.3.0' /Users/vvedition/Desktop/selfmodel/.claude/worktrees/agent-accecd4a/README.md`. Expected: **at least 5** (handoff notes 6 historical markers on lines 83, 190, 280, 358, 373, 430; at least 5 must remain).

9. **Smoke test block** — the Sprint contract (`## Smoke Test`) lists 7 checks. Re-run them in the worktree and confirm all pass. Report any failure as a blocker.

10. Score on the 6-dimension rubric. **Note**: because this Sprint is pure string sync, Originality is naturally capped low (there is no design space). Functionality / Code Quality / Completeness / Integration Depth are what should drive the score. Design Taste = "Did they pick the right CHANGELOG section titles and narrative" which is mostly about matching the verbatim Leader-provided text.

11. Output the JSON verdict to `/Users/vvedition/Desktop/selfmodel/.selfmodel/reviews/sprint-9-verdict.json`. Then reply with a ≤150-word summary.

### Agent self-reported results (VERIFY INDEPENDENTLY — do not trust)

- Branch: `worktree-agent-accecd4a`
- Commit: `802d375`
- 4 Edit operations, all one-shot anchor hits
- VERSION: 1 line changed
- scripts/selfmodel.sh: 1 line changed (line 8)
- README.md: 1 line changed (line 13)
- CHANGELOG.md: 20 additions, 0 deletions (new [0.5.0] block)
- `--version` first line: `selfmodel 0.5.0`
- All 8 local checks passed

---

## Section 1: Sprint Contract (Acceptance Criteria)

See `/Users/vvedition/Desktop/selfmodel/.selfmodel/contracts/active/sprint-9.md`.

The 9 acceptance criteria and the 7-check smoke test are your functionality rubric. An unchecked criterion = 0 on Functionality for that criterion.

## Section 2: Git Diff

```bash
cd /Users/vvedition/Desktop/selfmodel
git diff main...worktree-agent-accecd4a
git diff main...worktree-agent-accecd4a --stat
```

Expected stat: 4 files, +23/-3 (CHANGELOG +20, VERSION ±1, scripts/selfmodel.sh ±1, README.md ±1).

## Section 3: Calibration Anchors

### High Anchor (8.9/10) — Sprint 2: Hooks Enforcement
(Standard anchor — multi-file logic change with shellcheck clean, robust error handling, elegant design. Sprint 9 cannot reach 8.9 because it has no design space — there is only one correct version string.)

### Low Anchor (4.1/10) — placeholder/TODO Sprint
(Standard anchor — not applicable unless the Agent somehow introduced a TODO or hallucinated a wrong version number.)

### Sprint 9 expected range

- **Ideal**: 9 on Functionality (every AC passes), 9 on Code Quality (no slop, no off-target edits), 8 on Completeness (all 4 files synced including CHANGELOG narrative), 8 on Integration Depth (matches existing CHANGELOG format and README badge style), 8 on Design Taste (correct dating, correct section labels), 5-6 on Originality (cap — string sync has no creative space).
- **Any wrong version number** (e.g., 0.4.1 instead of 0.5.0) → auto-REJECT.
- **Any historical marker touched** → auto-REVISE.
- **Any CHANGELOG verbatim drift** → auto-REVISE.
- **Any 5th file touched** → auto-REVISE at minimum.

---

## Section 4: Auto-Reject Triggers

Standard 10 triggers. Most do not apply to a string-sync Sprint, but check:
1. TODO/FIXME markers — should be 0
2. Mock/placeholder content — should be 0
3. Swallowed exceptions — N/A (no new logic)
4. Build failure — run `bash -n scripts/selfmodel.sh` (syntax check)
5. Missing error handling — N/A
6. Short var names — N/A
7. Long functions — N/A
8. Dead code / commented-out blocks — check the diff for any `# ` prefixed commented-out lines
9. Hardcoded secrets — N/A
10. Missing type annotations — N/A (bash)

## Section 5: AI Slop Check

Watch for:
- Extra "helpful" CHANGELOG commentary that isn't in the verbatim reference
- Extra modification to `README.md` (e.g., "updating version references throughout")
- Extra touch to `scripts/selfmodel.sh` line 4034 (CLI usage example)
- "Helper" comments added to the 4 files
- Any explanation comments the Agent added to justify the change

A verbatim Sprint that adds even one comment beyond the approved text is REVISE.

---

## Section 6: Output JSON Schema

Standard 6-dimension schema per `evaluator-prompt.md` Section "Output JSON Schema". Write to `/Users/vvedition/Desktop/selfmodel/.selfmodel/reviews/sprint-9-verdict.json`.

Required fields:
- `sprint`: "9"
- `evaluator`: "opus-agent"
- `auto_reject_triggered`: boolean
- `auto_reject_reasons`: array
- `rationale`: object with 6 keys
- `scores`: object with 6 keys
- `weighted`: number (formula: func*0.25 + quality*0.20 + taste*0.15 + complete*0.15 + integration*0.15 + original*0.10)
- `verdict`: "ACCEPT" | "REVISE" | "REJECT"
- `must_fix`: array
- `should_fix`: array
- `praise`: array

Verdict thresholds: weighted ≥ 7.0 → ACCEPT, 5.0-6.9 → REVISE, <5.0 → REJECT.

## Output format

1. Write JSON to `/Users/vvedition/Desktop/selfmodel/.selfmodel/reviews/sprint-9-verdict.json` (valid JSON only — will be parsed by jq).
2. Reply in ≤150 words:
   - Weighted score, verdict
   - Confirmation that exactly 4 files are touched (name them)
   - Confirmation that CHANGELOG [0.5.0] block is byte-identical to the inbox verbatim reference (or name the first diverging character)
   - Confirmation that `--version` first line = `selfmodel 0.5.0`
   - Confirmation that ≥5 historical `v0.3.0` markers preserved in README.md
   - Any must_fix (should be empty for a verbatim Sprint)
