# E2E Verification: RiverCore

## Section 1: Context
- Sprint: rivercore-test
- Agent: e2e-verifier
- Worktree: N/A (testing external project at /Users/vvedition/Desktop/rivercore)
- Contract: N/A (cross-project E2E validation test)

## Section 2: Scenarios

### TypeScript Type Check
- Command: cd /Users/vvedition/Desktop/rivercore && npx tsc --noEmit 2>&1; echo "EXIT:$?"
- Expected: exit 0, no type errors
- Timeout: 120s

### Next.js Build
- Command: cd /Users/vvedition/Desktop/rivercore && npm run build 2>&1; echo "EXIT:$?"
- Expected: exit 0, build completes successfully
- Timeout: 180s

### ESLint Check
- Command: cd /Users/vvedition/Desktop/rivercore && npm run lint 2>&1; echo "EXIT:$?"
- Expected: exit 0, no lint errors (warnings acceptable)
- Timeout: 60s

### Shared Package Build
- Command: cd /Users/vvedition/Desktop/rivercore/packages/shared && npm run build 2>&1; echo "EXIT:$?"
- Expected: exit 0, package compiles
- Timeout: 30s

### POAI Package Build
- Command: cd /Users/vvedition/Desktop/rivercore/packages/poai && npm run build 2>&1; echo "EXIT:$?"
- Expected: exit 0, package compiles
- Timeout: 30s

### Database Schema Integrity
- Command: cd /Users/vvedition/Desktop/rivercore && npx drizzle-kit generate --dry-run 2>&1; echo "EXIT:$?"
- Expected: exit 0 or reports no pending changes (either is acceptable)
- Timeout: 30s

### Health Endpoint File Exists
- Command: test -f /Users/vvedition/Desktop/rivercore/src/app/api/health/route.ts && echo "EXISTS" || echo "MISSING"
- Expected: output "EXISTS"
- Timeout: 5s

## Section 3: Constraints
- Do NOT modify any source code
- Do NOT install global dependencies
- Do NOT call production APIs
- Do NOT start Docker containers or databases
- Report exact stdout/stderr (first 500 chars) as evidence
- If a scenario requires unavailable dependencies (DB, Redis, env vars), mark as SKIP with reason

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
    "total": 7,
    "passed": 0,
    "failed": 0,
    "skipped": 0,
    "timed_out": 0
  },
  "verdict": "PASS | FAIL",
  "blocking_failures": [],
  "notes": "runtime behavior observations"
}
