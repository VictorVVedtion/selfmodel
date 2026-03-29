# Sprint 2 任务: Claude Code Hooks 工作流强制执行

你是 Opus Agent，负责 Sprint 2。

## 任务

实现 3 个 Claude Code hook 脚本 + 1 个 settings.json 配置，将 CLAUDE.md 的工作流规则变为硬约束。

## 必须先读取的文件

1. `/Users/vvedition/Desktop/selfmodel/.selfmodel/contracts/active/sprint-2.md` — 合约详情和验收标准
2. `/Users/vvedition/Desktop/selfmodel/.selfmodel/inbox/research/sprint-2-report.md` — Researcher 调研报告，包含技术细节和代码示例
3. `/Users/vvedition/Desktop/selfmodel/CLAUDE.md` — 需要强制执行的规则

## 交付物

### 1. `scripts/hooks/session-start.sh`
- SessionStart hook
- 读取并输出 `.selfmodel/state/team.json` 和 `.selfmodel/state/next-session.md`
- 始终 exit 0

### 2. `scripts/hooks/enforce-leader-worktree.sh`
- PreToolUse hook，matcher: `Write|Edit`
- 从 stdin 读取 JSON，提取 `tool_input.file_path`
- 白名单放行（exit 0）：
  - `.selfmodel/` 目录下的所有文件
  - `CLAUDE.md`
  - `scripts/` 目录下的所有文件
  - `README.md`
  - `.gitignore`
  - `.claude/` 目录下的所有文件
  - 任何 `.md` 文件（Leader 可以写文档）
- 白名单外拦截（exit 2）：
  - stderr 输出清晰的拦截消息
  - 消息中明确告诉 Claude 应该怎么做（派 Agent 到 worktree 中实现）
- BYPASS_LEADER_RULES=1 时 exit 0

### 3. `scripts/hooks/enforce-agent-rules.sh`
- PreToolUse hook，matcher: `Bash`
- 从 stdin 读取 JSON，提取 `tool_input.command`
- 仅当命令包含 `gemini`、`codex` 关键词时检查：
  - 检查 `.selfmodel/contracts/active/` 下是否有 `.md` 文件（至少一个活跃合约）
  - 对 gemini 命令：检查 `.selfmodel/inbox/gemini/` 下是否有 `.md` 文件
  - 对 codex 命令：检查 `.selfmodel/inbox/codex/` 下是否有 `.md` 文件
  - 缺失则 exit 2 + stderr 拦截消息
- 不包含 agent 关键词的命令直接 exit 0
- BYPASS_AGENT_RULES=1 时 exit 0

### 4. `.claude/settings.json`
- 如果文件已存在，读取现有内容并合并 hooks 字段
- 如果不存在，创建新文件
- 配置格式参考调研报告

## 关键约束
- 每个脚本开头检测 jq，缺失时 exit 0（放行，不误拦截）
- 所有路径使用相对路径（相对于项目根目录）
- shellcheck 兼容
- 拦截消息必须用中文，清晰告知违反了哪条规则以及应该怎么做

## 完成后
在 worktree 根目录创建 DONE.md 记录交付物清单。
