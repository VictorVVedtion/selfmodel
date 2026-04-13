# Sprint W1: Wiki Foundation

## Status
ACTIVE

## Agent
opus

## Objective
Integrate project wiki scaffolding into selfmodel init/adapt, implement generate_wiki() with module auto-detection, and create wiki-protocol.md.

## Acceptance Criteria
- [ ] `create_structure()` creates `.selfmodel/wiki/{modules,decisions,patterns,entities}` with .gitkeep files
- [ ] `generate_wiki()` creates schema.md with page format conventions (# Title, ## Overview, ## Details, ## See Also, ## Last Updated)
- [ ] `generate_wiki()` scans project for code-bearing directories (src/, lib/, app/, pages/, components/, cmd/, pkg/, internal/, etc.), max 20
- [ ] `generate_wiki()` creates skeleton wiki/modules/<name>.md for each detected module with ## Overview, ## Key Files, ## Last Updated
- [ ] `generate_wiki()` creates architecture.md seeded from detect_stack results (type, stacks, frameworks, directory tree)
- [ ] `generate_wiki()` creates index.md listing all generated pages (one line each)
- [ ] `generate_wiki()` creates log.md with initial entry `[timestamp] INIT: wiki created, N module pages`
- [ ] `cmd_init()` calls `generate_wiki "$dir"` after `generate_playbook` (around L392)
- [ ] `cmd_adapt()` handles wiki: if wiki/ missing → full generate; if exists → scan for new modules, add skeleton pages, update index.md, append to log.md
- [ ] `generate_playbook()` generates wiki-protocol.md (page format, update rules, lint rules, auto-sync spec)
- [ ] `skill/references/wiki-protocol.md` is identical copy of playbook version
- [ ] Excluded dirs: .git, node_modules, __pycache__, .venv, vendor, dist, build, .selfmodel, .claude
- [ ] All bash passes shellcheck (no new warnings)
- [ ] No TODO, no mock data, no placeholder text

## Context
This integrates Karpathy's LLM Wiki pattern into selfmodel. Wiki is NOT a new command — it's scaffolded during init and maintained during sprints. Zero new CLI subcommands.

Reference files (READ these first):
- `/Users/vvedition/Desktop/selfmodel/scripts/selfmodel.sh` — the CLI to modify
  - `create_structure()` at L180-198 — add wiki dirs here
  - `detect_stack()` at L53-142 — reuse detection results
  - `cmd_init()` at L323-411 — add generate_wiki call
  - `cmd_adapt()` at L414-507 — add wiki reconciliation
  - `generate_playbook()` at L850-922 — add wiki-protocol.md generation
- `/Users/vvedition/Desktop/selfmodel/.selfmodel/playbook/` — existing playbook files for format reference

### generate_wiki() Design

```bash
generate_wiki() {
    local dir="$1"
    local wiki_dir="$dir/.selfmodel/wiki"

    # 1. Create subdirs (already done by create_structure, but ensure)
    mkdir -p "$wiki_dir"/{modules,decisions,patterns,entities}

    # 2. schema.md — page format conventions
    cat > "$wiki_dir/schema.md" << 'SCHEMA_EOF'
    # Wiki Schema
    ... page format, cross-link syntax, update rules ...
    SCHEMA_EOF

    # 3. Scan for modules (top-level dirs with code files)
    local module_count=0
    local exclude_pattern='^(\.git|node_modules|__pycache__|\.venv|vendor|dist|build|\.selfmodel|\.claude|\.github|\.vscode|\.idea)$'
    for entry in "$dir"/*/; do
        [[ ! -d "$entry" ]] && continue
        local dirname=$(basename "$entry")
        [[ "$dirname" =~ $exclude_pattern ]] && continue
        # Check if dir contains code files
        local has_code=$(find "$entry" -maxdepth 2 -type f \( -name "*.py" -o -name "*.js" -o -name "*.ts" ... \) 2>/dev/null | head -1)
        [[ -z "$has_code" ]] && continue
        [[ $module_count -ge 20 ]] && break
        # Generate skeleton page
        generate_module_page "$wiki_dir" "$dir" "$dirname"
        module_count=$((module_count + 1))
    done

    # 4. architecture.md from detect_stack results
    # 5. index.md listing all pages
    # 6. log.md with INIT entry
}
```

### wiki-protocol.md Content

- **Page Format**: # Title, ## Overview, ## Details, ## See Also, ## Last Updated (sprint number)
- **Update Rules**: Agent updates pages listed in Sprint contract ## Wiki Impact. Leader validates during post-merge Step 7.6. Missing updates are logged, not blocked.
- **Lint Rules**: (1) page count vs module count, (2) stale pages (no update in last N sprints), (3) broken internal links, (4) empty pages (≤3 lines)
- **Auto-Sync Spec**: Post-merge, check git diff vs wiki/modules/. If code changed but wiki page not updated, append warning to log.md.

## Constraints
- Timeout: 300s
- Atomic commits per logical unit
- Follow existing selfmodel.sh patterns (err, info, ok helpers)

## Files
### Creates
- `.selfmodel/playbook/wiki-protocol.md`
- `skill/references/wiki-protocol.md`

### Modifies
- `scripts/selfmodel.sh` — create_structure, generate_wiki (new), cmd_init, cmd_adapt, generate_playbook

### Out of Scope
- session-start.sh hook (Sprint W2)
- cmd_status() wiki health (Sprint W2)
- orchestration-loop.md (Sprint W2)
- CLAUDE.md, README.md (Sprint W3)

## Deliverables
- [ ] `scripts/selfmodel.sh` with wiki scaffolding in init + adapt
- [ ] `.selfmodel/playbook/wiki-protocol.md` — complete protocol
- [ ] `skill/references/wiki-protocol.md` — identical copy
