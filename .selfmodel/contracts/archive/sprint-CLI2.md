# Sprint CLI2: CLI Documentation Update

## Status
ACTIVE

## Agent
codex

## Objective
Update README, install.sh, slash command descriptions, and SKILL.md to reflect the consolidated CLI.

## Acceptance Criteria
- [ ] README Quick Start simplified to 3 steps: Install → Setup → Build
- [ ] README Commands section has two clear columns: "Terminal" and "Claude Code"
- [ ] README removes `selfmodel adapt` from primary commands (mention only as deprecated alias)
- [ ] README removes `selfmodel version` as standalone command (mention --version flag)
- [ ] install.sh post-install message reflects new command structure
- [ ] commands/init.md description updated to note "prefer CLI: selfmodel init"
- [ ] commands/status.md description updated to note "prefer CLI: selfmodel"
- [ ] skill/SKILL.md sub-commands table updated with primary/secondary markers
- [ ] No TODO, no placeholder

## Files
### Modifies
- `README.md`
- `install.sh`
- `commands/init.md`
- `commands/status.md`
- `skill/SKILL.md`

### Out of Scope
- scripts/selfmodel.sh (Sprint CLI1, merged)

## Deliverables
- [ ] All 5 files updated with consistent command references
