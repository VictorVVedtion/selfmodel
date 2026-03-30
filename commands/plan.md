---
description: "Create or update a multi-phase orchestration plan"
allowed-tools: ["Read", "Write", "Edit", "Bash", "Glob", "Grep"]
argument-hint: "<project description> [--phases N]"
---

# /selfmodel:plan

Create `.selfmodel/state/plan.md` for automated orchestration.

## Flow

1. **Understand Project**: From argument or scan codebase
2. **Design Phases**: Foundation → Features → Polish
3. **Design Sprints**: Title, agent, dependencies, priority, timeout per dispatch-rules.md
4. **Write plan.md**: Per orchestration-loop.md Plan File Format
5. **Output Summary**: Phase count, sprint count, estimated time

Ready to execute: `/selfmodel:loop` or `/selfmodel:sprint`
