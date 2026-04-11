# Task: Sprint 10 — GitHub PR Flow Evolution

## Identity & Rules

You are **Gemini CLI Agent** running in an isolated git worktree. You are the **Generator** for Sprint 10. Your role is to apply **precise, byte-identical Edit operations** to 3 playbook files based on a Leader-drafted design artifact. You have **zero editorial freedom** — all replacement text is already written. Your job is to find the right `old_string`, paste the right `new_string`, and verify.

### Hard Constraints

- **Modify only these 3 files** (use Edit tool, not Write — all 3 exist):
  - `.selfmodel/playbook/dispatch-rules.md`
  - `.selfmodel/playbook/orchestration-loop.md`
  - `CLAUDE.md`
- **Do not touch any other file.** No "helpful cleanups" in adjacent sections. No README updates. No hook edits. No `.selfmodel/state/` writes. No commits to main.
- **Do not read, modify, or commit** `.selfmodel/artifacts/sprint-10-pr-flow-design.md` beyond reading it for the verbatim replacement blocks.
- **Do not paraphrase** any text. If the artifact says "绝对禁止", you write "绝对禁止" — not "strictly forbidden" or "禁止". Every character matters.
- **Do not add explanation comments** that aren't in the artifact.
- **Do not** run `git push`, `git reset --hard`, `git clean`, `rm -rf`, `npm install`, `selfmodel init`, or any side-effectful command.

## Task Overview

You will perform **6 Edit operations** across 3 files, based on 6 pre-drafted replacement blocks (BLOCK A through BLOCK F) in the Leader artifact. Then run validation grep commands and report DELIVERED.

### Artifact Location

Read this file **in full** before starting:

```
/Users/vvedition/Desktop/selfmodel/.selfmodel/artifacts/sprint-10-pr-flow-design.md
```

It contains 6 BLOCK sections titled like:
- `### BLOCK A: dispatch-rules.md "Rebase-Then-Merge 流程（Iron Rule）" section replacement`
- `### BLOCK B: dispatch-rules.md "并行 Sprint 串行 Merge 规则" section update`
- `### BLOCK C: orchestration-loop.md Step 7 ACCEPT path replacement`
- `### BLOCK D: orchestration-loop.md — new Step 6.9 PRE-MERGE SMOKE TEST`
- `### BLOCK E: orchestration-loop.md — remove Step 7.5 POST-MERGE SMOKE TEST`
- `### BLOCK F: CLAUDE.md Sprint Lifecycle update (Steps 5-7)`

Each BLOCK contains an **OLD STRING** (fenced code block) and a **NEW STRING** (fenced code block). Use these **byte-identically** as your Edit tool parameters.

**Critical**: the OLD STRING and NEW STRING are themselves inside fenced markdown code blocks in the artifact. You need to extract the text INSIDE the code fence, not the fence markers. If the artifact shows:

````
**OLD STRING**:

\`\`\`
### Rebase-Then-Merge 流程（Iron Rule）
...
\`\`\`
````

Then your Edit tool's `old_string` is exactly `### Rebase-Then-Merge 流程（Iron Rule）\n...` — without the ` ``` ` fence markers.

When the replacement text itself contains ` ``` ` (bash code fences), those MUST be preserved. Do not strip them.

## Execution Steps

### Step 1 — Read the artifact and both target files

```bash
cat /Users/vvedition/Desktop/selfmodel/.selfmodel/artifacts/sprint-10-pr-flow-design.md
```

Then read the 3 target files so you can confirm line numbers and anchor context:

```bash
sed -n '380,435p' .selfmodel/playbook/dispatch-rules.md
sed -n '205,260p' .selfmodel/playbook/orchestration-loop.md
sed -n '190,215p' CLAUDE.md
```

### Step 2 — BLOCK A: dispatch-rules.md Rebase-Then-Merge replacement

Extract OLD STRING and NEW STRING from BLOCK A in the artifact.

Apply using the Edit tool:
- `file_path`: `.selfmodel/playbook/dispatch-rules.md`
- `old_string`: the artifact's BLOCK A OLD STRING (byte-identical, including internal ` ```bash ` fences)
- `new_string`: the artifact's BLOCK A NEW STRING (byte-identical, including internal ` ```bash ` fences)

**Sanity check after edit**:
```bash
grep -c 'Rebase-Then-Merge 流程（Iron Rule，v0.6.0 PR-era）' .selfmodel/playbook/dispatch-rules.md
# Expected: 1
grep -c 'git merge sprint/<N>-<agent> --no-ff' .selfmodel/playbook/dispatch-rules.md
# Expected: 0 (the old line is gone)
grep -c 'gh pr merge' .selfmodel/playbook/dispatch-rules.md
# Expected: >= 1
```

### Step 3 — BLOCK B: dispatch-rules.md Serial Merge rule update

Extract OLD/NEW from BLOCK B. Edit tool on `.selfmodel/playbook/dispatch-rules.md`.

**Sanity check after edit**:
```bash
grep -c '并行 Sprint 串行 Merge 规则（PR-era）' .selfmodel/playbook/dispatch-rules.md
# Expected: 1
grep -c 'SERIAL' .selfmodel/playbook/dispatch-rules.md  # optional, not required
```

### Step 4 — BLOCK C: orchestration-loop.md Step 7 ACCEPT replacement

Extract OLD/NEW from BLOCK C. Edit tool on `.selfmodel/playbook/orchestration-loop.md`.

**Sanity check**:
```bash
grep -c 'SERIAL PR LANDING' .selfmodel/playbook/orchestration-loop.md
# Expected: 1
grep -c 'gh pr create' .selfmodel/playbook/orchestration-loop.md
# Expected: >= 1
grep -c 'git merge sprint/<N>-<agent> --no-ff' .selfmodel/playbook/orchestration-loop.md
# Expected: 0
```

### Step 5 — BLOCK D: Insert new Step 6.9 PRE-MERGE SMOKE TEST

This is an **insert**, not a replace. The artifact tells you to insert the new block AFTER the existing line `Skip for internal tools, config changes, documentation-only sprints.` at the end of Step 6.5.

Use Edit tool with:
- `old_string`: the line `       Skip for internal tools, config changes, documentation-only sprints.`
- `new_string`: that same line + `\n\n` + BLOCK D's NEW BLOCK text

Alternatively, if the Edit tool prefers a larger anchor for uniqueness, use the entire Step 6.5 closing + a blank line + the next line `  7.` as anchor, and insert BLOCK D between them. Either approach is fine as long as:
1. BLOCK D lands between Step 6.5 and Step 7
2. No other content is duplicated or lost
3. Indentation matches the `  6.9.` 2-space outer indent

**Sanity check**:
```bash
grep -c '6.9. PRE-MERGE SMOKE TEST' .selfmodel/playbook/orchestration-loop.md
# Expected: 1
# And verify 6.5 still exists and 7. still exists and they bracket 6.9:
grep -n '^  6.5\|^  6.9\|^  7. ACT' .selfmodel/playbook/orchestration-loop.md
# Expected: line numbers in ascending order with 6.5 < 6.9 < 7
```

### Step 6 — BLOCK E: Remove Step 7.5 POST-MERGE SMOKE TEST

Edit tool on `.selfmodel/playbook/orchestration-loop.md`:
- `old_string`: BLOCK E's OLD STRING (the entire `7.5. POST-MERGE SMOKE TEST` block including its trailing blank line)
- `new_string`: empty string `""`

**Sanity check**:
```bash
grep -c '7.5. POST-MERGE SMOKE TEST' .selfmodel/playbook/orchestration-loop.md
# Expected: 0
grep -n '^  7.6\|^  8.' .selfmodel/playbook/orchestration-loop.md
# Expected: 7.6 still exists, followed by 8. (7.5 slot is gone, but 7.6 survives)
```

### Step 7 — BLOCK F: CLAUDE.md Sprint Lifecycle Step 5-7 replacement

Edit tool on `CLAUDE.md` using BLOCK F's OLD/NEW strings.

**Sanity check**:
```bash
grep -c 'SERIAL PR LANDING' CLAUDE.md
# Expected: 1
grep -c 'gh pr create' CLAUDE.md
# Expected: 1
grep -c 'git merge sprint/<N>-<agent> --no-ff' CLAUDE.md
# Expected: 0
```

### Step 8 — Full validation grep suite

Run the entire validation block from the artifact's "Validation Commands" section:

```bash
# Block A: new section exists
grep -n 'Rebase-Then-Merge 流程（Iron Rule，v0.6.0 PR-era）' .selfmodel/playbook/dispatch-rules.md
grep -n 'gh pr merge.*--auto' .selfmodel/playbook/dispatch-rules.md

# Block B: new section exists
grep -n '并行 Sprint 串行 Merge 规则（PR-era）' .selfmodel/playbook/dispatch-rules.md

# Block C: new Step 7 text
grep -n 'SERIAL PR LANDING' .selfmodel/playbook/orchestration-loop.md
grep -n 'gh pr merge.*auto' .selfmodel/playbook/orchestration-loop.md

# Block D: new Step 6.9 exists
grep -n '6.9. PRE-MERGE SMOKE TEST' .selfmodel/playbook/orchestration-loop.md

# Block E: old Step 7.5 gone
! grep -q '7.5. POST-MERGE SMOKE TEST' .selfmodel/playbook/orchestration-loop.md && echo "ok: 7.5 removed"

# Block F: CLAUDE.md updated
grep -n 'SERIAL PR LANDING' CLAUDE.md
grep -n 'gh pr create' CLAUDE.md

# No old flow remnants
! grep -q 'git merge sprint/<N>-<agent> --no-ff' .selfmodel/playbook/dispatch-rules.md && echo "ok: dispatch-rules clean"
! grep -q 'git merge sprint/<N>-<agent> --no-ff' .selfmodel/playbook/orchestration-loop.md && echo "ok: orchestration-loop clean"
! grep -q 'git merge sprint/<N>-<agent> --no-ff' CLAUDE.md && echo "ok: CLAUDE.md clean"
```

Every positive grep must return at least 1 line. Every negative grep (the `!` ones) must echo "ok".

### Step 9 — Scope verification

Confirm exactly 3 files modified and nothing else:

```bash
git diff --name-only main...HEAD
# Expected output (exactly these 3 lines, any order):
#   CLAUDE.md
#   .selfmodel/playbook/dispatch-rules.md
#   .selfmodel/playbook/orchestration-loop.md

changed=$(git diff --name-only main...HEAD 2>/dev/null | wc -l | tr -d ' ')
test "$changed" = "3" && echo "ok 3 files" || { echo "FAIL $changed files"; exit 1; }
```

### Step 10 — Commit

```bash
git add CLAUDE.md .selfmodel/playbook/dispatch-rules.md .selfmodel/playbook/orchestration-loop.md
git commit -m "sprint-10: evolve Sprint merge flow from local merge to gh pr create+auto-merge

Change the documented Sprint landing flow:
- dispatch-rules.md Rebase-Then-Merge: local 'git merge --no-ff' → 'gh pr merge --auto'
- dispatch-rules.md Serial Merge: local serial merge → PR-era serial PR landing
- orchestration-loop.md Step 7 ACCEPT: local merge → push + PR create + auto-merge + poll + ff-only pull
- orchestration-loop.md new Step 6.9 PRE-MERGE SMOKE TEST (replaces old Step 7.5)
- orchestration-loop.md Step 7.5 POST-MERGE SMOKE TEST: removed (shifted left to 6.9)
- CLAUDE.md Sprint Lifecycle Step 5-7: updated to reflect PR flow

Sprint 10 itself is a meta-exception — merged via the OLD local-merge flow
because the new flow is what this Sprint is defining. Sprint 11 will be
the first Sprint to use the new PR flow.

All replacement text is byte-identical to the Leader-drafted verbatim
blocks in .selfmodel/artifacts/sprint-10-pr-flow-design.md BLOCK A-F.
No paraphrasing. No additions. No scope creep."
```

### Step 11 — Report STATUS: DELIVERED

Output the following block for Leader to parse:

```
STATUS: DELIVERED

Files changed:
  M CLAUDE.md
  M .selfmodel/playbook/dispatch-rules.md
  M .selfmodel/playbook/orchestration-loop.md

Block landing:
  A: dispatch-rules.md Rebase-Then-Merge — OK (new section exists, old merge line gone)
  B: dispatch-rules.md Serial Merge — OK (PR-era header exists)
  C: orchestration-loop.md Step 7 ACCEPT — OK (SERIAL PR LANDING + gh pr create present)
  D: orchestration-loop.md Step 6.9 — OK (PRE-MERGE SMOKE TEST inserted)
  E: orchestration-loop.md Step 7.5 — OK (POST-MERGE SMOKE TEST removed)
  F: CLAUDE.md Sprint Lifecycle — OK (SERIAL PR LANDING + gh pr create present)

Validation greps: 8 positive passed, 4 negative passed
git diff name-only: 3 files, no extras
Commit: <git rev-parse --short HEAD>
```

## Allowed Tools
Read, Grep, Edit, Bash (limited to: cat, sed -n, grep, git diff, git log, git status, git add, git commit, git rev-parse, test, wc, tr, echo)

## Forbidden Tools
Write (all 3 target files exist, use Edit), TodoWrite, mv, cp, rm, git push, git reset, git clean, npm, selfmodel

## Timeout
300s

## Success Criteria
All 6 Edit operations applied, all 12 validation greps pass, 3 files in git diff, 1 commit made, STATUS: DELIVERED reported with per-BLOCK evidence.

## Failure Escalation
If any BLOCK's OLD STRING cannot be found (anchor missing), do NOT improvise. Stop, report:
- Which BLOCK failed
- The exact `old_string` you tried to match (first 100 chars)
- The actual file content at the expected line range
- Do NOT proceed to subsequent BLOCKS until the current one lands

Leader will triage.
