# Research Protocol

Researcher 角色的调度协议。Leader 在发起研究任务前必须查阅本文件。

---

## 角色定义

| 属性 | 值 |
|------|-----|
| Agent | Gemini CLI + `-G` (Google Search grounding) |
| 模型 | gemini-3.1-pro-preview |
| 超时 | 300s（标准）/ 600s（深度研究） |
| 产出 | 研究报告（Markdown），不产出代码 |
| 隔离 | 不需要 worktree（只读操作） |

---

## 研究类型与管道选择

### Type A: 快速查询（单通道）

适用：明确问题、单一答案、已知领域
管道：仅 Gemini -G
超时：120s

```bash
CI=true yes | timeout 120 gemini -G "问题" -s
```

### Type B: 技术调研（双通道）

适用：技术选型、库对比、最佳实践
管道：Gemini -G + context7（并行）
超时：300s

```bash
# 并行执行
CI=true yes | timeout 300 gemini -G \
  "@/Users/vvedition/Desktop/selfmodel/.selfmodel/inbox/research/sprint-<N>-query.md 深度调研" \
  -s 2>&1 | tee /Users/vvedition/Desktop/selfmodel/.selfmodel/inbox/research/sprint-<N>-report.md &
# 同时 Leader 用 context7 查库文档
```

### Type C: 深度研究（全管道）

适用：未知领域、需要多源验证、方案评估
管道：三层全开
超时：600s（总计，含 Leader 综合时间）

```
Layer 1 — 广度搜索（并行，总 300s）
├── Gemini -G          实时 Google Search 接地
├── NotebookLM         research_start 深度综合
└── context7           库/框架文档

Layer 2 — 深度挖掘（按需，额外 120s）
├── WebFetch           Layer 1 关键 URL 全文
└── Chrome MCP         需交互的页面

Layer 3 — 交叉验证（Leader，60s）
└── 消除矛盾 → 综合结论 → 输出报告
```

---

## 文件协议

### 查询文件（Leader → Researcher）

路径：`.selfmodel/inbox/research/sprint-<N>-query.md`

```markdown
# Research Query: Sprint <N>

## 研究类型
Type A / B / C

## 核心问题
<一句话问题>

## 上下文
<为什么需要这个研究，关联哪个实现任务>

## 期望产出
- [ ] 方案对比表
- [ ] 推荐方案 + 理由
- [ ] 关键代码示例
- [ ] 风险/限制说明

## 约束
<时间、技术栈、兼容性等硬约束>
```

### 报告文件（Researcher → Leader）

路径：`.selfmodel/inbox/research/sprint-<N>-report.md`

```markdown
# Research Report: Sprint <N>

## 核心结论
<3 句话以内的结论>

## 详细发现

### 方案 A: <名称>
- 优势: ...
- 劣势: ...
- 适用场景: ...

### 方案 B: <名称>
- 优势: ...
- 劣势: ...
- 适用场景: ...

## 推荐
<推荐方案 + 决策理由>

## 来源
- [1] <URL> — <关键信息>
- [2] <URL> — <关键信息>

## 置信度
High / Medium / Low（基于来源数量和一致性）

## 风险与限制
<已知的不确定性>
```

---

## CLI 调用模板

### 标准调用（文件缓冲）

```bash
# Leader 写查询
# → .selfmodel/inbox/research/sprint-<N>-query.md

# 执行研究（输出自动落盘）
CI=true yes | timeout 300 gemini -G \
  "@/Users/vvedition/Desktop/selfmodel/.selfmodel/inbox/research/sprint-<N>-query.md 基于上述问题进行深度调研，按照以下格式输出：核心结论、详细发现（含方案对比）、推荐、来源URL、置信度、风险" \
  -s 2>&1 | tee /Users/vvedition/Desktop/selfmodel/.selfmodel/inbox/research/sprint-<N>-report.md
```

### 快速调用（内联问题）

```bash
# 简单问题不需要文件缓冲
CI=true yes | timeout 120 gemini -G "具体问题" -s
```

### 并行多通道（Type C）

```bash
# Gemini -G（后台，输出落盘）
CI=true yes | timeout 300 gemini -G \
  "@/Users/vvedition/Desktop/selfmodel/.selfmodel/inbox/research/sprint-<N>-query.md 深度调研" \
  -s 2>&1 | tee /Users/vvedition/Desktop/selfmodel/.selfmodel/inbox/research/sprint-<N>-report.md &

# NotebookLM（Leader 通过 MCP 调用）
# → mcp__notebooklm-mcp__research_start

# context7（Leader 通过 MCP 调用）
# → mcp__plugin_context7_context7__query-docs

# 等待全部完成后 Leader 综合
```

---

## 评估标准

研究产出的评估不用代码质量门，使用研究质量门：

| 维度 | 权重 | 自动拒绝线 |
|------|------|-----------|
| 准确性 | 35% | 核心结论与来源矛盾 |
| 完整性 | 25% | 遗漏明显的替代方案 |
| 来源质量 | 20% | 无可验证的 URL |
| 可操作性 | 20% | 结论模糊无法指导决策 |

**判定**: ≥7.0 采纳 | 5.0-6.9 补充研究 | <5.0 换通道重做

---

## 研究前置规则

以下场景必须先研究再实现：

1. **未知技术栈** — 团队没用过的库/框架/服务
2. **多方案选择** — 存在 ≥2 个合理方案需要对比
3. **外部 API 集成** — 需要了解 API 文档、限制、定价
4. **性能关键路径** — 需要 benchmark 数据支撑决策
5. **安全相关** — 认证/授权/加密方案

Leader 可跳过研究的情况：
- 团队已有成熟经验的领域
- 前次研究报告仍然有效（< 7 天）
- 纯重构/修复（不涉及新技术决策）
