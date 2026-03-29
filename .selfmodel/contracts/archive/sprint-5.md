# Sprint 5: Long-Running Reliability — Evaluator Calibration + Context Reset

## Objective
补齐 Harness Design 长期运行的两个 P0 差距

## Assigned To
opus (两个子任务并行)

## Deliverables

### 5a: Evaluator 校准
- [ ] `playbook/quality-gates.md` 更新 — 添加 few-shot 校准样本（基于 Sprint 2/3 真实产出）
- [ ] 满分样本 (9.0/10)、及格样本 (7.0/10)、不及格样本 (<5.0) 各一个
- [ ] 评分漂移检测规则（写入 quality-gates.md）

### 5b: Context Reset 协议
- [ ] `playbook/context-protocol.md` 新建 — session 内 checkpoint + reset 策略
- [ ] 触发条件、交接文件格式、与 next-session.md 的关系
- [ ] CLAUDE.md Context Management 章节更新

### 5c: 成本追踪 (P1 顺带)
- [ ] `playbook/sprint-template.md` 更新 — 合约增加 Cost 字段
- [ ] 成本记录格式定义

## Acceptance Criteria
1. quality-gates.md 包含 3 个真实校准样本，每个样本有 5 维度分数和评语
2. 校准样本引用真实 Sprint（Sprint 2 或 3）的实际产出
3. context-protocol.md 定义了至少 3 个 checkpoint 触发条件
4. context-protocol.md 定义了交接文件格式（与 next-session.md 兼容）
5. sprint-template.md 包含 Cost 字段（tokens, duration, agent_calls）
6. CLAUDE.md Context Management 章节引用 context-protocol.md

## Context Files
- /Users/vvedition/Desktop/selfmodel/.selfmodel/playbook/quality-gates.md
- /Users/vvedition/Desktop/selfmodel/.selfmodel/playbook/sprint-template.md
- /Users/vvedition/Desktop/selfmodel/CLAUDE.md (Context Management 章节)
- /Users/vvedition/Desktop/selfmodel/.selfmodel/contracts/archive/sprint-2.md (校准样本来源)
- /Users/vvedition/Desktop/selfmodel/.selfmodel/contracts/archive/sprint-3.md (校准样本来源)
- /Users/vvedition/Desktop/selfmodel/.selfmodel/inbox/research/sprint-5a-report.md (调研报告)
- /Users/vvedition/Desktop/selfmodel/.selfmodel/inbox/research/sprint-5b-report.md (调研报告)

## Constraints
- Max execution time: 180s
- 校准样本必须基于真实 Sprint 产出，不 mock
- context-protocol.md 必须兼容 Claude Code 自动 compaction
- 不修改 CLAUDE.md 的 Iron Rules 和 Team 章节（只改 Context Management）

## Worktree
- Branch: sprint/5-opus
- Path: ../.zcf/selfmodel/sprint-5-opus/

## Lifecycle
当前状态: **MERGED**
