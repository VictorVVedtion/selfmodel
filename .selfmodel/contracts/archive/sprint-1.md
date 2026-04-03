# Sprint 1: Fix selfmodel.sh Argument Handling

## Status
DRAFT

## Agent
opus

## Objective
Fix all 6 argument validation issues in selfmodel.sh found by /rampage chaos testing.

## Acceptance Criteria
- [ ] `selfmodel init --help` prints init-specific help text (not "Initializing in --help")
- [ ] `selfmodel adapt --help` prints adapt-specific help text (no mkdir crash)
- [ ] `selfmodel update --help` prints update-specific help text
- [ ] `selfmodel status --help` prints status-specific help text
- [ ] `selfmodel init /nonexistent/path` exits 1 with error "directory does not exist"
- [ ] `selfmodel init /tmp/somefile` (where path is a file) exits 1 with error "path is not a directory"
- [ ] `selfmodel adapt /nonexistent/path` exits 1 with error "directory does not exist"
- [ ] `selfmodel update --version v1.0` (without --remote) prints warning about --version requiring --remote
- [ ] Error message for unknown command says "Run 'selfmodel --help'" instead of "Run 'selfmodel help'"
- [ ] All existing functionality unchanged (init, adapt, update, status, version still work)

## Context
The rampage report found these issues:
- RAMPAGE-001: --help flag on subcommands treated as directory argument
- RAMPAGE-002: adapt silently proceeds on non-existent directory
- RAMPAGE-003: init accepts file path as directory argument
- RAMPAGE-005: adapt --help crashes mkdir but exits 0
- RAMPAGE-006: update --version silently ignored without --remote
- RAMPAGE-007: Error message references non-existent 'help' subcommand

File to modify: `scripts/selfmodel.sh` (1516 lines)

Key areas:
- `cmd_init()` at line 323: Add --help check at top + path validation before line 328
- `cmd_adapt()` at line 392: Add --help check at top + path validation before line 402
- `cmd_update()` at line 466: Add --help check at top + --version warning at line 491
- `cmd_status()` at line 671: Add --help check at top
- `cmd_version()` at line 666: Add --help check at top
- `main()` case at line 1508-1510: Fix "Run 'selfmodel help'" to "Run 'selfmodel --help'"

## Constraints
- Timeout: 180s
- Files in scope: scripts/selfmodel.sh ONLY
- Files out of scope: everything else
- Preserve all existing behavior — only ADD validation/help, don't refactor
- Each subcommand --help should be a simple 3-5 line help text showing usage and available flags
- Path validation: use `[[ -e "$dir" ]]` and `[[ -d "$dir" ]]` checks
- Keep the existing coding style (info/err/warn helpers, same color scheme)

## Deliverables
- [ ] Modified scripts/selfmodel.sh with all 6 fixes

## E2E Depth
- Depth: standard
