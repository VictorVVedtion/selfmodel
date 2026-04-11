# Evaluation Input — Sprint 10 (GitHub PR Flow Evolution)

## Instructions

You are an **independent code auditor**. You have never seen this codebase in this conversation. Skeptical default. Sprint 10 is a **standard-complexity, documentation-only meta-Sprint** — the Generator (Gemini CLI) was instructed to perform exact byte-identical Edit operations based on 6 pre-drafted replacement blocks (BLOCK A-F) in a Leader-drafted design artifact. Your job is to verify rule-following and score on the 6-dimension rubric.

### Context — what Sprint 10 changes

Sprint 10 migrates the documented Sprint merge flow from **local `git merge --no-ff`** to **`gh pr create` + `gh pr merge --auto`** across 3 playbook files:
- `.selfmodel/playbook/dispatch-rules.md` (BLOCK A + B)
- `.selfmodel/playbook/orchestration-loop.md` (BLOCK C + D + E)
- `CLAUDE.md` (BLOCK F)

Sprint 10 **does not change any runtime behavior** — it only updates the documentation that describes the merge protocol. No code. No hooks. No scripts. No tests.

Sprint 10 itself is a **meta-exception**: it is merged via the OLD local-merge flow (one last time), because the new PR flow is what this Sprint is defining. Sprint 11 onward uses the new flow. This is documented in the contract and should NOT be counted against the Sprint (a Sprint cannot use a flow that doesn't exist yet).

### Generator channel fallback

Opus Agent channel (primary) hit rate limit earlier in the session. Gemini CLI was used as fallback Generator. During its run, Gemini hit a transient 429 RESOURCE_EXHAUSTED error midway but completed the 6 Edits before the capacity issue blocked the run. Gemini could not commit from inside the worktree due to macOS Seatbelt sandbox restrictions on `.git/worktrees/`; Leader committed the changes in a second step (no content changes — `git add` + `git commit` on exactly the 3 files Gemini modified).

### Protocol

1. Check the 10 auto-reject triggers (Section 4). Most will not apply to a pure documentation Sprint, but confirm nothing sneaked in.

2. Fetch the diff:
   ```bash
   cd /Users/vvedition/Desktop/selfmodel
   git diff main...sprint/10-gemini
   git diff main...sprint/10-gemini --stat
   ```

3. Read the Sprint contract at `/Users/vvedition/Desktop/selfmodel/.selfmodel/contracts/active/sprint-10.md`. Pay attention to:
   - `## Acceptance Criteria` (9 checkboxes)
   - `## Files` section (3 Modifies, 0 Creates, a long Out of Scope list)
   - `## Smoke Test` section (12 grep validation commands)
   - `## Dispatch Note` about the meta-exception

4. Read the Leader design artifact at `/Users/vvedition/Desktop/selfmodel/.selfmodel/artifacts/sprint-10-pr-flow-design.md`. The 6 BLOCKs (A-F) contain the byte-identical OLD STRING / NEW STRING pairs. Your verification is that the diff reflects these pairs exactly.

5. **Verbatim check** — each of the 6 BLOCK replacements must land byte-identically. Use `git show sprint/10-gemini:<file>` to read the new content, then search for key phrases from the NEW STRINGs.

   Fast check via grep:
   ```bash
   # Block A landmarks
   git show sprint/10-gemini:.selfmodel/playbook/dispatch-rules.md | grep -c 'Rebase-Then-Merge 流程（Iron Rule，v0.6.0 PR-era）'
   git show sprint/10-gemini:.selfmodel/playbook/dispatch-rules.md | grep -c 'gh pr merge "\$PR_NUMBER" --merge --delete-branch --auto'
   # Block B landmarks
   git show sprint/10-gemini:.selfmodel/playbook/dispatch-rules.md | grep -c '并行 Sprint 串行 Merge 规则（PR-era）'
   # Block C landmarks
   git show sprint/10-gemini:.selfmodel/playbook/orchestration-loop.md | grep -c 'SERIAL PR LANDING'
   git show sprint/10-gemini:.selfmodel/playbook/orchestration-loop.md | grep -c 'gh pr create'
   # Block D landmarks
   git show sprint/10-gemini:.selfmodel/playbook/orchestration-loop.md | grep -c '6.9. PRE-MERGE SMOKE TEST'
   # Block F landmarks
   git show sprint/10-gemini:CLAUDE.md | grep -c 'SERIAL PR LANDING'
   git show sprint/10-gemini:CLAUDE.md | grep -c 'gh pr create'
   # Block E (removal)
   git show sprint/10-gemini:.selfmodel/playbook/orchestration-loop.md | grep -c '7.5. POST-MERGE SMOKE TEST'
   # Expected 0
   ```

6. **Scope check** — the diff MUST touch exactly 3 files:
   - `CLAUDE.md`
   - `.selfmodel/playbook/dispatch-rules.md`
   - `.selfmodel/playbook/orchestration-loop.md`

   Any other file touched → auto-REVISE. Any file under `scripts/`, `.github/`, `README.md`, or other playbook files touched → auto-REVISE at minimum.

   ```bash
   git diff main...sprint/10-gemini --name-only
   ```

7. **Structural continuity check** — after BLOCK D insertion and BLOCK E deletion, `orchestration-loop.md` must still have:
   - Step 6.5 at some line
   - Step 6.9 at a later line
   - Step 7 at a later line
   - Step 7.6 at an even later line
   - NO Step 7.5 anywhere

   ```bash
   git show sprint/10-gemini:.selfmodel/playbook/orchestration-loop.md | grep -n '^  6\.5\|^  6\.9\|^  7\. ACT\|^  7\.5\|^  7\.6'
   ```

8. **Negative checks** — the old flow references MUST be gone from the 3 primary flow paths:
   ```bash
   git show sprint/10-gemini:.selfmodel/playbook/dispatch-rules.md | grep -c 'git merge sprint/<N>-<agent> --no-ff'
   # Expected 0
   git show sprint/10-gemini:.selfmodel/playbook/orchestration-loop.md | grep -c 'git merge sprint/<N>-<agent> --no-ff'
   # Expected 0
   git show sprint/10-gemini:CLAUDE.md | grep -c 'git merge sprint/<N>-<agent> --no-ff'
   # Expected 0
   ```

   **Note**: the artifact file `.selfmodel/artifacts/sprint-10-pr-flow-design.md` contains the OLD STRING (with `git merge sprint/<N>-<agent> --no-ff`) as reference. That file is **out of scope** for this Sprint (it was created BEFORE this Sprint, and Agent was forbidden to edit it). Do NOT flag the artifact file's retention of the old reference — that's by design.

9. **Design taste check** — the new text should read naturally, match the existing playbook style (mixed Chinese/English section headers, Markdown conventions, code fence usage), and form coherent self-referential references. Specifically:
   - `dispatch-rules.md` BLOCK A references `orchestration-loop.md Step 6.9` — verify 6.9 exists in the sibling file.
   - `orchestration-loop.md` Step 7 references `dispatch-rules.md Step 8` — this is a lateral reference. Verify `dispatch-rules.md` has such a Step 8 in BLOCK A.
   - `CLAUDE.md` Step 6.d references `orchestration-loop.md Step 6.9` — verify consistent.

10. **Meta-exception integrity** — the contract declares Sprint 10 itself will be merged via OLD local-merge flow. The Agent's job was to modify documentation; it did NOT and SHOULD NOT have attempted to merge via the new flow. Verify the Agent did not prematurely attempt `gh pr create` or `git push`.

    ```bash
    # Agent should not have touched remote
    cd /Users/vvedition/Desktop/selfmodel
    git ls-remote origin sprint/10-gemini
    # Expected: empty output (branch not on remote yet)
    ```

11. Score on the 6-dimension rubric. Calibration notes below.

12. Output the JSON verdict to `/Users/vvedition/Desktop/selfmodel/.selfmodel/reviews/sprint-10-verdict.json`. Reply in ≤200 words.

### Agent self-reported results (VERIFY INDEPENDENTLY — do not trust)

- Branch: `sprint/10-gemini`
- Commit: `a700bab` (Leader-committed; Gemini authored the content but could not commit from sandbox)
- 6 Edit operations:
  - BLOCK A: dispatch-rules.md Rebase-Then-Merge section — new `v0.6.0 PR-era` content
  - BLOCK B: dispatch-rules.md Serial Merge rule — new `（PR-era）` section
  - BLOCK C: orchestration-loop.md Step 7 ACCEPT — new SERIAL PR LANDING flow
  - BLOCK D: orchestration-loop.md Step 6.9 PRE-MERGE SMOKE TEST — new insertion
  - BLOCK E: orchestration-loop.md Step 7.5 POST-MERGE SMOKE TEST — removed
  - BLOCK F: CLAUDE.md Sprint Lifecycle Step 5-7 — updated
- Files changed: 3 (CLAUDE.md, dispatch-rules.md, orchestration-loop.md)
- Lines: +149 / -53 (net +96)
- All 12 smoke validation greps passed when Leader ran them on the worktree

---

## Section 1: Sprint Contract (Acceptance Criteria)

See `/Users/vvedition/Desktop/selfmodel/.selfmodel/contracts/active/sprint-10.md`.

The 9 acceptance criteria checklist and the 12-check smoke test block are your functionality rubric.

## Section 2: Git Diff

```bash
cd /Users/vvedition/Desktop/selfmodel
git diff main...sprint/10-gemini
git diff main...sprint/10-gemini --stat
```

Expected stat: 3 files, +149/-53.

## Section 3: Calibration Anchors

### High Anchor (8.9/10) — Sprint 2: Hooks Enforcement
Multi-file shellscript implementation with clean error handling and elegant design. Sprint 10 is documentation-only so it cannot match on Completeness (no runtime surface to be complete on), but it can match on Code Quality (verbatim fidelity) and Integration Depth (preserving section structure, references consistent across files).

### Low Anchor (4.1/10) — placeholder/TODO Sprint
Not applicable unless Gemini paraphrased the verbatim text or left stale merge references.

### Sprint 10 expected range
- **Ideal**: 9 on Functionality (all 12 validation greps pass → every AC met), 9 on Code Quality (byte-identical insertion), 8 on Design Taste (natural reading, style-consistent), 8 on Completeness (the 3 files reference each other correctly, no dangling references), 9 on Integration Depth (cross-file consistency — CLAUDE.md summary matches dispatch-rules.md detail matches orchestration-loop.md steps), 6-7 on Originality (verbatim-style Sprint, low design space).
- **Any paraphrase** → Code Quality tanks to 5-6.
- **Any scope creep** (4th file touched) → auto-REVISE regardless of scores.
- **Any dangling reference** (e.g. orchestration-loop.md mentions Step 6.9 but it doesn't exist) → REVISE.
- **Any Step 7.5 remnant** in orchestration-loop.md → REVISE.

---

## Section 4: Auto-Reject Triggers

Standard 10 triggers. Most do not apply to documentation:
1. TODO/FIXME markers — should be 0 new introductions
2. Mock/placeholder content — N/A
3. Swallowed exceptions — N/A
4. Build failure — N/A (no build step for .md files; sanity check: `bash -n scripts/selfmodel.sh` should still succeed because Sprint 10 didn't touch it)
5. Missing error handling — N/A
6. Short var names — N/A
7. Long functions — N/A
8. Dead code / commented-out blocks — check for any `# ` prefixed commented-out lines in the new text
9. Hardcoded secrets — N/A (but scan anyway since prose might accidentally include one)
10. Missing type annotations — N/A

## Section 5: AI Slop Check

Watch for:
- Extra "helpful" explanatory paragraphs that aren't in the artifact
- "Let me add a note about..." sentences
- Emoji bullets if the originals use text bullets
- Inconsistent section header style (e.g. adding `---` separators where the original used blank lines)
- Rephrased variable names or commands (any change to `gh pr merge --merge --delete-branch --auto` is a red flag)

A verbatim Sprint that adds even one comment beyond the approved text is REVISE.

---

## Section 6: Output JSON Schema

Standard 6-dimension schema per `evaluator-prompt.md`. Write to `/Users/vvedition/Desktop/selfmodel/.selfmodel/reviews/sprint-10-verdict.json`.

Required fields:
- `sprint`: "10"
- `evaluator`: "gemini" | "opus-agent" | "leader-self-fallback"
- `auto_reject_triggered`: boolean
- `auto_reject_reasons`: array
- `rationale`: object with 6 keys
- `scores`: object with 6 keys (0-10 each)
- `weighted`: number (formula: func*0.25 + quality*0.20 + taste*0.15 + complete*0.15 + integration*0.15 + original*0.10)
- `verdict`: "ACCEPT" | "REVISE" | "REJECT"
- `must_fix`: array
- `should_fix`: array
- `praise`: array

Verdict thresholds: weighted ≥ 7.0 → ACCEPT, 5.0-6.9 → REVISE, <5.0 → REJECT.

## Output format

1. Write JSON to `/Users/vvedition/Desktop/selfmodel/.selfmodel/reviews/sprint-10-verdict.json` (valid JSON, parseable by jq).
2. Reply in ≤200 words:
   - Weighted score, verdict
   - Confirmation that exactly 3 files are touched
   - Confirmation that all 6 BLOCKs land verbatim (or name the first diverging one)
   - Confirmation that cross-file references are consistent (CLAUDE.md ↔ dispatch-rules.md ↔ orchestration-loop.md)
   - Confirmation that Step 6.9 exists and Step 7.5 is removed
   - Any must_fix
