# Lessons Learned

进化协议积累的经验。每 10 个 Sprint 回顾更新。

---

## Format

每条经验记录：

- **Sprint**: <N>（触发经验的 Sprint 编号）
- **Category**: <dispatch | quality | communication | tooling | architecture>
- **Lesson**: <我们学到了什么>
- **Action**: <对协议做了什么修改>
- **Result**: <修改后的效果：改善 / 无变化 / 回退>

---

## Auto-Learned

Hook 拦截记录自动追加到 `.selfmodel/state/hook-intercepts.log`（不在此文件中，避免修改受保护的 playbook）。
Leader 每 10 sprint 审查 hook-intercepts.log，提取有价值的经验升级为下方正式 Log 条目。

### Log 格式
```
[<timestamp>] hook=<hook-name> tool=<tool-name> reason=<why-blocked>
```

---

## Log

### Sprint 1: Gemini CLI -G flag 不存在
- **Category**: tooling
- **Lesson**: Gemini CLI 没有 `-G` flag。Google Search 是模型内置 tool，通过 `-y` (yolo) 模式自动调用
- **Action**: 修正 research-protocol.md 和 CLAUDE.md 中所有 Researcher CLI 模板
- **Result**: 改善 — Researcher 首次成功执行调研

### Sprint 2: Researcher inbox 路径
- **Category**: dispatch
- **Lesson**: Researcher 用 gemini CLI 但 inbox 在 `inbox/research/` 而非 `inbox/gemini/`。enforce-agent-rules.sh 需同时检查两个目录
- **Action**: 修正 enforce-agent-rules.sh gemini 检查逻辑
- **Result**: 改善 — Researcher 调用不再被误拦截

### Sprint 6: yes | 管道导致 Gemini CLI E2BIG
- **Category**: tooling
- **Lesson**: `yes |` 无限写入 stdin，Gemini CLI sandbox relaunch 时 stdin buffer 已积累数 MB 数据，execve() 调用超出 ARG_MAX (1MB macOS) 导致 `spawn E2BIG`。问题与文件大小和环境变量无关，纯粹是无限 stdin 流的副作用。Codex `--full-auto` 和 Gemini `--yolo` 已原生处理交互确认，`yes |` 完全不需要。
- **Action**: 从所有 CLI 模板中移除 `yes |`，三层静默执行降为两层 (`CI=true GIT_TERMINAL_PROMPT=0 timeout <N>`)
- **Result**: 改善 — Gemini CLI 在 POAI 项目 Sprint 57 重试后正常执行

### Sprint 65-76: Merge 冲突与细节丢失（系统性缺陷）
- **Category**: architecture
- **Lesson**: 并行 worktree 从同一个 commit fork 后各自独立修改，merge 时必然冲突。用 `--theirs` 解决冲突会丢弃 main 侧变更（即先 merge 的 Sprint 修复）。根因有四层：(1) 无 rebase-before-merge (2) `--theirs` 是破坏性策略 (3) 无文件重叠检测 (4) 无 post-merge 回归验证
- **Action**: 四项协议修改：
  - dispatch-rules.md: merge 流程改为 rebase-then-merge，新增冲突解决优先级，串行 merge 规则
  - orchestration-loop.md: Step 4 增加 file overlap 检测，Step 7 改为串行 rebase+merge，新增 Step 7.5 post-merge smoke test
  - quality-gates.md: 新增 Post-Merge Regression Gate
  - CLAUDE.md: Iron Rules 新增 No Blind Merge
- **Result**: 待验证

### Sprint 65-78 (vibe-sensei): 分支脱离 main 成为事实主线
- **Category**: architecture
- **Lesson**: Leader 在某个时刻 checkout 到了 worktree 分支上工作，后续所有 Sprint 都在这个分支上积累。main 被遗忘在 92 commits 之前。worktree 之间直接合并（`Merge worktree-A into worktree-B`），main 作为唯一真相源的约束被打破。最终导致两条平行线、47K 行差异、无法轻松合并。
- **Action**: 三条新 Iron Rule：
  - Rule 14 **Main Is Truth**: Leader 必须始终在 main 上，所有 merge 只能 target main
  - Rule 15 **Short-Lived Branches**: worktree 分支必须在同 session 内 merge 或 discard
  - Rule 16 **No Orphan Work**: DELIVERED 分支必须先 merge 才能 fork 新的
  - orchestration-loop.md 新增 Step 0 Pre-Flight Check
  - Session Start/End Protocol 强化为 mandatory cleanup
- **Result**: 待验证

### Sprint 65-76: K 线图技术选型走弯路
- **Category**: dispatch
- **Lesson**: 从 Lightweight Charts → 各种配置 → TradingView Charting Library，走了多个 Sprint 的弯路。根因：实现前未先派 Researcher 做技术选型
- **Action**: 强化 dispatch-rules.md 的"研究前置"原则 — 涉及未知领域（库选型、API 选型、架构方案）的实现任务，必须先派 Researcher 再派 Generator
- **Result**: 待验证

### Sprint 5: Worktree 路径混淆
- **Category**: communication
- **Lesson**: inbox 任务文件给了 main 仓库的绝对路径作为 Context Files，Agent 直接编辑了 main 的文件而非 worktree 副本。Leader cp worktree→main 时覆盖了 Agent 的修改
- **Action**: 未来 inbox 任务必须强调 "work within your worktree, translate absolute paths to worktree-relative paths"。Leader 合并产出时先 diff 确认内容在 worktree 中
- **Result**: 改善 — 本次手动恢复，后续可避免

### 11-Sprint Fan-Out Merge Hell（跨项目通用模式）
- **Category**: architecture
- **Lesson**: 11 个 Sprint 并行派发，6+ 个同时修改相同"收敛文件"（tools.ts, index.ts, types.ts 等注册表文件），导致串行合并时需要 10 次级联 rebase 冲突解决。六层根因：(1) 文件重叠检测是建议性文本，Leader 可跳过 (2) 无并行调度上限 — "MUST parallelize" 鼓励全量扇出 (3) "收敛文件"概念不存在 — 注册表文件和普通文件同等对待 (4) Rule 16 不够 — DELIVERED Sprint 同时到达时规则失效 (5) Sprint Files 列表是自由文本，重叠检测不可靠 (6) 无滚动批次概念 — 全部派发或逐个派发，没有中间态
- **Action**: 首次引入代码级强制执行（hook），而非仅文档更新：
  - 新建 `enforce-dispatch-gate.sh` PreToolUse hook — 三道硬门禁：并行上限（active contracts < max_parallel）、收敛文件门禁（同一热文件不得被多个 active Sprint 修改）、文件重叠检查（active Sprint 间不得有共享文件）。exit 2 拦截，无法绕过
  - 新建 `.selfmodel/state/dispatch-config.json` — JSON 配置（max_parallel, convergence_files），shell 用 jq 确定性解析
  - 新建 `scripts/verify-delivery.sh` — 交付后对比合约声明文件 vs 实际修改文件，发现未声明修改
  - sprint-template.md 新增结构化 `## Files` 段（Creates/Modifies/Out of Scope），hook 自动解析
  - orchestration-loop.md Step 4 重写为 "Rolling Batch Dispatch"（滚动批次：调度 3 → 合并 3 → 调度 3）
  - dispatch-rules.md 新增 "收敛文件管理" 段，并行调度加三条硬约束
  - CLAUDE.md 新增 Iron Rule 17 (Rolling Batch) 和 Rule 18 (Convergence File Gate)
  - `.claude/settings.json` 注册新 hook 到 Bash matcher 链
- **Result**: 待验证

### v0.5.0 Retroactive Audit: selfmodel 没在自己身上 dogfood
- **Sprint**: R1-R4（retroactive）+ Sprint 7（首次合规 dogfooding）
- **Category**: architecture
- **Lesson**: selfmodel 定义了 Rule 7/14/15/16/17/18/19 这一整套纪律给用户项目用，但 selfmodel 自己的代码开发（v0.5.0 到 f0410d7 4 个 commit）全部直提 main。直接后果：R4 (`f0410d7`) 在 "regenerated from canonical heredoc" 的幌子下静默删除了 `enforce-leader-worktree.sh` Rules 7/8/9（LICENSE/VERSION/.github/assets 白名单），regression 在 main 上带病运行 3 天，发布和 CI 流程实质冻结。retroactive audit 给 R1-R4 打出平均 6.83 分，其中 R4 仅 5.15（REVISE）。如果走了 Sprint 流程，Evaluator 会在 merge 前 catch 住 canonical heredoc 和 live hook 的 drift——因为这正是 Integration Depth 维度应当检测的。
- **Action**:
  - 事后：生成 retroactive contracts `sprint-R{1,2,3,4}-retroactive.md`，派独立 Evaluator 评分，写入 quality.jsonl（首次有数据），归档为 `.selfmodel/reviews/retroactive-v0.5.0-audit.md`
  - 系统性修复：CLAUDE.md 新增 Rule 20 (Self-Dogfood)，明确 selfmodel 自己代码库的修改不得绕过 Sprint 流程；`ABSOLUTELY FORBIDDEN` 段新增 "No direct-to-main commits on selfmodel codebase"
  - 工具层修复：Sprint 7 派 Opus Agent 走完整流程修复 R4 regression，新增 `scripts/tests/test-hook-drift.sh` 锁死 canonical heredoc 和 live hook 的字节一致性，未来 `selfmodel update` 无法再重现此 bug
  - Evaluator mutation test 证明 drift test 真实生效：注入 `# DRIFT` → test exit 1 + diff，恢复 → exit 0
- **Result**: 改善验证中 — Sprint 7 拿到 9.15/10 ACCEPT，比 retroactive 平均分 +2.32。纪律红利已量化。Sprint 9（depth gate Agent tool 覆盖）+ Sprint 10（VERSION 同步）将继续走相同流程作为第二、第三次验证
