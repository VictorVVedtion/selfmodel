# Evaluation Input — Sprint 8

## Instructions

You are an **independent code auditor**. You have never seen this codebase in this conversation. Skeptical default. Sprint 8 is a pure documentation insertion Sprint — the Agent was instructed to insert Leader-approved exact text and change nothing else. Your job is to verify that rule was followed.

### Protocol

1. Check the 10 auto-reject triggers (Section 4) — most won't apply to documentation but check anyway.
2. Fetch the diff:
   ```bash
   cd /Users/vvedition/Desktop/selfmodel
   git diff main...worktree-agent-aadaf9eb
   ```
3. Read the Sprint contract at `/Users/vvedition/Desktop/selfmodel/.selfmodel/contracts/active/sprint-8.md`. It contains three "Text 1 / Text 2 / Text 3" blocks that MUST appear verbatim in the diff.
4. **Verbatim check** — each text block must be byte-for-byte identical to the contract's approved version. Paraphrase, re-ordering, punctuation drift, or smart-quote substitution are all rejection-grade issues. This is the whole point of this Sprint.
5. **Scope check** — the diff must touch exactly two files (`CLAUDE.md` and `.selfmodel/playbook/lessons-learned.md`) and contain zero deletions (pure insertion). Any other file touched or any line removed → REVISE at minimum.
6. **Monotonic rule check** — CLAUDE.md Iron Rules must read `1, 2, ..., 19, 20` in order with no gaps.
7. **Insertion placement check** — Rule 20 must sit between Rule 19 and `### Leader Decision Principles`. The FORBIDDEN entry must sit in the `### ABSOLUTELY FORBIDDEN` list right after "No serial execution". The lessons-learned entry must sit at the end of the file after "11-Sprint Fan-Out Merge Hell".
8. **Format consistency** — new FORBIDDEN bullet must match `- **<bold>** — <explanation>` style of siblings. New lessons-learned entry must match the Sprint/Category/Lesson/Action/Result schema.
9. Score on the 6-dimension rubric. Note: because this Sprint is pure insertion of approved text, "Originality" is naturally capped low — this is not a negative.
10. Output JSON verdict to `/Users/vvedition/Desktop/selfmodel/.selfmodel/reviews/sprint-8-verdict.json`.

### Agent self-reported results (verify independently, don't trust)

- Branch: `worktree-agent-aadaf9eb`
- Commit: `efbf4194944a06b3772cc28cd6659d4ae90031ee`
- 3 Edit operations, all one-shot anchor hits
- CLAUDE.md: +2 lines (Rule 20 is one line, FORBIDDEN bullet is one line)
- lessons-learned.md: +11 lines
- Total: 13 additions, 0 deletions, 2 files

---

## Section 1: Sprint Contract

`/Users/vvedition/Desktop/selfmodel/.selfmodel/contracts/active/sprint-8.md`

Acceptance Criteria are explicit. The three "Exact Text" blocks in the contract's `## Context` section are your verbatim reference.

## Section 2: Diff

```bash
cd /Users/vvedition/Desktop/selfmodel
git diff main...worktree-agent-aadaf9eb -- CLAUDE.md .selfmodel/playbook/lessons-learned.md
git diff main...worktree-agent-aadaf9eb --stat   # verify only these 2 files
```

## Section 3: Calibration Anchors

### High Anchor (8.9/10) — Sprint 2: Hooks Enforcement

(Same anchor as Sprint 7 eval. Hooks Enforcement had multiple dimensions working hard; a pure-insertion Sprint cannot reach 8.9 because Originality caps low. Use this anchor to understand where real work sits, not to penalize Sprint 8 for being simple.)

### Low Anchor (4.1/10) — placeholder/TODO Sprint

Same as before. Not applicable here unless the Agent somehow inserted wrong text.

### Sprint 8 expected range

- **Ideal**: 8.5-9.0 on Functionality (every AC passes), 9-10 on Code Quality (verbatim match), 8 on Integration Depth (format match with siblings), 6-7 on Originality (cap — pure insertion).
- **Any deviation from verbatim** → Functionality and Code Quality tank to 5 or below.
- **Any collateral file touched** → auto-REVISE even if verbatim is perfect.

---

## Section 4: Auto-Reject Triggers

(Standard 10 triggers — mostly N/A for documentation, but check for accidental `TODO` / `FIXME` / placeholder text introduced in the Agent's insertion.)

## Section 5: AI Slop

Unlikely to apply to verbatim insertion, but verify the Agent didn't inject a "helpful" comment or explanation that isn't in the contract's approved text.

---

## Section 6: Output JSON Schema

Standard schema (see prior evals). Write to `.selfmodel/reviews/sprint-8-verdict.json`.

## Output format

Write JSON to the verdict file, then reply in under 120 words:
- Weighted score, verdict
- Confirmation that Rule 20, FORBIDDEN bullet, and lessons entry are byte-identical to the contract's approved text (any deviation = name the character)
- Confirmation that only 2 files were touched, 13 additions, 0 deletions
- Confirmation that Iron Rules are monotonic 1..20
- Any must_fix
