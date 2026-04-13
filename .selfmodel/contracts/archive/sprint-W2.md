# Sprint W2: Wiki Session + Status + Orchestration Integration

## Status
ACTIVE

## Agent
opus

## Objective
Integrate wiki into session-start hook, cmd_status() health display, sprint template Wiki Impact section, and orchestration-loop post-merge wiki sync.

## Acceptance Criteria
- [ ] session-start.sh hook injects wiki/index.md content (if exists) after next-session.md
- [ ] session-start.sh hook injects last 10 lines of wiki/log.md (if exists)
- [ ] selfmodel.sh heredoc that generates session-start.sh includes the same wiki injection
- [ ] `selfmodel status` shows Wiki Health line: `Wiki: N pages (M modules) | X stale | Y empty | health: Z/10`
- [ ] Wiki health score = `10 - empty_count - (stale > 2 ? 2 : 0)`, minimum 0
- [ ] Stale detection: pages without `## Last Updated` line
- [ ] Empty detection: pages with ≤ 3 lines (excluding schema.md and log.md)
- [ ] `selfmodel status` shows "Wiki: not initialized" if wiki/ doesn't exist
- [ ] `playbook_files` array in cmd_status() includes `wiki-protocol.md`
- [ ] sprint-template.md (playbook version) has `## Wiki Impact` optional section after `## Chaos Gate`
- [ ] sprint-template.md (skill/references version) has matching `## Wiki Impact` section
- [ ] orchestration-loop.md has Step 7.6 POST-MERGE WIKI SYNC after Step 7.5
- [ ] Step 8.5 EVOLUTION CHECK includes wiki health audit sub-step
- [ ] All bash passes shellcheck (no new warnings)
- [ ] No TODO, no mock, no placeholder

## Context
Sprint W1 (MERGED) added generate_wiki(), wiki-protocol.md, and init/adapt integration. This sprint connects the wiki to the runtime: session hooks, status display, sprint lifecycle, and orchestration loop.

Reference files:
- `/Users/vvedition/Desktop/selfmodel/scripts/selfmodel.sh` — cmd_status() at L760-847, session-start heredoc (search for "session-start.sh" in generate_hooks)
- `/Users/vvedition/Desktop/selfmodel/scripts/hooks/session-start.sh` — live hook file
- `/Users/vvedition/Desktop/selfmodel/.selfmodel/playbook/orchestration-loop.md` — Steps 7.5, 8.5
- `/Users/vvedition/Desktop/selfmodel/.selfmodel/playbook/sprint-template.md` — contract template
- `/Users/vvedition/Desktop/selfmodel/skill/references/sprint-template.md` — skill copy

### session-start.sh wiki injection (add after next-session block)
```bash
echo ""
echo "── Wiki Index ──"
WIKI_INDEX="${PROJECT_ROOT}/.selfmodel/wiki/index.md"
if [[ -f "${WIKI_INDEX}" ]]; then
    cat "${WIKI_INDEX}"
else
    echo "(wiki not initialized)"
fi

echo ""
echo "── Wiki Recent ──"
WIKI_LOG="${PROJECT_ROOT}/.selfmodel/wiki/log.md"
if [[ -f "${WIKI_LOG}" ]]; then
    tail -10 "${WIKI_LOG}"
fi
```

### cmd_status() wiki health (add after playbook consistency section, before final ═══)
```bash
echo "────────────────────────────────────────────────────"
local wiki_dir="$selfmodel_dir/wiki"
if [[ -d "$wiki_dir" ]]; then
    # Count pages, modules, stale, empty → compute health score
    echo "Wiki: $pages pages ($modules modules) | $stale stale | $empty empty | health: $score/10"
else
    warn "Wiki: not initialized (run 'selfmodel init' or 'selfmodel adapt')"
fi
```

### Sprint template addition
```markdown
## Wiki Impact (optional — which wiki pages this Sprint affects)
- <wiki page path, e.g. wiki/modules/auth.md>
(Agent updates these pages as part of delivery. Leader validates in post-merge.)
```

### orchestration-loop.md Step 7.6
```markdown
  7.6. POST-MERGE WIKI SYNC (after smoke test passes)
       a. Extract changed files: git diff HEAD~1 --name-only
       b. Map to wiki/modules/ pages
       c. Check Sprint contract ## Wiki Impact — listed pages not updated → log warning
       d. Update wiki/index.md if new pages created
       e. Informational only — does NOT block merge
       f. Append to wiki/log.md: [timestamp] SYNC sprint-<N>: <summary>
```

## Constraints
- Timeout: 300s
- session-start.sh changes must be in BOTH the live file AND the selfmodel.sh heredoc

## Files
### Creates
(none)

### Modifies
- `scripts/selfmodel.sh` — cmd_status() + session-start heredoc + playbook_files array
- `scripts/hooks/session-start.sh` — wiki injection
- `.selfmodel/playbook/orchestration-loop.md` — Step 7.6 + Step 8.5 wiki audit
- `.selfmodel/playbook/sprint-template.md` — ## Wiki Impact
- `skill/references/sprint-template.md` — ## Wiki Impact

### Out of Scope
- CLAUDE.md (Sprint W3)
- README.md (Sprint W3)

## Deliverables
- [ ] `scripts/selfmodel.sh` with wiki health in status + session-start heredoc updated
- [ ] `scripts/hooks/session-start.sh` with wiki injection
- [ ] `.selfmodel/playbook/orchestration-loop.md` with Step 7.6 + 8.5 wiki audit
- [ ] `.selfmodel/playbook/sprint-template.md` with Wiki Impact
- [ ] `skill/references/sprint-template.md` with Wiki Impact
