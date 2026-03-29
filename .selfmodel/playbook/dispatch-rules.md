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
| Sprint 交付审查 / 质量评估 / code review / 评审 | **Evaluator** | 独立上下文，怀疑论提示词，防止自评偏见 |
| 调研 / research / 选型 / 对比 / best practice / 怎么做 / 最佳方案 | **Researcher** | Google Search 接地，搜索深度和实时性最强 |
| 技术选型 / 库对比 / 方案评估 | **Researcher → Leader** | 先搜再判，研究报告输入 Leader 决策 |

**路由冲突优先级**: Leader > Evaluator > Researcher > Opus Agent > Gemini > Codex
**Evaluator 约束**: Evaluator 只做评审，不做实现。只有 Leader 可以 dispatch Evaluator。
**研究前置**: 涉及未知领域的实现任务，先派 Researcher 再派 Generator
**研究 vs 实现**: 任务同时匹配研究和实现信号时，Researcher 优先（先搜再做）
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

### Evaluator（独立质量审查 — 只读）

1. Leader 构建 eval 输入：`.selfmodel/inbox/evaluator/sprint-<N>-eval.md`
   （格式见 `playbook/evaluator-prompt.md` Input Protocol）
2. **不需要 worktree**（只读评审）

**Opus Agent 通道（主通道）**:

```
Agent tool:
  prompt: |
    You are an independent code auditor. Read the evaluation file below and execute
    the review protocol exactly as specified. Output ONLY valid JSON matching the schema.
    Evaluation file: /Users/vvedition/Desktop/selfmodel/.selfmodel/inbox/evaluator/sprint-<N>-eval.md
  isolation: "worktree"
  model: opus
```

**Gemini 通道（备用）**:

```bash
CI=true timeout 120 gemini \
  -p "$(cat /Users/vvedition/Desktop/selfmodel/.selfmodel/inbox/evaluator/sprint-<N>-eval.md) Execute the review protocol. Output ONLY valid JSON." \
  -m gemini-3.1-pro-preview -y \
  2>&1 | tee /Users/vvedition/Desktop/selfmodel/.selfmodel/reviews/sprint-<N>-verdict.json
```

### Researcher（Google Search 接地 — 只读）

1. Leader 将研究问题写入：`.selfmodel/inbox/research/sprint-<N>-query.md`
2. **不需要 worktree**（只读操作，不修改代码）
3. 执行：

```bash
CI=true timeout 300 gemini \
  -p "$(cat /Users/vvedition/Desktop/selfmodel/.selfmodel/inbox/research/sprint-<N>-query.md) 基于上述问题进行深度调研" \
  -m gemini-3.1-pro-preview -y \
  2>&1 | tee /Users/vvedition/Desktop/selfmodel/.selfmodel/inbox/research/sprint-<N>-report.md
```

**三层研究管道**（复杂调研时启用）：

```
Layer 1 — 广度搜索（并行）:
├── Gemini -G         → Google Search 实时接地回答
├── NotebookLM        → research_start 多源深度综合（需认证）
└── context7 MCP      → 库/框架精确文档（技术调研时）

Layer 2 — 深度挖掘（按需）:
├── WebFetch          → 抓取 Layer 1 关键 URL 全文
└── Chrome MCP        → 需要交互的页面

Layer 3 — 交叉验证:
└── Leader            → 消除矛盾，综合结论，输出最终报告
```

### 并行调度

无依赖的任务必须并行调度：
- 多个 Agent tool 调用放在同一个 message 中
- Gemini/Codex 用 `run_in_background: true` 后台执行
- **Researcher 可与 Generator 并行**（研究和实现无依赖时）
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
| **Evaluator 评审** | **120s** | **只读分析，不做实现** |
| 单文件编辑 / 简单修复 | 60s | 快速操作 |
| 组件创建 / 中等复杂度 | 120s | 大部分 Sprint 标准 |
| 多文件实现 / 复杂逻辑 | 180s | 单次最大值 |
| **Researcher 调研** | **300s** | **搜索+综合需要时间** |
| npm install / build | 300s | 网络延迟不可控 |

---

## Backpressure 协议

### Generator（Gemini/Codex/Opus）

1. **第一次超时** → 相同 timeout 重试一次
2. **第二次超时** → 拆分为更小子 Sprint，每个 ≤60s
3. **第三次超时** → 升级到 Leader 手动介入，记录到 lessons-learned.md

失败时保留 worktree 不清理，便于诊断。

### Researcher

1. **第一次超时/失败** → 相同 timeout 重试一次
2. **第二次超时/失败** → 降级通道：Gemini -G → Leader 用 WebSearch + WebFetch 自研
3. **第三次失败** → Leader 用 Chrome MCP 手动搜索 → 记录到 lessons-learned.md

降级链: `Gemini -G` → `WebSearch + WebFetch` → `Chrome MCP` → `Leader 自研`

### Evaluator

1. **第一次超时** → 相同通道重试
2. **第二次超时** → 切换通道（Opus ↔ Gemini）
3. **两通道均失败** → Leader self-fallback，review 记录标注 `evaluator: self-fallback`
