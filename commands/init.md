---
description: "Initialize selfmodel multi-AI orchestration framework in the current project"
allowed-tools: ["Read", "Write", "Edit", "Bash", "Glob"]
argument-hint: "[--force] to reinitialize existing project"
---

# /selfmodel:init

Initialize the selfmodel multi-AI agent orchestration framework in the current project.

## Steps

### 1. Check Prerequisites
Verify git repo. Check for existing `.selfmodel/`. If exists and no `--force`, confirm with user.

### 2. Detect Tech Stack
Scan for: package.json, pyproject.toml, go.mod, Cargo.toml, tsconfig.json.
Update `detected_stack` in team.json.

### 3. Create Directory Structure
```bash
mkdir -p .selfmodel/contracts/{active,archive}
mkdir -p .selfmodel/inbox/{gemini,codex,opus,research,evaluator,e2e}
mkdir -p .selfmodel/hooks .selfmodel/artifacts .selfmodel/reviews .selfmodel/state
touch .selfmodel/state/.gitkeep .selfmodel/artifacts/.gitkeep
```

### 4. Copy Templates
- Read `/Users/vvedition/.claude/skills/selfmodel/assets/team-template.json` → `.selfmodel/state/team.json` (replace __TIMESTAMP__)
- Read `/Users/vvedition/.claude/skills/selfmodel/assets/settings-template.json` → merge into `.claude/settings.json`

### 5. Copy Hook Scripts
```bash
cp "/Users/vvedition/.claude/skills/selfmodel/scripts/"*.sh .selfmodel/hooks/ && chmod +x .selfmodel/hooks/*.sh
```

### 6. Update .gitignore
Append entries from `/Users/vvedition/.claude/skills/selfmodel/assets/gitignore-template`.

### 7. Create Lightweight CLAUDE.md Section
Append selfmodel section pointing to skill commands. Keep it lightweight.

### 8. Create Initial next-session.md
Write initial state with detected stack info.

### 9. Output Summary
Show: directories created, hooks installed, agents ready, detected stack.
Suggest: `/selfmodel:sprint` to create first Sprint.
