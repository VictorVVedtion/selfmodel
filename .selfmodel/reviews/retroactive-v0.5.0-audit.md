# Retroactive Audit Report — v0.5.0 era (4 commits)

**Audited**: 2026-04-11
**Evaluator**: Opus Agent (independent, skeptical, isolated context)
**Raw JSON**: `.selfmodel/reviews/retroactive-v0.5.0-audit.json`
**Persisted to**: `.selfmodel/state/quality.jsonl` (4 entries, `retroactive: true`)

---

## Why this audit exists

Between 2026-04-07 and 2026-04-08, four commits landed directly on `main` without
going through the selfmodel Sprint → contract → worktree → Evaluator → PR flow
that the project's own rules require. This is a Rule 7 / 14 / 15 violation (Leader
implemented and merged without delegation or independent review).

This retroactive audit reconstructs what the Sprint process would have produced if
followed, and persists the results to `quality.jsonl` so the evolution pipeline
has real data to work with.

---

## Summary table

| # | SHA | Title | Weighted | Verdict | Notes |
|---|-----|-------|----------|---------|-------|
| R1 | `302f9aa` | v0.5.0 — Depth-First Workflow Enforcement | **7.85** | ACCEPT | Coherent, but hook only catches literal `gemini`/`codex` in Bash — Opus Agent tool dispatches bypass Gate 4/5/6 |
| R2 | `2bfaba0` | `selfmodel update` preserves sprint-template.md | **7.6** | ACCEPT | Clean 3-line guard matching sibling protection |
| R3 | `dd07f19` | settings.json SessionStart hook format fix | **6.7** | REVISE | AC1 vacuously true — live settings.json was already correct at parent commit; only template generator was broken |
| R4 | `f0410d7` | team.json regen + leader-worktree hook cleanup | **5.15** | REVISE | **Silent behavior regression** — see below |

## Aggregate dimension averages

| Dimension | Avg | Notes |
|-----------|-----|-------|
| Functionality | 6.75 | Weakest in R3 (6) and R4 (4) — R4 AC4 is factually false |
| Code Quality | 7.75 | No AI slop detected across any commit; shellcheck-clean |
| Design Taste | 6.75 | Taste drops on the small chore commits (R3/R4) |
| Completeness | 5.5 | **Systemic weakness** — missing tests / edge cases across all 4 |
| Integration Depth | 7.5 | R1 and R2 match existing patterns well |
| Originality | 6.25 | Small commits inherently cap this dimension |

**Takeaway**: Completeness is the systemic weakness — no tests on any of the 4
fixes, no regression verification. This is exactly what an independent Evaluator
would have caught pre-merge.

---

## Critical finding: R4 is a blocker-level regression

### What the commit claimed (from contract/commit message)

> "chore: selfmodel update regenerated team.json + leader-worktree hook
>  - enforce-leader-worktree.sh: regenerated from canonical heredoc template"
> AC4: "hook 行为未回归"

### What the diff actually did

`scripts/hooks/enforce-leader-worktree.sh` went from **9 whitelist rules** to
**6 rules**. The missing three rules (in pre-R4 `dd07f19^`):

```sh
# 7. Project infrastructure files (LICENSE, VERSION, CHANGELOG, etc.)
if [[ "${NORMALIZED}" == LICENSE* || "${NORMALIZED}" == VERSION || "${NORMALIZED}" == CHANGELOG* ]]; then ...

# 8. .github/ directory (issue templates, PR templates, workflows)
if [[ "${NORMALIZED}" == .github/* ]]; then ...

# 9. assets/ directory (visual assets, diagrams)
if [[ "${NORMALIZED}" == assets/* ]]; then ...
```

These were removed. The "canonical heredoc" in `scripts/selfmodel.sh:1640-1745`
only contains Rules 1–6 — so every `selfmodel update` will re-delete these rules
on any project that tries to add them.

### Blast radius — this is why the bug is important

As of 2026-04-11 (three days post-merge), these file types are **blocked from
Leader edits**:

- `LICENSE`, `VERSION`, `CHANGELOG` — releases are blocked
- `.github/workflows/*.yml` — CI changes blocked
- `assets/*` — diagrams / screenshots blocked

This silently breaks the core selfmodel publishing flow, and it blocks our own
Task #10 (fix the version-number mismatch) before we even start — Leader cannot
edit `VERSION` without tripping the hook.

### Why the retroactive contract labeled AC4 true

Because nobody ran an Evaluator. The Leader who wrote the chore message assumed
"regenerated from canonical" meant "semantically equivalent to pre-regen state",
which silently wasn't true because the canonical template had been drifting for
weeks.

### Required fix (blocker)

1. Restore Rules 7/8/9 in `scripts/selfmodel.sh` canonical heredoc
2. Regenerate `scripts/hooks/enforce-leader-worktree.sh` from updated heredoc OR
   manually restore from `f0410d7^`
3. Add a unit test comparing live hook vs canonical heredoc (structural regression
   catch)
4. This fix goes through a real Sprint (contract + worktree + Evaluator + PR) —
   Task #11 in the session task list

Workaround meanwhile: `BYPASS_LEADER_RULES=1` env var already exists at
`enforce-leader-worktree.sh:10` and can unblock Leader edits during the fix.

---

## Critical finding: R1 has a conceptual coverage gap

`enforce-depth-gate.sh` (the v0.5.0 centerpiece) only fires on Bash tool calls
containing literal `gemini` or `codex` strings. But the selfmodel Leader also
dispatches work via the Claude Code Agent tool (Opus Agent with
`isolation: "worktree"`) — the Opus Agent channel is the one most likely to carry
complex Sprints, and it completely bypasses Gate 4/5/6.

This isn't an auto-reject — the hook does what its code says — but it's a
conceptual incoherence: the gate that was added to protect complex Sprints
doesn't protect the channel that runs complex Sprints.

**Should-fix** (not blocker): add Agent-tool matcher to the depth gate.

---

## Aggregate should_fix themes (across all 4 commits)

Recurring patterns in what the Evaluator flagged:
1. **No tests written** for any of the 4 fixes — no hook unit test, no regression guard
2. **No drift-detection between canonical heredoc and live hook files** — R4's bug exists because this check doesn't exist
3. **Commit messages overstate scope** — R3 said "fixed both live and template" when only the template was fixed (live was already correct)
4. **Chore commits inherit no review** — the word "chore" masked R4's regression; in a real Sprint process, chore commits are still scored on the 6-dim rubric

---

## What quality.jsonl now looks like

```
R1  7.85  ACCEPT   (v0.5.0 depth-first enforcement)
R2  7.60  ACCEPT   (sprint-template guard)
R3  6.70  REVISE   (settings hook format — AC wording inaccurate)
R4  5.15  REVISE   (whitelist regression — blocker)
```

Average: **6.83** — exactly the kind of "just passing" score a rushed direct-to-main
batch would produce. If the Sprint process had been followed, R4 would have
bounced back as REVISE and the regression never hits users.

---

## Next actions

1. **Task #11** — Fix R4 whitelist regression via full Sprint flow (blocker)
2. **Task #10** — Version-number Sprint (unblocks after #11 since VERSION is
   currently gated)
3. **Task #9** — Formalize dogfooding rule in CLAUDE.md (requires human approval)
4. **Optional follow-ups** filed from should_fix items: Agent-tool depth gate
   coverage, heredoc/live drift check, hook unit tests
