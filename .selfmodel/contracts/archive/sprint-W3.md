# Sprint W3: Wiki Documentation Integration

## Status
ACTIVE

## Agent
codex

## Objective
Update all documentation files to reflect the integrated wiki feature: CLAUDE.md, README.md, skill/SKILL.md, context-protocol.md.

## Acceptance Criteria
- [ ] CLAUDE.md Session Start Protocol has step 4.5: `Scan .selfmodel/wiki/index.md (wiki catalog for context)`
- [ ] CLAUDE.md On-Demand Loading table includes `wiki-protocol.md` row
- [ ] CLAUDE.md Directory Structure includes wiki/ subdirectory tree
- [ ] README.md has "Project Wiki" section describing the integrated wiki behavior
- [ ] skill/SKILL.md Directory Structure includes wiki/ directory
- [ ] context-protocol.md Externalization Rules table includes wiki targets (architecture decisions → wiki/decisions/, module knowledge → wiki/modules/, discovered patterns → wiki/patterns/)
- [ ] All changes are documentation only
- [ ] No TODO, no placeholder text

## Context
Sprint W1 (MERGED) added wiki scaffolding in init/adapt + wiki-protocol.md.
Sprint W2 (ACTIVE, parallel) adds session hook, status display, orchestration integration.

This sprint updates documentation to reference the wiki capability.

Reference files:
- `/Users/vvedition/Desktop/selfmodel/CLAUDE.md` — Session Start L262-290, On-Demand Loading ~L248, Directory Structure ~L336
- `/Users/vvedition/Desktop/selfmodel/README.md` — add section near existing features
- `/Users/vvedition/Desktop/selfmodel/skill/SKILL.md` — directory structure section
- `/Users/vvedition/Desktop/selfmodel/.selfmodel/playbook/context-protocol.md` — externalization table
- `/Users/vvedition/Desktop/selfmodel/.selfmodel/playbook/wiki-protocol.md` — source of truth for wiki description

### Specific Changes

**CLAUDE.md Session Start Protocol** (around L262-290):
Add between step 4 and step 5:
```
4.5. Scan .selfmodel/wiki/index.md (wiki catalog — auto-injected by session-start hook)
```

**CLAUDE.md On-Demand Loading** (around L248):
Add row:
```
| Wiki protocol + page format | `.selfmodel/playbook/wiki-protocol.md` |
```

**CLAUDE.md Directory Structure** (around L336):
Add under .selfmodel/:
```
    ├── wiki/                              # Project knowledge base (auto-managed)
    │   ├── index.md                       # Content catalog
    │   ├── log.md                         # Update log (append-only)
    │   ├── schema.md                      # Page conventions
    │   ├── architecture.md                # System overview
    │   ├── modules/                       # Per-module pages
    │   ├── decisions/                     # Architecture Decision Records
    │   ├── patterns/                      # Code patterns
    │   └── entities/                      # Key concepts
```

**README.md**: Add "Project Wiki" subsection:
```markdown
### Project Wiki

selfmodel auto-generates and maintains a project knowledge base at `.selfmodel/wiki/`. No separate command — wiki is woven into existing flows:

- **`selfmodel init`** scaffolds wiki with detected module pages and architecture overview
- **Session start hook** injects wiki index into Leader context automatically
- **Sprint contracts** can declare `## Wiki Impact` for pages the agent should update
- **Post-merge** (Step 7.6) detects stale wiki pages from code diffs
- **`selfmodel status`** reports wiki health score (page count, staleness, completeness)
```

**context-protocol.md Externalization Rules**: Add rows to the existing table:
```
| Architecture decisions | `wiki/decisions/` (ADR) + `playbook/lessons-learned.md` |
| Module knowledge | `wiki/modules/<module>.md` |
| Discovered patterns | `wiki/patterns/<pattern>.md` |
```

## Constraints
- Timeout: 120s
- Documentation only

## Files
### Creates
(none)

### Modifies
- `CLAUDE.md`
- `README.md`
- `skill/SKILL.md`
- `.selfmodel/playbook/context-protocol.md`

### Out of Scope
- scripts/selfmodel.sh (Sprint W1/W2)
- scripts/hooks/session-start.sh (Sprint W2)
- orchestration-loop.md (Sprint W2)

## Deliverables
- [ ] `CLAUDE.md` with 3 update points
- [ ] `README.md` with Project Wiki section
- [ ] `skill/SKILL.md` with wiki directory
- [ ] `.selfmodel/playbook/context-protocol.md` with wiki externalization targets
