# Sprint 2: Move install.sh Backup Outside Skills Directory

## Status
ACTIVE

## Agent
opus

## Objective
Fix install.sh backup location to prevent Claude Code skill namespace pollution.

## Acceptance Criteria
- [ ] install.sh creates backups in `~/.claude/.backups/selfmodel.{timestamp}` instead of `~/.claude/skills/selfmodel.bak.{timestamp}`
- [ ] Backup directory `~/.claude/.backups/` is created if it doesn't exist
- [ ] Existing backup behavior preserved (only creates backup when previous install exists)
- [ ] install.sh still works correctly for fresh install (no backup needed)
- [ ] install.sh still works correctly for upgrade install (backup created in new location)

## Context
RAMPAGE-004: When install.sh creates a backup of an existing selfmodel skill, it puts the backup at `~/.claude/skills/selfmodel.bak.{timestamp}`. Claude Code interprets any directory in `~/.claude/skills/` as a skill, causing the backup to appear as a ghost skill named `selfmodel.bak.{timestamp}` with its own sub-commands.

Fix: Move backup to `~/.claude/.backups/` (dotdir, Claude Code won't scan it).

File to modify: `install.sh` (only ~50 lines)
- Line with `mv "${SKILL_DIR}" "${SKILL_DIR}.bak.$(date +%s)"` → change destination
- Same pattern for `CMD_DIR` backup

## Constraints
- Timeout: 60s
- Files in scope: install.sh ONLY
- Keep it simple, minimal change

## Deliverables
- [ ] Modified install.sh with backup path fix
