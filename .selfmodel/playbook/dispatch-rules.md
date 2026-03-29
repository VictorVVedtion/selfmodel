# Dispatch Rules

任务调度规则。Leader 在分配 Sprint 前必须查阅本文件。

---

## 决策矩阵

| Signal（信号关键词） | Route To | Why |
|---|---|---|
| UI / UX / CSS / component / page / animation / layout / 前端 / 界面 / 组件 | **Gemini** | 视觉设计强项，擅长 JSX/TSX/样式系统 |
| 单文件 backend / utility / data transform / function / fix / 工具函数 | **Codex** | 快速、聚焦、解耦，适合独立文件作业 |
| 多文件 refactor / system integration / complex logic / 跨模块 / 重构 | **Opus Agent** | 深度推理 + 百万 token 上下文 |
| Architecture / spec / review / arbitration / 架构决策 / 仲裁 | **Leader** | 编排权威，不可委托 |

**路由冲突优先级**: Leader > Opus Agent > Gemini > Codex
**判断困难时**: 默认路由到 Opus Agent（安全选择，能力最全面）。

---

## CLI 调用模板

### Gemini（文件缓冲 + @ 语法）

1. Leader 将完整任务写入：`.selfmodel/inbox/gemini/sprint-<N>.md`
2. 创建 worktree（见 Worktree 管理）
3. 在 worktree 内执行：

```bash
cd <worktree-path> && \
CI=true GIT_TERMINAL_PROMPT=0 yes | timeout 180 gemini \
  "@/Users/vvedition/Desktop/selfmodel/.selfmodel/inbox/gemini/sprint-<N>.md 执行上述任务" \
  -s --yolo
```

### Codex（文件缓冲）

1. Leader 将完整任务写入：`.selfmodel/inbox/codex/sprint-<N>.md`
2. 创建 worktree
3. 在 worktree 内执行：

```bash
cd <worktree-path> && \
CI=true GIT_TERMINAL_PROMPT=0 yes | timeout 180 codex exec \
  "Read /Users/vvedition/Desktop/selfmodel/.selfmodel/inbox/codex/sprint-<N>.md and implement exactly as specified. Working directory: $(pwd)" \
  --full-auto
```

### Opus Agent（原生 Agent tool）

通过 Claude Code 的 Agent tool 调用，自带 worktree 隔离：

```
Agent tool:
  prompt: |
    你是 Opus Agent，负责 Sprint <N>。
    任务合约: /Users/vvedition/Desktop/selfmodel/.selfmodel/contracts/active/sprint-<N>.md
    请读取合约后严格按照验收标准实现。
    完成后在 worktree 根目录创建 DONE.md 记录交付物清单。
  isolation: "worktree"
  model: opus
```

### 并行调度

无依赖的任务必须并行调度：
- 多个 Agent tool 调用放在同一个 message 中
- Gemini/Codex 用 `run_in_background: true` 后台执行
- 等全部完成后统一审查

---

## Worktree 管理

| 操作 | 命令 |
|---|---|
| 创建 | `/git-worktree add sprint-<N>-<agent> -b sprint/<N>-<agent>` |
| 路径 | `../.zcf/selfmodel/sprint-<N>-<agent>/` |
| 列表 | `git worktree list` |
| 审 diff | `git diff main...sprint/<N>-<agent>` |
| 合并 | `git merge sprint/<N>-<agent> --no-ff -m "Sprint <N>: <title>"` |
| 清理 | `/git-worktree remove sprint-<N>-<agent>` |

---

## 三层静默执行

| Layer | 机制 | 作用 |
|---|---|---|
| 1 | `yes \|` | 吞掉 Y/n 交互提示 |
| 2 | `CI=true GIT_TERMINAL_PROMPT=0` | 环境变量跳过交互 |
| 3 | `timeout <N>` | 硬超时，超时即 kill |

完整模式: `CI=true GIT_TERMINAL_PROMPT=0 yes | timeout <N> <command>`

---

## 超时指南

| 任务类型 | Timeout | 说明 |
|---|---|---|
| 单文件编辑 / 简单修复 | 60s | 快速操作 |
| 组件创建 / 中等复杂度 | 120s | 大部分 Sprint 标准 |
| 多文件实现 / 复杂逻辑 | 180s | 单次最大值 |
| npm install / build | 300s | 网络延迟不可控 |

---

## Backpressure 协议

1. **第一次超时** → 相同 timeout 重试一次
2. **第二次超时** → 拆分为更小子 Sprint，每个 ≤60s
3. **第三次超时** → 升级到 Leader 手动介入，记录到 lessons-learned.md

失败时保留 worktree 不清理，便于诊断。
