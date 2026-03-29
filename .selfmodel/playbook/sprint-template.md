# Sprint Template

创建新 Sprint 合约时，复制本模板到 `.selfmodel/contracts/active/sprint-<N>.md` 并填写。

---

## 模板

```markdown
# Sprint <N>: <标题>

## Objective
<一句话描述本 Sprint 的目标，不超过 20 字>

## Assigned To
<gemini | codex | opus>

## Deliverables
- [ ] <具体文件路径或产物>
- [ ] <第二个交付物>

## Acceptance Criteria（可测试的验收标准）
1. <可衡量条件，如：运行 npm run build 编译通过>
2. <第二条件，如：组件渲染时间 < 100ms>
3. <第三条件，如：所有导出函数包含 JSDoc>

## Scoring Rubric（本 Sprint 专属评分）
| Dimension | Weight | 本 Sprint 的 10/10 |
|---|---|---|
| Functionality | 30% | <专属定义> |
| Code Quality | 25% | <专属定义> |
| Design Taste | 20% | <专属定义> |
| Completeness | 15% | <专属定义> |
| Originality | 10% | <专属定义> |

## Context Files（Agent 需要提前读取）
- <绝对路径>
- <绝对路径>

## Constraints
- Max execution time: <60s | 120s | 180s>
- 非交互执行（三层静默防护）
- 禁止 TODO / mock / placeholder
- <本 Sprint 专属约束>

## Worktree
- Branch: sprint/<N>-<agent>
- Path: ../.zcf/selfmodel/sprint-<N>-<agent>/

## Lifecycle
DRAFT → ACTIVE → DELIVERED → REVIEWED → MERGED | REJECTED
当前状态: **DRAFT**
```

---

## 填写规则

1. **Objective**: 一句话，≤20 字
2. **Deliverables**: 必须是具体文件路径或可验证产物，禁止模糊描述
3. **Acceptance Criteria**: 每条必须可通过命令或代码验证，禁止主观描述
4. **Context Files**: 绝对路径，Agent 需读取的所有相关文件
5. **Constraints**: 时间约束参照 dispatch-rules.md 超时指南

## 合约生命周期

| 状态 | 触发 | 存储 |
|---|---|---|
| DRAFT | Leader 创建合约 | contracts/active/ |
| ACTIVE | Leader 调度 Agent | contracts/active/ |
| DELIVERED | Agent 完成工作 | contracts/active/ |
| REVIEWED | Leader 完成审查 | contracts/active/ |
| MERGED | 通过，合并 main | 移至 contracts/archive/ |
| REJECTED | 不通过，重做 | 保留 active/，版本号 +1 |
