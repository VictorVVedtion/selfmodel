# Sprint 3: selfmodel CLI 集成 Hooks 自动生成

## Objective
init/adapt/update 自动生成 hooks 配置

## Assigned To
opus

## Deliverables
- [ ] `scripts/selfmodel.sh` 更新 — 新增 `generate_hooks()` 函数，init/adapt/update 时自动生成 3 个 hook 脚本 + 合并 settings.json

## Acceptance Criteria
1. `selfmodel init /tmp/test` 后 `scripts/hooks/` 目录包含 3 个可执行 hook 脚本
2. `selfmodel init /tmp/test` 后 `.claude/settings.json` 包含正确的 hooks 配置
3. 对已有 `.claude/settings.json`（含用户自定义配置）运行 `selfmodel adapt`，hooks 被注入但用户配置保留
4. 对已有 hooks 运行 `selfmodel update`，旧 hooks 备份为 `.bak.<timestamp>`，新 hooks 写入
5. 多次运行 init/adapt 结果幂等（settings.json 不重复注入同一 hook）
6. 无 jq 时 settings.json 用 echo 直接写入（降级方案）
7. 生成的 hook 脚本内容与 Sprint 2 产出一致（从 Heredoc 写出）

## Scoring Rubric
| Dimension | Weight | 10/10 |
|---|---|---|
| Functionality | 30% | 7 条验收标准全部通过 |
| Code Quality | 25% | 函数封装清晰，与现有 selfmodel.sh 风格一致 |
| Design Taste | 20% | 合并逻辑优雅，日志输出清晰 |
| Completeness | 15% | 边界：settings.json 语法错误、空文件、目录不存在 |
| Originality | 10% | 备份+覆盖策略简洁可靠 |

## Context Files
- /Users/vvedition/Desktop/selfmodel/scripts/selfmodel.sh — 需要修改的主文件
- /Users/vvedition/Desktop/selfmodel/scripts/hooks/session-start.sh — Sprint 2 产出，内容需内嵌
- /Users/vvedition/Desktop/selfmodel/scripts/hooks/enforce-leader-worktree.sh — 同上
- /Users/vvedition/Desktop/selfmodel/scripts/hooks/enforce-agent-rules.sh — 同上
- /Users/vvedition/Desktop/selfmodel/.claude/settings.json — 目标 hooks 配置格式
- /Users/vvedition/Desktop/selfmodel/.selfmodel/inbox/research/sprint-3-report.md — 调研报告

## Constraints
- Max execution time: 180s
- 非交互执行
- 禁止 TODO / mock / placeholder
- 必须与 selfmodel.sh 现有代码风格一致（同样的 helper 函数、颜色、日志格式）
- Heredoc 内嵌 hook 脚本内容（不从外部文件复制）
- settings.json 合并使用 jq 深度合并，无 jq 时降级为直接写入
- 备份文件用 `.bak.<timestamp>` 后缀

## Worktree
- Branch: sprint/3-opus
- Path: ../.zcf/selfmodel/sprint-3-opus/

## Lifecycle
DRAFT → ACTIVE → DELIVERED → REVIEWED → MERGED | REJECTED
当前状态: **MERGED**
