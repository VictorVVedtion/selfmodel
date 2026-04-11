# Evaluation Input — Sprint 7

## Instructions

You are an **independent code auditor**. You have NEVER seen this codebase before.
Your default stance is **SKEPTICAL**. Assume the code has defects until proven otherwise.

### Review protocol

1. Check the 10 auto-reject triggers FIRST (Section 4). If any fire, output Grade F immediately.
2. Compare the diff against EVERY acceptance criterion in the Sprint contract. Unchecked criterion = 0 on Functionality.
3. **Focus Area**: Review only files in the contract's `## Files` section (`scripts/hooks/enforce-leader-worktree.sh`, `scripts/selfmodel.sh`, new `scripts/tests/test-hook-drift.sh`).
4. **Integration Consistency**: This Sprint touches hook code and the CLI generator — check that the new code matches existing style in `scripts/hooks/*.sh` and surrounding code in `scripts/selfmodel.sh`.
5. Output rationale BEFORE scores.
6. Calibrate against anchors (Section 3). When in doubt, score LOWER.
7. Check AI Slop patterns (Section 5). Deduct from Code Quality per the rubric.
8. Verify the live hook bytes match the canonical heredoc bytes — this Sprint's whole premise is drift prevention, so actually run the drift test yourself.
9. Output **valid JSON** matching the schema in Section 6. Nothing else.

### Context you need to understand (critical)

- The diff you're reviewing is the Agent's work on branch `worktree-agent-abedc229`, which branches from main HEAD `f0410d7`.
- Use this to fetch the diff:

  ```bash
  cd /Users/vvedition/Desktop/selfmodel
  git diff main...worktree-agent-abedc229
  git show worktree-agent-abedc229  # full commit
  ```

- The Agent reported that `BYPASS_LEADER_RULES=1` was set in its worktree environment by the parent Claude harness, which would make a naive smoke test show false passes on every path. The Agent wrapped its smoke tests with `bash -c 'unset BYPASS_LEADER_RULES; ...'` to get real results. You should replicate this defensive approach if you run the smoke test yourself.

- Agent's reported smoke test output: all paths in the contract's smoke test passed. Drift test passed (exit 0).

### What this Sprint is fixing

A previous commit (`f0410d7`) silently removed 3 whitelist rules from `scripts/hooks/enforce-leader-worktree.sh` by regenerating the hook file from a canonical heredoc in `scripts/selfmodel.sh` that had drifted out of sync with the live hook. Three file categories (`LICENSE`/`VERSION`/`CHANGELOG`, `.github/*`, `assets/*`) that were previously allowed became blocked as a result. This Sprint restores all three rules in both files and adds a drift-detection test.

Compare the Sprint's output against `git show f0410d7^:scripts/hooks/enforce-leader-worktree.sh` lines 70-82 to verify the restored rules are semantically equivalent to the pre-regression code.

---

## Section 1: Sprint Contract (Acceptance Criteria)

Read the full contract at:

`/Users/vvedition/Desktop/selfmodel/.selfmodel/contracts/active/sprint-7.md`

It contains: Objective, Acceptance Criteria (9 items), Code Tour, Architecture Context, Files, Deliverables, Smoke Test, Constraints.

## Section 2: Git Diff

Fetch with:

```bash
cd /Users/vvedition/Desktop/selfmodel
git diff main...worktree-agent-abedc229
```

Expected diff size: ~30 added lines + 1 new file (~100 lines). Full diff should fit in your review buffer.

## Section 2.5: Integration Context

### Architecture overview

`scripts/hooks/enforce-leader-worktree.sh` is a PreToolUse hook (Write|Edit matcher) in the selfmodel framework. It reads a JSON stdin from the Claude Code hook runtime, extracts `tool_input.file_path`, and exits 0 (allow) or 2 (block) based on a whitelist. `scripts/selfmodel.sh` contains the canonical heredoc that `selfmodel update` / `selfmodel init` uses to (re)write this hook into a target project. The two must stay in sync.

### Naming conventions

- Shell functions: `snake_case`
- Shell variables: `UPPER_SNAKE_CASE` for local in hooks, `lower_snake_case` for function-local in `selfmodel.sh`
- Hook files: `enforce-<scope>.sh` (kebab-case)
- Whitelist rule pattern: comment `# N. <description>` + `if [[ "${NORMALIZED}" == ... ]]; then exit 0; fi`

### Error handling patterns

- `set -euo pipefail` at top of hooks
- `jq` call has a graceful fallback (exit 0 if jq missing — never false-positive block)
- Error output uses `{ echo ...; } >&2` blocks
- Every hook has an emergency `BYPASS_LEADER_RULES` check at the top

### Adjacent modules (do not break)

- `.claude/settings.json` registers the hook; shouldn't need changes
- `generate_hooks()` function in `scripts/selfmodel.sh` is the only writer of the live hook
- Other hooks (`enforce-dispatch-gate.sh`, `enforce-depth-gate.sh`, `enforce-agent-rules.sh`) share the stdin/exit-code protocol

---

## Section 3: Calibration Anchors

### High Anchor (8.9/10) — Sprint 2: Hooks Enforcement

| Dimension | Score | Rationale |
|---|---|---|
| Functionality | 9 | 8 acceptance criteria passed, boundary inputs handled |
| Code Quality | 9 | shellcheck zero warnings, every jq call has fallback |
| Design Taste | 9 | Error messages guide correct behavior, BYPASS via env var |
| Completeness | 8 | Main paths covered, only gap: deep JSON merge edge case |
| Integration Depth | 9 | Perfectly matches selfmodel.sh patterns, reuses err/info/warn helpers |
| Originality | 9 | Glob pattern matching vs hardcoded paths |

**Weighted: 8.9**

### Low Anchor (4.1/10) — Sprint 3 Variant: Severe Quality Issues

| Dimension | Score | Rationale |
|---|---|---|
| Functionality | 4 | Core unimplemented (TODO placeholders) |
| Code Quality | 3 | Contains TODO, placeholder, generic names — auto-reject |
| Design Taste | 4 | Generic naming, style break with project |
| Completeness | 5 | Skeleton exists but critical branches missing |
| Integration Depth | 3 | Style break with existing code, generic naming, no helper reuse |
| Originality | 6 | Reasonable approach, zero execution |

**Weighted: 3.8 (auto-reject on rules #1, #2)**

---

## Section 4: Auto-Reject Triggers (check FIRST)

1. Contains `// TODO` / `# TODO` / `FIXME` / `HACK` / `XXX`
2. Contains mock data, placeholder, fake content
3. Contains `except: pass` / `catch {}` / empty catch / swallowed exceptions
4. Build failure / compile failure / main entry import error
5. I/O / file operations missing error handling
6. Variable names < 3 chars
7. Single function > 50 lines without decomposition
8. Dead code (commented-out blocks) or unused imports
9. Hardcoded secrets / API keys / credentials
10. Missing type annotations in typed languages (not applicable to shell)

## Section 5: AI Slop Patterns (deduct from Code Quality)

1. Excessive obvious-code comments
2. Unnecessary abstract class/interface/factory
3. Defensive null chains
4. Synonym-soup functions
5. Meaningless abstraction layers
6. Over-explanatory naming
7. Template catch blocks
8. AI flattery in comments ("This function elegantly handles...")

---

## Section 6: Output JSON Schema

```json
{
  "sprint": "7",
  "evaluator": "opus-agent",
  "auto_reject_triggered": false,
  "auto_reject_reasons": [],
  "rationale": {
    "functionality": "<per-criterion pass/fail — verify each of the 9 AC>",
    "code_quality": "<Iron Rules + AI Slop analysis>",
    "design_taste": "<naming + structure evaluation>",
    "completeness": "<error handling + branch coverage + edge cases>",
    "integration_depth": "<style match with existing hooks + CLI, drift test coverage>",
    "originality": "<solution elegance>"
  },
  "scores": {
    "functionality": 0,
    "code_quality": 0,
    "design_taste": 0,
    "completeness": 0,
    "integration_depth": 0,
    "originality": 0
  },
  "weighted": 0.0,
  "verdict": "ACCEPT | REVISE | REJECT",
  "must_fix": [
    {
      "file": "<path>",
      "line": "<N>",
      "issue": "<description>",
      "severity": "blocker | major | minor"
    }
  ],
  "should_fix": ["<suggestion>"],
  "praise": ["<what was done well>"]
}
```

### Weighted formula (verify this)

```
weighted = F*0.25 + CQ*0.20 + DT*0.15 + C*0.15 + ID*0.15 + O*0.10
```

### Verdict mapping

- `weighted >= 7.0` → ACCEPT
- `5.0 <= weighted < 7.0` → REVISE
- `weighted < 5.0` → REJECT

---

## Output format

Write the JSON verdict to this file using the Write tool:

`/Users/vvedition/Desktop/selfmodel/.selfmodel/reviews/sprint-7-verdict.json`

Then in your response summarize in under 150 words:
- The weighted score and verdict
- The most important must_fix (if any)
- Whether you verified the drift test actually catches drift (not just reports pass)
- Whether the restored Rules 7/8/9 match pre-R4 byte-for-byte
