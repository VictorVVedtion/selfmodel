# Sprint Template

创建新 Sprint 合约时，复制本模板到 `.selfmodel/contracts/active/sprint-<N>.md` 并填写。

---

## 模板

```markdown
# Sprint <N>: <标题>

## Task Preamble（自动注入，不要修改）

你是 selfmodel 团队的 <agent role>。遵守以下铁律：
1. Never Fallback — 需要 500 行就写 500 行
2. Never Mock — 全部真实数据
3. Never Lazy — 无 TODO，每个 try 有完整 catch
4. 在 worktree 内工作，将绝对路径转换为 worktree 相对路径
5. 每个独立变更单独 commit，commit message 格式: `sprint-<N>: <what changed>`
6. 禁止操作: rm -rf / git push / 修改 .selfmodel/ / 安装全局依赖 / 调用生产 API

## Objective
<一句话描述本 Sprint 的目标，不超过 20 字>

## Assigned To
<gemini | codex | opus>

## Files（必填 — 结构化文件列表，用于调度门禁自动重叠检测）
### Creates
- <新建文件的具体路径，如 src/components/NewFeature.tsx>

### Modifies
- <修改文件的具体路径，如 src/tools.ts>

### Out of Scope
- .selfmodel/

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
- 非交互执行（两层静默防护）
- 禁止 TODO / mock / placeholder
- **原子提交**: 每完成一个可独立验证的变更即 commit（而非最终交付一个大补丁）
- **即时验证**: 每次 commit 后运行相关测试/类型检查，回归则 revert
- **禁止操作**: 见 Task Preamble 第 6 条及 CLAUDE.md Agent Safety Guardrails
- <本 Sprint 专属约束>

## E2E Depth（可选 — Leader 判断需要 E2E 时填写）
- Depth: quick | standard | deep | auto
- Notes: <可选，额外验证重点>
（v2 协议：Agent 自主分析 diff + 验收标准生成验证策略，Leader 无需手写场景）

## Chaos Gate（可选 — Sprint 有用户交互面时填写）
- Surfaces: web | cli | api | lib | auto
- Intensity: gentle | standard | berserk
- Budget: 5m
- Threshold: resilience >= 70
（Leader 在 E2E PASS 后可选派发 `/rampage --selfmodel`，详见 quality-gates.md Step 4.7）

## Wiki Impact（可选 — 本 Sprint 影响的 wiki 页面）
- <wiki 页面路径，如 wiki/modules/auth.md>
（Agent 在交付时更新这些页面。Leader 在 post-merge 时验证。）

## Cost (Leader 填写，Sprint 完成后)
- Tokens: <estimated total, e.g. 125k input + 38k output>
- Duration: <wall clock time, e.g. 4m 32s>
- Agent calls: <number of agent invocations, e.g. 2>
- Researcher calls: <number of research queries, e.g. 1>

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
2. **Files**: 必须是具体文件路径（精确到文件名）。Creates/Modifies 分开列出。禁止目录级模糊描述（`src/` 不可接受，`src/tools.ts` 可以）。此字段被 `enforce-dispatch-gate.sh` hook 自动解析，用于并行上限、收敛文件门禁、文件重叠检测三道硬门禁。
3. **Deliverables**: 必须是具体文件路径或可验证产物，禁止模糊描述
4. **Acceptance Criteria**: 每条必须可通过命令或代码验证，禁止主观描述
5. **Context Files**: 绝对路径，Agent 需读取的所有相关文件
6. **Constraints**: 时间约束参照 dispatch-rules.md 超时指南

## 合约生命周期

| 状态 | 触发 | 存储 |
|---|---|---|
| DRAFT | Leader 创建合约 | contracts/active/ |
| ACTIVE | Leader 调度 Agent | contracts/active/ |
| DELIVERED | Agent 完成工作 | contracts/active/ |
| REVIEWED | Leader 完成审查 | contracts/active/ |
| MERGED | 通过，合并 main | 移至 contracts/archive/ |
| REJECTED | 不通过，重做 | 保留 active/，版本号 +1 |
