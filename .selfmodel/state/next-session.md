# Next Session Handoff

**Last session**: 2026-04-11 — Retroactive audit + first two dogfooding Sprints

## 一句话状态

selfmodel 的第一次真正的 dogfooding 发生了。Sprint 7 + Sprint 8 走完整 Sprint 流程，都拿到 9.15/10 ACCEPT；retroactive audit 为 R1-R4 建立了 quality.jsonl baseline。Rule 20 (Self-Dogfood) 已写入 CLAUDE.md。已 push 到 `origin/main`（5 commits: `f0410d7..327331d`）。

## 今天做了什么

### 起因
用户问 "有没有收到新的 PR，按我们这个机制应该会有的？"

两层答案：
1. **Evolution pipeline 在 selfmodel 仓库本身里 by design 不会产生 PR** —— 它的目的是让下游项目把本地改进贡献回 upstream selfmodel，而这个仓库就是 upstream
2. **selfmodel 自己的开发没 dogfood** —— v0.5.0 到 `f0410d7` 之间 4 个 commit 全部直提 main，绕过了 Sprint 流程

### 动作

**Phase 1 — Retroactive audit of 4 commits**
- 创建 `sprint-R{1,2,3,4}-retroactive.md` contracts
- 派独立 Opus Agent 做 Evaluator，按 6 维打分
- 结果写入 `.selfmodel/reviews/retroactive-v0.5.0-audit.{json,md}`
- `.selfmodel/state/quality.jsonl` 首次有数据（4 行 retroactive）

Audit 结果（均分 6.83）：

| # | SHA | 标题 | Weighted | Verdict | 关键发现 |
|---|-----|------|----------|---------|----------|
| R1 | `302f9aa` | v0.5.0 depth-first enforcement | 7.85 | ACCEPT | depth gate 只 grep Bash 字面量，Agent tool 调用绕过（概念漏洞） |
| R2 | `2bfaba0` | sprint-template guard | 7.60 | ACCEPT | 干净的 3 行 guard |
| R3 | `dd07f19` | settings.json hook format | 6.70 | REVISE | AC1 虚假：live file 在 parent 时已是正确格式 |
| R4 | `f0410d7` | team.json + hook regen | **5.15** | **REVISE (blocker)** | **静默删除 whitelist Rules 7/8/9** |

**Phase 2 — Sprint 7 修 R4 regression（首次合规 dogfooding）**
- Contract: `.selfmodel/contracts/archive/sprint-7.md`
- Worktree branch: `worktree-agent-abedc229`（harness 自动命名）
- 派 Opus Agent 到隔离 worktree，干净实现：
  - `scripts/hooks/enforce-leader-worktree.sh` 恢复 Rules 7/8/9（pre-R4 byte-for-byte）
  - `scripts/selfmodel.sh` 同步 canonical heredoc
  - **新建 `scripts/tests/test-hook-drift.sh`**（101 行，awk 提取 heredoc + diff live hook）
- 独立 Evaluator 验证：**9.15/10 ACCEPT**
- Evaluator 做了 **mutation test**：注入 `# DRIFT` 到 live hook 验证 test exit 1 并 diff，恢复后 exit 0 —— 证明 test 真正 catch drift 而不是 rubber stamp
- Rebase → merge --no-ff → post-merge smoke (6/6) → cleanup

**Phase 3 — Sprint 8 落实 Rule 20（meta 自验证）**
- 用户批准 3 处 diff：CLAUDE.md Rule 20 新增 + ABSOLUTELY FORBIDDEN 新条 + lessons-learned 新条目
- Contract: `.selfmodel/contracts/archive/sprint-8.md`
- 派 Opus Agent 做 **verbatim 插入**（精确文本由 Leader 提供，Agent 不得改写）
- Agent 用 3 次 Edit 精准插入，13 additions 0 deletions 2 files
- Evaluator 做了 **byte-identical verification**（Python string equality on every line）+ monotonic check (1..20)：**9.15/10 ACCEPT**
- Meta 时刻：**定义 "Sprint 必须用 Sprint 流程" 这条规则本身就用了 Sprint 流程**

**Phase 4 — Commit + push**
- Orchestration artifacts commit: `327331d`（16 files, 1805 insertions）
- 5 个 commit push 到 origin/main：
  ```
  327331d chore: orchestration artifacts (Sprint 7 + 8)
  9966bb2 Merge Sprint 8: codify Rule 20 Self-Dogfood
  b2a149c docs(sprint-8): codify Rule 20 Self-Dogfood
  43686e5 Merge Sprint 7: restore enforce-leader-worktree whitelist
  fd4fa3c fix(sprint-7): restore enforce-leader-worktree whitelist
  ```

## quality.jsonl 最终状态

6 行，平均对比：

| 来源 | 数量 | 均分 | 说明 |
|------|-----|------|------|
| Retroactive (R1-R4) | 4 | 6.83 | 直提 main 时代 |
| 真正 Sprint (7, 8) | 2 | 9.15 | Dogfooding 时代 |
| **纪律红利** | — | **+2.32** | 已量化 |

## Pending — 下一个 session 的任务队列

### 高优先级（已讨论过，方向明确）

1. **机制演进 — 从"本地 merge"到"GitHub PR"流程**（用户最核心的诉求）
   - 当前 Sprint 流程：`worktree → rebase → git merge --no-ff → 本地 main`
   - 目标 Sprint 流程：`worktree → push feature branch → gh pr create → CI 审 → gh pr merge`
   - 需要改 `dispatch-rules.md` 的 Rebase-Then-Merge 章节和 `orchestration-loop.md` 的 Step 6/7
   - 这本身应该是一个 Sprint（复杂度 standard，涉及规则文档）
   - **先做这个**，之后 Sprint 9/10 的交付就是真正的 GitHub PR

2. **Sprint 9: R1 depth gate Agent tool 覆盖** (用户已确认要做)
   - Problem: `enforce-depth-gate.sh` 只匹配 Bash 命令字面量 `gemini`/`codex`
   - 但 Opus Agent 通过 Agent tool (Task tool) 派发，完全不经过 Bash
   - Depth gate 保护不了它"最应该保护的通道"（最复杂 Sprint 都是 Opus Agent 派的）
   - 修复：在 `.claude/settings.json` PreToolUse 加 Task matcher；hook 读 subagent prompt 判断复杂度
   - 同样的漏洞在 `enforce-agent-rules.sh` 也存在（见下）

3. **Sprint 10: VERSION 号同步**
   - `VERSION` 文件 = `0.4.0`
   - CLI `selfmodel --version` = `0.3.0`（`scripts/selfmodel.sh` 里的常量）
   - 实际 v0.5.0 已实现
   - 修复：VERSION → `0.5.0`，CLI 常量 → `0.5.0`
   - 小 Sprint，complexity = simple

### 中优先级（Sprint 7 + Sprint 8 Evaluator 的 should_fix）

4. **泛化 drift test 到所有 4 个 hook**
   - 当前 `test-hook-drift.sh` 只对 `enforce-leader-worktree.sh` 一个 hook
   - 应覆盖 `enforce-dispatch-gate.sh`, `enforce-depth-gate.sh`, `enforce-agent-rules.sh`
   - Evaluator 原话：loop over all four generated hooks

5. **把 drift test 接入 post-merge smoke 或 Stop hook**
   - 当前只在手动跑时 catch drift
   - 应在 merge 时自动跑，或 Stop hook 结束前跑

6. **enforce-agent-rules.sh / enforce-depth-gate.sh 的 literal-grep false positive**
   - 今天 `git commit` 触发了 `enforce-agent-rules.sh`，因为 commit message 里字面量含 "codex"
   - Sprint 7 Evaluator 也指出相同 pattern 在 depth gate 里
   - 修复方向：只匹配命令行首 token（`gemini `、`codex `）而非整体字符串 grep；或者只 match `jq -r .tool_input.command` 后的 argv[0]

7. **Evaluator JSON schema 不一致**
   - `evaluator-prompt.md` Section 6 schema 用 `weighted`, `auto_reject_triggered`
   - Sprint 8 Evaluator 写出的 JSON 用了 `weighted_score`, `auto_reject_triggers.any_triggered`（嵌套）
   - Leader 的 quality.jsonl 追加脚本取不到字段（已在 Sprint 8 手动修正）
   - 修复：要么收紧 evaluator-prompt.md 强制 schema，要么 Leader 的 jq 兼容两种

### 低优先级 / 维护

8. **老遗留 untracked 文件的决策**（这个 session 有意跳过的）
   - `.selfmodel/contracts/archive/sprint-{A,B,C,D,CLI1,CLI2,W1,W2,W3}.md` — 之前 session 的 Sprint
   - `.selfmodel/inbox/codex/sprint-{CLI2,D,W3}.md` — 之前 session 的 inbox
   - `.selfmodel/wiki/` — wiki 目录整体 untracked
   - 需要决定：tracked 还是 .gitignore？或者清理？
   - 不能单方面 commit，需要用户 review

9. **team.json session_count 更新** — 今天 session 结束应该 +1，但是 session-start hook 已经 mount 过当前值，人工决定是否更新

10. **Rampage 重跑** — 上一个 session 的 handoff 说要重跑 `/rampage` 验证韧性分提升到 85+，这个 session 完全没碰。Sprint 9/10 不触发 Rampage gate（都不是 user-facing surfaces），但未来 CLI 改动 Sprint 可能要跑

### 新的后续候选（今天 Sprint 8 之后发现的）

11. **Sprint 8 commit message 的 BYPASS 使用**
    - Leader 用 `BYPASS_AGENT_RULES=1` 绕过了 `enforce-agent-rules.sh` false positive
    - 按 Rule 20 "唯一例外" 条款，BYPASS 使用必须 retroactive audit Sprint 补文档
    - 本文档即是该补充
    - 但未来为了避免这种 false positive 重复，应该做 #6

## Blockers

无。所有 main 状态干净，worktree 列表只剩 main，quality.jsonl 有数据，Rule 20 在位。

## Active Worktrees

无（post-Sprint-7 + Sprint-8 cleanup 完成）

## Open / Active Sprints

无（Sprint 7 + Sprint 8 都已 archive）

## 本次关键决策

1. **方向 A（selfmodel dogfood 自己）**而非方向 B（下游项目贡献）或方向 C（self-referential evolve mode）
2. **Retroactive audit 而非 rewrite history** —— R1-R4 不回退、不改 git 历史，只做 evaluator 事后评分 + lessons 记录
3. **Sprint 7 contract 严格限定只恢复 3 条 rule** —— 不借机加新 whitelist（Agent 也遵守了）
4. **Sprint 8 用 verbatim 插入，Leader 提供精确文本** —— Agent 零自由度，meta 一致性（"不要 freestyle selfmodel 代码" 这条规则本身也不 freestyle）
5. **Evaluator mutation test** —— 注入 `# DRIFT` 验证 test 真正 catch，是 Sprint 7 Evaluator 自创的做法，应该推广到所有 state 验证类 test 的评审
6. **Push 本地 main** 但不改造成 PR 流程（这次）—— 机制演进作为单独的 Sprint 在下一个 session
7. **不动老遗留 untracked 文件** —— 避免把多 session 遗留问题混入当前 commit

## Context metrics

- 5 次 Agent 派发（2 × Opus Agent 做 Sprint 实现，2 × Opus Agent 做 Evaluator，1 × Opus Agent 做 retroactive audit）
- 16 个 artifact 文件 commit
- 6 行 quality.jsonl（首次）
- 1 条 lessons-learned 条目（首次在 dogfooding 语境下）
- Rule 总数 19 → 20
