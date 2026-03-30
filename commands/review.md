---
description: "Review a delivered Sprint: Quick Scan + Evaluator + E2E + verdict"
allowed-tools: ["Read", "Write", "Edit", "Bash", "Glob", "Grep", "Agent"]
argument-hint: "[sprint-N] [--skip-e2e] [--evaluator opus|gemini]"
---

# /selfmodel:review

Full quality review pipeline for delivered Sprints.

## Flow

1. **Identify Sprint**: From argument or latest ACTIVE/DELIVERED contract
2. **Quick Scan (30s)**: Check `git diff` for 10 auto-reject triggers (quality-gates.md)
3. **Prepare Evaluator Input**: Build eval file with AC + diff + calibration anchors
4. **Check E2E Trigger**: Runtime verbs in AC? Executable deliverables? (e2e-protocol.md)
5. **Parallel Dispatch**: Evaluator (Opus/fallback) + E2E Agent v2 (if triggered)
6. **Parse & Merge Verdicts**: Per verdict merge rules in quality-gates.md
7. **Act**: ACCEPT (merge) | REVISE (feedback) | REJECT (redo)
8. **Log**: Append quality.jsonl, update team.json
