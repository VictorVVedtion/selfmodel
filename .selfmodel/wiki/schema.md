# Wiki Schema

Page format conventions for the project wiki.

---

## Page Structure

Every wiki page follows this skeleton:

```markdown
# Title

## Overview
Brief description: what this is, why it exists.

## Details
In-depth content, code references, diagrams.

## See Also
- [[related-page]]
- [[another-page]]

## Last Updated
Sprint <N> (<date or "init">)
```

## Cross-Link Syntax

Use double-bracket wiki links to reference other pages:
- `[[modules/auth]]` — link to a module page
- `[[decisions/001-database-choice]]` — link to a decision record
- `[[patterns/repository-pattern]]` — link to a pattern page
- `[[entities/user]]` — link to an entity page

## Naming Conventions

- **Module pages**: `modules/<directory-name>.md` — one page per code-bearing top-level directory
- **Decision records**: `decisions/<NNN>-<slug>.md` — numbered, append-only
- **Pattern pages**: `patterns/<pattern-name>.md` — reusable design patterns
- **Entity pages**: `entities/<entity-name>.md` — domain model entities

## Update Rules

1. When a Sprint modifies files in a module, the corresponding `modules/<name>.md` page should be updated.
2. Architectural decisions should be recorded in `decisions/` with rationale and alternatives considered.
3. Updates are logged in `log.md` with timestamp, Sprint reference, and summary.
4. The `index.md` must stay in sync with actual pages — run `selfmodel adapt` to reconcile.

## Lint Rules

1. **Page count vs module count**: every code-bearing directory should have a wiki page.
2. **Stale pages**: pages not updated in the last 10 Sprints are flagged.
3. **Broken internal links**: `[[target]]` must resolve to an existing `.md` file.
4. **Empty pages**: pages with 3 or fewer non-blank lines are flagged as stubs.

## Auto-Sync Spec

Post-merge, compare `git diff --name-only` against `wiki/modules/`. If code in a module directory changed but its wiki page was not updated, append a warning entry to `log.md`:
```
[<timestamp>] WARN: <module> code changed in Sprint <N> but wiki page not updated
```
