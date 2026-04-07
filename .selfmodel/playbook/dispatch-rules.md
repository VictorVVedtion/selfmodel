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
| E2E / 运行验证 / 集成测试 / 端到端 | **E2E Agent** | 运行时验证，不做代码修改 |
| 混沌测试 / chaos / rampage / 边界探索 / 压力测试 / 横冲直撞 | **Rampage (`/rampage`)** | 多 surface 混沌渗透，QA 通过后的混沌关卡 |
| 深度阅读 / 大文件分析 / 模式提取 / 架构设计 / deep read | **Leader (Deep-Read)** | 不可并行化，需上下文连续性 |

**路由冲突优先级**: Leader > Evaluator > Researcher > Opus Agent > Gemini > Codex
**Evaluator 约束**: Evaluator 只做评审，不做实现。只有 Leader 可以 dispatch Evaluator。
**研究前置**: 涉及未知领域的实现任务，先派 Researcher 再派 Generator
**研究 vs 实现**: 任务同时匹配研究和实现信号时，Researcher 优先（先搜再做）
**Rampage 后置**: QA/E2E 通过后，对有用户交互面的 Sprint 可选派发 `/rampage` 做混沌验证
**判断困难时**: 默认路由到 Opus Agent（安全选择，能力最全面）。

---

## CLI 调用模板

### Atomic Commit Workflow（所有 Agent 通用）

Agent 必须遵循 fix → verify → commit 循环。每个可独立验证的变更单独 commit。
禁止在 worktree 中积累所有变更后一次性 commit。
Commit message 格式: `sprint-<N>: <concise description of change>`

### Gemini（文件缓冲 + @ 语法）

1. Leader 将完整任务写入：`.selfmodel/inbox/gemini/sprint-<N>.md`
2. 创建 worktree（见 Worktree 管理）
3. 在 worktree 内执行：

```bash
cd <worktree-path> && \
CI=true GIT_TERMINAL_PROMPT=0 timeout 180 gemini \
  "@/Users/vvedition/Desktop/selfmodel/.selfmodel/inbox/gemini/sprint-<N>.md 执行上述任务" \
  -s --yolo
```

### Codex（文件缓冲）

1. Leader 将完整任务写入：`.selfmodel/inbox/codex/sprint-<N>.md`
2. 创建 worktree
3. 在 worktree 内执行：

```bash
cd <worktree-path> && \
CI=true GIT_TERMINAL_PROMPT=0 timeout 180 codex exec \
  "Read /Users/vvedition/Desktop/selfmodel/.selfmodel/inbox/codex/sprint-<N>.md and implement exactly as specified. Working directory: $(pwd)" \
  --full-auto
```

### Opus Agent（原生 Agent tool — 自带 worktree 隔离）

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

### E2E Agent v2（智能验证引擎 — 只读）

1. Leader 写入最小化 dispatch 文件：`.selfmodel/inbox/e2e/sprint-<N>.md`（仅 worktree 路径 + 合约路径 + depth hint）
2. **与 Evaluator 并行派发**（步骤 6 中同时触发）
3. Agent 自主：读合约 → 解析 AC 为原子验证 → 探测环境 → 逐条执行 → 逐条举证 → 报告

**Opus Agent 通道（主通道 — claude-opus-4-6）**:

```
Agent tool:
  prompt: |
    You are the E2E Verification Agent v2 (Opus 4.6).
    Mission: verify delivered code works at runtime. Do NOT modify code.
    CORE PRINCIPLE: The atom of verification is the Acceptance Criterion.
    Parse every AC from the contract into atomic verifications.
    Each AC = one command + one expected result + one evidence.
    Also verify implicit ACs (files exist, build passes, tests pass, no vulns).
    Workflow: UNDERSTAND → PROBE → DECOMPOSE → SETUP → EXECUTE → RETRY → TEARDOWN → REPORT
    Constraints: no code modification, no global installs, no prod APIs, no git push.
    Save artifacts to: .selfmodel/artifacts/sprint-<N>/
    Verification file: /Users/vvedition/Desktop/selfmodel/.selfmodel/inbox/e2e/sprint-<N>.md
    Output ONLY valid JSON matching E2E Verdict v2 schema.
  isolation: "worktree"
  model: opus
```

**Gemini CLI 通道（降级，仅隐式 AC）**:

```bash
cd <worktree-path> && \
CI=true GIT_TERMINAL_PROMPT=0 timeout 120 gemini \
  "@/Users/vvedition/Desktop/selfmodel/.selfmodel/inbox/e2e/sprint-<N>.md Verify only implicit ACs (files exist, build passes). Output JSON." \
  -s --yolo
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

### Rampage（混沌渗透 — Leader 直接调用 Skill）

Rampage 不是 Agent，是 Claude Code Skill。Leader 在 E2E PASS 后直接调用：

```
Skill tool:
  skill: "rampage"
  args: "--selfmodel --budget 5m <target-url-or-cmd>"
```

或在对话中直接输入 `/rampage --selfmodel`。

**不需要 worktree**（只读测试，不修改代码）
**不需要 inbox**（参数通过 Skill args 传递）
**产物输出**: `.selfmodel/artifacts/rampage-sprint-<N>.json` + `.gstack/rampage-reports/`

**调用时机**: orchestration-loop.md Step 6.5（E2E PASS 且 Sprint 有用户交互面时）
**Verdict 合并**: quality-gates.md Step 4.7

---

## Deep-Read Mode (Leader Research)

### 定义

某些工作**无法并行化**：读 30KB+ 源文件、理解 state machine、从 reference implementation 提取模式。这是研究工作，不是实现——不违反 Iron Rule 7 (No Implementation)。

### 使用场景

- 读大型源文件提取架构模式
- 分析 state machine 或复杂控制流
- 从参考实现设计架构
- 为后续 complex Sprint 预提取 code tour

### 流程

1. Leader 留在 main（不需要 worktree）
2. 用 Read tool 读源文件
3. 产出提取文档: `.selfmodel/artifacts/<topic>.md`
4. 提取文档成为后续 Sprint 的输入（在 ## Context 或 ## Code Tour 中引用）
5. 不需要 Sprint contract（这是 Leader 编排工作）

### Artifact 格式

```markdown
# Deep-Read: <Topic>

## Source Files Read
- <path> (lines N-M): <发现>

## Extracted Patterns
### Pattern: <name>
<code snippet + explanation>

## Architecture Map
<组件连接方式>

## Recommendations for Sprint <N>
<给 agent sprint 的具体指导>

## Created
<timestamp>
```

### plan.md 集成

Deep-read 工作在 plan.md 中以特殊类型出现：

```markdown
### Deep-Read DR1: <Title>
- Agent: leader
- Dependencies: none
- Status: PENDING | DONE
- Type: deep-read
- Output: .selfmodel/artifacts/<topic>.md
- Feeds: Sprint 5, Sprint 6
```

Leader 写完 artifact 后标记 Status → DONE。下游 Sprint 在 Dependencies 中列出 `DR1`。Deep-read artifact 路径写入下游 Sprint 的 ## Context。

---

## Two-Phase Dispatch (Complex Sprints)

Complexity: complex 的 Sprint，分两阶段调度：

### Phase A: Understand (只读)

Agent 读代码库，产出 `understanding.md`。不写实现代码。

**Gemini Phase A**:

```bash
cd <worktree-path> && \
CI=true GIT_TERMINAL_PROMPT=0 timeout 120 gemini \
  "@/Users/vvedition/Desktop/selfmodel/.selfmodel/inbox/gemini/sprint-<N>.md Phase A ONLY: 读取所有 Code Tour 和 Context 文件。按合约 Understanding Checkpoint 写 understanding.md。不要写任何实现代码。" \
  -s --yolo
```

**Codex Phase A**:

```bash
cd <worktree-path> && \
CI=true GIT_TERMINAL_PROMPT=0 timeout 120 codex exec \
  "Read /Users/vvedition/Desktop/selfmodel/.selfmodel/inbox/codex/sprint-<N>.md — Phase A ONLY: 读取所有 Code Tour 和 Context 文件。按 Understanding Checkpoint 写 understanding.md。不要实现任何代码。Working directory: $(pwd)" \
  --full-auto
```

**Opus Agent Phase A**:

```
Agent tool:
  prompt: |
    你是 Opus Agent，Sprint <N> — PHASE A (Understand Only)。
    合约: /Users/vvedition/Desktop/selfmodel/.selfmodel/contracts/active/sprint-<N>.md
    读取合约，然后读取所有 Code Tour 和 Context 中引用的文件。
    产出 understanding.md 在 worktree 根目录，内容：
    1. Files Read (路径 + 行范围 + 学到什么)
    2. Patterns Found (必须遵循的现有模式)
    3. Integration Plan (新代码如何连接现有模块)
    4. Failure Modes (可能出错的场景)
    不要写实现代码。只写 understanding.md。
  isolation: "worktree"
  model: opus
```

### Phase A 验证 (Leader)

Leader 读 worktree 中的 `understanding.md`，逐项检查：

- [ ] 列出了具体文件和行号（非笼统的「我读了代码库」）
- [ ] 识别了至少 2 个需要遵循的现有模式
- [ ] Integration plan 引用了具体的函数/类型/导出
- [ ] Failure modes 是针对本 Sprint 的，不是泛泛而谈

**PASS** → Dispatch Phase B (实现)
**FAIL** → 写反馈，Agent 在同一 worktree 重写 understanding.md

### Phase B: Implement

标准调度（per existing CLI templates），追加指令：
「你的 understanding.md 已批准，按 integration plan 实现。」

### 跳过条件

- `Complexity: simple` — 直接实现，无理解阶段
- `Complexity: standard` — 除非 Leader 判断风险高
- Agent 是 Researcher / Evaluator — 只读角色，不需理解阶段

---

## Code Tour Extraction (Leader Pre-Dispatch)

Complexity: standard 或 complex 的 Sprint，Leader **必须**在写 contract 前提取 code tour。

### 提取流程

1. 读 plan.md 中 Sprint 条目引用的参考文件
2. 识别关键模式（函数签名、类型定义、命名约定、错误处理）
3. 提取 2-5 个代表性片段（每个 5-20 行）
4. 写入 contract 的 `## Code Tour` section（含文件路径、行范围、「为什么重要」）
5. 识别架构上下文（数据流、邻接模块、命名约定、错误模式）
6. 写入 contract 的 `## Architecture Context` section

### 规则

- 片段**必须是真实代码** — 从代码库复制，不是编造
- **包含行号** — Agent 可以核实
- **最多 5 个片段** — 够展示模式即可
- **聚焦接口** — 函数签名、类型导出、配置结构
- 如果存在常见反模式，包含一个「错误示范」

### 跳过条件

- `Complexity: simple` — 无需 code tour
- Agent 是 Researcher — 产出报告，不写代码
- 纯文档 Sprint — 无代码模式

---

### 并行调度（受限滚动批次）

并行调度受以下硬约束限制（由 `enforce-dispatch-gate.sh` hook 强制执行）：

1. **最大并行上限**: `.selfmodel/state/dispatch-config.json` → `max_parallel`（默认 3）
   - ACTIVE + DELIVERED 状态的 Sprint 总数不得超过此上限
   - **Hook 强制**: 超限时 hook 以 exit 2 拦截 agent 调用，无法绕过（除非 BYPASS）
2. **收敛文件门禁**: `dispatch-config.json` → `convergence_files[]`
   - 两个 Sprint 触碰同一收敛文件 → 必须串行（先调度编号小的）
   - **Hook 强制**: 检测到收敛文件冲突时拦截
3. **结构化文件重叠检测**: Sprint 合约 `## Files` 段（具体路径列表）
   - 两个 active Sprint 共享任何文件 → hook 拦截
   - **禁止**: 用模糊描述替代文件路径（如 "src/ 目录" → 不可接受）

调度方式不变：
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
| 合并 | 见下方 Rebase-Then-Merge 流程 |
| 清理 | `/git-worktree remove sprint-<N>-<agent>` |

### Rebase-Then-Merge 流程（Iron Rule）

**绝对禁止**: 直接 `git merge` 不经 rebase。
**绝对禁止**: 用 `--theirs` 或 `--ours` 盲目解决冲突。

```bash
# Step 1: 在 worktree 中 rebase 到最新 main
cd <worktree-path>
git rebase main

# Step 2: rebase 冲突处理
#   → Agent 在 worktree 中解决（Agent 有完整任务上下文）
#   → 如 Agent 已退出：Leader 逐文件手动审查，理解两侧意图后决定
#   → 绝不盲目 --theirs / --ours

# Step 3: rebase 成功后，回 main merge（此时是 clean merge）
cd /Users/vvedition/Desktop/selfmodel
git merge sprint/<N>-<agent> --no-ff -m "Sprint <N>: <title>"

# Step 4: Post-merge smoke test（见 orchestration-loop.md Step 7.5）
```

### 冲突解决优先级

| 优先级 | 策略 | 适用场景 |
|--------|------|----------|
| 1 | Agent rebase 解决 | Agent 有上下文，知道两侧代码意图 |
| 2 | Leader 手动审查 | 逐文件、逐 hunk 决定保留哪侧 |
| 3 | 拆分 Sprint | 文件重叠太多，合并为一个 Sprint 或串行执行 |
| 4 | `--theirs` / `--ours` | **仅当** Leader 确认另一侧变更可丢弃时 |

### 并行 Sprint 串行 Merge 规则

多个 Sprint 可并行执行（提高效率），但 **merge 必须串行**：

```
并行派发: Sprint 65 + Sprint 66 + Sprint 67
并行评审: Evaluator 同时评审三个

串行合并（按 Sprint 编号顺序）:
  1. Sprint 65 rebase onto main HEAD → merge → main 前进
  2. Sprint 66 rebase onto 新 main HEAD → merge → main 再前进
  3. Sprint 67 rebase onto 最新 main HEAD → merge
```

**关键**: 每次 merge 后，后续待 merge 的分支必须先 rebase 到新的 main HEAD。

---

## 收敛文件管理（Convergence Files）

### 定义

收敛文件是项目中多个功能都需要修改的"热文件"。典型例子：
- 工具注册表（`tools.ts`）— 每个新工具都需要在此注册
- 导出聚合文件（`index.ts`）— 每个新模块都需要在此导出
- 类型定义（`types.ts`）— 每个新功能都需要在此添加类型
- 观察者注册（`guardian-observer.ts`）— 每个新 hook 都需要在此注册
- 路由注册（`routes/index.ts`）— 每个新页面都需要在此注册

### 存储

收敛文件列表存储在 `.selfmodel/state/dispatch-config.json` → `convergence_files[]`。
由 `enforce-dispatch-gate.sh` hook 在每次 agent 调度时自动读取和检查。

### 识别时机

Leader 在以下时刻识别和更新收敛文件列表：
1. **创建 plan.md 时**: 自动扫描所有 Sprint 的 Files 列表:
   - 出现在 3+ Sprint 中 → 自动标记为收敛文件候选
   - 匹配注册文件模式 (index.ts, types.ts, routes.ts, __init__.py, mod.rs) → 自动标记
   - Leader 确认候选列表后写入 dispatch-config.json
   - 详见 orchestration-loop.md Step 1.5
2. **Phase 边界**: 审查本 Phase 是否有新的共享文件
3. **merge 冲突后**: 冲突涉及的文件自动加入候选列表
4. **`verify-delivery.sh` 报告未声明修改时**: 频繁出现的未声明文件 → 候选

### 运行时规则（由 hook 强制）

- 收敛文件同一时间只允许一个 ACTIVE Sprint 触碰
- Sprint merge 后，收敛文件"释放"，下一个触碰它的 Sprint 才可调度
- **Leader 不得绕过此规则**（hook 硬门禁，非建议）

---

## 两层静默执行

| Layer | 机制 | 作用 |
|---|---|---|
| 1 | `CI=true GIT_TERMINAL_PROMPT=0` | 环境变量跳过交互 |
| 2 | `timeout <N>` | 硬超时，超时即 kill |

完整模式: `CI=true GIT_TERMINAL_PROMPT=0 timeout <N> <command>`

**CRITICAL**: 不要使用 `yes |` 管道。`yes` 的无限 stdin 流在 Gemini CLI sandbox
relaunch 时导致 `spawn E2BIG`（stdin buffer 积累数 MB 数据超出 execve ARG_MAX）。
Gemini `--yolo` 和 Codex `--full-auto` 已原生处理交互确认，`yes |` 完全不需要。

---

## 超时指南

| 任务类型 | Timeout | 说明 |
|---|---|---|
| **Evaluator 评审** | **120s** | **只读分析，不做实现** |
| 单文件编辑 / 简单修复 | 60s | 快速操作 |
| 组件创建 / 中等复杂度 | 120s | 大部分 Sprint 标准 |
| 多文件实现 / 复杂逻辑 | 180s | 单次最大值 |
| **Researcher 调研** | **300s** | **搜索+综合需要时间** |
| **E2E 验证（完整）** | **300s** | **build + test + server 启动验证** |
| **E2E 验证（仅 build）** | **120s** | **降级通道，仅编译检查** |
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
