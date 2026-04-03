# Project Plan: Fix Rampage Findings

## Plan Meta
- Total Phases: 2
- Total Sprints: 2
- Created: 2026-04-03T12:55:00Z
- Last Updated: 2026-04-03T12:55:00Z
- Current Phase: 0
- Source: /rampage report 2026-04-03 (7 findings, 0 critical, 4 high, 2 medium, 1 low)

## Phase 0: CLI Argument Resilience

### Gate
selfmodel.sh 参数处理健壮化。所有子命令支持 --help，路径参数验证通过。

### Sprint 1: Fix all selfmodel.sh argument handling (RAMPAGE-001 through 007)
- Agent: opus
- Dependencies: none
- Status: MERGED
- Priority: P0
- Timeout: 180
- Rampage: RAMPAGE-001, RAMPAGE-002, RAMPAGE-003, RAMPAGE-005, RAMPAGE-006, RAMPAGE-007
- Notes: 合并原 Sprint 1/2/3（同一文件，避免 merge 冲突）。修改 scripts/selfmodel.sh：(1) 所有子命令支持 --help/-h，(2) init/adapt 验证路径存在且是目录，(3) update --version 无 --remote 时警告，(4) 修复错误消息引用不存在的 help 子命令。

## Phase 1: Install Safety

### Gate
Phase 0 所有 Sprint MERGED + selfmodel.sh 参数验证通过

### Sprint 2: Move install.sh backup outside skills directory
- Agent: opus
- Dependencies: Sprint 1
- Status: MERGED
- Priority: P1
- Timeout: 60
- Rampage: RAMPAGE-004
- Notes: install.sh 备份目录从 ~/.claude/skills/selfmodel.bak.{ts} 改为 ~/.claude/.backups/selfmodel.{ts}。防止 Claude Code 将备份目录识别为独立 skill。
