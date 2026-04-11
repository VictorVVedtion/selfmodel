# Sprint 7 Task — Restore enforce-leader-worktree.sh whitelist

You are Opus Agent working in an isolated worktree. Read the Sprint contract carefully and implement exactly what it says. No scope creep. No extra "improvements".

## Sprint contract

`/Users/vvedition/Desktop/selfmodel/.selfmodel/contracts/active/sprint-7.md` (read this first — it has the full Code Tour, Acceptance Criteria, Architecture Context, and Smoke Test)

## Background (one paragraph)

A commit `f0410d7` silently deleted 3 whitelist rules from `scripts/hooks/enforce-leader-worktree.sh` by regenerating it from a canonical heredoc template in `scripts/selfmodel.sh` that had never absorbed those rules. This Sprint restores the 3 rules in both the live hook and the canonical heredoc, and adds a drift-check test so `selfmodel update` can't silently revert this again.

## What to do (step by step)

### Step 1 — Get the exact pre-R4 code

Run this to see exactly what Rules 7/8/9 looked like before the regression:

```bash
git show f0410d7^:scripts/hooks/enforce-leader-worktree.sh
```

Pay attention to lines 70-82 (the three `if` blocks). Your restored rules should match that style and position in the file (between the current Rule 6 `.gitignore` block and the "白名单外：拦截" fallthrough).

### Step 2 — Edit `scripts/hooks/enforce-leader-worktree.sh`

Insert Rules 7/8/9 after the current Rule 6 `.gitignore` block. Also update the error-message text at line ~77 that lists "白名单范围: .selfmodel/、.claude/、scripts/、playbook/、*.md、.gitignore" to include the 3 new categories (LICENSE/VERSION/CHANGELOG, `.github/`, `assets/`).

### Step 3 — Edit `scripts/selfmodel.sh` canonical heredoc

Find the function `generate_hooks` and within it the `enforce-leader-worktree.sh` heredoc block (around lines 1640-1745, delimited by `cat > "$hooks_dir/enforce-leader-worktree.sh" << 'HOOKEOF'` and `HOOKEOF`). The content inside the heredoc must now match your updated live hook byte-for-byte (modulo the heredoc delimiter itself).

**Important**: don't reflow the surrounding `generate_hooks` function. Only change the heredoc body.

### Step 4 — Create `scripts/tests/test-hook-drift.sh`

Create a new test script that:

1. Sources or invokes `scripts/selfmodel.sh`'s `generate_hooks` logic in a way that writes to a temporary directory (you may need to extract the heredoc content into a temp file another way — read `generate_hooks` carefully and pick the cleanest method).
2. Compares the generated canonical content against the current `scripts/hooks/enforce-leader-worktree.sh` file.
3. Exits 0 on match, exits 1 with a diff output on mismatch.

Acceptable alternative if the generate_hooks function is hard to call in isolation: use `awk` / `sed` to extract the heredoc body between `<< 'HOOKEOF'` and the next `HOOKEOF` line, write it to a temp file, and diff against the live hook.

Make the script executable: `chmod +x scripts/tests/test-hook-drift.sh`.

Add a shebang (`#!/usr/bin/env bash`) and `set -euo pipefail`. Match the project's shell style (see `scripts/hooks/enforce-leader-worktree.sh` for reference).

### Step 5 — Run the smoke test from the contract

Exactly as written in the Sprint contract's `## Smoke Test` section. All three parts must pass. Paste the output into your delivery report.

### Step 6 — Stage, commit, push

Standard worktree flow:

```bash
git add scripts/hooks/enforce-leader-worktree.sh scripts/selfmodel.sh scripts/tests/test-hook-drift.sh
git status  # verify nothing else
git commit -m "fix(sprint-7): restore enforce-leader-worktree whitelist Rules 7/8/9

R4 (f0410d7) silently deleted Rules 7/8/9 (LICENSE/VERSION/CHANGELOG,
.github/*, assets/*) by regenerating from a canonical heredoc that had
drifted from the live file. This restores all three rules in both the
live hook and the canonical heredoc, and adds scripts/tests/test-hook-drift.sh
to catch future drift at test time.

Retroactive audit: .selfmodel/reviews/retroactive-v0.5.0-audit.md

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

Do **NOT** push. Do **NOT** merge to main. Leader will rebase and merge.

## Constraints

- Work in the worktree provided. Do NOT cd to `/Users/vvedition/Desktop/selfmodel` (that's main).
- Do NOT edit `.selfmodel/` anything. Do NOT edit CLAUDE.md.
- Do NOT add new whitelist rules beyond the 3 being restored. (If you notice a case for a new rule, note it in the delivery report — don't implement it.)
- Do NOT use mock data, TODO, or fallback strings. Implement the drift check properly.
- Do NOT use `--no-verify` on commits.
- Do NOT run `git push`, `git reset --hard`, `git clean -f`.
- Do NOT add `.github/` or `assets/` files just to test the whitelist. Test via `echo '{...}' | hook.sh` as shown in the contract smoke test.

## Forbidden

- Modifying any file in `.selfmodel/`
- Modifying CLAUDE.md
- Installing new dependencies
- Network calls to anything outside GitHub

## What to return

When done, print:

```
DELIVERY REPORT — Sprint 7

Branch: sprint/7-opus
Files changed:
  - scripts/hooks/enforce-leader-worktree.sh (+N -M)
  - scripts/selfmodel.sh (+N -M)
  - scripts/tests/test-hook-drift.sh (new, N lines)

Smoke test output:
  <paste the actual output here>

Drift test output:
  <paste "bash scripts/tests/test-hook-drift.sh" output>

Notes:
  <anything unexpected, alternatives considered, edge cases found>
```
