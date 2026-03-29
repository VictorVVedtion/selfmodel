# Next Session Handoff

## 状态
Hooks 强制执行系统上线。Claude Code 现在会硬约束工作流规则（Leader 不下场、合约前置、Inbox 缓冲）。Sprint 2 按完整协议（合约→inbox→Agent worktree→审查）完成。

## 下一步
1. **决定产品方向** — selfmodel 要构建什么具体产品？
2. **GitHub Template** — 在 GitHub Settings 中标记为 Template Repository
3. **验证 Hooks** — 新 session 启动时确认 session-start.sh 注入上下文
4. **selfmodel init 集成** — selfmodel.sh init 时自动生成 hooks 配置

## Blockers
无

## 本次关键决策
- 自建通信层（不依赖 /do skill，完全控制调度语义）
- Agent 必须在 worktree 隔离中工作（防止代码冲突+认知污染）
- State 双轨制：team.json（机器读写）+ next-session.md（人类可读 handoff）
- Skill 不预判好坏，通过实际 Sprint 使用后评分决定保留/淘汰
- CLAUDE.md 采用 router pattern — 主文件 ~200 行，详细规则在 playbook/ 模块
- 文件缓冲通信 — 复杂 prompt 写入 inbox 文件再 @ 引用，解决引号转义
- 三层静默执行 — yes | CI=true timeout，杜绝交互死锁
- 小批量 — 每个 agent 任务 30-60 秒完成
- 效率至上 — 能并行就并行，最大化 agent 利用率
- **Researcher 角色** — Gemini CLI（`-y` 模式，模型内置 Google Search tool）作为专职研究 agent
- **研究前置** — 未知领域先研究再实现，研究报告输入 Leader 决策
- **selfmodel CLI** — `scripts/selfmodel.sh` 实现 init/adapt/update，Nx 风格特征文件推断
- **Gemini CLI 修正** — `-G` flag 不存在，正确用法是 `-p "..." -m gemini-3.1-pro-preview -y`
- **Hooks 强制执行** — 3 个 hook 脚本 + settings.json，将 CLAUDE.md 软规则变硬约束
- **Sprint 2 完整协议执行** — 首次按合约→inbox→Agent worktree→审查流程完成

## Active Worktrees
无

## Open Sprints
无
