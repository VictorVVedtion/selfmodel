# Sprint 5b Research Report: Context Management Strategy

## 核心结论
在长时间运行的 AI Agent 系统中，依赖单一的自动上下文压缩（Compaction）是脆弱的。最佳策略是**混合式上下文管理（Hybrid Context Management）**：在微观任务（短周期）中依赖系统原生的我已经调研了关于长时间运行的 AI Agent 的 Context 管理策略，并将详细的分析报告写入了 `.selfmodel/inbox/research/sprint-5b-report.md` 文件中。以下是研究的核心结论和各个要点的总结：

### 核心结论
在长时间运行的系统中，不应单一依赖自动上下文压缩（Compaction）。最佳实践是采用**混合式上下文管理（Hybrid Context Management）**：
- **微观周期**：依赖原生 Compaction 来维持心流和当前工作记忆。
- **宏观周期 / 认知衰退时**：强制执行显式的 Checkpoint 并进行硬性 Context Reset，所有关键状态必须外部化为单一事实来源（如 `next-session.md`）。

### 1. Reset vs Compaction 对比及适用场景
- **Context Compaction（上下文压缩）**：
  - **机制与优势**：系统后台自动总结历史对话，保留当前轮次，对开发者无感，能有效推迟触碰 Token 上限的时间。
  - **劣势**：**有损压缩**。早期设立的精准约束（非 System Prompt 级别）、代码细节和避免踩坑的记忆极易丢失，导致幻觉率逐步上升。
  - **适用**：单一明确的短时子任务、处于同一模块的心流开发。
- **Context Reset（上下文重置）**：
  - **机制与优势**：清空当前会话，由外部文件重新加载上下文。这是高信噪比的新起点，单次请求成本最低，彻底消除累积噪音。
  - **劣势**：打断连贯工作流，对 Checkpoint 文件的质量依赖极高。
  - **适用**：完成 Sprint 子目标、切换大模块或遇到陷入死循环的“打地鼠”式 Bug 时。

### 2. "Context Anxiety" 识别信号与缓解方法
- **识别信号**：
  - Agent 开始重复询问早期已解决的问题。
  - 虚构不存在的文件路径或遗忘项目架构。
  - 修复 Bug 时陷入死循环，修 A 坏 B，失去全局逻辑。
  - 输出退化，代码开始省略注释、类型甚至核心逻辑；或者频繁请求补充上下文。
- **缓解方法**：必须立即中止操作，命令 Agent 输出当前进度和阻塞点至 `next-session.md`，随后硬重置（执行 `/clear`）再通过读取 Checkpoint 文件重构记忆。

### 3. Session 内 Checkpoint 协议设计
- **触发条件**：连续交互达到 40-50 轮； Token 占用逼近上限的 75%；完成核心层级跨越；或者出现 Context Anxiety 信号。
- **交接格式**：`next-session.md` 应当高度结构化，包含**当前目标**、**状态总结（近期核心修改和关键决策）**、**核心工作区（当前所需的 3-5 个关键文件路径）**、**阻塞点**，以及**重置后必须立即执行的确切第一步操作（Actionable Next Steps）**。

### 4. Claude Code 的适配方案
Claude Code 原生拥有达到 Token 阈值时自动压缩中间对话（保留首尾）的机制，这会导致“发生了什么”被记住，但“怎么做的”和“微观限制”被遗忘。
- **策略：不要对抗，而是外部化记忆（Externalize Memory）**。绝不把长期有效的规则留在聊天历史里，一旦确立了关键约束，必须马上落地到 `playbook` 或者源码注释中。
- 将 `/clear` 常规化，规定在微小的 Sprint 完成并撰写好 `next-session.md` 之后，主动清空并重新 `read` 会话加载核心约束。

完整的中英文混合详细文档可查阅刚才更新的 `.selfmodel/inbox/research/sprint-5b-report.md`。
ion 机制细节与适配

**机制细节：**
Claude Code 会在后台监控 Token 消耗。当逼近上限时，会自动提取中间 N 轮对话发送给摘要模型，生成高度浓缩的历史总结替换原对话。副作用是：它优先保留“发生了什么”的叙事，极易丢弃“具体怎么写的”和“不能碰的坑”的微观约束。

**适配方案 (Externalize Memory & Proactive Reset)：**
- **不要对抗，要利用**：接受其作为短时微操的利器。
- **外部化关键记忆**：绝不把长期有效规则留存在聊天历史中。发现关键约束立刻写入 `.selfmodel/playbook/lessons-learned.md` 或代码注释。
- **主动周期性 `/clear`**：将 `/clear` 纳入常规工作流。每个微小 Sprint 结束时写入 `next-session.md`，随后立即 `/clear`，再通过读取文件唤醒 Agent。
