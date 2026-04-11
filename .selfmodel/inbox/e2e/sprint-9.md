# E2E Verification: Sprint 9 (VERSION string sync)

## Context
- Sprint: 9
- Worktree: `/Users/vvedition/Desktop/selfmodel/.claude/worktrees/agent-accecd4a`
- Branch: `worktree-agent-accecd4a`
- Commit: `802d375`
- Contract: `/Users/vvedition/Desktop/selfmodel/.selfmodel/contracts/active/sprint-9.md`
- Inbox reference (verbatim CHANGELOG text): `/Users/vvedition/Desktop/selfmodel/.selfmodel/inbox/opus/sprint-9.md`

## Depth
quick

Sprint 9 is a 4-file string sync with no runtime feature. Quick depth covers all the runtime surface: `cat`, `grep`, `bash scripts/selfmodel.sh --version`, and a byte-comparison on the CHANGELOG insertion. No server, no UI, no build pipeline in scope.

## Trigger Rationale
- Trigger #2 applies: acceptance criterion contains runtime verb (`bash scripts/selfmodel.sh --version 在 worktree 中运行，输出第一行是 selfmodel 0.5.0`).
- Trigger #1 does NOT apply: no new runnable entry point was introduced.
- Trigger #3 does NOT apply: no test_tools touched.

## Atomic Verifications (one per explicit AC)

You MUST execute every check below in order, from the feature worktree (`cd /Users/vvedition/Desktop/selfmodel/.claude/worktrees/agent-accecd4a` once at start), and produce per-check evidence.

### AC1 — VERSION file content
```bash
cd /Users/vvedition/Desktop/selfmodel/.claude/worktrees/agent-accecd4a
content=$(cat VERSION | tr -d '[:space:]')
test "$content" = "0.5.0" && echo "AC1 PASS: VERSION=$content" || { echo "AC1 FAIL: got '$content'"; exit 1; }
```
Evidence: exact literal content of `VERSION` file (stripped of whitespace).

### AC2 — CLI constant on line 8
```bash
line8=$(sed -n '8p' scripts/selfmodel.sh)
test "$line8" = 'SELFMODEL_VERSION="0.5.0"' && echo "AC2 PASS" || { echo "AC2 FAIL: line 8 = |$line8|"; exit 1; }
```
Evidence: exact text of scripts/selfmodel.sh line 8.

### AC3 — README badge (line 13)
```bash
line13=$(sed -n '13p' README.md)
echo "$line13" | grep -q 'version-0.5.0-green' \
  && echo "$line13" | grep -q 'alt="Version 0.5.0"' \
  && echo "AC3 PASS: badge line = $line13" \
  || { echo "AC3 FAIL: line 13 = |$line13|"; exit 1; }
```
Evidence: exact text of README.md line 13.

### AC4 — CHANGELOG [0.5.0] entry byte-identical to verbatim reference

Extract the committed [0.5.0] block and the inbox verbatim reference, then diff them:

```bash
# Committed CHANGELOG entry (from feature branch)
awk '/^## \[0.5.0\]/,/^## \[0.4.0\]/' CHANGELOG.md | awk 'NR==1 || !/^## \[0.4.0\]/' > /tmp/sprint9-actual.md
# Also strip trailing blank line (the blank between [0.5.0] and [0.4.0])
sed -i.bak -e '${/^$/d;}' /tmp/sprint9-actual.md && rm -f /tmp/sprint9-actual.md.bak

# Inbox verbatim reference
awk '/^```markdown$/{f=1; next} /^```$/ && f==1 {exit} f' /Users/vvedition/Desktop/selfmodel/.selfmodel/inbox/opus/sprint-9.md > /tmp/sprint9-reference.md

diff /tmp/sprint9-actual.md /tmp/sprint9-reference.md
diff_exit=$?
if [ $diff_exit -eq 0 ]; then
  echo "AC4 PASS: CHANGELOG entry is byte-identical"
else
  echo "AC4 FAIL: diverged — see diff above"
  exit 1
fi
```
Evidence: diff output (empty = pass).

Note: if the awk extraction approach gets tripped up by edge cases, you MAY switch to reading both files with Read and comparing textually. Document whichever method you used.

### AC5 — Historical v0.3.0 markers preserved
```bash
count=$(grep -c 'v0.3.0' README.md)
test "$count" -ge 5 && echo "AC5 PASS: $count historical markers preserved" || { echo "AC5 FAIL: only $count markers found (need ≥5)"; exit 1; }
```
Evidence: count.

### AC6 — Runtime `--version` output
```bash
first_line=$(bash scripts/selfmodel.sh --version 2>/dev/null | head -1)
test "$first_line" = "selfmodel 0.5.0" && echo "AC6 PASS: $first_line" || { echo "AC6 FAIL: got '$first_line'"; exit 1; }
```
Evidence: the first line of stdout.

### AC7 — CHANGELOG ordering
```bash
line_new=$(grep -n '^## \[0.5.0\]' CHANGELOG.md | head -1 | cut -d: -f1)
line_old=$(grep -n '^## \[0.4.0\]' CHANGELOG.md | head -1 | cut -d: -f1)
test -n "$line_new" && test -n "$line_old" && test "$line_new" -lt "$line_old" \
  && echo "AC7 PASS: [0.5.0] at line $line_new < [0.4.0] at line $line_old" \
  || { echo "AC7 FAIL: new=$line_new old=$line_old"; exit 1; }
```
Evidence: line numbers.

### AC8 — .selfmodel/ untouched
```bash
touched=$(git diff --name-only main...HEAD 2>/dev/null | grep -c '^\.selfmodel/' || true)
test "$touched" = "0" && echo "AC8 PASS: .selfmodel/ untouched" || { echo "AC8 FAIL: $touched files touched under .selfmodel/"; exit 1; }
```
Evidence: count (should be 0).

### AC9 — Exactly 4 files changed
```bash
changed=$(git diff --name-only main...HEAD 2>/dev/null | wc -l | tr -d ' ')
test "$changed" = "4" && echo "AC9 PASS: exactly 4 files" || { echo "AC9 FAIL: $changed files changed"; git diff --name-only main...HEAD; exit 1; }
```
Evidence: file count.

### IMPLICIT AC — bash syntax check
```bash
bash -n scripts/selfmodel.sh && echo "IMPLICIT PASS: syntax ok" || { echo "IMPLICIT FAIL: bash -n failed"; exit 1; }
```
Evidence: exit code.

## Verdict Rules

- All 9 explicit ACs PASS + IMPLICIT PASS → **PASS**
- Any AC FAIL → **FAIL** (Sprint 9 cannot degrade gracefully — every check is necessary)
- Report per-AC with status + evidence snippet (one line each is fine)

## Output

Write the verdict to `/Users/vvedition/Desktop/selfmodel/.selfmodel/reviews/sprint-9-e2e.json`:

```json
{
  "sprint": "9",
  "depth": "quick",
  "verdict": "PASS | FAIL",
  "explicit_acs": {
    "AC1": {"status": "PASS", "evidence": "VERSION=0.5.0"},
    "AC2": {"status": "PASS", "evidence": "..."},
    ...
  },
  "implicit_acs": {
    "bash_syntax": {"status": "PASS", "evidence": "exit 0"}
  },
  "notes": "..."
}
```

Then reply in ≤100 words: verdict + per-AC one-line summary.

## Timeout
60s (quick depth).

## Allowed
Read, Bash (for the verification commands above), Grep.

## Forbidden
Write (except to the output JSON), Edit, any file modification, any `git push`, any state change outside the verdict file.
