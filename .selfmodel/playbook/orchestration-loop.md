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

### Sprint 2: <Title>
- Agent: opus
- Dependencies: Sprint 1
- Status: PENDING
- Priority: P0
- Timeout: 180

## Phase 1: <Phase Name>

### Gate
<condition: e.g., "all Phase 0 sprints MERGED + npm test passes">

### Sprint 3: <Title>
- Agent: codex
- Dependencies: Sprint 1, Sprint 2
- Status: PENDING
- Priority: P0
- Timeout: 120
```

### Format Rules

- Dependencies: comma-separated Sprint numbers. Leader checks all have Status == MERGED.
- Phase is logical grouping. Sprints CAN have cross-phase dependencies.
- Status updated by Leader only (single writer, no concurrency).
- Gate: evaluated by Leader when all sprints in previous phase are MERGED.

---

## Orchestration Loop

```
LOOP:
  1. READ state/plan.md
     - Parse current phase, all sprint statuses
     - Identify: executable (PENDING + all deps MERGED), blocked, active

  2. FIND executable sprints
     - Filter: Status == PENDING AND all Dependencies have Status == MERGED
     - Sort: Priority (P0 first) → Sprint number (lower first)

  3. EXIT conditions
     - All sprints MERGED → project complete, write final report
     - No executable AND some not MERGED → BLOCKED, report to user

  4. PARALLEL DISPATCH (sprints with no mutual dependencies)
     For each executable sprint:
     a. Read sprint-template.md, write contract → contracts/active/sprint-<N>.md
     b. Write task → inbox/<agent>/sprint-<N>.md
     c. Create worktree (or use Agent tool isolation)
     d. Update plan.md: Status → ACTIVE
     e. Dispatch agent per dispatch-rules.md

  5. WAIT for all dispatched agents

  6. EVALUATE + E2E VERIFY each delivered sprint
     a. Quick Scan: 10 auto-reject triggers on git diff
        - If any trigger → Grade F, skip Evaluator AND E2E (save cost)
     b. Parallel dispatch:
        b1. Prepare eval input → inbox/evaluator/sprint-<N>-eval.md
            Dispatch Independent Evaluator (per evaluator-prompt.md)
        b2. IF e2e_needed(sprint):  (see e2e-protocol.md trigger conditions)
            Write verification file → inbox/e2e/sprint-<N>.md
            Dispatch E2E Agent (per e2e-protocol.md)
     c. Wait for Evaluator + E2E Agent (if dispatched) to complete
     d. Parse Evaluator JSON verdict
     e. Parse E2E JSON verdict (if dispatched)
     f. Merge verdicts (per e2e-protocol.md verdict merge rules):
        - Evaluator REJECT → final REJECT (E2E irrelevant)
        - E2E FAIL(build) → final REJECT (overrides Evaluator)
        - Evaluator ACCEPT + E2E FAIL → final REVISE
        - Evaluator ACCEPT + E2E PASS/undispatched → final ACCEPT
        - Evaluator REVISE → final REVISE (merge must_fix lists)

  7. ACT on each verdict
     - ACCEPT → merge, archive contract, cleanup worktree
                 plan.md Status → MERGED
     - REVISE → write must_fix feedback, agent continues
                 plan.md Status → ACTIVE (retry count +1)
     - REJECT → discard branch
                 plan.md Status → PENDING (redo)
                 If 3 consecutive REJECTs → Status → BLOCKED, notify user

  8. CHECKPOINT
     - Write next-session.md (current phase + completed sprints + pending)
     - Append to quality.jsonl
     - Append to orchestration.log

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

## Parallel Sprint Dispatch

Within a phase, sprints with no mutual dependencies dispatch in parallel:

```
# Example: Phase 1 has Sprint 3 (no deps), Sprint 4 (no deps), Sprint 5 (deps: 3,4)

Batch 1 (parallel): dispatch Sprint 3 + Sprint 4
Wait for both
Evaluate both (serial or parallel if using different evaluator channels)
Batch 2: dispatch Sprint 5 (now deps satisfied)
```

Parallel evaluation options:
- Serial: Opus evaluates Sprint 3, then Sprint 4 (safer, simpler)
- Parallel: Opus evaluates Sprint 3, Gemini evaluates Sprint 4 (faster, cross-model)

Default: serial evaluation. Switch to parallel when phase has 4+ parallel sprints.

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
