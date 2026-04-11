# Sprint R3 (RETROACTIVE AUDIT): settings.json SessionStart hook format fix

## Status
RETROACTIVE_AUDIT — commit already merged to main without Sprint lifecycle
Original commit: `dd07f19d166fac58bedb50a71e31529c462ca93c` (2026-04-08)

## Agent
opus (Leader — Rule 7 violation)

## Objective
修复 SessionStart hook 条目格式错误：扁平 `{type, command}` 在 session start 时校验失败。改为和 PreToolUse 一致的 `{matcher, hooks[]}` 包装结构。同时修 live `.claude/settings.json` 和 selfmodel.sh 的模板生成器 `generate_hooks()`。

## Acceptance Criteria
- [x] `.claude/settings.json` 中 SessionStart 条目用 `{matcher, hooks[]}` 包装
- [x] `scripts/selfmodel.sh` 中 `generate_hooks()` 生成同样的正确格式
- [x] 下次 `selfmodel update` 不再重新写错格式
- [x] Claude Code session start 时不再报 validation error

## Context
SessionStart hook 和 PreToolUse 共享同一 schema（matcher + hooks[]），但 generate_hooks 对两者处理不一致，导致 SessionStart 被生成为旧的扁平格式。Claude Code 的 hook runtime 校验 schema 时失败。

## Complexity
simple（单文件配置修复）

## Files

### Modifies
- scripts/selfmodel.sh
- (implied: .claude/settings.json — 本仓库配置文件，不在 git 追踪里可能)

## Deliverables
- [x] SessionStart hook 注入正确格式
- [x] 模板 + live 同步

## Audit Notes (Retroactive)
- Scale: +7 -2 lines
- Bug fix for schema mismatch
- 应该有个 hook 格式校验的 unit test，但没有
- Fix 同时应用到 live + template，基本做对了两边

## Scoring Rubric
按 quality-gates.md 6 维度评分。Evaluator 读 `git show dd07f19` 获取 diff。
