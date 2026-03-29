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

### Sprint 5: Worktree 路径混淆
- **Category**: communication
- **Lesson**: inbox 任务文件给了 main 仓库的绝对路径作为 Context Files，Agent 直接编辑了 main 的文件而非 worktree 副本。Leader cp worktree→main 时覆盖了 Agent 的修改
- **Action**: 未来 inbox 任务必须强调 "work within your worktree, translate absolute paths to worktree-relative paths"。Leader 合并产出时先 diff 确认内容在 worktree 中
- **Result**: 改善 — 本次手动恢复，后续可避免
