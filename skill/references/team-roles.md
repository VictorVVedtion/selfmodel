# Team Roles & Decision Matrix

selfmodel 团队角色定义和任务路由。

---

## 团队组成

| 角色 | Agent | 模型 | 调用方式 |
|------|-------|------|---------|
| **Leader / 编排者** | Claude Opus 4.6 | 当前 session | 直接执行，只编排 + 仲裁 |
| **Evaluator** | Opus Agent / Gemini CLI | claude-opus-4-6 / gemini-3.1-pro-preview | Agent tool (只读) 或 `gemini -p "$(cat <eval-file>)" -y` |
| **Frontend Colleague** | Gemini CLI | gemini-3.1-pro-preview | `timeout 180 gemini "@<file>" -s --yolo` |
| **Backend Intern** | Codex CLI | GPT-5.4 xhigh fast | `CI=true timeout 180 codex exec "Read <file>" --full-auto` |
| **Senior Fullstack** | Opus Agent | claude-opus-4-6 | Agent tool, `isolation: "worktree"` |
| **Researcher** | Gemini CLI | gemini-3.1-pro-preview | `timeout 300 gemini -p "$(cat <file>)" -m gemini-3.1-pro-preview -y` |
| **E2E Verifier** | Opus Agent / Gemini CLI | claude-opus-4-6 / gemini-3.1-pro-preview | Agent tool (只读) 或 `gemini "@<file>" -s --yolo` |

---

## 核心约束

- **Harness mapping**: Leader = Planner + Orchestrator | Evaluator = Independent Quality Gate | Gemini/Codex/Opus = Generator | Researcher = Intelligence | E2E Verifier = Runtime Validator
- **Core constraint**: Generators 绝不自评。Leader 绝不实现。Leader 绝不评估（委派给 Evaluator）。Evaluator 只接收 diff + 合约 + 校准。
- **Researcher constraint**: 只读。不产出代码。不需要 worktree。产出研究报告供 Leader 决策。
- **E2E constraint**: 只读。绝不修改代码。解析验收标准为原子验证，逐条执行，报告证据。与 Evaluator 并行。

---

## 路由决策矩阵

| 信号关键词 | 路由到 | 原因 |
|-----------|-------|------|
| UI / UX / CSS / component / page / animation / layout | **Gemini** | 视觉设计强项 |
| 单文件 backend / utility / function / fix | **Codex** | 快速、聚焦、解耦 |
| 多文件 refactor / system integration / complex logic | **Opus Agent** | 深度推理 + 百万 token |
| Architecture / spec / review / arbitration | **Leader** | 编排权威 |
| Sprint 审查 / quality audit / code review | **Evaluator** | 独立上下文 |
| 调研 / research / 选型 / 对比 | **Researcher** | Google Search 接地 |
| E2E / 运行验证 / 集成测试 | **E2E Agent** | 运行时验证 |

**路由冲突优先级**: Leader > Evaluator > Researcher > Opus > Gemini > Codex

---

## 两层静默执行

所有 Agent 调用必须使用两层静默防护：

```bash
CI=true GIT_TERMINAL_PROMPT=0 timeout <N> <command>
```

**WARNING**: 不要使用 `yes |` 管道。会导致 `spawn E2BIG`。
Gemini `--yolo` 和 Codex `--full-auto` 已原生处理交互确认。

---

## 超时指南

| 任务类型 | Timeout |
|---------|---------|
| Evaluator 评审 | 120s |
| 单文件编辑 | 60s |
| 组件创建 | 120s |
| 多文件实现 | 180s |
| Researcher 调研 | 300s |
| E2E 验证 (完整) | 300s |
| E2E 验证 (仅 build) | 120s |
| npm install / build | 300s |
