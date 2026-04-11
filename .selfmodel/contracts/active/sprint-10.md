# Sprint 10: GitHub PR Flow Evolution (v0.6.0)

## Status
ACTIVE

## Agent
gemini

## Complexity
standard

## Objective
将 Sprint merge 流程从"本地 rebase + 本地 `git merge --no-ff`"演进为"本地 rebase + `git push` + `gh pr create` + `gh pr merge --auto`"。实现为 3 个 playbook 文件的精准 Edit 替换：`dispatch-rules.md`、`orchestration-loop.md`、`CLAUDE.md`。所有替换文本由 Leader 在 `.selfmodel/artifacts/sprint-10-pr-flow-design.md` 的 6 个 BLOCK 中 verbatim 提供，Agent 做零改写的 Edit 插入。

## Acceptance Criteria

- [ ] `.selfmodel/playbook/dispatch-rules.md`：BLOCK A 替换生效——`### Rebase-Then-Merge 流程（Iron Rule）` 段的旧 `git merge sprint/<N>-<agent> --no-ff` 段被替换为新 `v0.6.0 PR-era` 段，包含 `gh pr merge` + `gh pr create` + pre-merge smoke 描述
- [ ] `.selfmodel/playbook/dispatch-rules.md`：BLOCK B 替换生效——`### 并行 Sprint 串行 Merge 规则` 段升级为 `（PR-era）` 版本，提及 `gh pr merge --auto` 和 serial PR landing
- [ ] `.selfmodel/playbook/orchestration-loop.md`：BLOCK C 替换生效——Step 7 `ACT on each verdict` 的 ACCEPT 分支从 local merge 改为 SERIAL PR LANDING 流程（10 个子步骤 a-l）
- [ ] `.selfmodel/playbook/orchestration-loop.md`：BLOCK D 插入生效——在 Step 6.5 和 Step 7 之间新增 `6.9. PRE-MERGE SMOKE TEST`（v0.6.0 PR-era 段）
- [ ] `.selfmodel/playbook/orchestration-loop.md`：BLOCK E 删除生效——原 `7.5. POST-MERGE SMOKE TEST` 整段被删除（取而代之的是 Step 6.9）
- [ ] `CLAUDE.md`：BLOCK F 替换生效——`### Sprint Lifecycle` 的 Step 5/6/7 从 local merge 改为 PR flow 版本，包含 `gh pr create`、`gh pr merge --auto`、`git merge --ff-only origin/main`、`git branch -D sprint/<N>-<agent>` 等关键字
- [ ] 所有 6 个 BLOCK 的 old_string/new_string 必须**字节一致地**来自 `.selfmodel/artifacts/sprint-10-pr-flow-design.md`。paraphrase/augmentation/truncation 都是拒绝级问题。
- [ ] 3 个目标文件以外**无任何**其他文件被修改（禁止"顺手修一下"任何其他 playbook 文件、hook 脚本、README 等）
- [ ] 新内容里必须出现的关键字：`gh pr create`, `gh pr merge`, `--auto`, `--force-with-lease`, `origin/main`, `PRE-MERGE SMOKE TEST`, `SERIAL PR LANDING`
- [ ] 旧内容中**必须被移除**的危险残留（Leader 手动 grep 验证）：
  - `git merge sprint/<N>-<agent> --no-ff` 不应在 `dispatch-rules.md`、`orchestration-loop.md`、`CLAUDE.md` 的三个主流程路径中再出现
  - `POST-MERGE SMOKE TEST` 不应出现在 `orchestration-loop.md`（已迁移为 PRE-MERGE）
- [ ] `## Context` 段必须**保留** Sprint 10 自身的 meta-exception 说明（Sprint 10 本身是最后一次用 local merge 落地的 Sprint）

## Context

### 为什么改 PR 流程

- 现行 local merge 流程把"落地时刻"留在 Leader 本地磁盘。没有 CI 验证，没有 GitHub 纪录，外部协作者看不到 Sprint 门禁在跑，也无法用 gh PR workflow 做 code review。
- 仓库已经公开（20+ 历史 PR 显示过去用过 PR flow），dogfood 自己的开发流程应该同样走 PR。
- CI workflow (`.github/workflows/ci.yml`) 当前存在且注册为 "CI active"；Sprint 10 不测试 CI 内容，只让 merge 流程开始通过 CI 这个 gate。

### Sprint 10 本身是 meta-exception

Sprint 10 是**定义新 PR 流程的 Sprint**。Sprint 10 自己的 merge 无法使用还没写好的流程，所以 Sprint 10 自己走**最后一次旧的 local merge 流程**：

1. Agent 在 worktree 完成 6 个 Edit
2. Evaluator（Gemini fallback）评审
3. E2E（Leader self-run：跑 artifact 里的 7 条 grep 验证命令）
4. Leader rebase + 本地 `git merge --no-ff`（最后一次）
5. Leader post-merge 跑 grep 验证 + 文件读取
6. Archive + cleanup
7. Sprint 11 起，所有 Sprint 必须使用本 Sprint 定义的新 PR flow

这个 meta-exception **必须在合约的 Context 段落里显式记录**，作为未来 audit 的依据，也避免 Sprint 10 自己走 PR flow 时陷入"没文档，不知怎么走"的死锁。

### 通道 fallback

Sprint 9 Evaluator 已经证明 Gemini fallback 能干活。Sprint 10 Generator 也用 Gemini：
- Opus Agent 子通道仍在 rate-limit 期（resets 5am PT）
- Gemini 作为 Generator 适合"verbatim Edit 插入"类任务——Sprint 10 的所有替换文本都已 Leader 起草完毕
- Codex 是 backup generator，Sprint 10 不需要用 Codex，因为 Gemini 对 markdown 结构更敏感

### 设计 artifact

**所有 verbatim 替换文本**（6 个 BLOCK）都在：

```
/Users/vvedition/Desktop/selfmodel/.selfmodel/artifacts/sprint-10-pr-flow-design.md
```

artifact 结构：
- Deep-Read Summary（Leader 读过的 3 个文件关键行）
- Design Decisions D1-D10（10 个带 rationale 的决策）
- Verbatim Replacement Blocks A-F（6 个精准 old_string/new_string 对）
- Summary Table of Changes
- Validation Commands（Leader 用来 grep 检查）
- Meta Exception 说明

Agent 必须**全文读完** artifact 再开始编辑。

## Code Tour

### dispatch-rules.md (lines 384-413): 当前的 Rebase-Then-Merge 段

```bash
### Rebase-Then-Merge 流程（Iron Rule）

**绝对禁止**: 直接 `git merge` 不经 rebase。
**绝对禁止**: 用 `--theirs` 或 `--ours` 盲目解决冲突。

```bash
# Step 1: 在 worktree 中 rebase 到最新 main
cd <worktree-path>
git rebase main

# Step 2: rebase 冲突处理
#   → Agent 在 worktree 中解决（Agent 有完整任务上下文）
...
# Step 3: rebase 成功后，回 main merge（此时是 clean merge）
cd /Users/vvedition/Desktop/selfmodel
git merge sprint/<N>-<agent> --no-ff -m "Sprint <N>: <title>"

# Step 4: Post-merge smoke test（见 orchestration-loop.md Step 7.5）
```
```

**为什么重要**: 这个段落是 Iron Rule 13 的实现细节。它包含 fenced code block 嵌套（外层 bash，内层是文档中的 "```bash" 字面量）。Agent 在替换时必须小心保留 markdown 的双层 fencing，不能误 parse。artifact BLOCK A 的 OLD STRING / NEW STRING 已经保留完整 fencing。

### orchestration-loop.md (lines 218-234): 当前的 Step 7 ACCEPT 分支

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
```

**为什么重要**: 这是整个 orchestration loop 的 state transition。替换必须保留缩进（2 空格层级的 `- ACCEPT →` 格式），replacement block 扩展后缩进还是 2 空格。

### CLAUDE.md (lines 196-209): 当前的 Sprint Lifecycle Step 5-7

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

**为什么重要**: CLAUDE.md 是"路由文件"——Leader 每个 session 启动都读。Step 5/6/7 的更改必须一致地展现新 PR flow，否则 Leader 启动会看到两种矛盾描述。替换后必须保留外层的 Worktree Isolation Workflow 结构和 Step 7 之后的 `### Absolute Prohibitions` 段不变。

## Architecture Context

- **所在层次**: `.selfmodel/playbook/` 是 on-demand loaded rule files。Leader 启动时读 `CLAUDE.md`（路由），遇到 Sprint 编排决策时按需加载 `dispatch-rules.md` 或 `orchestration-loop.md`。
- **数据流**: 决策 → 读 playbook → 执行命令。playbook 是**只由 Leader 读、只有本 Sprint 这种 meta-Sprint 才写**的协议文档。
- **邻接模块**:
  - `scripts/hooks/enforce-dispatch-gate.sh`：读 `dispatch-config.json`，不读 playbook。hook 不受本 Sprint 影响。
  - `scripts/hooks/enforce-depth-gate.sh`：读 contract 文件找 Code Tour，不读 playbook。不受影响。
  - `scripts/selfmodel.sh` `generate_playbook()`：用 if-not-exists guard（R2 修过）生成 playbook 文件。**重要**：新内容必须进入 generate_playbook 的 canonical heredoc 吗？**否**——因为 guard 保护原文件不被覆盖，`selfmodel update` 对已存在的 playbook 是 no-op。本 Sprint 只改 live 文件，不改 heredoc（下一个 Sprint 的事）。
- **命名约定**: playbook 文件名 `kebab-case.md`。section headers `###` 三级 + 中英混合（如 `### Rebase-Then-Merge 流程（Iron Rule）`）。code fence 用 ` ```bash`（指定语言）。
- **错误处理模式**: playbook 是纯文档，无运行时错误处理。但文档中描述的**流程**应该 fail-loud 而非 silent swallow（即"smoke fail → 不 push"，不是"smoke fail → 记一条 log 继续"）。

## Files

### Creates
_无_

### Modifies
- .selfmodel/playbook/dispatch-rules.md
- .selfmodel/playbook/orchestration-loop.md
- CLAUDE.md

### Out of Scope
- .selfmodel/artifacts/sprint-10-pr-flow-design.md（已由 Leader 预先写好，Agent **只读**它提取替换文本，不编辑它）
- scripts/selfmodel.sh `generate_playbook()`（if-not-exists guard 已经在 R2 修了，无需改 heredoc；新 playbook 内容只落在 live 文件）
- 所有 hook 脚本
- .selfmodel/state/ 任何文件
- .github/workflows/ci.yml（CI 文件本身不动，只让 merge 流程开始使用它）
- README.md
- 其他 playbook 文件（quality-gates.md、sprint-template.md、evaluator-prompt.md、e2e-protocol-v2.md、lessons-learned.md 等）
- 任何 scripts/ 下的代码

## Constraints
- Timeout: 300s（Agent 需要读 artifact + 做 6 次 Edit + 6 次 grep 验证）
- Agent MUST work in worktree, NOT edit main directly
- Agent MUST use Edit tool with **byte-identical** old_string/new_string pairs from `.selfmodel/artifacts/sprint-10-pr-flow-design.md`
- Agent MUST NOT paraphrase, augment, or "clean up" any text
- Agent MUST NOT touch any file outside the 3 Modified files
- Agent MUST NOT use Write tool (all 3 files exist, use Edit only)
- Agent MUST run all validation grep commands from the artifact's "Validation Commands" section after edits
- Agent MUST report a STATUS: DELIVERED block at the end (see inbox/gemini/sprint-10.md Step 7)

## Deliverables
- [ ] 6 Edit operations landed across 3 files
- [ ] All validation grep commands pass (7 positive greps + 3 negative greps)
- [ ] git diff in worktree shows exactly 3 modified files, 0 creates, 0 deletes
- [ ] STATUS: DELIVERED block reported with per-BLOCK evidence

## Smoke Test

Leader 在 merge 后执行（worktree 内也应通过）:

```bash
# Positive greps: new content must exist
grep -q 'Rebase-Then-Merge 流程（Iron Rule，v0.6.0 PR-era）' .selfmodel/playbook/dispatch-rules.md && echo "  ok A1" || { echo "  FAIL A1"; exit 1; }
grep -q 'gh pr merge.*--auto' .selfmodel/playbook/dispatch-rules.md && echo "  ok A2" || { echo "  FAIL A2"; exit 1; }
grep -q '并行 Sprint 串行 Merge 规则（PR-era）' .selfmodel/playbook/dispatch-rules.md && echo "  ok B" || { echo "  FAIL B"; exit 1; }
grep -q 'SERIAL PR LANDING' .selfmodel/playbook/orchestration-loop.md && echo "  ok C1" || { echo "  FAIL C1"; exit 1; }
grep -q 'gh pr create' .selfmodel/playbook/orchestration-loop.md && echo "  ok C2" || { echo "  FAIL C2"; exit 1; }
grep -q '6.9. PRE-MERGE SMOKE TEST' .selfmodel/playbook/orchestration-loop.md && echo "  ok D" || { echo "  FAIL D"; exit 1; }
grep -q 'SERIAL PR LANDING' CLAUDE.md && echo "  ok F1" || { echo "  FAIL F1"; exit 1; }
grep -q 'gh pr create' CLAUDE.md && echo "  ok F2" || { echo "  FAIL F2"; exit 1; }

# Negative greps: old content must be gone
! grep -q '7.5. POST-MERGE SMOKE TEST' .selfmodel/playbook/orchestration-loop.md && echo "  ok E (7.5 removed)" || { echo "  FAIL E (7.5 still present)"; exit 1; }
! grep -q 'git merge sprint/<N>-<agent> --no-ff' .selfmodel/playbook/dispatch-rules.md && echo "  ok negA" || { echo "  FAIL negA"; exit 1; }
! grep -q 'git merge sprint/<N>-<agent> --no-ff' .selfmodel/playbook/orchestration-loop.md && echo "  ok negB" || { echo "  FAIL negB"; exit 1; }

# Scope: 3 files modified, nothing else
changed=$(git diff --name-only main...HEAD 2>/dev/null | wc -l | tr -d ' ')
test "$changed" = "3" && echo "  ok 3 files" || { echo "  FAIL $changed files"; git diff --name-only main...HEAD; exit 1; }

echo "all smoke checks passed"
```

## Dispatch Note

Sprint 10 本身的 merge 是 **meta-exception**：它用 OLD local-merge flow（最后一次），因为定义新 flow 的 Sprint 无法使用还没存在的 flow。Sprint 11 将是第一个使用新 PR flow 的 Sprint——如果新 flow 有设计缺陷，Sprint 11 会立刻暴露。
