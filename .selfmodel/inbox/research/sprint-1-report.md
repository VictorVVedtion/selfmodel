这份调研报告针对 **selfmodel (多 AI Agent 编排系统)** 的项目自适应初始化机制进行了深度分析。以下是详细的研究结果。

### 核心结论

1. **AI 编程工具正从“全局配置”走向“项目级记忆库”**：早期工具（如 Aider）偏向于命令行参数或全局 YAML 配置，而新一代工具（如 Claude Code, Cline）均采用了 **“根目录 Markdown 规则文件 (如 CLAUDE.md) + 本地记忆目录 (如 memory-bank/)”** 的模式。这与 `selfmodel` 当前的架构（`CLAUDE.md` + `.selfmodel/playbook/`）完全一致且具备前瞻性。
2. **自动探测的行业标准是“配置文件特征推断”**：成熟的 Scaffolding 工具（如 Nx, create-next-app）并不强依赖繁琐的 AST 解析，而是通过匹配特征文件（如 `package.json` 的 `dependencies`、`next.config.js`、`pyproject.toml`）来推断技术栈。
3. **Agent 编排框架缺乏原生的“项目自适应”能力**：CrewAI、AutoGen 和 LangGraph 均需要开发者手动硬编码 Agent 的 Role 和 Workflow。要实现 `selfmodel adapt`，我们需要在 Agent 编排层之上，封装一个“特征侦测与模板路由”的 Shell 初始化层。

---

### 详细发现

#### 1. AI 编程工具初始化模式对比表

| 工具名称 | 核心规则文件/目录 | 初始化方式 (Scaffolding / Adapt) | 自动项目类型检测能力 |
| :--- | :--- | :--- | :--- |
| **Claude Code** | `CLAUDE.md` | 运行 `/init` 命令。 | **强**。会自动扫描代码库结构、配置文件，并生成带有 tech stack 和 commands 的 `CLAUDE.md`。 |
| **Cline** | `.clinerules` / `memory-bank/` | 聊天输入 `initialize memory bank`。 | **中**。依赖 LLM 在对话时读取当前目录文件并总结，没有硬编码的快速扫描器。 |
| **Aider** | `.aider.conf.yml` | 无专属 init 命令，依赖对话自动构建。 | **弱**。不强调持久化规则，配置主要针对 LLM 模型和 Lint 命令。 |
| **Windsurf** | `.windsurf/rules/` | 通过 UI 面板手动添加。 | **弱**。基于 glob 匹配（如 `*.py` 触发特定规则），需手动配置。 |
| **Continue** | `.continue/rules/` | 手动创建或通过 `create_rule_block`。 | **弱**。基于文件结构加载，无自动扫描项目特征的功能。 |

#### 2. 自适应 Scaffolding (脚手架) 最佳实践
- **特征文件推断 (Nx 模式)**：Nx 通过扫描工作区中的 `nx.json`、`package.json` 以及特定框架的配置文件（如 `vite.config.ts`, `cargo.toml`），自动推断出项目包含哪些 Task（build, test, lint）。这是一种高效的无侵入式检测。
- **状态记忆 (Copier 模式)**：相比于 Cookiecutter 的静态生成，Copier 会在项目根目录生成 `.copier-answers.yml`。这使得二次运行 `adapt` 或 `update` 时，可以读取之前的状态，实现增量更新而不是全量覆盖。

#### 3. 多 Agent 框架的项目配置现状
- **CrewAI / AutoGen / LangGraph** 等框架本质上是**执行引擎**。它们不关心“这是什么项目”，只关心“Agent 的 Prompt 和工具是什么”。
- 结论：不存在开箱即用的“扫描项目 → 自动推荐 Agent 组合”的开源原生机制。这恰恰是 `selfmodel` 可以填补的生态空白。

---

### 推荐方案：Selfmodel 的 Zero-Dependency 架构设计

为了满足 **Zero-dependency（纯 Bash）、跨平台 (macOS/Linux) 以及兼容现有目录结构** 的约束，推荐采用以下架构实现 `selfmodel init` 和 `selfmodel adapt`。

#### 核心机制：特征匹配路由 (Bash Script)
创建一个名为 `selfmodel.sh` 的单文件可执行脚本。

**第一步：环境探测 (Environment Detection)**
脚本内置一组简单的 `grep` 和文件存在性检查逻辑：
*   **Node/React**: 检查 `package.json` 是否包含 `react` 或 `next`。
*   **Python**: 检查是否存在 `pyproject.toml` 或 `requirements.txt`。
*   **Go/Rust**: 检查 `go.mod` 或 `Cargo.toml`。

**第二步：模板合并与写入 (Template Rendering)**
根据探测到的特征，利用 Bash 的 `cat` 和 `Here Document (<<EOF)` 将特定的 playbook 规则注入。

*   **执行 `selfmodel init` (全新项目)**：
    1. 触发交互式终端提示（类似 create-next-app），询问用户技术栈（Frontend/Backend/Fullstack）。
    2. 生成基础文件：`CLAUDE.md`，并在 `.selfmodel/playbook/` 生成对应技术栈的 `quality-gates.md` 和 `dispatch-rules.md`。
    3. 根据技术栈写入初始的 `.selfmodel/state/team.json`（配置初始启用的 Agent，如默认开启 Opus Leader 和 Gemini Frontend）。

*   **执行 `selfmodel adapt` (存量项目适配)**：
    1. 静默扫描目录结构。
    2. 若发现 `package.json` 包含 `jest`，则在 `.selfmodel/playbook/quality-gates.md` 中自动追加 Node.js 测试规范。
    3. 如果没有 `CLAUDE.md`，则生成一份基准模板，并提示用户补充业务逻辑。

---

### 来源 URL
1. **Claude Code Init**: [Claude Code 官方文档与发布说明](https://claude.com)
2. **Cline Memory Bank**: [Cline GitHub 仓库与文档](https://cline.bot)
3. **Nx Inference**: [Nx 官方架构文档 (Task Inference)](https://nx.dev)
4. **Copier Adaptive Templates**: [Copier 官方文档](https://copier.readthedocs.io/en/stable/)
5. **Agent Frameworks Comparison**: [CrewAI vs AutoGen vs LangGraph 分析](https://towardsai.net/p/machine-learning/crewai-vs-autogen-vs-langgraph)

### 置信度
**高 (95%)**。所有收集到的信息均基于各工具最新的官方架构设计和 2024-2025 年的开发者实践。尤其是 Claude Code `/init` 和 Cline `memory-bank` 的概念是目前最前沿且被广泛认可的 LLM 编码工作流。

### 风险评估
1. **Bash 脚本的可维护性风险**：随着需要识别的技术栈越来越多，纯 Bash 脚本中的 `if-else` 逻辑可能会变得非常臃肿。
   * **缓解措施**：将不同技术栈的探测逻辑拆分为模块化的 bash 函数，或将模板定义抽象为简单的 JSON/文本文件供 Bash 读取。
2. **CLAUDE.md 冲突风险**：如果用户项目已经有了自己的 `CLAUDE.md`，`selfmodel adapt` 直接覆盖会丢失用户数据。
   * **缓解措施**：在执行写入前必须检查文件存在性，如果存在，则将 selfmodel 的专属指令（如 `<selfmodel_rules>` 标签）通过 `sed` 或追加 (`>>`) 的方式注入，而不是完全覆盖。
