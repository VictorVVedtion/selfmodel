# Sprint <N>: <Title>

## Status
DRAFT → ACTIVE → DELIVERED → REVIEWED → MERGED | REJECTED

## Agent
<gemini | codex | opus>

## Objective
<One sentence: what this Sprint delivers>

## Acceptance Criteria
- [ ] <Specific, testable criterion 1>
- [ ] <Specific, testable criterion 2>
- [ ] <Specific, testable criterion 3>

## Context
<Background info the agent needs. Reference files, APIs, design decisions.>

## Code Tour (complex/standard sprints — simple 跳过)
Agent 实现前必须读的关键代码片段：

### <file-path> (lines N-M): <展示什么>
```<lang>
<Leader 提取的实际代码片段，5-20 行>
```
为什么重要: <一句话解释模式>

### <file-path-2> (lines N-M): <展示什么>
```<lang>
<Leader 提取的实际代码片段>
```
为什么重要: <一句话>

## Architecture Context (complex/standard sprints — simple 跳过)
- **所在层次**: <一句话：哪个 layer/module/subsystem>
- **数据流**: <input → this module → output>
- **邻接模块**: <与本模块有 import/export 关系的模块>
- **命名约定**: <如 "函数 camelCase, 文件 kebab-case, 类型 PascalCase">
- **错误处理模式**: <如 "所有 I/O 用 try/catch, 错误用 structured logger">

## Pattern Examples (complex sprints only — simple/standard 跳过)
本代码库中正确实现风格的 2-3 个例子：

### Pattern: <name>
```<lang>
<项目中的真实代码，5-15 行>
```
使用此模式的文件: <列表>

## Complexity
simple | standard | complex

- **simple**: 单文件修复、配置变更。无理解阶段。
- **standard**: 多文件实现，模式清晰。理解阶段可选。Code Tour 和 Architecture Context 必填。
- **complex**: 跨模块集成，需发现模式。理解阶段**强制**。所有 section 必填。

## Constraints
- Timeout: <60 | 120 | 180>s
- Files: see ## Files section above (enforced by dispatch-gate hook)

## Understanding Checkpoint (complex sprints only — simple/standard 跳过)
实现前，Agent 必须在 worktree 根目录产出 `understanding.md`：
1. **Files Read**: 列出读过的每个文件（路径+行范围+学到什么）
2. **Patterns Found**: 必须遵循的现有代码模式
3. **Integration Plan**: 新代码如何连接现有模块（imports, exports, type flow）
4. **Failure Modes**: 可能出错的场景、边界条件、已有测试覆盖

Leader 验证 understanding.md 后才允许进入 Phase B（实现）。
Agent 在 Leader 批准前**不得**写实现代码。

## Files (必填 — 结构化文件列表，用于调度门禁自动重叠检测)
### Creates
- <新建文件路径>

### Modifies
- <修改文件路径>

### Out of Scope
- .selfmodel/

## Deliverables
- [ ] <File or feature 1>
- [ ] <File or feature 2>

## Chaos Gate (optional — for Sprints with user-facing surfaces)
- Surfaces: web | cli | api | lib | auto
- Intensity: gentle | standard | berserk
- Budget: 5m
- Threshold: resilience >= 70
(Leader dispatches `/rampage --selfmodel` after E2E PASS, see quality-gates.md Step 4.7)

## Wiki Impact (optional — which wiki pages this Sprint affects)
- <wiki page path, e.g. wiki/modules/auth.md>
(Agent updates these pages as part of delivery. Leader validates in post-merge.)

## Smoke Test (可选 — 有可运行交付物的 Sprint)
merge 后端到端验证特性是否工作的命令：

```bash
# <测试什么>
<具体命令>
# Expected: <成功表现>
```

指南:
- Web/CLI Sprint: 跑基本工作流
- Library Sprint: import 并调用
- API Sprint: curl 端点验证响应
- Internal/config Sprint: 跳过（不需要此 section）

Leader 在 post-merge Step 7.5 中执行。失败处理同 build/test 失败（revert + REVISE）。
