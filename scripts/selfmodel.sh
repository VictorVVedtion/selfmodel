#!/usr/bin/env bash
# selfmodel — AI Agent Team 工作流初始化与适配工具
# Usage: selfmodel <init|adapt|update|version> [options]
# Zero dependencies. macOS + Linux.
set -eo pipefail

SELFMODEL_VERSION="0.2.0"
SELFMODEL_REPO="https://raw.githubusercontent.com/VictorVVedtion/selfmodel/main"

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ─── Helpers ──────────────────────────────────────────────────────────────────
info()  { printf "${BLUE}[selfmodel]${NC} %s\n" "$*"; }
ok()    { printf "${GREEN}[selfmodel]${NC} %s\n" "$*"; }
warn()  { printf "${YELLOW}[selfmodel]${NC} %s\n" "$*"; }
err()   { printf "${RED}[selfmodel]${NC} %s\n" "$*" >&2; }
bold()  { printf "${BOLD}%s${NC}" "$*"; }

confirm() {
    local prompt="${1:-Continue?}"
    printf "${CYAN}[selfmodel]${NC} %s [Y/n] " "$prompt"
    read -r reply
    [[ -z "$reply" || "$reply" =~ ^[Yy] ]]
}

# ─── Tech Stack Detection ────────────────────────────────────────────────────
# Nx-style feature file inference: check config files, not AST
detect_stack() {
    local dir="${1:-.}"
    local stacks=()
    local frameworks=()
    local test_tools=()
    local has_frontend=false
    local has_backend=false

    # --- Language / Runtime ---
    if [[ -f "$dir/package.json" ]]; then
        stacks+=("node")
        # Framework detection from dependencies
        if grep -q '"react"\|"next"\|"vue"\|"svelte"\|"angular"' "$dir/package.json" 2>/dev/null; then
            has_frontend=true
            grep -q '"next"' "$dir/package.json" 2>/dev/null && frameworks+=("nextjs")
            grep -q '"react"' "$dir/package.json" 2>/dev/null && frameworks+=("react")
            grep -q '"vue"' "$dir/package.json" 2>/dev/null && frameworks+=("vue")
            grep -q '"svelte"' "$dir/package.json" 2>/dev/null && frameworks+=("svelte")
            grep -q '"angular"' "$dir/package.json" 2>/dev/null && frameworks+=("angular")
        fi
        if grep -q '"express"\|"fastify"\|"nest"\|"hono"\|"koa"' "$dir/package.json" 2>/dev/null; then
            has_backend=true
            grep -q '"express"' "$dir/package.json" 2>/dev/null && frameworks+=("express")
            grep -q '"nest"' "$dir/package.json" 2>/dev/null && frameworks+=("nestjs")
        fi
        # Test tool detection
        grep -q '"jest"\|"vitest"' "$dir/package.json" 2>/dev/null && test_tools+=("jest/vitest")
        grep -q '"playwright"\|"cypress"' "$dir/package.json" 2>/dev/null && test_tools+=("e2e")
    fi
    if [[ -f "$dir/tsconfig.json" ]]; then
        stacks+=("typescript")
    fi
    if [[ -f "$dir/pyproject.toml" || -f "$dir/requirements.txt" || -f "$dir/setup.py" ]]; then
        stacks+=("python")
        has_backend=true
        [[ -f "$dir/pyproject.toml" ]] && grep -q 'django\|flask\|fastapi' "$dir/pyproject.toml" 2>/dev/null && {
            grep -q 'django' "$dir/pyproject.toml" 2>/dev/null && frameworks+=("django")
            grep -q 'flask' "$dir/pyproject.toml" 2>/dev/null && frameworks+=("flask")
            grep -q 'fastapi' "$dir/pyproject.toml" 2>/dev/null && frameworks+=("fastapi")
        }
        grep -q 'pytest' "$dir/pyproject.toml" "$dir/requirements.txt" 2>/dev/null && test_tools+=("pytest")
    fi
    if [[ -f "$dir/go.mod" ]]; then
        stacks+=("go")
        has_backend=true
    fi
    if [[ -f "$dir/Cargo.toml" ]]; then
        stacks+=("rust")
        has_backend=true
    fi
    if [[ -f "$dir/Package.swift" || -d "$dir/*.xcodeproj" ]] 2>/dev/null; then
        stacks+=("swift")
        has_frontend=true
        frameworks+=("swiftui")
    fi
    if [[ -f "$dir/Gemfile" ]]; then
        stacks+=("ruby")
        has_backend=true
        grep -q 'rails' "$dir/Gemfile" 2>/dev/null && frameworks+=("rails")
    fi

    # --- Infra signals ---
    [[ -f "$dir/Dockerfile" || -f "$dir/docker-compose.yml" ]] && stacks+=("docker")
    [[ -d "$dir/.github/workflows" ]] && stacks+=("github-actions")
    [[ -f "$dir/terraform.tf" || -d "$dir/.terraform" ]] && stacks+=("terraform")

    # --- Determine project type ---
    local project_type="unknown"
    if $has_frontend && $has_backend; then
        project_type="fullstack"
    elif $has_frontend; then
        project_type="frontend"
    elif $has_backend; then
        project_type="backend"
    elif [[ ${#stacks[@]} -gt 0 ]]; then
        project_type="library"
    fi

    # Export results (safe for empty arrays)
    DETECTED_STACKS=("${stacks[@]+"${stacks[@]}"}")
    DETECTED_FRAMEWORKS=("${frameworks[@]+"${frameworks[@]}"}")
    DETECTED_TEST_TOOLS=("${test_tools[@]+"${test_tools[@]}"}")
    DETECTED_TYPE="$project_type"
    DETECTED_HAS_FRONTEND=$has_frontend
    DETECTED_HAS_BACKEND=$has_backend
}

# ─── Team Composition ────────────────────────────────────────────────────────
# Map detected project type → recommended agent team
recommend_team() {
    local type="$1"
    local has_frontend="$2"
    local has_backend="$3"

    # Leader + Researcher are always present
    local agents='"leader": {"status": "idle", "role": "leader_evaluator"}'
    agents+=', "researcher": {"status": "idle", "role": "researcher", "config": {"engine": "gemini-cli", "model": "gemini-3.1-pro-preview", "timeout": 300, "requires_worktree": false}}'

    case "$type" in
        fullstack)
            agents+=', "gemini": {"status": "idle", "role": "frontend_colleague", "sprints_completed": 0, "avg_score": 0}'
            agents+=', "codex": {"status": "idle", "role": "backend_intern", "sprints_completed": 0, "avg_score": 0}'
            agents+=', "opus": {"status": "idle", "role": "senior_fullstack", "sprints_completed": 0, "avg_score": 0}'
            ;;
        frontend)
            agents+=', "gemini": {"status": "idle", "role": "frontend_lead", "sprints_completed": 0, "avg_score": 0}'
            agents+=', "opus": {"status": "idle", "role": "senior_fullstack", "sprints_completed": 0, "avg_score": 0}'
            ;;
        backend)
            agents+=', "codex": {"status": "idle", "role": "backend_lead", "sprints_completed": 0, "avg_score": 0}'
            agents+=', "opus": {"status": "idle", "role": "senior_fullstack", "sprints_completed": 0, "avg_score": 0}'
            ;;
        library|unknown)
            agents+=', "opus": {"status": "idle", "role": "senior_fullstack", "sprints_completed": 0, "avg_score": 0}'
            ;;
    esac

    echo "{$agents}"
}

# ─── Directory Scaffold ──────────────────────────────────────────────────────
create_structure() {
    local dir="${1:-.}"
    mkdir -p "$dir/.selfmodel/contracts/active"
    mkdir -p "$dir/.selfmodel/contracts/archive"
    mkdir -p "$dir/.selfmodel/inbox/gemini"
    mkdir -p "$dir/.selfmodel/inbox/codex"
    mkdir -p "$dir/.selfmodel/inbox/opus"
    mkdir -p "$dir/.selfmodel/inbox/research"
    mkdir -p "$dir/.selfmodel/reviews"
    mkdir -p "$dir/.selfmodel/state"
    mkdir -p "$dir/.selfmodel/playbook"

    # .gitkeep for empty directories
    for d in contracts/active contracts/archive inbox/gemini inbox/codex inbox/opus inbox/research reviews; do
        touch "$dir/.selfmodel/$d/.gitkeep"
    done
}

# ─── Generate team.json ──────────────────────────────────────────────────────
generate_team_json() {
    local dir="${1:-.}"
    local type="$2"
    local has_frontend="$3"
    local has_backend="$4"

    local agents_json
    agents_json=$(recommend_team "$type" "$has_frontend" "$has_backend")

    # Safe JSON array generation for potentially empty arrays
    local stacks_json frameworks_json test_tools_json
    if [[ ${#DETECTED_STACKS[@]} -gt 0 ]]; then
        stacks_json=$(printf '%s\n' "${DETECTED_STACKS[@]}" | jq -R . | jq -s .)
    else
        stacks_json="[]"
    fi
    if [[ ${#DETECTED_FRAMEWORKS[@]} -gt 0 ]]; then
        frameworks_json=$(printf '%s\n' "${DETECTED_FRAMEWORKS[@]}" | jq -R . | jq -s .)
    else
        frameworks_json="[]"
    fi
    if [[ ${#DETECTED_TEST_TOOLS[@]} -gt 0 ]]; then
        test_tools_json=$(printf '%s\n' "${DETECTED_TEST_TOOLS[@]}" | jq -R . | jq -s .)
    else
        test_tools_json="[]"
    fi

    cat > "$dir/.selfmodel/state/team.json" << TEAMEOF
{
  "current_sprint": 0,
  "session_count": 0,
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "agents": $agents_json,
  "evolution": {
    "last_review_sprint": 0,
    "protocol_version": "$SELFMODEL_VERSION",
    "experiments_active": []
  },
  "detected_stack": {
    "type": "$type",
    "stacks": $stacks_json,
    "frameworks": $frameworks_json,
    "test_tools": $test_tools_json
  },
  "skills_evaluated": {},
  "worktrees_active": [],
  "meta": {
    "state_version": 1,
    "last_modified": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "last_modified_by": "selfmodel-init"
  }
}
TEAMEOF
}

# ─── Generate next-session.md ─────────────────────────────────────────────────
generate_next_session() {
    local dir="${1:-.}"
    cat > "$dir/.selfmodel/state/next-session.md" << 'SESSIONEOF'
# Next Session Handoff

## Status
Project initialized via `selfmodel`. Ready for first Sprint.

## Next Steps
1. Review generated CLAUDE.md and customize Iron Rules if needed
2. Create Sprint 1 contract — pick a small task, fill sprint-template.md
3. Verify end-to-end pipeline — worktree → inbox → agent → diff → merge

## Blockers
None

## Active Worktrees
None

## Open Sprints
None
SESSIONEOF
}

# ─── Print Detection Summary ─────────────────────────────────────────────────
print_detection() {
    echo ""
    info "$(bold 'Detection Results')"
    echo "  Project Type:  $(bold "$DETECTED_TYPE")"
    echo "  Stacks:        ${DETECTED_STACKS[*]:-none}"
    echo "  Frameworks:    ${DETECTED_FRAMEWORKS[*]:-none}"
    echo "  Test Tools:    ${DETECTED_TEST_TOOLS[*]:-none}"

    echo "  Has Frontend:  $DETECTED_HAS_FRONTEND"
    echo "  Has Backend:   $DETECTED_HAS_BACKEND"
    echo ""
}

# ─── Print Team Summary ──────────────────────────────────────────────────────
print_team() {
    local type="$1"
    info "$(bold 'Recommended Team')"
    echo "  Leader/Evaluator:  Claude Opus (always)"
    echo "  Researcher:        Gemini CLI (always)"
    case "$type" in
        fullstack)
            echo "  Frontend:          Gemini CLI (--yolo)"
            echo "  Backend:           Codex CLI (--full-auto)"
            echo "  Senior Fullstack:  Opus Agent (worktree)"
            ;;
        frontend)
            echo "  Frontend Lead:     Gemini CLI (--yolo)"
            echo "  Senior Fullstack:  Opus Agent (worktree)"
            ;;
        backend)
            echo "  Backend Lead:      Codex CLI (--full-auto)"
            echo "  Senior Fullstack:  Opus Agent (worktree)"
            ;;
        library|unknown)
            echo "  Senior Fullstack:  Opus Agent (worktree)"
            ;;
    esac
    echo ""
}

# ─── CMD: init ────────────────────────────────────────────────────────────────
cmd_init() {
    local dir="${1:-.}"
    info "Initializing selfmodel in $(bold "$dir")"

    # Check for existing selfmodel
    if [[ -d "$dir/.selfmodel" ]]; then
        warn ".selfmodel/ already exists. Use 'selfmodel adapt' instead."
        exit 1
    fi

    # Detect if there's an existing project
    if [[ -f "$dir/package.json" || -f "$dir/pyproject.toml" || -f "$dir/go.mod" || -f "$dir/Cargo.toml" ]]; then
        info "Existing project detected. Running auto-detection..."
        detect_stack "$dir"
        print_detection
        print_team "$DETECTED_TYPE"
        confirm "Generate selfmodel config for this $(bold "$DETECTED_TYPE") project?" || exit 0
    else
        info "Empty or new project. Running interactive setup..."
        echo ""
        echo "  1) fullstack  (Frontend + Backend)"
        echo "  2) frontend   (UI/Web only)"
        echo "  3) backend    (API/Service only)"
        echo "  4) library    (Package/SDK)"
        echo ""
        printf "${CYAN}[selfmodel]${NC} Project type [1-4]: "
        read -r choice
        case "$choice" in
            1) DETECTED_TYPE="fullstack"; DETECTED_HAS_FRONTEND=true; DETECTED_HAS_BACKEND=true ;;
            2) DETECTED_TYPE="frontend"; DETECTED_HAS_FRONTEND=true; DETECTED_HAS_BACKEND=false ;;
            3) DETECTED_TYPE="backend"; DETECTED_HAS_FRONTEND=false; DETECTED_HAS_BACKEND=true ;;
            4) DETECTED_TYPE="library"; DETECTED_HAS_FRONTEND=false; DETECTED_HAS_BACKEND=false ;;
            *) err "Invalid choice"; exit 1 ;;
        esac
        DETECTED_STACKS=()
        DETECTED_FRAMEWORKS=()
        DETECTED_TEST_TOOLS=()
        print_team "$DETECTED_TYPE"
        confirm "Generate selfmodel config?" || exit 0
    fi

    # Create structure
    create_structure "$dir"
    generate_team_json "$dir" "$DETECTED_TYPE" "$DETECTED_HAS_FRONTEND" "$DETECTED_HAS_BACKEND"
    generate_next_session "$dir"

    # Copy playbook from repo (or generate defaults)
    generate_playbook "$dir"

    # Generate or inject CLAUDE.md
    generate_claude_md "$dir"

    # Git init if needed
    if [[ ! -d "$dir/.git" ]]; then
        confirm "Initialize git repository?" && {
            git -C "$dir" init -b main
            ok "Git initialized"
        }
    fi

    echo ""
    ok "selfmodel initialized! ($SELFMODEL_VERSION)"
    info "Next: review CLAUDE.md, then create your first Sprint contract."
}

# ─── CMD: adapt ───────────────────────────────────────────────────────────────
cmd_adapt() {
    local dir="${1:-.}"
    info "Adapting selfmodel to existing project in $(bold "$dir")"

    # Detect stack
    detect_stack "$dir"
    print_detection
    print_team "$DETECTED_TYPE"

    # Create structure if missing
    if [[ ! -d "$dir/.selfmodel" ]]; then
        info "No .selfmodel/ found. Creating structure..."
        create_structure "$dir"
        generate_team_json "$dir" "$DETECTED_TYPE" "$DETECTED_HAS_FRONTEND" "$DETECTED_HAS_BACKEND"
        generate_next_session "$dir"
        generate_playbook "$dir"
    else
        info ".selfmodel/ exists. Updating team.json with detected stack..."
        generate_team_json "$dir" "$DETECTED_TYPE" "$DETECTED_HAS_FRONTEND" "$DETECTED_HAS_BACKEND"
    fi

    # Handle CLAUDE.md — inject rather than overwrite
    if [[ -f "$dir/CLAUDE.md" ]]; then
        if grep -q '<!-- selfmodel:start -->' "$dir/CLAUDE.md" 2>/dev/null; then
            info "CLAUDE.md already has selfmodel section. Updating..."
            inject_claude_md "$dir" "update"
        else
            warn "CLAUDE.md exists but has no selfmodel section."
            confirm "Inject selfmodel rules into existing CLAUDE.md?" && inject_claude_md "$dir" "append"
        fi
    else
        generate_claude_md "$dir"
    fi

    echo ""
    ok "selfmodel adapted! ($SELFMODEL_VERSION)"
}

# ─── CMD: update ──────────────────────────────────────────────────────────────
cmd_update() {
    local dir="${1:-.}"
    info "Updating selfmodel playbook in $(bold "$dir")"

    if [[ ! -d "$dir/.selfmodel" ]]; then
        err "No .selfmodel/ found. Run 'selfmodel init' or 'selfmodel adapt' first."
        exit 1
    fi

    # Re-detect stack (project may have evolved)
    detect_stack "$dir"
    info "Re-detected: $(bold "$DETECTED_TYPE") project"

    # Update playbook files (framework layer)
    generate_playbook "$dir"

    # Update team.json with new detection but preserve sprints/scores
    if [[ -f "$dir/.selfmodel/state/team.json" ]]; then
        info "Preserving agent history, updating detected_stack..."
        local stacks_json frameworks_json
        if [[ ${#DETECTED_STACKS[@]} -gt 0 ]]; then
            stacks_json=$(printf '%s\n' "${DETECTED_STACKS[@]}" | jq -R . | jq -s .)
        else
            stacks_json="[]"
        fi
        if [[ ${#DETECTED_FRAMEWORKS[@]} -gt 0 ]]; then
            frameworks_json=$(printf '%s\n' "${DETECTED_FRAMEWORKS[@]}" | jq -R . | jq -s .)
        else
            frameworks_json="[]"
        fi
        local tmp
        tmp=$(mktemp)
        jq --arg ver "$SELFMODEL_VERSION" \
           --argjson stacks "$stacks_json" \
           --argjson frameworks "$frameworks_json" \
           --arg type "$DETECTED_TYPE" \
           '.evolution.protocol_version = $ver | .detected_stack = {"type": $type, "stacks": $stacks, "frameworks": $frameworks}' \
           "$dir/.selfmodel/state/team.json" > "$tmp" && mv "$tmp" "$dir/.selfmodel/state/team.json"
    fi

    echo ""
    ok "selfmodel updated to $SELFMODEL_VERSION!"
}

# ─── CMD: version ─────────────────────────────────────────────────────────────
cmd_version() {
    echo "selfmodel $SELFMODEL_VERSION"
}

# ─── Generate Playbook ────────────────────────────────────────────────────────
generate_playbook() {
    local dir="${1:-.}"

    # sprint-template.md — universal
    cat > "$dir/.selfmodel/playbook/sprint-template.md" << 'TMPLEOF'
# Sprint <N>: <Title>

## Status
DRAFT → ACTIVE → DELIVERED → REVIEWED → MERGED | REJECTED

## Agent
<gemini | codex | opus>

## Objective
<One sentence: what this Sprint delivers>

## Acceptance Criteria
- [ ] <Specific, testable criterion 1>
- [ ] <Specific, testable criterion 2>
- [ ] <Specific, testable criterion 3>

## Context
<Background info the agent needs. Reference files, APIs, design decisions.>

## Constraints
- Timeout: <60 | 120 | 180>s
- Files in scope: <list specific files or directories>
- Files out of scope: <do not touch>

## Deliverables
- [ ] <File or feature 1>
- [ ] <File or feature 2>
TMPLEOF

    # lessons-learned.md — universal skeleton
    if [[ ! -f "$dir/.selfmodel/playbook/lessons-learned.md" ]]; then
        cat > "$dir/.selfmodel/playbook/lessons-learned.md" << 'LESSONSEOF'
# Lessons Learned

Accumulated knowledge from Sprint reviews and evolution cycles.

---

## Patterns That Work
(populated after Sprints)

## Anti-Patterns Discovered
(populated after Sprints)

## Tool/Skill Evaluations
(populated after trying new skills)
LESSONSEOF
    fi

    # quality-gates.md and dispatch-rules.md — fetch from repo or generate
    # For now, generate locally (could curl from SELFMODEL_REPO in future)
    if [[ ! -f "$dir/.selfmodel/playbook/dispatch-rules.md" ]]; then
        info "Generating dispatch-rules.md..."
        generate_dispatch_rules "$dir"
    fi

    if [[ ! -f "$dir/.selfmodel/playbook/quality-gates.md" ]]; then
        info "Generating quality-gates.md..."
        generate_quality_gates "$dir"
    fi

    if [[ ! -f "$dir/.selfmodel/playbook/research-protocol.md" ]]; then
        info "Generating research-protocol.md..."
        generate_research_protocol "$dir"
    fi

    ok "Playbook generated."
}

# ─── Generate dispatch-rules.md ──────────────────────────────────────────────
generate_dispatch_rules() {
    local dir="${1:-.}"
    cat > "$dir/.selfmodel/playbook/dispatch-rules.md" << 'DISPATCHEOF'
# Dispatch Rules

Task dispatch rules. Leader must consult this file before assigning Sprints.

---

## Decision Matrix

| Signal | Route To | Why |
|---|---|---|
| UI / UX / CSS / component / page / layout | **Gemini** | Visual design strength |
| Single-file backend / utility / function / fix | **Codex** | Fast, focused, decoupled |
| Multi-file refactor / system integration / complex logic | **Opus Agent** | Deep reasoning + 1M context |
| Architecture / spec / review / arbitration | **Leader** | Orchestration authority |
| Research / comparison / best practice / how-to | **Researcher** | Google Search grounding |
| Tech selection / library comparison | **Researcher → Leader** | Search first, decide second |

**Routing Priority**: Leader > Researcher > Opus Agent > Gemini > Codex
**Research First**: Unknown domains must be researched before implementation.

---

## Parallel Dispatch

Independent tasks MUST be dispatched in parallel:
- Multiple Agent tool calls in the same message
- Gemini/Codex with `run_in_background: true`
- Researcher can run alongside Generators
- Unified review after all complete

---

## Timeout Guide

| Task Type | Timeout | Notes |
|---|---|---|
| Single file edit / simple fix | 60s | Quick operation |
| Component creation / medium complexity | 120s | Standard Sprint |
| Multi-file implementation / complex logic | 180s | Single task max |
| Researcher investigation | 300s | Search + synthesis |
| npm install / build | 300s | Network latency |

---

## Backpressure Protocol

### Generator (Gemini/Codex/Opus)
1. First timeout → retry with same timeout
2. Second timeout → split into smaller Sprints (≤60s each)
3. Third timeout → escalate to Leader, log to lessons-learned.md

### Researcher
1. First timeout → retry
2. Second timeout → degrade: Gemini → WebSearch + WebFetch
3. Third failure → Leader manual research via Chrome MCP
DISPATCHEOF
}

# ─── Generate quality-gates.md ───────────────────────────────────────────────
generate_quality_gates() {
    local dir="${1:-.}"
    cat > "$dir/.selfmodel/playbook/quality-gates.md" << 'QUALITYEOF'
# Quality Gates

5-dimension scoring for Sprint review.

---

## Scoring Dimensions

| Dimension | Weight | Auto-Reject |
|---|---|---|
| Functionality | 30% | Missing acceptance criteria |
| Code Quality | 25% | Contains TODO/mock/swallowed exceptions |
| Design Taste | 20% | Generic naming |
| Completeness | 15% | Missing else/catch branches |
| Originality | 10% | Brute force when elegant solution exists |

## Verdict

- **≥7.0**: Accept → merge
- **5.0-6.9**: Revise → feedback to agent
- **<5.0**: Reject → redo from scratch

## Cross-Validation

- Gemini reviews Codex output
- Codex reviews Gemini output
- Leader makes final arbitration
QUALITYEOF
}

# ─── Generate research-protocol.md ───────────────────────────────────────────
generate_research_protocol() {
    local dir="${1:-.}"
    cat > "$dir/.selfmodel/playbook/research-protocol.md" << 'RESEARCHEOF'
# Research Protocol

Researcher role dispatch protocol. Leader must consult before research tasks.

---

## Research Types

### Type A: Quick Query (single channel, 120s)
```bash
CI=true timeout 120 gemini -p "question" -m gemini-3.1-pro-preview -y
```

### Type B: Tech Research (dual channel, 300s)
Gemini + context7 in parallel.

### Type C: Deep Research (full pipeline, 600s)
Layer 1: Gemini + NotebookLM + context7 (breadth)
Layer 2: WebFetch + Chrome MCP (depth)
Layer 3: Leader cross-validation (synthesis)

---

## Evaluation

| Dimension | Weight | Auto-Reject |
|---|---|---|
| Accuracy | 35% | Conclusions contradict sources |
| Completeness | 25% | Missing obvious alternatives |
| Source Quality | 20% | No verifiable URLs |
| Actionability | 20% | Vague conclusions |

Verdict: ≥7.0 adopt | 5.0-6.9 supplement | <5.0 redo with different channel
RESEARCHEOF
}

# ─── Generate CLAUDE.md ──────────────────────────────────────────────────────
generate_claude_md() {
    local dir="${1:-.}"
    local project_name
    project_name=$(basename "$(cd "$dir" && pwd)")

    cat > "$dir/CLAUDE.md" << CLAUDEEOF
# $project_name

<!-- selfmodel:start -->
## Iron Rules

1. **Never Fallback** — The correct solution needs 500 lines, write 500 lines. Never say "for simplicity..."
2. **Never Mock** — All data from real sources. No mock data, placeholders, fake data
3. **Never Lazy** — No skipping error handling, no TODO, every try has complete catch
4. **Best Taste** — Naming like prose, architecture worth screenshotting
5. **Infinite Time** — Never compromise quality for efficiency
6. **True Artist** — Code is signed artwork. Low quality is shame

### Leader Rules

7. **No Implementation** — Leader only orchestrates, reviews, arbitrates
8. **No Self-Review** — Implementer ≠ Reviewer
9. **File Buffer** — Complex prompts written to .selfmodel/inbox/ files
10. **No Interactive** — All commands: CI=true yes | timeout <N> <cmd>
11. **Small Batch** — Each agent task completes in 30-60 seconds
12. **Efficiency First** — Parallelize everything with no dependencies

## Team

$(generate_team_table "$DETECTED_TYPE" "$DETECTED_HAS_FRONTEND" "$DETECTED_HAS_BACKEND")

## Execution

### File Buffer Communication

\`\`\`bash
# Step 1: Leader writes task to inbox
#   → .selfmodel/inbox/<agent>/sprint-<N>.md
# Step 2: CLI references file
CI=true timeout 180 gemini \\
  -p "\\\$(cat .selfmodel/inbox/gemini/sprint-<N>.md) Execute the task above" \\
  -m gemini-3.1-pro-preview -y
\`\`\`

### Parallel Dispatch

Independent tasks MUST be dispatched in parallel.

## On-Demand Loading

| Scenario | Load File |
|----------|-----------|
| Dispatch decisions | .selfmodel/playbook/dispatch-rules.md |
| Research protocol | .selfmodel/playbook/research-protocol.md |
| Quality review | .selfmodel/playbook/quality-gates.md |
| Sprint contracts | .selfmodel/playbook/sprint-template.md |
| Lessons learned | .selfmodel/playbook/lessons-learned.md |
<!-- selfmodel:end -->
CLAUDEEOF

    ok "CLAUDE.md generated."
}

# ─── Inject into existing CLAUDE.md ──────────────────────────────────────────
inject_claude_md() {
    local dir="${1:-.}"
    local mode="${2:-append}"  # append or update

    local selfmodel_block
    selfmodel_block=$(cat << 'INJECTEOF'

<!-- selfmodel:start -->
## selfmodel Agent Team

See .selfmodel/playbook/ for detailed rules.
See .selfmodel/state/team.json for team composition.

### Quick Reference
- Dispatch: .selfmodel/playbook/dispatch-rules.md
- Quality: .selfmodel/playbook/quality-gates.md
- Research: .selfmodel/playbook/research-protocol.md
- Sprint Template: .selfmodel/playbook/sprint-template.md
<!-- selfmodel:end -->
INJECTEOF
    )

    if [[ "$mode" == "update" ]]; then
        # Remove old block and inject new
        sed -i '' '/<!-- selfmodel:start -->/,/<!-- selfmodel:end -->/d' "$dir/CLAUDE.md"
        echo "$selfmodel_block" >> "$dir/CLAUDE.md"
    else
        echo "$selfmodel_block" >> "$dir/CLAUDE.md"
    fi

    ok "selfmodel rules injected into CLAUDE.md"
}

# ─── Generate Team Table ─────────────────────────────────────────────────────
generate_team_table() {
    local type="$1"
    local has_frontend="$2"
    local has_backend="$3"

    echo "| Role | Agent | Model | Invocation |"
    echo "|------|-------|-------|------------|"
    echo "| **Leader / Evaluator** | Claude Opus | claude-opus-4-6 | Current session |"
    echo "| **Researcher** | Gemini CLI | gemini-3.1-pro-preview | \`timeout 300 gemini -p \"...\" -y\` |"

    case "$type" in
        fullstack)
            echo "| **Frontend** | Gemini CLI | gemini-3.1-pro-preview | \`timeout 180 gemini -p \"...\" -y\` |"
            echo "| **Backend** | Codex CLI | gpt-5.4 | \`timeout 180 codex exec \"...\" --full-auto\` |"
            echo "| **Senior Fullstack** | Opus Agent | claude-opus-4-6 | Agent tool, isolation: worktree |"
            ;;
        frontend)
            echo "| **Frontend Lead** | Gemini CLI | gemini-3.1-pro-preview | \`timeout 180 gemini -p \"...\" -y\` |"
            echo "| **Senior Fullstack** | Opus Agent | claude-opus-4-6 | Agent tool, isolation: worktree |"
            ;;
        backend)
            echo "| **Backend Lead** | Codex CLI | gpt-5.4 | \`timeout 180 codex exec \"...\" --full-auto\` |"
            echo "| **Senior Fullstack** | Opus Agent | claude-opus-4-6 | Agent tool, isolation: worktree |"
            ;;
        library|unknown)
            echo "| **Senior Fullstack** | Opus Agent | claude-opus-4-6 | Agent tool, isolation: worktree |"
            ;;
    esac
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
    local cmd="${1:-help}"
    shift || true

    case "$cmd" in
        init)    cmd_init "$@" ;;
        adapt)   cmd_adapt "$@" ;;
        update)  cmd_update "$@" ;;
        version) cmd_version ;;
        -v)      cmd_version ;;
        --version) cmd_version ;;
        help|--help|-h)
            echo "selfmodel $SELFMODEL_VERSION — AI Agent Team Workflow"
            echo ""
            echo "Usage: selfmodel <command> [directory]"
            echo ""
            echo "Commands:"
            echo "  init     Initialize selfmodel in a new or existing project"
            echo "  adapt    Adapt selfmodel to an existing project (non-destructive)"
            echo "  update   Update playbook files to latest version"
            echo "  version  Show version"
            echo ""
            echo "Examples:"
            echo "  selfmodel init                # Initialize in current directory"
            echo "  selfmodel init ./my-project   # Initialize in specific directory"
            echo "  selfmodel adapt               # Adapt to existing project"
            echo "  selfmodel update              # Update playbook to latest"
            ;;
        *)
            err "Unknown command: $cmd"
            err "Run 'selfmodel help' for usage."
            exit 1
            ;;
    esac
}

main "$@"
