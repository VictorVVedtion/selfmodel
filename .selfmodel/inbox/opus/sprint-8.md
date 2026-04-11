# Sprint 8 Task — Codify Rule 20 (Self-Dogfood) into CLAUDE.md + lessons-learned

You are Opus Agent working in an isolated worktree. This Sprint is pure documentation — you are inserting Leader-approved exact text into three specific locations. **Do not rewrite. Do not simplify. Do not "improve".** Your job is surgical insertion, not authoring.

## Contract (read this first)

`/Users/vvedition/Desktop/selfmodel/.selfmodel/contracts/active/sprint-8.md`

It has the complete Code Tour, Acceptance Criteria, and most importantly the **exact text** you must insert verbatim. Copy the three text blocks labeled "Text 1", "Text 2", "Text 3" from the contract and use the Edit tool to place them.

## Three insertions

### Insertion 1: CLAUDE.md Rule 20

**File**: `CLAUDE.md` (worktree root)

**Anchor**: The existing Rule 19 ends with `**Enforced by \`enforce-depth-gate.sh\` hook** — dispatch blocked at tool level if contract lacks depth content.` and is followed by a blank line, then `### Leader Decision Principles`.

**What to do**: Insert the entire Text 1 block (from the contract) after Rule 19's final line and before the blank line that precedes `### Leader Decision Principles`. The block is a single paragraph that starts with `20. **Self-Dogfood** — ` and contains no line breaks inside it (it's one logical paragraph).

After insertion the structure must be:

```
19. **Depth Gate** — ... dispatch blocked at tool level if contract lacks depth content.

20. **Self-Dogfood** — selfmodel 仓库自己的代码修改也必须走 Sprint 流程：contract → worktree → Agent → Evaluator → merge。...纪律红利。

### Leader Decision Principles
```

Use the **Edit** tool. Pick an `old_string` that uniquely identifies the "Rule 19 end + blank line + Leader Decision Principles heading" context, and replace it with "Rule 19 end + blank line + Rule 20 + blank line + Leader Decision Principles heading".

### Insertion 2: CLAUDE.md ABSOLUTELY FORBIDDEN entry

**File**: `CLAUDE.md` (same file)

**Anchor**: In the `### ABSOLUTELY FORBIDDEN` section, find the line:

```
- **No serial execution** — Independent tasks MUST be parallelized (within rolling batch cap, Rule 17)
```

This is the last bullet in that list.

**What to do**: Append Text 2 (from the contract) as a new bullet after it. Use the Edit tool. The `old_string` should include enough context around `No serial execution` to be unique in the file.

### Insertion 3: lessons-learned.md new entry

**File**: `.selfmodel/playbook/lessons-learned.md`

**Anchor**: The file currently ends with the "11-Sprint Fan-Out Merge Hell" entry, whose last line is `- **Result**: 待验证`.

**What to do**: Append Text 3 (from the contract) to the very end of the file, with one blank line separator before the new `### v0.5.0 Retroactive Audit` heading. Use the Edit tool with a unique `old_string` anchor (e.g., including the `- **Result**: 待验证` line as the last thing in the match).

If the file ends with a trailing newline, preserve it; if not, add one. Match the style of existing entries.

## Verify your work

After all three Edits, run from the worktree:

```bash
# 1. Rule 20 visible
grep -n "20. \*\*Self-Dogfood\*\*" CLAUDE.md

# 2. Forbidden entry visible
grep -n "No direct-to-main commits on selfmodel codebase" CLAUDE.md

# 3. lessons-learned entry visible
grep -n "v0.5.0 Retroactive Audit" .selfmodel/playbook/lessons-learned.md

# 4. Diff is ONLY these two files
git diff --stat HEAD

# 5. Rule numbers are monotonic
awk '/^[0-9]+\. \*\*/{print}' CLAUDE.md | head -25
# Should show 1..20 in order
```

Paste the output of each of these into your delivery report.

## Hard rules

- Work ONLY in your isolated worktree. Do NOT touch files in `/Users/vvedition/Desktop/selfmodel` (main).
- Do NOT change any other line of either file. Not one character. Not whitespace. Nothing.
- Do NOT use the Write tool (too risky for surgical edits — it would rewrite the whole file and introduce drift). Use Edit only.
- Do NOT rewrite the Leader-approved text. If you think a word is off, leave it. The text is final.
- Do NOT add a new `.selfmodel/state/` entry or other side effects.
- No `git push`, no `git reset --hard`, no `--no-verify`.
- Commit message format:
  ```
  docs(sprint-8): codify Rule 20 Self-Dogfood + lessons entry

  Inserts Rule 20 (Self-Dogfood) and a corresponding ABSOLUTELY FORBIDDEN
  entry in CLAUDE.md, plus a new lessons-learned entry documenting the
  v0.5.0 retroactive audit and Sprint 7 as the first compliant dogfooding
  Sprint. Pure insertion — no existing line changed.

  Approved verbatim text provided by Leader.

  Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
  ```

## Delivery report format

```
DELIVERY REPORT — Sprint 8

Branch: <your worktree branch name>
Worktree path: <absolute>

Files changed:
  - CLAUDE.md (+N -0 lines)
  - .selfmodel/playbook/lessons-learned.md (+N -0 lines)

Edit operations: 3 (one per insertion)

Smoke test output:
  grep "20. **Self-Dogfood**": <result>
  grep "No direct-to-main commits on selfmodel codebase": <result>
  grep "v0.5.0 Retroactive Audit": <result>
  git diff --stat HEAD: <output>
  rule numbering sanity: <awk output first 20 rules>

Commit SHA (worktree, not pushed): <sha>

Notes:
  <anything unexpected>
```

This Sprint is a meta-moment: Rule 20 defines how selfmodel must modify its own code, and this very Sprint is the first instance of applying that rule to itself. Precision matters. No improvisation.