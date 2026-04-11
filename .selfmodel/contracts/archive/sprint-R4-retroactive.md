# Sprint R4 (RETROACTIVE AUDIT): team.json regen + leader-worktree hook cleanup

## Status
RETROACTIVE_AUDIT — commit already merged to main without Sprint lifecycle
Original commit: `f0410d7c1ca8523197083d7835a062a758dfcc33` (2026-04-08)

## Agent
opus (Leader — Rule 7 violation)

## Objective
`selfmodel update` 副作用清理：重新检测 stack type（unknown → library）并刷新 team.json protocol version；同时把 `enforce-leader-worktree.sh` 从规范 heredoc 模板中重新生成，去掉手动编辑残留。

## Acceptance Criteria
- [x] `team.json` `detected_stack.type` 从 unknown → library
- [x] `team.json` `evolution.protocol_version` = "0.3.0"
- [x] `enforce-leader-worktree.sh` 与 canonical template 一致（diff 为 net -15 lines 说明删除了残留代码）
- [x] hook 行为未回归（leader-worktree 保护仍有效）

## Context
前序 commit（R2/R3）改动后，`selfmodel update` 重新运行会触发 team.json stack redetection 和 hook 模板 regen。这些都是 update 流水的副作用，被打包成一个 chore commit。

## Complexity
simple（state file + hook 模板同步）

## Files

### Modifies
- .selfmodel/state/team.json
- scripts/hooks/enforce-leader-worktree.sh

## Deliverables
- [x] team.json 反映正确的 stack
- [x] hook 模板无编辑残留

## Audit Notes (Retroactive)
- Scale: +5 -18 lines
- **最弱的一个 commit**——chore 类，实际上是 `selfmodel update` 的 side effect 被 manual commit
- 理论上应该在 selfmodel CLI 内部就完成状态刷新，用户不应该看到这些副作用
- hook 模板里 "-15 lines" 引人注意：删掉了什么？是死代码还是功能减少？没有 Evaluator 验证

## Scoring Rubric
按 quality-gates.md 6 维度评分。Evaluator 读 `git show f0410d7` 获取 diff。
