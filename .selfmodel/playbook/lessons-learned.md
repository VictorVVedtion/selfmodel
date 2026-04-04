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
