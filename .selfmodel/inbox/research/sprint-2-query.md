# Research Query: Sprint 2

## 研究类型
Type B（技术调研）

## 核心问题
如何通过 Claude Code Hooks 机制强制执行自定义工作流规则？我们需要让 CLAUDE.md 中的流程规则变成硬约束，而不是建议。

## 调研范围

### 1. Claude Code Hooks 机制
- Claude Code hooks 的完整文档：PreToolUse / PostToolUse / session start hooks
- Hook 的 JSON schema 和配置格式（.claude/settings.json 中怎么定义）
- Hook 能拦截哪些工具？Edit/Write/Bash/Agent 都能拦吗？
- Hook 的 exit code 语义：exit 0 = 放行, exit 2 = 拦截？
- Hook 能读取哪些上下文？当前文件路径、工具参数、会话状态？
- Hook 的 stdin 数据格式是什么？JSON？包含哪些字段？

### 2. 现有 Hook 实践
- 社区里有人用 hooks 做工作流强制执行吗？
- 有没有开源的 Claude Code hook 集合/模板？
- 常见的 hook 用法：lint、测试、安全检查、权限控制？

### 3. 我们需要的具体 Hooks
- **worktree 隔离强制**：Edit/Write 操作时检查是否在 worktree 中，主仓库拒绝
- **合约前置检查**：调用 agent 前检查是否有对应的 Sprint 合约文件
- **inbox 文件缓冲检查**：调 gemini/codex 时检查是否有对应 inbox 文件
- **Leader 不下场**：检测 Leader（当前 session）是否在直接写实现代码
- **Session Start 强制**：新 session 必须先读 next-session.md 和 team.json

## 上下文
selfmodel 是一个多 AI agent 团队编排系统。CLAUDE.md 定义了严格的工作流规则（Leader 不下场、worktree 隔离、Sprint 合约制等），但实际使用中 Claude Code 会忽略这些规则直接写代码。我们需要通过 hooks 机制将软约束变成硬约束。

## 期望产出
- [ ] Claude Code hooks 的完整技术细节（配置格式、stdin schema、exit code 语义）
- [ ] 每个需要的 hook 的具体实现方案（shell 脚本）
- [ ] settings.json 的完整配置示例
- [ ] 有没有现成的 hook 框架/工具可以复用

## 约束
- Hooks 必须是轻量级的（每次调用 < 100ms）
- 必须支持 macOS
- 不能误拦正常操作（比如 Leader 编辑 CLAUDE.md 和 playbook 应该被允许）
- 需要有 bypass 机制（紧急情况下可以临时关闭）
