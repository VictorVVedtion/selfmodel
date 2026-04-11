# Deep-Read + Design: Sprint 10 — GitHub PR Flow Evolution

> Leader orchestration artifact. Not implementation code. Per Rule 7 clarification,
> Leader deep-reads + drafts verbatim replacement blocks for standard Sprints with
> high-cost semantic changes; Agent then performs precise Edit insertions.

## Source Files Read

### `.selfmodel/playbook/dispatch-rules.md` (522 lines)
- **Lines 384-413**: `### Rebase-Then-Merge 流程（Iron Rule）` — current local-merge spec. Cites `git merge sprint/<N>-<agent> --no-ff` as the canonical merge step.
- **Lines 415-429**: `### 并行 Sprint 串行 Merge 规则` — serial merge on main, each Sprint rebases on new main HEAD before local merge.

### `.selfmodel/playbook/orchestration-loop.md` (444 lines)
- **Lines 218-234**: Step 7 `ACT on each verdict` — ACCEPT path does `cd <worktree> && git rebase main`, then `cd <main-repo> && git merge sprint/<N>-<agent> --no-ff`, then archive + cleanup.
- **Lines 236-255**: Step 7.5 `POST-MERGE SMOKE TEST` — runs build/test + contract `## Smoke Test` commands within 30s after local merge; `git revert HEAD --no-edit` on failure.

### `CLAUDE.md` (Worktree Isolation Workflow section)
- **Lines 175-209**: `### Sprint Lifecycle` — high-level 7-step outline. Steps 5-7 describe local review + rebase-merge + cleanup.
- Rule 13 (Iron Rule) at line 53 cites "Rebase-Then-Merge" in dispatch-rules.md. Text itself unchanged; still requires rebase + serial + post-merge smoke.

## Current Flow (summary)

```
1. Agent delivers in worktree (branch: worktree-agent-XXX or sprint/N-agent)
2. Leader reviews: git diff main...<branch>
3. Evaluator + E2E verdict
4. ACCEPT:
   a. cd <worktree> && git rebase main
   b. cd <main-repo> && git merge <branch> --no-ff
   c. Post-merge smoke (build + test + contract smoke block, 30s)
   d. Smoke fail → git revert HEAD --no-edit, Sprint → REVISE
5. Cleanup: git worktree remove, git branch -d
```

**Observability gap**: all merge decisions live on the Leader's local disk. No record in
GitHub. No CI run against the final merge commit. No paper trail for human review. No
way for a collaborator to see Sprint gates in action. This was acceptable when selfmodel
was a private experimental loop; it's now a real open-source project with 20+ merged PRs
in git history.

## Design Decisions

### D1. Branch naming before push
Harness-generated `worktree-agent-XXXXXXX` branches are ugly in PR lists. Before the
first `git push`, Leader renames to `sprint/<N>-<agent>` (the existing template name
in dispatch-rules.md line 191).

```bash
cd <worktree>
git branch -m sprint/<N>-<agent>      # local rename
```

This is a worktree-local operation and does not affect main.

### D2. Push strategy
First push: `git push -u origin sprint/<N>-<agent>`.
Updates (after Agent revisions): `git push --force-with-lease origin sprint/<N>-<agent>`.
Never `--force` without `--lease` (would clobber remote blindly if divergence occurred).

### D3. PR creation
```bash
gh pr create \
  --base main \
  --head sprint/<N>-<agent> \
  --title "Sprint <N>: <title>" \
  --body-file .selfmodel/reviews/sprint-<N>-pr-body.md
```

PR body file is auto-generated from contract + evaluator + e2e verdicts. Template:

```markdown
## Sprint <N>: <title>

**Verdict**: ACCEPT <weighted>/10 (<evaluator_channel>)
**E2E**: PASS <N>/<N> atomic verifications
**Complexity**: <simple|standard|complex>

### Summary
<one-paragraph contract objective>

### Files Changed
<from contract ## Files section>

### Acceptance Criteria
<contract AC list with ✓ marks from evaluator rationale>

### Evaluator Notes
<rationale summary from verdict JSON>

### Contract
`.selfmodel/contracts/archive/sprint-<N>.md`
```

### D4. Merge strategy: `--merge --delete-branch --auto`
```bash
gh pr merge <PR_NUMBER> --merge --delete-branch --auto
```

- `--merge` creates a merge commit (preserves Sprint boundary, equivalent to `--no-ff`)
- `--delete-branch` deletes the remote branch after merge
- `--auto` queues auto-merge; waits for required checks (CI green) + required reviews

Rejected alternatives:
- `--squash`: loses Agent's fine-grained commits, harder to bisect
- `--rebase`: linear history but loses visible Sprint boundary

### D5. Pre-merge smoke (not post-merge)
Rationale: with auto-merge via `gh pr merge`, Leader learns the merge happened AFTER
GitHub did it. A post-merge smoke failure on the remote is hard to revert (another PR
needed). Shift smoke left: run it on the **rebased local feature branch** BEFORE push.

If pre-merge smoke fails → Sprint stays in REVISE, no push, Agent fixes in same worktree.
If pre-merge smoke passes → push + PR + auto-merge.

After auto-merge completes, Leader polls `gh pr view --json state` and only does a
lightweight sanity pull (`git fetch origin && git merge --ff-only origin/main`). No
second smoke run, no revert path, because the only way to reach this point is through
a passing smoke + CI green.

### D6. Poll-until-merged with timeout
`gh pr merge --auto` queues the merge. Leader polls:

```bash
for i in $(seq 1 60); do
  state=$(gh pr view <PR_NUMBER> --json state --jq .state)
  [ "$state" = "MERGED" ] && break
  [ "$state" = "CLOSED" ] && { echo "PR closed without merge"; exit 1; }
  sleep 5
done
```

5-minute hard cap (60 × 5s). If not merged within 5 minutes, Leader reports BLOCKED.
(CI typically takes ~2 minutes; 5 minutes is generous.)

### D7. REVISE path: push updated commits, PR auto-refreshes
When Agent revises in the same worktree, Leader pushes the new commits to the same
remote branch with `--force-with-lease`. The existing PR picks them up automatically
and re-runs CI. No new PR needed.

### D8. REJECT path: close PR, delete branch
```bash
gh pr close <PR_NUMBER> --delete-branch
cd <main-repo>
git worktree remove <worktree>
git branch -D <branch>
```

### D9. Cutover semantics — Sprint 10's own merge is the last local-merge
Sprint 10 documents the new flow. Sprint 10 itself is merged via the OLD local-merge
flow (it can't use the flow it's writing). From Sprint 11 onward, all Sprints MUST use
the new PR flow. This is documented in the contract Context section as "meta-exception".

### D10. Rule 13 text update
Rule 13 currently says "Rebase-Then-Merge" in the reference to dispatch-rules.md. Keep
the section name "Rebase-Then-Merge" (rebase still happens, just against a remote-merged
PR instead of local merge). No text change to the Iron Rule itself. The SECTION content
in dispatch-rules.md is what changes; the name stays.

## Verbatim Replacement Blocks

The Agent's job is to perform **precise Edit operations** using these exact old→new
pairs. No paraphrase. No augmentation. Each block here is copy-paste ready.

---

### BLOCK A: dispatch-rules.md "Rebase-Then-Merge 流程（Iron Rule）" section replacement

**Location**: lines 384-413 (the entire `### Rebase-Then-Merge 流程（Iron Rule）` section up to but NOT including `### 冲突解决优先级`).

**OLD STRING** (exactly as it appears):

```
### Rebase-Then-Merge 流程（Iron Rule）

**绝对禁止**: 直接 `git merge` 不经 rebase。
**绝对禁止**: 用 `--theirs` 或 `--ours` 盲目解决冲突。

```bash
# Step 1: 在 worktree 中 rebase 到最新 main
cd <worktree-path>
git rebase main

# Step 2: rebase 冲突处理
#   → Agent 在 worktree 中解决（Agent 有完整任务上下文）
#   → 如 Agent 已退出：Leader 逐文件手动审查，理解两侧意图后决定
#   → 绝不盲目 --theirs / --ours

# Step 3: rebase 成功后，回 main merge（此时是 clean merge）
cd /Users/vvedition/Desktop/selfmodel
git merge sprint/<N>-<agent> --no-ff -m "Sprint <N>: <title>"

# Step 4: Post-merge smoke test（见 orchestration-loop.md Step 7.5）
```

```

**NEW STRING** (exactly as written below):

```
### Rebase-Then-Merge 流程（Iron Rule，v0.6.0 PR-era）

**绝对禁止**: 直接 merge 不经 rebase。
**绝对禁止**: 用 `--theirs` 或 `--ours` 盲目解决冲突。
**v0.6.0 起**: merge 通过 GitHub PR 完成，由 CI + `gh pr merge --auto` 而非本地 `git merge` 落地。local merge 流程**仅在 Sprint 10 本身**作为 meta-exception 保留（Sprint 10 是定义本流程的 Sprint）。

```bash
# Step 1: 在 worktree 中 rebase 到最新 main
cd <worktree-path>
git fetch origin main
git rebase origin/main

# Step 2: rebase 冲突处理
#   → Agent 在 worktree 中解决（Agent 有完整任务上下文）
#   → 如 Agent 已退出：Leader 逐文件手动审查，理解两侧意图后决定
#   → 绝不盲目 --theirs / --ours

# Step 3: 分支改名为 sprint/<N>-<agent>（若 harness 用了 worktree-agent-XXX）
git branch -m sprint/<N>-<agent>

# Step 4: 预合并烟雾测试（见 orchestration-loop.md Step 6.9）
#   smoke fail → 不 push, Sprint → REVISE, Agent 在 worktree 修复
#   smoke pass → 进入 Step 5

# Step 5: push feature branch 到 origin
#   首次: git push -u origin sprint/<N>-<agent>
#   revise 后更新: git push --force-with-lease origin sprint/<N>-<agent>

# Step 6: 生成 PR body + 创建 PR
#   Leader 根据 contract + evaluator verdict + e2e verdict 生成 PR body 到：
#     .selfmodel/reviews/sprint-<N>-pr-body.md
#   然后：
#   gh pr create \
#     --base main \
#     --head sprint/<N>-<agent> \
#     --title "Sprint <N>: <title>" \
#     --body-file .selfmodel/reviews/sprint-<N>-pr-body.md

# Step 7: 自动合并（CI 绿 + 所有 required checks 通过后由 GitHub 落地）
PR_NUMBER=$(gh pr view --json number --jq .number)
gh pr merge "$PR_NUMBER" --merge --delete-branch --auto

# Step 8: 轮询等 PR 进入 MERGED 状态（最多 5 分钟）
for i in $(seq 1 60); do
  state=$(gh pr view "$PR_NUMBER" --json state --jq .state)
  [ "$state" = "MERGED" ] && break
  [ "$state" = "CLOSED" ] && { echo "PR closed without merge — abort"; exit 1; }
  sleep 5
done

# Step 9: 本地 main 追上 remote
cd /Users/vvedition/Desktop/selfmodel
git fetch origin main
git merge --ff-only origin/main

# Step 10: Cleanup（本地 worktree + 本地分支）
git worktree remove <worktree-path>
git branch -D sprint/<N>-<agent>
```

**为什么 pre-merge smoke 而不是 post-merge**: auto-merge 把落地时刻从 Leader 移到 GitHub，post-merge 的 `git revert` 变成"再发一个 PR"。smoke 左移到 push 前，smoke 是最后一道本地可控门，smoke 通过再 push。post-merge 的 `ff-only pull` 是纯 sanity check，不是第二次烟雾。

**REVISE 路径**: Agent 在同一 worktree 修复 → Leader 重跑 smoke → `git push --force-with-lease` 到同一分支 → 既有 PR 自动刷新 → CI 重跑 → 再走 Step 8-10。无需新 PR。

**REJECT 路径**: `gh pr close <PR_NUMBER> --delete-branch`（若已 push）或直接清理（未 push 时），然后 `git worktree remove` + `git branch -D`。
```

---

### BLOCK B: dispatch-rules.md "并行 Sprint 串行 Merge 规则" section update

**Location**: lines 415-429 (the `### 并行 Sprint 串行 Merge 规则` section).

**OLD STRING**:

```
### 并行 Sprint 串行 Merge 规则

多个 Sprint 可并行执行（提高效率），但 **merge 必须串行**：

```
并行派发: Sprint 65 + Sprint 66 + Sprint 67
并行评审: Evaluator 同时评审三个

串行合并（按 Sprint 编号顺序）:
  1. Sprint 65 rebase onto main HEAD → merge → main 前进
  2. Sprint 66 rebase onto 新 main HEAD → merge → main 再前进
  3. Sprint 67 rebase onto 最新 main HEAD → merge
```

**关键**: 每次 merge 后，后续待 merge 的分支必须先 rebase 到新的 main HEAD。
```

**NEW STRING**:

```
### 并行 Sprint 串行 Merge 规则（PR-era）

多个 Sprint 可并行执行（提高效率），但 **PR 落地必须串行**：

```
并行派发: Sprint 65 + Sprint 66 + Sprint 67（3 个 worktree, 3 个 Agent）
并行评审: Evaluator 同时评审三个
并行 E2E: E2E Agent 同时运行

串行 PR 落地（按 Sprint 编号顺序）:
  1. Sprint 65 rebase onto origin/main HEAD → smoke → push → gh pr create →
     gh pr merge --auto → poll until MERGED → ff-only pull → cleanup
  2. Sprint 66 rebase onto 新 origin/main HEAD → smoke → push → PR → merge → pull → cleanup
  3. Sprint 67 rebase onto 最新 origin/main HEAD → smoke → push → PR → merge → pull → cleanup
```

**关键**:
- 每次 PR 落地后，后续待落地的分支必须先 `git fetch origin main && git rebase origin/main` 到新的 main HEAD。
- `gh pr merge --auto` 的队列机制不足以保证 Sprint 编号顺序——Leader 必须手动按编号逐个 push + create PR。
- 并行 PR create（为了 CI 同时跑）是允许的，但 `gh pr merge --auto` 必须按编号顺序逐个调用；前一个 MERGED 后才调下一个。
```

---

### BLOCK C: orchestration-loop.md Step 7 ACCEPT path replacement

**Location**: lines 218-234 (the ACCEPT branch under `7. ACT on each verdict`).

**OLD STRING**:

```
  7. ACT on each verdict (SERIAL MERGE — one at a time, in Sprint number order)
     - ACCEPT →
         a. Rebase sprint branch onto current main HEAD (in worktree):
            cd <worktree-path> && git rebase main
         b. If rebase conflict:
            - Re-dispatch Agent to resolve in worktree (Agent has task context)
            - If Agent unavailable: Leader resolves manually per file
            - NEVER use --theirs / --ours blindly
         c. After clean rebase: merge into main
            cd <main-repo> && git merge sprint/<N>-<agent> --no-ff -m "Sprint <N>: <title>"
         d. Archive contract, cleanup worktree
         e. plan.md Status → MERGED
     - REVISE → write must_fix feedback, agent continues
                 plan.md Status → ACTIVE (retry count +1)
     - REJECT → discard branch
                 plan.md Status → PENDING (redo)
                 If 3 consecutive REJECTs → Status → BLOCKED, notify user
```

**NEW STRING**:

```
  7. ACT on each verdict (SERIAL PR LANDING — one PR at a time, in Sprint number order)
     - ACCEPT →
         a. Rebase sprint branch onto remote main HEAD (in worktree):
            cd <worktree-path>
            git fetch origin main
            git rebase origin/main
         b. If rebase conflict:
            - Re-dispatch Agent to resolve in worktree (Agent has task context)
            - If Agent unavailable: Leader resolves manually per file
            - NEVER use --theirs / --ours blindly
         c. Rename branch if harness-generated (e.g. worktree-agent-XXX → sprint/<N>-<agent>):
            git branch -m sprint/<N>-<agent>
         d. PRE-MERGE SMOKE TEST (see Step 6.9) — smoke runs on rebased worktree.
            smoke fail → push blocked, final verdict downgrades to REVISE.
         e. Push feature branch:
            first push: git push -u origin sprint/<N>-<agent>
            revise updates: git push --force-with-lease origin sprint/<N>-<agent>
         f. Generate PR body from contract + verdicts:
            write .selfmodel/reviews/sprint-<N>-pr-body.md
            (template: title, verdict summary, files changed, AC checklist,
             evaluator rationale, link to contract)
         g. Create PR:
            gh pr create \
              --base main \
              --head sprint/<N>-<agent> \
              --title "Sprint <N>: <title>" \
              --body-file .selfmodel/reviews/sprint-<N>-pr-body.md
         h. Queue auto-merge:
            PR_NUMBER=$(gh pr view --json number --jq .number)
            gh pr merge "$PR_NUMBER" --merge --delete-branch --auto
         i. Poll until PR reaches MERGED (5 min cap, see dispatch-rules.md Step 8):
            while state != MERGED and attempts < 60: sleep 5
            MERGED → proceed to j
            CLOSED without MERGED → BLOCKED, notify user
            timeout → BLOCKED, notify user, record in orchestration.log
         j. Local main fast-forward to remote:
            cd <main-repo>
            git fetch origin main
            git merge --ff-only origin/main
         k. Archive contract, cleanup local worktree + branch:
            git worktree remove <worktree-path>
            git branch -D sprint/<N>-<agent>
         l. plan.md Status → MERGED
     - REVISE → write must_fix feedback to worktree, Agent continues (same worktree).
                 If PR already pushed: updates will land via step e after next ACCEPT.
                 plan.md Status → ACTIVE (retry count +1)
     - REJECT → gh pr close <PR_NUMBER> --delete-branch (if pushed), then:
                 git worktree remove <worktree-path>
                 git branch -D sprint/<N>-<agent>
                 plan.md Status → PENDING (redo)
                 If 3 consecutive REJECTs → Status → BLOCKED, notify user
```

---

### BLOCK D: orchestration-loop.md — new Step 6.9 PRE-MERGE SMOKE TEST

**Location**: insert between Step 6.5 (Chaos Verification) at line 216 and Step 7 at line 218.

**Insertion position**: after the closing `Skip for internal tools, config changes, documentation-only sprints.` line of Step 6.5.

**Behavior**: Leader adds a new `  6.9. PRE-MERGE SMOKE TEST` block. This block REPLACES
the old Step 7.5 (Post-Merge Smoke Test) — the old 7.5 should be removed entirely in Block E.

**NEW BLOCK** (the whole new Step 6.9 — insert verbatim):

```
  6.9. PRE-MERGE SMOKE TEST (v0.6.0 PR-era, runs on rebased worktree BEFORE push)
       Why pre-merge: with gh auto-merge, post-merge revert = follow-up PR. Shift smoke
       left. If smoke passes, push + PR. If smoke fails, don't push, downgrade to REVISE.

       Run within 30 seconds, from the rebased worktree (after Step 7.a rebase):
       a. Build check (if applicable):
          npm run build 2>&1 | tail -5  OR  cargo build 2>&1 | tail -5  OR
          bash -n scripts/selfmodel.sh (for shell-script-only projects)
       b. Test check (if applicable):
          npm test -- --bail 2>&1 | tail -10  OR  cargo test 2>&1 | tail -10
       c. Diff sanity:
          git diff origin/main --stat
          (verify change scope matches Sprint deliverables)
       d. Sprint-specific smoke (if declared in contract):
          - Read contract ## Smoke Test section
          - Execute each command from worktree root with 30s timeout
          - Any command fail OR output mismatch expected → smoke FAIL
       e. If any check fails:
          - DO NOT push
          - Final verdict downgrades ACCEPT → REVISE
          - Write feedback: "Pre-merge smoke failed: <error>"
          - Agent continues in same worktree
       f. If all checks pass:
          - Proceed to Step 7.e (push)
          - Log: event=pre_merge_smoke sprint=<N> result=pass
```

---

### BLOCK E: orchestration-loop.md — remove Step 7.5 POST-MERGE SMOKE TEST

**Location**: lines 236-255 (the entire `7.5. POST-MERGE SMOKE TEST` block).

**OLD STRING** (delete this whole block):

```
  7.5. POST-MERGE SMOKE TEST (after each merge in Step 7)
       Run within 30 seconds:
       a. Build check (if applicable):
          npm run build 2>&1 | tail -5  OR  cargo build 2>&1 | tail -5
       b. Test check (if applicable):
          npm test -- --bail 2>&1 | tail -10  OR  cargo test 2>&1 | tail -10
       c. Diff sanity:
          git diff HEAD~1 --stat  (verify change scope matches Sprint deliverables)
       d. If build OR test fails:
          - git revert HEAD --no-edit  (revert the merge commit)
          - Sprint status → REVISE (not MERGED)
          - Write feedback: "Post-merge regression detected: <error>"
          - Agent must fix in worktree, re-rebase, re-merge
       e. Sprint-specific smoke test (if declared in contract):
          - Read contract ## Smoke Test section
          - Execute each command with 30s timeout
          - If any command fails or output mismatches expected:
            same handling as build/test failure (revert + REVISE)
          - If no ## Smoke Test section: skip (no block)
          - Log: event=smoke_test sprint=<N> result=pass|fail|skipped

```

**NEW STRING**: (empty — delete the whole block including the trailing blank line)

---

### BLOCK F: CLAUDE.md Sprint Lifecycle update (Steps 5-7)

**Location**: CLAUDE.md lines 196-209 (Steps 5, 6, 7 of Sprint Lifecycle).

**OLD STRING**:

```
5. Leader reviews ON MAIN: git diff main...sprint/<N>-<agent>

6. Verdict (SERIAL MERGE — one Sprint at a time)
   Pass  → rebase onto latest main → merge to main → post-merge smoke test → archive
   Fail  → write feedback → agent continues in same worktree

   Rebase-then-merge flow (see dispatch-rules.md for full details):
   a. cd <worktree> && git rebase main
   b. If conflict → Agent resolves (has context) | Leader reviews manually
   c. cd <main-repo> && git merge sprint/<N>-<agent> --no-ff
   d. Post-merge: build + test must pass, else git revert + REVISE

7. Cleanup (MANDATORY — same session)
   /git-worktree remove sprint-<N>-<agent>
   git branch -d sprint/<N>-<agent>
```

**NEW STRING**:

```
5. Leader reviews ON MAIN: git diff origin/main...<branch>

6. Verdict (SERIAL PR LANDING — one PR at a time, v0.6.0 PR-era)
   Pass  → rebase onto origin/main → pre-merge smoke → push → gh pr create →
           gh pr merge --auto → poll until MERGED → ff-only pull → archive
   Fail  → write feedback → agent continues in same worktree

   Rebase-Then-Merge flow (see dispatch-rules.md for full details):
   a. cd <worktree> && git fetch origin main && git rebase origin/main
   b. If conflict → Agent resolves (has context) | Leader reviews manually
   c. git branch -m sprint/<N>-<agent> (if harness named it worktree-agent-XXX)
   d. Pre-merge smoke: build + test + contract smoke block (see orchestration-loop.md Step 6.9)
      smoke fail → no push, downgrade to REVISE
   e. git push -u origin sprint/<N>-<agent> (or --force-with-lease on revisions)
   f. gh pr create --base main --head sprint/<N>-<agent> --title "..." --body-file ...
   g. gh pr merge <N> --merge --delete-branch --auto  (CI gates the merge)
   h. Poll PR state until MERGED (5 min cap)
   i. cd <main-repo> && git fetch origin main && git merge --ff-only origin/main

7. Cleanup (MANDATORY — same session)
   git worktree remove <worktree-path>
   git branch -D sprint/<N>-<agent>
   (remote branch auto-deleted by `gh pr merge --delete-branch`)
```

---

## Summary Table of Changes

| File | Block | Operation | Lines affected |
|------|-------|-----------|----------------|
| `dispatch-rules.md` | A | Replace | 384-413 (30 lines → ~70 lines) |
| `dispatch-rules.md` | B | Replace | 415-429 (15 lines → ~20 lines) |
| `orchestration-loop.md` | C | Replace | 218-234 (17 lines → ~50 lines) |
| `orchestration-loop.md` | D | Insert new | After line 216 (+27 lines) |
| `orchestration-loop.md` | E | Delete | 236-255 (-20 lines) |
| `CLAUDE.md` | F | Replace | 196-209 (14 lines → ~25 lines) |

Net delta: **+97 lines** across 3 files. No new files. No file deletions. No code changes
(all docs).

## Context for Agent

- Agent will work in a worktree (isolation="worktree")
- Agent must NOT touch any file outside the 3 listed files
- Agent must use Edit tool with the **exact** old_string / new_string pairs from this
  artifact — no paraphrase, no augmentation
- Agent must preserve surrounding markdown structure exactly (blank lines before/after)
- Agent must NOT modify the section headers or adjacent sections
- After all 6 edits, Agent must verify each Block landed correctly via grep

## Validation Commands (Leader post-dispatch)

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
! grep -q '7.5. POST-MERGE SMOKE TEST' .selfmodel/playbook/orchestration-loop.md

# Block F: CLAUDE.md updated
grep -n 'SERIAL PR LANDING' CLAUDE.md
grep -n 'gh pr create' CLAUDE.md

# No old flow remnants in primary paths
! grep -q 'git merge sprint/<N>-<agent> --no-ff' .selfmodel/playbook/dispatch-rules.md
! grep -q 'git merge sprint/<N>-<agent> --no-ff' .selfmodel/playbook/orchestration-loop.md
! grep -q 'git merge sprint/<N>-<agent> --no-ff' CLAUDE.md
```

## Meta Exception (Sprint 10 itself)

Sprint 10 is the Sprint that defines the PR flow. Therefore Sprint 10's OWN merge MUST
use the OLD local-merge flow (it cannot use a flow that doesn't exist yet). This is
documented explicitly in the contract Context section. From Sprint 11 onward, all
Sprints use the new PR flow.

Leader action for Sprint 10 merge:
1. rebase onto local main
2. pre-merge smoke test (ad-hoc: grep commands from BLOCK validation above)
3. local `git merge --no-ff` (last time)
4. archive + cleanup
5. Sprint 11 will be the first Sprint to use the new flow — if anything about this
   design is wrong, Sprint 11's own execution will surface it within a few hours.

## Created
2026-04-11 (Sprint 10 design phase)
