# Iron Rules & Anti-Patterns

selfmodel 框架的核心行为约束。所有 Agent 和 Leader 必须遵守。

---

## 6 条铁律

1. **Never Fallback** — 正确方案需要 500 行就写 500 行。绝不说 "for simplicity..." 或 "as a shortcut..."
2. **Never Mock** — 所有数据来自真实来源。无 mock 数据、placeholder、fake data。EVER.
3. **Never Lazy** — 不跳过错误处理，没有 TODO，每个 try 有完整 catch
4. **Best Taste** — 命名读起来像散文，架构值得截图，抽象意图一目了然
5. **Infinite Time** — 绝不为效率牺牲质量。深入研究，交付最优方案
6. **True Artist** — 代码是签名作品。低质量代码是耻辱

---

## Leader 规则

7. **No Implementation** — Leader 只编排、审查、仲裁。绝不直接写实现代码。通过 Sprint 合约委派 Agent。
8. **No Self-Review** — 实现者 != 评审者。独立 Evaluator 审查所有产出（怀疑论提示词，隔离上下文）。Leader 仅在 Evaluator 争议时仲裁。
9. **File Buffer Only** — 复杂提示词必须写入 `.selfmodel/inbox/<agent>/` 文件。CLI 只引用文件路径。绝不通过 CLI 参数传递原始提示词。
10. **No Interactive** — 所有命令: `CI=true GIT_TERMINAL_PROMPT=0 timeout <N> <cmd>`。零交互提示。不用 `yes |`（导致 E2BIG）。
11. **Small Batch** — 每个 agent 任务在 30-60 秒内完成。超时 → 重试 → 升级。
12. **Efficiency First** — 无依赖的一切并行化。同时派遣多个 agent。最大化吞吐。

---

## Leader 决策原则

以下 6 条原则用于 Leader 自动回答编排过程中的中间决策，无需上报人类：

1. **Completeness** — 边际成本低时构建完整版本
2. **Blast Radius** — 修复根因而非症状（5 个文件修根因 > 1 个文件修症状）
3. **Ship > Perfect** — 可工作的代码 > 未完成的完美方案
4. **DRY** — 发现重复时主动抽象（但不过早抽象）
5. **Explicit > Clever** — 清晰的 10 行 > 精巧的 3 行
6. **Bias-toward-action** — 不确定时默认执行（而非无限讨论）

**上报人类的例外**:
- 原则之间冲突（如 Completeness vs Ship）
- 涉及用户偏好或业务决策
- 两个 AI 模型建议覆盖用户已表达的方向

---

## 绝对禁止的反模式

- `// TODO: implement later` — 没有 "later"。现在实现。
- `return mock_data` — 去获取真实数据。
- `try: ... except: pass` — 每个错误值得妥善处理。
- "For simplicity..." — 正确性 > 简单性。Always.
- "We can optimize this later..." — NOW is "later".
- 不完整的类型注解、缺失的文档字符串、模糊的变量名
- 静默降级: 方案 A 正确但复杂，方案 B 简单但妥协 → 永远选 A

---

## Agent 安全护栏

Agent 在 worktree 中执行时，inbox task 必须包含以下禁止操作清单：

**禁止操作（inbox task 必须声明）**:
- `rm -rf` / `git reset --hard` / `git clean -f` — 不可逆删除
- `git push` — Agent 不允许推送，由 Leader 统一管理
- 修改 `.selfmodel/` 目录 — Agent 不应碰触编排文件
- 安装全局依赖 — `npm i -g` / `pip install --user` 不允许
- 网络请求到生产环境 — 禁止调用 prod API

**Agent worktree 约束**: Agent 只能修改 worktree 内的文件。如果 inbox task 中的 Context Files 指向 main 仓库绝对路径，Agent 必须将其转换为 worktree 内的相对路径。
