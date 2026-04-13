# Sprint CLI1: CLI Consolidation Core

## Status
ACTIVE

## Agent
opus

## Objective
Consolidate selfmodel CLI: smart dashboard as default, idempotent init (absorb adapt), interactive evolve default, two-tier help.

## Acceptance Criteria
- [ ] `selfmodel` (no args) shows smart dashboard: status summary + next action suggestion + 8-line command reference
- [ ] Dashboard suggests next action based on state (no .selfmodel → "selfmodel init", DELIVERED contracts → "/selfmodel:review", etc.)
- [ ] `selfmodel init` on project WITH existing .selfmodel/ runs adapt logic (non-destructive update) instead of exiting with error
- [ ] `selfmodel init` on project WITHOUT .selfmodel/ runs full init (current behavior unchanged)
- [ ] `selfmodel adapt` prints deprecation warning then delegates to cmd_init
- [ ] `selfmodel evolve` (no flags) runs interactive pipeline: detect → stage → offer submit (not just detect)
- [ ] `selfmodel evolve --detect` still works (backward compat)
- [ ] `selfmodel --help` shows full detailed reference (current help content + slash commands section)
- [ ] `selfmodel -v` / `selfmodel --version` shows version
- [ ] `version` removed from "Commands:" list in help (only --version flag)
- [ ] `selfmodel status` still works as explicit alias
- [ ] All bash passes shellcheck (no new warnings)
- [ ] No TODO, no mock, no placeholder

## Context
User feedback: "命令太碎片化了". Goal: fewer entry points, smarter defaults, progressive disclosure.

Reference files (READ these first):
- `/Users/vvedition/Desktop/selfmodel/scripts/selfmodel.sh` — the full CLI:
  - `main()` at L3818 — route table, default "help"
  - `cmd_init()` at L327 — current init with early exit at L354-357
  - `cmd_adapt()` at L421 — adapt logic to extract
  - `cmd_status()` at L776 — reuse in dashboard
  - `cmd_evolve()` at L3756 — current default is "detect"
  - Help text at L3831-3860

### Design Specifications

**cmd_dashboard()**: New function that:
1. Runs the existing cmd_status display
2. Adds a "→ Next:" suggestion line based on:
   - No .selfmodel/ → "Run: selfmodel init"
   - DELIVERED contracts in active/ → "Run: /selfmodel:review"  
   - No plan.md → "Run: /selfmodel:plan"
   - All quiet → "All clear. Run /selfmodel:sprint for next task"
   - Evolution overdue → "Evolution review overdue. Run: selfmodel evolve"
3. Appends 8-line command reference (Terminal + Claude Code columns)

**cmd_init() idempotent**: At L354-357, replace:
```bash
# OLD:
if [[ -d "$dir/.selfmodel" ]]; then
    warn ".selfmodel/ already exists. Use 'selfmodel adapt' instead."
    exit 1
fi
# NEW:
if [[ -d "$dir/.selfmodel" ]]; then
    info ".selfmodel/ exists. Running non-destructive update..."
    # [adapt logic here]
    return 0
fi
```

Extract adapt body into helper, call from both places.

**cmd_adapt() deprecation**:
```bash
cmd_adapt() {
    warn "'selfmodel adapt' is deprecated. Use 'selfmodel init' (now idempotent)."
    cmd_init "$@"
}
```

**cmd_evolve() interactive default**:
Add `evolve_interactive()` that chains: detect → stage → offer submit.
Change default action from "detect" to "interactive".
Keep all --flags working for backward compat.

**main() routing**:
```bash
local cmd="${1:-dashboard}"
case "$cmd" in
    dashboard|"") check_deps; cmd_dashboard "$@" ;;
    init|setup)   check_deps; cmd_init "$@" ;;
    adapt)        check_deps; cmd_adapt "$@" ;;
    update|sync)  check_deps; cmd_update "$@" ;;
    status)       check_deps; cmd_status "$@" ;;
    evolve)       check_deps; cmd_evolve "$@" ;;
    version|-v|--version) cmd_version "$@" ;;
    help|--help|-h) cmd_help_full ;;
    *) ...
```

**Help two-tier**:
- cmd_help_short(): 8 lines (used by dashboard)
- cmd_help_full(): current detailed help + slash commands section (used by --help)

## Constraints
- Timeout: 300s
- Backward compatibility: adapt, version, status all still work
- Atomic commits per logical unit

## Files
### Creates
(none)

### Modifies
- `scripts/selfmodel.sh` — main(), cmd_dashboard (new), cmd_init, cmd_adapt, cmd_evolve, help text

### Out of Scope
- README.md (Sprint CLI2)
- install.sh (Sprint CLI2)
- commands/*.md (Sprint CLI2)
- skill/SKILL.md (Sprint CLI2)

## Deliverables
- [ ] `scripts/selfmodel.sh` with all 6 changes (dashboard, idempotent init, adapt alias, evolve interactive, help tiers, main routing)
