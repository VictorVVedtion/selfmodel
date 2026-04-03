# E2E Verification: Test Run

## Section 1: Context
- Sprint: test
- Agent: e2e-test (validation of E2E Agent itself)
- Worktree: (current repo — this is a protocol validation test)
- Contract: N/A (test run)

## Section 2: Scenarios

### Build Verification — selfmodel.sh syntax check
- Command: bash -n scripts/selfmodel.sh
- Expected: exit 0, no syntax errors
- Timeout: 10s

### CLI Execution — selfmodel.sh status
- Command: bash scripts/selfmodel.sh status
- Expected: exit 0, output contains "Team Status" or team member names
- Timeout: 30s

### CLI Execution — selfmodel.sh with no args
- Command: bash scripts/selfmodel.sh 2>&1; echo "EXIT:$?"
- Expected: shows usage/help, exit code 0 or 1 (either acceptable)
- Timeout: 10s

### File Integrity — playbook completeness
- Command: ls -1 .selfmodel/playbook/ | wc -l | tr -d ' '
- Expected: output is "9" (9 playbook files)
- Timeout: 5s

### File Integrity — team.json valid JSON
- Command: python3 -c "import json; json.load(open('.selfmodel/state/team.json')); print('valid')"
- Expected: exit 0, output "valid"
- Timeout: 5s

## Section 3: Constraints
- Do NOT modify any source code
- Do NOT install global dependencies
- Do NOT call production APIs
- Report exact stdout/stderr (first 500 chars) as evidence
- If a scenario requires unavailable dependencies, mark as SKIP with reason

## Section 4: Output Schema
Output ONLY valid JSON:
{
  "sprint": "<N>",
  "agent": "opus-agent | gemini",
  "scenarios": [
    {
      "name": "scenario name",
      "type": "build | test-suite | server | cli | ui",
      "status": "PASS | FAIL | SKIP | TIMEOUT",
      "command": "executed command",
      "exit_code": 0,
      "duration_seconds": 12,
      "evidence": "first 500 chars of stdout/stderr",
      "error": null
    }
  ],
  "summary": {
    "total": 5,
    "passed": 0,
    "failed": 0,
    "skipped": 0,
    "timed_out": 0
  },
  "verdict": "PASS | FAIL",
  "blocking_failures": [],
  "notes": "runtime behavior observations"
}
