# Orchestration Loop Protocol

Automated Leader loop for large projects (10+ Sprints). Drives from plan file,
minimizes Leader context consumption, forces reset between phases.

Small projects (<10 Sprints) can use manual mode. This protocol is optional enhancement.

---

## Plan File Format

Path: `.selfmodel/state/plan.md`

```markdown
# Project Plan: <Project Name>

## Plan Meta
- Total Phases: <N>
- Total Sprints: <N>
- Created: <timestamp>
- Last Updated: <timestamp>
- Current Phase: <N>

## Phase 0: <Phase Name>

### Gate
<condition to pass before entering Phase 1>

### Sprint 1: <Title>
- Agent: gemini | codex | opus | researcher
- Dependencies: none
- Status: PENDING | ACTIVE | DELIVERED | MERGED | REJECTED | BLOCKED
- Priority: P0 | P1 | P2
- Timeout: 60 | 120 | 180 | 300
- Files: src/components/Button.tsx, src/components/Button.test.tsx

### Sprint 2: <Title>
- Agent: opus
- Dependencies: Sprint 1
- Status: PENDING
- Priority: P0
- Timeout: 180
- Files: src/tools.ts, src/exchange/index.ts

## Phase 1: <Phase Name>

### Gate
<condition: e.g., "all Phase 0 sprints MERGED + npm test passes">

### Sprint 3: <Title>
- Agent: codex
- Dependencies: Sprint 1, Sprint 2
- Status: PENDING
- Priority: P0
- Timeout: 120
- Files: src/utils/helpers.ts

## Convergence Files (多 Sprint 共触的热文件，强制串行)
- src/tools.ts
- src/exchange/index.ts

## Dispatch Config
- Max Parallel Sprints: 3
```

### Format Rules

- Dependencies: comma-separated Sprint numbers. Leader checks all have Status == MERGED.
- Phase is logical grouping. Sprints CAN have cross-phase dependencies.
- Status updated by Leader only (single writer, no concurrency).
- Gate: evaluated by Leader when all sprints in previous phase are MERGED.
- Files: comma-separated file paths the Sprint will create or modify. MUST be populated before
  dispatch. Used by `enforce-dispatch-gate.sh` hook for structural overlap detection and
  convergence file gate. Freeform descriptions NOT acceptable — only concrete file paths.
- Convergence Files: files appearing in 2+ Sprint Files lists. Touching the same convergence
  file forces serialization — only one ACTIVE Sprint may modify it at a time. Leader identifies
  these when creating plan.md. Also stored in `.selfmodel/state/dispatch-config.json` for hook.
- Max Parallel Sprints: default 3. ACTIVE + DELIVERED count MUST NOT exceed this value.
  Enforced by `enforce-dispatch-gate.sh` hook — dispatch is blocked at tool level if exceeded.

---

## Orchestration Loop

```
LOOP:
  0. PRE-FLIGHT CHECK (every loop iteration)
     a. Verify Leader is on main: git branch --show-current == "main"
        - If NOT on main → STOP, switch to main, investigate why
     b. Check for orphan worktrees: git worktree list
        - If worktrees exist from previous sessions → merge or discard before continuing
     c. Check for DELIVERED but unmerged sprints in plan.md
        - If any → review and merge them first (no new dispatches until cleared)
     d. Verify no branch-to-branch merges in recent history:
        git log --merges --oneline -5 (scan for "into worktree-" patterns)

  1. READ state/plan.md
     - Parse current phase, all sprint statuses
     - Identify: executable (PENDING + all deps MERGED), blocked, active

  2. FIND executable sprints
     - Filter: Status == PENDING AND all Dependencies have Status == MERGED
     - Sort: Priority (P0 first) → Sprint number (lower first)

  3. EXIT conditions
     - All sprints MERGED → project complete, write final report
     - No executable AND some not MERGED → BLOCKED, report to user

  4. ROLLING BATCH DISPATCH (capped, overlap-gated)

     NOTE: Gates 1-3 are ENFORCED by enforce-dispatch-gate.sh hook.
     Even if Leader skips this step, hook blocks dispatch at tool level.

     Gate 1 — DISPATCH CAP:
     a. Read Max Parallel Sprints from dispatch-config.json (default: 3)
     b. current_inflight = count(contracts/active/*.md with ACTIVE or DELIVERED status)
     c. available_slots = cap - current_inflight
     d. available_slots <= 0 → merge existing sprints first, then dispatch

     Gate 2 — CONVERGENCE FILE GATE:
     a. Read convergence_files from dispatch-config.json
     b. For each candidate sprint, check its Files list against convergence files
     c. If candidate touches a convergence file AND any ACTIVE/DELIVERED sprint
        also touches that same convergence file → candidate WAITS
     d. Log: blocked_by=convergence_file in orchestration.log

     Gate 3 — FILE OVERLAP CHECK (structural, enforced by hook):
     a. For each pair of candidate sprints, compare Files lists
     b. Shared file → merge into one Sprint or serialize (lower N first)
     c. MANDATORY — hook will block dispatch if overlap detected

     BATCH ASSEMBLY:
     a. From eligible candidates (passed all gates), take up to available_slots
     b. Sort: Priority (P0 first) → Sprint number (lower first)
     c. Remaining eligible sprints wait for next loop iteration

     For each sprint in batch:
     a. Read sprint-template.md, write contract → contracts/active/sprint-<N>.md
        (contract MUST include structured ## Files section with Creates/Modifies)
     b. Update dispatch-config.json convergence_files if new hot files identified
     c. Write task → inbox/<agent>/sprint-<N>.md
     d. Create worktree (or use Agent tool isolation)
     e. Update plan.md: Status → ACTIVE
     f. Dispatch agent per dispatch-rules.md

  5. WAIT for all dispatched agents

  6. EVALUATE + E2E VERIFY each delivered sprint
     a. Quick Scan: 10 auto-reject triggers on git diff
        - If any trigger → Grade F, skip Evaluator AND E2E (save cost)
     b. Parallel dispatch:
        b1. Prepare eval input → inbox/evaluator/sprint-<N>-eval.md
            Dispatch Independent Evaluator (per evaluator-prompt.md)
        b2. IF e2e_needed(sprint):  (see e2e-protocol-v2.md trigger conditions)
            Write minimal dispatch file → inbox/e2e/sprint-<N>.md
            (only: worktree path + contract path + depth hint)
            Dispatch E2E Agent v2 (per e2e-protocol-v2.md)
            Agent auto: read contract → parse ACs into atomic verifications → probe env → execute atoms → report
     c. Wait for Evaluator + E2E Agent (if dispatched) to complete
     d. Parse Evaluator JSON verdict
     e. Parse E2E JSON verdict (if dispatched)
     f. Merge verdicts (per e2e-protocol-v2.md verdict merge rules):
        - Evaluator REJECT → final REJECT (E2E irrelevant)
        - E2E FAIL(build) → final REJECT (overrides Evaluator)
        - Evaluator ACCEPT + E2E FAIL → final REVISE
        - Evaluator ACCEPT + E2E PASS/undispatched → final ACCEPT
        - Evaluator ACCEPT + E2E PASS + Blocker regression → final REVISE
        - Evaluator REVISE + E2E PASS/undispatched → final REVISE
        - Evaluator REVISE + E2E FAIL → final REVISE (merge both must_fix + E2E blocking_failures, see quality-gates.md Step 4.5)
        - FLAKY atoms do not affect verdict (recorded in flaky_report)

  6.5. OPTIONAL: CHAOS VERIFICATION (Rampage)
       IF final verdict == ACCEPT
       AND sprint has user-facing surfaces (WEB/CLI/API/LIB deliverables):
         a. Dispatch: /rampage --selfmodel --budget 5m <target>
            (target auto-detected from sprint deliverables)
         b. Parse rampage artifact: .selfmodel/artifacts/rampage-sprint-<N>.json
         c. Merge with verdict (per quality-gates.md Step 4.7):
            - RAMPAGE PASS → no change
            - RAMPAGE PASS_WITH_CONCERNS → ACCEPT + record suggestions
            - RAMPAGE FAIL (critical) → upgrade ACCEPT to REVISE
       Note: This step is advisory. Leader decides whether to dispatch based on
       Sprint content and project maturity. Skip for internal tools, config changes,
       documentation-only sprints.

  7. ACT on each verdict (SERIAL MERGE — one at a time, in Sprint number order)
     - ACCEPT →
         a. Rebase sprint branch onto current main HEAD (in worktree):
            cd <worktree-path> && git rebase main
         b. If rebase conflict:
            - Re-dispatch Agent to resolve in worktree (Agent has task context)
            - If Agent unavailable: Leader resolves manually per file
            - NEVER use --theirs / --ours blindly
         c. After clean rebase: merge into main
            cd <main-repo> && git merge sprint/<N>-<agent> --no-ff -m "Sprint <N>: <title>"
         d. Archive contract, cleanup worktree
         e. plan.md Status → MERGED
     - REVISE → write must_fix feedback, agent continues
                 plan.md Status → ACTIVE (retry count +1)
     - REJECT → discard branch
                 plan.md Status → PENDING (redo)
                 If 3 consecutive REJECTs → Status → BLOCKED, notify user

  7.5. POST-MERGE SMOKE TEST (after each merge in Step 7)
       Run within 30 seconds:
       a. Build check (if applicable):
          npm run build 2>&1 | tail -5  OR  cargo build 2>&1 | tail -5
       b. Test check (if applicable):
          npm test -- --bail 2>&1 | tail -10  OR  cargo test 2>&1 | tail -10
       c. Diff sanity:
          git diff HEAD~1 --stat  (verify change scope matches Sprint deliverables)
       d. If build OR test fails:
          - git revert HEAD --no-edit  (revert the merge commit)
          - Sprint status → REVISE (not MERGED)
          - Write feedback: "Post-merge regression detected: <error>"
          - Agent must fix in worktree, re-rebase, re-merge

  8. CHECKPOINT
     - Write next-session.md (current phase + completed sprints + pending)
     - Append to quality.jsonl
     - Append to orchestration.log

  8.5. EVOLUTION CHECK (every 10 MERGED Sprints)
       a. Read team.json → evolution.last_review_sprint
       b. Count MERGED sprints since last review (from quality.jsonl or plan.md)
       c. If count >= 10:
          i.   Run evolution detection (equivalent to selfmodel evolve --detect)
          ii.  Log: phase=<N> event=evolution_detect candidates=<N>
          iii. If candidates > 0: notify user "N evolution candidates. Run /selfmodel:evolve"
          iv.  Update team.json: evolution.last_review_sprint = current_sprint
       d. If count < 10: skip

  9. CHECK context health
     - Phase boundary (all sprints in current phase MERGED) → Phase Gate → FORCE RESET
     - Context > 70% → FORCE RESET
     - Context anxiety signals → FORCE RESET

  10. GOTO LOOP
```

---

## Context Minimization Strategy

### What Leader keeps in working memory

- plan.md summary: phase names + current active Sprint numbers
- Current Sprint contract (full text)
- Current Evaluator verdict (current Sprint only)

### What Leader reads from filesystem on-demand

- Completed Sprint details → contracts/archive/
- Historical scores → quality.jsonl
- Agent output → git diff in worktree
- Calibration anchors → evaluator-prompt.md

### Why this works

Each loop iteration is self-contained:
1. Read plan.md (current state)
2. Execute one batch of sprints
3. Write results back to files
4. Checkpoint

No accumulated history needed. A fresh context can resume from files alone.

---

## Phase Boundary Reset

When all sprints in a phase reach MERGED:

1. **Evaluate Phase Gate** — run the gate condition from plan.md
   - Gate passes → proceed to next phase
   - Gate fails → mark as BLOCKED, notify user

2. **Write checkpoint** to `next-session.md`:
   ```markdown
   # Phase <N> Complete — Checkpoint

   ## Completed Phase Summary
   - Phase <N>: <name>
   - Sprints: <list with scores>
   - Duration: <wall clock>
   - Key decisions: <any overrides or surprises>

   ## Next Phase Preview
   - Phase <N+1>: <name>
   - Sprint count: <N>
   - First executable sprints: <list>

   ## Accumulated Lessons
   - <from lessons-learned.md, relevant to next phase>

   ## Critical Context (must survive reset)
   - <architectural decisions affecting next phase>
   - <user preferences or constraints>
   ```

3. **Update plan.md**: `Current Phase: <N+1>`, `Last Updated: <timestamp>`

4. **Force context reset** (`/clear`)

5. **New context startup reads**:
   - CLAUDE.md → next-session.md → plan.md → orchestration-loop.md (this file)
   - Resume from step 1 of the loop

---

## Rolling Batch Dispatch

Within a phase, sprints dispatch in rolling batches — capped and overlap-gated:

```
# Cap=3. Sprint 4 和 6 都修改 src/tools.ts (convergence file).

Batch 1: dispatch Sprint 3, 4, 7 (3 slots, no overlap)
  → Sprint 6 BLOCKED: shares convergence file src/tools.ts with Sprint 4 (ACTIVE)
  → Sprint 8 BLOCKED: cap full (3 active)
Wait → Sprint 3 DELIVERED → merge → 1 slot opens
Batch 2: dispatch Sprint 5 (deps on Sprint 3, now MERGED)
  → Sprint 6 still BLOCKED: Sprint 4 still ACTIVE, convergence file held
Wait → Sprint 4 MERGED → convergence file released
Batch 3: dispatch Sprint 6 (gate clear, slot available)
Wait → all merge
Batch 4: dispatch Sprint 8
```

Key principles:
- **Cap enforced by hook**: ACTIVE + DELIVERED ≤ Max Parallel Sprints (hook blocks dispatch)
- **Convergence files serialize**: touching same hot file gates dispatch (hook blocks)
- **File overlap blocks**: shared files between active sprints blocked (hook blocks)
- **Rolling**: as sprints merge, slots open → next batch dispatches immediately
- **No fan-out**: dispatch 3, merge 3, dispatch 3 (never dispatch 11, merge 11)

Evaluation: serial by default. Parallel when 3+ sprints in batch.

---

## Exception Handling

| Exception | Action |
|-----------|--------|
| Sprint 3x consecutive REJECT | Status → BLOCKED, notify user, skip to other executable sprints |
| Phase has sprint BLOCKED | Continue other sprints. If blocked sprint is a dependency, report |
| All executable sprints BLOCKED | Pause loop, output full status report, wait for user |
| Context > 85% mid-sprint | Emergency checkpoint, force reset, resume sprint next context |
| plan.md parse error | Stop loop, output parse error, wait for user fix |
| Agent timeout (all retries) | Status → PENDING, log failure, continue to next sprint |
| Evaluator timeout (all channels) | Leader self-fallback, mark in review, continue |

---

## Observability

### orchestration.log

One line per event, appended to `.selfmodel/state/orchestration.log`:

```
[<timestamp>] phase=<N> sprint=<N> event=<dispatch|evaluate|merge|reject|revise|checkpoint|reset|blocked> agent=<name> evaluator=<channel> score=<weighted> duration=<seconds>
```

### Status Summary

Leader can output current loop status at any time:

```
Orchestration Status
Phase: 2/5 | Sprints: 12/49 merged | 3 active | 1 blocked
Current batch: Sprint 14 (codex, ACTIVE), Sprint 15 (gemini, DELIVERED)
Next: Sprint 16, 17 (waiting on 14, 15)
Context: ~45% | Last checkpoint: 2 minutes ago
```

---

## Manual Mode Compatibility

This protocol is additive. Without a `state/plan.md` file, the system operates
in manual mode exactly as before (Leader manually decides which sprint to run next).

To switch from manual to orchestrated:
1. Create `state/plan.md` with all remaining sprints
2. Load this file (`playbook/orchestration-loop.md`)
3. Start the loop

To switch from orchestrated to manual:
1. Stop referencing the loop protocol
2. Continue using contracts/inbox/worktree manually
3. plan.md remains as read-only reference
