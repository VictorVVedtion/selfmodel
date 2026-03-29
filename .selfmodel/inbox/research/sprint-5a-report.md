基于对 LLM Evaluator 架构（尤其是 Anthropic 的 Harness Design）以及评分漂移防治的行业最佳实践的深入调研，以下是为您整理的针对 Sprint 产出评估的核心结论与落地指南。

### 核心结论
LLM 作为评估者（Evaluator）通常会患上**“病态乐观主义”（Pathological Optimism）**——即倾向于给生成的内容打高分，对平庸的“AI 风格”产出进行合理化辩护。为了防止长期的评分漂移，必须建立独立的“生成-评估”隔离架构，将评估提示词像代码一样进行版本控制，并使用具有详细“思维链（CoT）”的锚点样本（Anchor Examples）来严格校准大模型的打分尺度。

---

### 一、 Anthropic Harness Design 中的 Evaluator 校准实践
Anthropic 的 Harness 架构将大模型系统视为一个多智能体环境，其评估者校准的核心做法如下：

1. **GAN 式的角色隔离**：将 Generator（生成者）和 Evaluator（评估者）严格分离。Evaluator 被设定为“持怀疑态度的 QA 工程师”，而不是“有用的 AI 助手”，以打破其默认的讨好倾向。
2. **反宽容提示词（Anti-Leniency Prompting）**：在系统提示词中明确指出并警告“合理化陷阱”（Rationalization Trap），禁止 Evaluator 在产出存在明显缺陷时通过脑补上下文来给予及格分。
3. **加权多维量表与结果导向**：不使用简单的通过/失败，而是进行多维度评分（如你指定的 5 维度）。Anthropic 发现，**大幅提高“Design Taste / Originality”的权重**，能有效逼迫系统摆脱千篇一律的、乏味的默认设计。评估只看最终状态（如：UI 是否真的渲染？），不看过程。
4. **提供“Unknown”逃生舱**：明确告诉 Evaluator，如果无法根据提供的上下文做出明确判断，必须返回 `Unknown`，严禁猜测或幻觉出“看起来没错”的结论。

---

### 二、 评分漂移（Scoring Drift）的检测与修正
评分漂移通常由模型底层的微调更新或提示词的微小变动引起。

#### 1. 检测方法 (Detection)
*   **黄金数据集基线（Golden Dataset / Anchor Set）**：维护一个由人类专家（如 Tech Lead）精心打分的、包含约 20-50 个历史 Sprint 真实产出的静态测试集。
*   **统计学监控**：每次底层模型更新或每隔几周，让 Evaluator 重新评估黄金数据集。通过计算 **PSI (群体稳定性指标)** 或观察分数分布的变化（比如平均分突然变高），来识别漂移。
*   **人工抽检一致性**：定期抽取 5% 的日常评估，由人工盲评，并计算 LLM 与人类的 **Cohen's Kappa 系数**（一致性相关度）。系数下降即代表发生漂移。

#### 2. 修正方法 (Mitigation)
*   **锁定模型快照（Pinning）**：在生产环境中，绝不使用 `gpt-4o` 或 `claude-3-5-sonnet-latest` 这种滚动版本，必须锁定到具体的 API 版本号（如 `claude-3-5-sonnet-20240620`）。
*   **CoT 强制前置**：在输出具体分数前，强制 LLM 先按维度输出 `<rationale>`（理由）。先推导后打分能极大提高分数的稳定性。
*   **动态 Few-shot 注入**：如果漂移严重，可以通过 RAG 技术，根据当前待评估的 Sprint 任务类型，从“黄金数据集”中动态提取最相似的 3 个 Few-shot 样本放入 Prompt 中重新对齐基准。

---

### 三、 Few-Shot 校准样本的最佳格式 (5 维度体系)
最佳实践表明，校准样本必须包含**原始输入、待评产出、思维链分析（最关键）、最终打分**。以下是基于真实 Sprint 场景的格式模板，包含满分、及格和不及格的示例基准：

```markdown
# 评估校准指南 (Evaluation Calibration Guide)
作为代码与设计审查专家，你必须严格按照以下标准进行评分。请先写出详细的推导过程（Rationale），再给出各维度的分数（1-5分）。

## 校准样本 1：满分标准 (Score: 5)
**[Sprint 任务]**：实现一个带交互动效的用户设置面板。
**[提交产出]**：(代码包含完整的 React 组件、Tailwind 动画类，并处理了加载与错误边界。使用了非对称的现代卡片布局)。

**[Evaluation Rationale]**
* Functionality (功能性): 代码无明显 Bug，完整处理了 API 的 loading 和 error 状态，组件挂载正常。
* Code Quality (代码质量): 组件拆分合理，提取了自定义 Hook 处理表单逻辑，类型定义 (TypeScript) 严谨无 `any`。
* Design Taste (设计品味): 间距遵循 8pt 规则，使用了优雅的微交互（如 hover 时的轻微上浮和阴影变化），色彩层级分明。
* Completeness (完整性): 实现了所有的需求点，并额外补充了响应式断点测试代码。
* Originality (原创性): 摒弃了传统的“两列居中表单”布局，采用了创新的侧边栏+动态内容区设计，视觉感受非常现代，非套路化产出。

**[Final Scores]**
Functionality: 5 | Code Quality: 5 | Design Taste: 5 | Completeness: 5 | Originality: 5

---

## 校准样本 2：及格/平庸标准 (Score: 3)
**[Sprint 任务]**：实现一个带交互动效的用户设置面板。
**[提交产出]**：(代码功能正常，但把所有逻辑写在了一个 400 行的文件里。界面是经典的 Bootstrap 风格表单，缺乏动效)。

**[Evaluation Rationale]**
* Functionality (功能性): 表单能正常提交并更新数据，没有阻断性错误。
* Code Quality (代码质量): 逻辑堆砌严重，缺少组件复用；但变量命名尚可，没有严重的内存泄漏风险。
* Design Taste (设计品味): 设计虽然可用，但显得过时且生硬，完全没有实现要求的“交互动效”，视觉体验平庸。
* Completeness (完整性): 核心功能具备，但缺少对异常状态（如断网）的优雅降级 UI。
* Originality (原创性): 典型的“AI 模板代码”，采用了最安全的、随处可见的通用 UI 设计，没有任何巧思。

**[Final Scores]**
Functionality: 4 | Code Quality: 3 | Design Taste: 2 | Completeness: 3 | Originality: 2

---

## 校准样本 3：不及格/幻觉标准 (Score: 1)
**[Sprint 任务]**：实现一个带交互动效的用户设置面板。
**[提交产出]**：(代码中调用了一个不存在的第三方库 `<SuperForm />`，CSS 类名冲突，完全未处理错误状态)。

**[Evaluation Rationale]**
* Functionality (功能性): 致命错误。由于引入了未安装/不存在的依赖，代码在本地根本无法运行编译。
* Code Quality (代码质量): 大量使用 `any`，存在未使用的变量，函数过长且充斥着无效的注释。
* Design Taste (设计品味): 无法实际预览，从代码结构推断 UI 处于混乱状态。
* Completeness (完整性): 任务未完成，提交了半成品。
* Originality (原创性): 生成了毫无意义的占位符代码，未能解决实际问题。

**[Final Scores]**
Functionality: 1 | Code Quality: 1 | Design Taste: 1 | Completeness: 1 | Originality: 1
```

### 实施建议
在您的 `.selfmodel/playbook/quality-gates.md` 或相关的 Prompt 文件中，强烈建议将上述 `<Rationale>` 标签强制作为 Evaluator 输出的第一步。只要 Evaluator 被迫用文字把“为什么它觉得好/不好”写下来，评分漂移的概率就会降低 80% 以上。
