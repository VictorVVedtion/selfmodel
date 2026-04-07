# Wiki Protocol

Project knowledge wiki maintenance protocol. Agents and Leader follow these rules to keep the wiki accurate and useful.

---

## Page Format

Every wiki page uses this structure:

```markdown
# Title

## Overview
Brief description: what this is, why it exists.

## Details
In-depth content, code references, architecture notes, diagrams.

## See Also
- [[related-page]]

## Last Updated
Sprint <N> (<date or "init">)
```

### Page Types

| Type | Location | Naming | Purpose |
|------|----------|--------|---------|
| Module | `wiki/modules/<dir-name>.md` | matches top-level directory name | per-module documentation |
| Decision | `wiki/decisions/<NNN>-<slug>.md` | numbered, append-only | architectural decision records |
| Pattern | `wiki/patterns/<pattern-name>.md` | descriptive slug | reusable design patterns |
| Entity | `wiki/entities/<entity-name>.md` | domain noun | domain model entities |

---

## Update Rules

### Sprint-Level Updates

1. **Contract declaration**: Sprint contracts SHOULD include a `## Wiki Impact` section listing wiki pages that need updating.
2. **Agent responsibility**: When a Sprint modifies code in a module, the agent SHOULD update the corresponding `wiki/modules/<name>.md` page with relevant changes.
3. **Leader validation**: During post-merge review (Step 7), Leader checks if code-changed modules have corresponding wiki page updates. Missing updates are logged to `wiki/log.md` as warnings, not treated as blockers.

### Update Workflow

```
1. Agent modifies code in src/auth/
2. Agent updates wiki/modules/src.md (or wiki/modules/auth.md if nested)
3. Agent updates "## Last Updated" to current Sprint number
4. Leader verifies wiki update in post-merge diff review
5. If missed: Leader appends warning to wiki/log.md
```

### Decision Records

- Create a new decision record when making significant architectural choices.
- Decision records are append-only — never modify past decisions.
- Format: `decisions/<NNN>-<descriptive-slug>.md` where NNN is zero-padded sequential.
- Include: context, options considered, chosen option, rationale, consequences.

---

## Lint Rules

These rules detect wiki staleness and inconsistency:

### 1. Page Count vs Module Count
Every code-bearing top-level directory should have a corresponding `wiki/modules/<name>.md` page. Run `selfmodel adapt` to auto-generate missing pages.

**Detection**: Compare `ls -d */` (excluding ignored dirs) against `ls wiki/modules/*.md`.

### 2. Stale Pages
Pages not updated in the last 10 Sprints are flagged as potentially stale.

**Detection**: Parse `## Last Updated` line, extract Sprint number, compare against current Sprint from `team.json`.

### 3. Broken Internal Links
Wiki links (`[[target]]`) must resolve to an existing `.md` file under `wiki/`.

**Detection**: Extract all `[[...]]` references, verify each resolves to a file at `wiki/<reference>.md`.

### 4. Empty Pages
Pages with 3 or fewer non-blank lines are flagged as stubs needing content.

**Detection**: `awk 'NF' <file> | wc -l` for each wiki page.

---

## Auto-Sync Spec

Post-merge automation to detect wiki-code drift:

### Trigger
After each Sprint merge to main.

### Detection Logic
```bash
# 1. Get changed code files from Sprint
changed_dirs=$(git diff --name-only HEAD~1..HEAD | \
  grep -v '^\.' | \
  cut -d/ -f1 | \
  sort -u)

# 2. For each changed dir, check if wiki page was also updated
for dir_name in $changed_dirs; do
    wiki_page="wiki/modules/${dir_name}.md"
    if [ -f ".selfmodel/$wiki_page" ]; then
        # Check if wiki page was in the diff
        if ! git diff --name-only HEAD~1..HEAD | grep -q ".selfmodel/$wiki_page"; then
            # Wiki page exists but was not updated
            echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] WARN: ${dir_name} code changed but wiki page not updated" >> .selfmodel/wiki/log.md
        fi
    fi
done
```

### Output
Warnings are appended to `wiki/log.md`. They are informational — they do not block merges or fail CI.

---

## Wiki Scaffolding

### During `selfmodel init`
1. `create_structure()` creates `wiki/{modules,decisions,patterns,entities}` with `.gitkeep` files.
2. `generate_wiki()` creates:
   - `schema.md` — page format conventions
   - `modules/<name>.md` — skeleton page for each detected code-bearing directory (max 20)
   - `architecture.md` — seeded from `detect_stack` results
   - `index.md` — listing all generated pages
   - `log.md` — with initial INIT entry

### During `selfmodel adapt`
1. If `wiki/` missing → full `generate_wiki()` run.
2. If `wiki/` exists → `reconcile_wiki()`:
   - Scan for new code-bearing directories not yet in `wiki/modules/`.
   - Generate skeleton pages for new modules.
   - Rebuild `index.md` from current state.
   - Append ADAPT entry to `log.md`.

### Excluded Directories
The following directories are never treated as modules:
`.git`, `node_modules`, `__pycache__`, `.venv`, `venv`, `vendor`, `dist`, `build`, `.selfmodel`, `.claude`, `.github`, `.vscode`, `.idea`, `.next`, `.nuxt`, `coverage`, `tmp`, `temp`, `.cache`, `.turbo`, `target`, `out`, `bin`, `obj`
