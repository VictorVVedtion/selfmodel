# Sprint R2 (RETROACTIVE AUDIT): selfmodel update preserves sprint-template.md

## Status
RETROACTIVE_AUDIT — commit already merged to main without Sprint lifecycle
Original commit: `2bfaba06a9c872dfc179245d5d04d6b0fe7c45ec` (2026-04-08)

## Agent
opus (Leader — Rule 7 violation)

## Objective
`generate_playbook()` 无条件覆盖 `sprint-template.md` 导致每次 update 都抹掉 v0.5.0 新增的 depth-gate 章节（Code Tour / Complexity / Understanding Checkpoint / Smoke Test）。改为 if-not-exists guard，与 dispatch-rules.md / quality-gates.md 保持一致的保护策略。

## Acceptance Criteria
- [x] `scripts/selfmodel.sh` 中 `generate_playbook()` 对 `sprint-template.md` 加 if-not-exists guard
- [x] remote update 仍能从 GitHub 同步（不破坏 `--remote` 流程）
- [x] 被覆盖破坏的 `sprint-template.md` 恢复到 v0.5.0 状态
- [x] 与 dispatch-rules.md / quality-gates.md 使用相同的保护模式

## Context
2bfaba0 之前 `generate_playbook()` 对所有 playbook 文件统一覆盖。dispatch-rules.md 和 quality-gates.md 已经加了 guard 但 sprint-template.md 漏了。导致用户每次 `selfmodel update` v0.5.0 depth-gate 字段就丢失。属于 generate_playbook 的协议不一致。

## Complexity
simple（单文件 3 行改动）

## Files

### Modifies
- scripts/selfmodel.sh

## Deliverables
- [x] sprint-template.md 在本地 update 时保留用户定制
- [x] 回归 bug：覆盖破坏已恢复

## Audit Notes (Retroactive)
- Scale: +3 -1 lines，严格来说可以作为 "inline fix"，但：
- Bug fix 性质明确（protocol regression），应该有 test case 防回归，没有
- 没经过 Evaluator → 无法确认 fix 正确且完整（是否还有其他文件有同样问题？）

## Scoring Rubric
按 quality-gates.md 6 维度评分。Evaluator 读 `git show 2bfaba0` 获取 diff。
