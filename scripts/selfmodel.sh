#!/usr/bin/env bash
# selfmodel — AI Agent Team 工作流初始化与适配工具
# Usage: selfmodel [command] [options]
# With no args, shows smart dashboard. Run selfmodel --help for full reference.
# Requires: jq (for JSON processing). macOS + Linux.
set -eo pipefail

SELFMODEL_VERSION="0.5.0"
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

# Cross-platform sed -i
sed_inplace() {
    if [[ "$(uname)" == "Darwin" ]]; then
        sed -i '' "$@"
    else
        sed -i "$@"
    fi
}

# Check required dependencies
check_deps() {
    if ! command -v jq &>/dev/null; then
        err "jq is required but not installed."
        err "Install: brew install jq (macOS) or apt install jq (Linux)"
        exit 1
    fi
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
        # Check both pyproject.toml and requirements.txt for Python frameworks
        local py_deps=""
        [[ -f "$dir/pyproject.toml" ]] && py_deps+=$(cat "$dir/pyproject.toml" 2>/dev/null)
        [[ -f "$dir/requirements.txt" ]] && py_deps+=$(cat "$dir/requirements.txt" 2>/dev/null)
        if [[ -n "$py_deps" ]]; then
            echo "$py_deps" | grep -qi 'django' && frameworks+=("django")
            echo "$py_deps" | grep -qi 'flask' && frameworks+=("flask")
            echo "$py_deps" | grep -qi 'fastapi' && frameworks+=("fastapi")
        fi
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
    if [[ -f "$dir/Package.swift" ]] || ls "$dir"/*.xcodeproj &>/dev/null; then
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

    # Leader + Researcher + Evaluator are always present
    local agents='"leader": {"status": "idle", "role": "leader_orchestrator"}'
    agents+=', "researcher": {"status": "idle", "role": "researcher", "config": {"engine": "gemini-cli", "model": "gemini-3.1-pro-preview", "timeout": 300, "requires_worktree": false}}'
    agents+=', "evaluator": {"status": "idle", "role": "independent_evaluator", "evaluations_completed": 0, "avg_score_given": 0, "channel": "opus-agent", "fallback_channel": "gemini", "config": {"timeout": 120, "requires_worktree": false, "skeptical_prompt": true}}'
    agents+=', "e2e": {"status": "idle", "role": "e2e_verifier", "verifications_completed": 0, "pass_rate": 0, "last_sprint": null, "config": {"engine": "opus-agent", "timeout": 300, "requires_worktree": true, "fallback_engine": "gemini-cli", "protocol_version": "2.0"}}'

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
    mkdir -p "$dir/.selfmodel/inbox/evaluator"
    mkdir -p "$dir/.selfmodel/inbox/e2e"
    mkdir -p "$dir/.selfmodel/reviews"
    mkdir -p "$dir/.selfmodel/state"
    mkdir -p "$dir/.selfmodel/playbook"
    mkdir -p "$dir/.selfmodel/wiki/modules"
    mkdir -p "$dir/.selfmodel/wiki/decisions"
    mkdir -p "$dir/.selfmodel/wiki/patterns"
    mkdir -p "$dir/.selfmodel/wiki/entities"

    # .gitkeep for empty directories
    for d in contracts/active contracts/archive inbox/gemini inbox/codex inbox/opus inbox/research inbox/evaluator inbox/e2e reviews wiki/modules wiki/decisions wiki/patterns wiki/entities; do
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
    [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]] && {
        echo "Usage: selfmodel init [directory]"
        echo ""
        echo "  Initialize selfmodel in a new or existing project."
        echo "  Creates .selfmodel/ structure, generates CLAUDE.md, and detects project stack."
        echo ""
        echo "Arguments:"
        echo "  directory    Target directory (default: current directory)"
        return 0
    }

    local dir="${1:-.}"

    # Validate path
    if [[ "$dir" != "." && ! -e "$dir" ]]; then
        err "Directory does not exist: $dir"
        exit 1
    fi
    if [[ "$dir" != "." && -e "$dir" && ! -d "$dir" ]]; then
        err "Path is not a directory: $dir"
        exit 1
    fi

    info "Initializing selfmodel in $(bold "$dir")"

    # Idempotent: if .selfmodel/ already exists, run non-destructive adapt logic
    if [[ -d "$dir/.selfmodel" ]]; then
        info ".selfmodel/ exists. Running non-destructive update..."
        _adapt_existing_project "$dir"
        return 0
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

    # Generate project wiki scaffolding
    generate_wiki "$dir"

    # Generate hooks and merge settings.json
    generate_hooks "$dir"

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

# ─── Adapt Helper: non-destructive update for existing .selfmodel/ ────────────
# Extracted from old cmd_adapt so both cmd_init (idempotent) and cmd_adapt
# (deprecated alias) share the same body.  Takes one arg: target directory.
_adapt_existing_project() {
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
        info ".selfmodel/ exists. Updating detected_stack only (preserving agents/history)..."
        # Selective update: only detected_stack and protocol_version, NOT agents
        if [[ -f "$dir/.selfmodel/state/team.json" ]]; then
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
            local tmp
            tmp=$(mktemp)
            jq --arg ver "$SELFMODEL_VERSION" \
               --argjson stacks "$stacks_json" \
               --argjson frameworks "$frameworks_json" \
               --argjson tests "$test_tools_json" \
               --arg type "$DETECTED_TYPE" \
               --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
               '.evolution.protocol_version = $ver |
                .detected_stack = {"type": $type, "stacks": $stacks, "frameworks": $frameworks, "test_tools": $tests} |
                .meta.last_modified = $ts |
                .meta.last_modified_by = "selfmodel-adapt"' \
               "$dir/.selfmodel/state/team.json" > "$tmp" && mv "$tmp" "$dir/.selfmodel/state/team.json"
            ok "team.json updated (agents preserved)."
        fi
    fi

    # Generate hooks and merge settings.json
    generate_hooks "$dir"

    # Handle wiki — full generate if missing, reconcile if exists
    if [[ ! -d "$dir/.selfmodel/wiki" ]]; then
        info "No wiki/ found. Generating full wiki scaffolding..."
        generate_wiki "$dir"
    else
        info "Wiki exists. Reconciling modules..."
        reconcile_wiki "$dir"
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

# ─── CMD: adapt (deprecated — delegates to cmd_init) ─────────────────────────
cmd_adapt() {
    warn "'selfmodel adapt' is deprecated. Use 'selfmodel init' (now idempotent)."
    cmd_init "$@"
}

# ─── CMD: update ──────────────────────────────────────────────────────────────
cmd_update() {
    [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]] && {
        echo "Usage: selfmodel update [directory] [flags]"
        echo ""
        echo "  Update selfmodel playbook files."
        echo "  Re-detects project stack and regenerates playbook from templates."
        echo ""
        echo "Arguments:"
        echo "  directory        Target directory (default: current directory)"
        echo ""
        echo "Flags:"
        echo "  --remote         Fetch latest playbook from GitHub instead of local templates"
        echo "  --version TAG    Specify GitHub tag/branch to fetch (requires --remote, default: main)"
        return 0
    }

    local dir="."
    local remote=false
    local version="main"

    # Parse flags
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --remote)  remote=true; shift ;;
            --version) version="$2"; shift 2 ;;
            *)         dir="$1"; shift ;;
        esac
    done

    # Warn if --version used without --remote
    if [[ "$remote" == "false" && "$version" != "main" ]]; then
        warn "--version requires --remote, ignoring"
    fi

    info "Updating selfmodel playbook in $(bold "$dir")"

    if [[ ! -d "$dir/.selfmodel" ]]; then
        err "No .selfmodel/ found. Run 'selfmodel init' or 'selfmodel adapt' first."
        exit 1
    fi

    if [[ "$remote" == "true" ]]; then
        remote_update "$dir" "$version"
        return $?
    fi

    # ── Local update (original behavior) ─────────────────────────────────────

    # Re-detect stack (project may have evolved)
    detect_stack "$dir"
    info "Re-detected: $(bold "$DETECTED_TYPE") project"

    # Update playbook files (framework layer)
    generate_playbook "$dir"

    # Update hooks and merge settings.json
    generate_hooks "$dir"

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

# ─── Remote Update ──────────────────────────────────────────────────────────
# Download latest playbook + hooks from GitHub tarball and sync to local
remote_update() {
    local dir="${1:-.}"
    local version="${2:-main}"
    local repo="VictorVVedtion/selfmodel"
    local tmp_dir
    tmp_dir=$(mktemp -d)
    local ts
    ts=$(date +%s)

    # Determine tarball URL: tags use /tags/, branches use /heads/
    local tarball_url
    if [[ "$version" == v* ]]; then
        tarball_url="https://github.com/$repo/archive/refs/tags/$version.tar.gz"
    else
        tarball_url="https://github.com/$repo/archive/refs/heads/$version.tar.gz"
    fi

    info "Fetching selfmodel $version from GitHub..."
    info "URL: $tarball_url"

    # 1. Download tarball to temp directory
    if ! curl -f -sS -L --connect-timeout 10 --max-time 60 \
         "$tarball_url" | tar -xz -C "$tmp_dir" 2>/dev/null; then
        err "Failed to download from GitHub. Local files unchanged."
        rm -rf "$tmp_dir"
        return 1
    fi

    # 2. Find extracted root directory (selfmodel-main/ or selfmodel-v1.0.0/)
    local extracted
    extracted=$(ls -d "$tmp_dir"/selfmodel-* 2>/dev/null | head -1)
    if [[ -z "$extracted" || ! -d "$extracted" ]]; then
        err "Unexpected archive structure. Local files unchanged."
        rm -rf "$tmp_dir"
        return 1
    fi

    ok "Downloaded and extracted successfully."

    # 3. Sync playbook/*.md (backup → overwrite)
    local sync_count=0
    if [[ -d "$extracted/.selfmodel/playbook" ]]; then
        mkdir -p "$dir/.selfmodel/playbook"
        for f in "$extracted/.selfmodel/playbook/"*.md; do
            [[ -f "$f" ]] || continue
            local name
            name=$(basename "$f")
            local target="$dir/.selfmodel/playbook/$name"
            if [[ -f "$target" ]]; then
                cp "$target" "${target}.bak.${ts}"
                info "Backed up: playbook/$name → .bak.${ts}"
            fi
            cp "$f" "$target"
            ok "Updated: playbook/$name"
            sync_count=$((sync_count + 1))
        done
    else
        warn "No playbook/ found in remote archive."
    fi

    # 4. Sync hooks/*.sh (backup → overwrite → chmod)
    if [[ -d "$extracted/scripts/hooks" ]]; then
        mkdir -p "$dir/scripts/hooks"
        for f in "$extracted/scripts/hooks/"*.sh; do
            [[ -f "$f" ]] || continue
            local name
            name=$(basename "$f")
            local target="$dir/scripts/hooks/$name"
            if [[ -f "$target" ]]; then
                cp "$target" "${target}.bak.${ts}"
                info "Backed up: hooks/$name → .bak.${ts}"
            fi
            cp "$f" "$target"
            chmod +x "$target"
            ok "Updated: hooks/$name"
            sync_count=$((sync_count + 1))
        done
    else
        warn "No scripts/hooks/ found in remote archive."
    fi

    # 5. Sync scripts/*.sh (root-level scripts including selfmodel.sh, verify-delivery.sh)
    if [[ -d "$extracted/scripts" ]]; then
        mkdir -p "$dir/scripts"
        for f in "$extracted/scripts/"*.sh; do
            [[ -f "$f" ]] || continue
            local name
            name=$(basename "$f")
            local target="$dir/scripts/$name"
            if [[ -f "$target" ]]; then
                cp "$target" "${target}.bak.${ts}"
                info "Backed up: scripts/$name → .bak.${ts}"
            fi
            cp "$f" "$target"
            chmod +x "$target"
            ok "Updated: scripts/$name"
            sync_count=$((sync_count + 1))
        done
    fi

    # 6. Update VERSION file
    if [[ -f "$extracted/VERSION" ]]; then
        cp "$extracted/VERSION" "$dir/VERSION"
        ok "VERSION updated to $(cat "$dir/VERSION")"
    fi

    # 7. CLAUDE.md — only update selfmodel:start/end block if markers exist
    if [[ -f "$extracted/CLAUDE.md" && -f "$dir/CLAUDE.md" ]]; then
        if grep -q '<!-- selfmodel:start -->' "$dir/CLAUDE.md" 2>/dev/null \
           && grep -q '<!-- selfmodel:start -->' "$extracted/CLAUDE.md" 2>/dev/null; then
            # Extract new block from remote
            local new_block
            new_block=$(sed -n '/<!-- selfmodel:start -->/,/<!-- selfmodel:end -->/p' "$extracted/CLAUDE.md")
            if [[ -n "$new_block" ]]; then
                cp "$dir/CLAUDE.md" "$dir/CLAUDE.md.bak.${ts}"
                # Remove old block
                sed_inplace '/<!-- selfmodel:start -->/,/<!-- selfmodel:end -->/d' "$dir/CLAUDE.md"
                # Append new block
                echo "$new_block" >> "$dir/CLAUDE.md"
                ok "CLAUDE.md selfmodel block updated (user content preserved)."
                sync_count=$((sync_count + 1))
            fi
        else
            info "CLAUDE.md: no selfmodel markers found. Skipped (manual sync needed)."
        fi
    fi

    # 8. Seed dispatch-config.json (only if not present — never overwrite user config)
    if [[ -f "$extracted/.selfmodel/state/dispatch-config.json" ]]; then
        local target="$dir/.selfmodel/state/dispatch-config.json"
        if [[ ! -f "$target" ]]; then
            mkdir -p "$dir/.selfmodel/state"
            cp "$extracted/.selfmodel/state/dispatch-config.json" "$target"
            ok "Created: dispatch-config.json (new — edit convergence_files for your project)"
            sync_count=$((sync_count + 1))
        else
            info "dispatch-config.json already exists. Skipped (user config preserved)."
        fi
    fi

    # 9. NOT synced: state/{team.json,plan.md,...}, contracts/, inbox/ (project-specific data)
    #    These directories contain per-project state and must not be overwritten.

    # 9. Cleanup
    rm -rf "$tmp_dir"

    echo ""
    ok "Remote update complete! ($version, $sync_count files synced)"
}

# ─── CMD: version ─────────────────────────────────────────────────────────────
cmd_version() {
    [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]] && {
        echo "Usage: selfmodel version"
        echo ""
        echo "  Print the selfmodel version."
        return 0
    }
    echo "selfmodel $SELFMODEL_VERSION"
}

# ─── CMD: status ──────────────────────────────────────────────────────────────
cmd_status() {
    [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]] && {
        echo "Usage: selfmodel status [directory]"
        echo ""
        echo "  Show selfmodel project status."
        echo "  Displays team state, active contracts, worktrees, and quality trends."
        echo ""
        echo "Arguments:"
        echo "  directory    Target directory (default: current directory)"
        return 0
    }

    local dir="${1:-.}"
    local selfmodel_dir="$dir/.selfmodel"

    if [[ ! -d "$selfmodel_dir" ]]; then
        err "No .selfmodel/ directory found. Run 'selfmodel init' first."
        exit 1
    fi

    echo "═══════════════════════════════════════════════════"
    echo " selfmodel status — v$SELFMODEL_VERSION"
    echo "═══════════════════════════════════════════════════"

    # Team state
    if [[ -f "$selfmodel_dir/state/team.json" ]]; then
        local sprint version
        sprint=$(jq -r '.current_sprint // 0' "$selfmodel_dir/state/team.json" 2>/dev/null)
        version=$(jq -r '.evolution.protocol_version // "unknown"' "$selfmodel_dir/state/team.json" 2>/dev/null)
        echo "Protocol: v$version | Sprint: $sprint"
    else
        warn "team.json not found"
    fi

    # Active contracts
    local active archived
    active=$(find "$selfmodel_dir/contracts/active" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
    archived=$(find "$selfmodel_dir/contracts/archive" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
    echo "Contracts: $active active | $archived archived"

    # Active worktrees
    local worktrees
    worktrees=$(git -C "$dir" worktree list 2>/dev/null | grep -v "bare" | grep -v "$(cd "$dir" && pwd) " | wc -l | tr -d ' ') || worktrees=0
    echo "Worktrees: $worktrees active"

    # Recent quality scores (last 5)
    if [[ -f "$selfmodel_dir/state/quality.jsonl" ]] && [[ -s "$selfmodel_dir/state/quality.jsonl" ]]; then
        echo "────────────────────────────────────────────────────"
        echo "Recent Scores (last 5):"
        tail -5 "$selfmodel_dir/state/quality.jsonl" | while IFS= read -r line; do
            local s a w v
            s=$(echo "$line" | jq -r '.sprint // "?"' 2>/dev/null)
            a=$(echo "$line" | jq -r '.agent // "?"' 2>/dev/null)
            w=$(echo "$line" | jq -r '.weighted // 0' 2>/dev/null)
            v=$(echo "$line" | jq -r '.verdict // "?"' 2>/dev/null)
            printf "  Sprint %-3s %-8s %s %s\n" "$s" "$a" "$w" "$v"
        done
    fi

    # Lessons count
    local lessons auto_learned
    lessons=$(grep -c "^### Sprint" "$selfmodel_dir/playbook/lessons-learned.md" 2>/dev/null || echo 0)
    if [[ -f "$selfmodel_dir/state/hook-intercepts.log" ]]; then
        auto_learned=$(wc -l < "$selfmodel_dir/state/hook-intercepts.log" | tr -d ' ')
    else
        auto_learned=0
    fi
    echo "────────────────────────────────────────────────────"
    echo "Lessons: $lessons formal | $auto_learned auto-learned"

    # Playbook consistency
    echo "────────────────────────────────────────────────────"
    local playbook_files=("dispatch-rules.md" "quality-gates.md" "sprint-template.md" \
        "evaluator-prompt.md" "e2e-protocol.md" "e2e-protocol-v2.md" "orchestration-loop.md" \
        "research-protocol.md" "context-protocol.md" "lessons-learned.md" "wiki-protocol.md")
    local missing=0
    for f in "${playbook_files[@]}"; do
        if [[ ! -f "$selfmodel_dir/playbook/$f" ]]; then
            missing=$((missing + 1))
            warn "  MISSING: $f"
        fi
    done
    if [[ $missing -eq 0 ]]; then
        ok "Playbook: all ${#playbook_files[@]} files present"
    fi

    # Wiki health
    echo "────────────────────────────────────────────────────"
    local wiki_dir="$selfmodel_dir/wiki"
    if [[ -d "$wiki_dir" ]]; then
        local wiki_pages wiki_modules wiki_stale wiki_empty wiki_score

        # Count all .md pages (excluding log.md which is append-only)
        wiki_pages=$(find "$wiki_dir" -name "*.md" ! -name "log.md" 2>/dev/null | wc -l | tr -d ' ')

        # Count module pages
        wiki_modules=0
        if [[ -d "$wiki_dir/modules" ]]; then
            wiki_modules=$(find "$wiki_dir/modules" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
        fi

        # Stale detection: pages without "## Last Updated" line
        wiki_stale=0
        while IFS= read -r page; do
            [[ -z "$page" ]] && continue
            if ! grep -q "^## Last Updated" "$page" 2>/dev/null; then
                wiki_stale=$((wiki_stale + 1))
            fi
        done < <(find "$wiki_dir" -name "*.md" ! -name "log.md" 2>/dev/null)

        # Empty detection: pages with <= 3 lines (excluding schema.md and log.md)
        wiki_empty=0
        while IFS= read -r page; do
            [[ -z "$page" ]] && continue
            local basename_page
            basename_page=$(basename "$page")
            if [[ "$basename_page" == "schema.md" || "$basename_page" == "log.md" ]]; then
                continue
            fi
            local line_count
            line_count=$(wc -l < "$page" | tr -d ' ')
            if [[ "$line_count" -le 3 ]]; then
                wiki_empty=$((wiki_empty + 1))
            fi
        done < <(find "$wiki_dir" -name "*.md" 2>/dev/null)

        # Health score: 10 - empty_count - (stale > 2 ? 2 : 0), minimum 0
        wiki_score=10
        wiki_score=$((wiki_score - wiki_empty))
        if [[ "$wiki_stale" -gt 2 ]]; then
            wiki_score=$((wiki_score - 2))
        fi
        if [[ "$wiki_score" -lt 0 ]]; then
            wiki_score=0
        fi

        echo "Wiki: $wiki_pages pages ($wiki_modules modules) | $wiki_stale stale | $wiki_empty empty | health: $wiki_score/10"
    else
        warn "Wiki: not initialized (run 'selfmodel init' or 'selfmodel adapt')"
    fi

    echo "═══════════════════════════════════════════════════"
}

# ─── Generate Wiki ───────────────────────────────────────────────────────────

# Code file extensions used to detect whether a directory contains code
WIKI_CODE_EXTENSIONS='*.py *.js *.ts *.tsx *.jsx *.go *.rs *.rb *.java *.kt *.swift *.c *.cpp *.h *.cs *.php *.sh *.lua *.ex *.exs *.zig *.nim *.ml *.hs *.scala *.clj'

# Find code files in a directory (bash 3.2 compatible — no negative array indices)
_wiki_find_code() {
    local search_dir="$1"
    local depth="${2:-2}"
    local first_only="${3:-}"
    local args=""
    local first=true
    for ext in $WIKI_CODE_EXTENSIONS; do
        if $first; then
            args="-name $ext"
            first=false
        else
            args="$args -o -name $ext"
        fi
    done
    if [[ -n "$first_only" ]]; then
        eval "find \"$search_dir\" -maxdepth $depth -type f \\( $args \\) 2>/dev/null | head -1"
    else
        eval "find \"$search_dir\" -maxdepth $depth -type f \\( $args \\) 2>/dev/null | head -10"
    fi
}

# Directories excluded from module scanning
WIKI_EXCLUDE_PATTERN='^(\.|node_modules|__pycache__|\.venv|venv|vendor|dist|build|\.selfmodel|\.claude|\.github|\.vscode|\.idea|\.next|\.nuxt|coverage|tmp|temp|\.cache|\.turbo|target|out|bin|obj)$'

# Generate a skeleton module page for a detected code directory
generate_module_page() {
    local wiki_dir="$1"
    local project_dir="$2"
    local module_name="$3"

    local module_file="$wiki_dir/modules/${module_name}.md"

    # Collect up to 10 key files in this module (by extension)
    local key_files=()
    while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        local rel="${f#"$project_dir"/}"
        key_files+=("$rel")
    done < <(_wiki_find_code "$project_dir/$module_name" 3)

    cat > "$module_file" << MODEOF
# ${module_name}

## Overview
Module detected during project scaffolding. Update this section with a description of what \`${module_name}/\` contains and its role in the architecture.

## Key Files
MODEOF

    if [[ ${#key_files[@]} -gt 0 ]]; then
        for kf in "${key_files[@]}"; do
            echo "- \`${kf}\`" >> "$module_file"
        done
    else
        echo "_No code files detected at scan depth._" >> "$module_file"
    fi

    cat >> "$module_file" << 'MODEOF2'

## See Also
_Link related wiki pages here._

## Last Updated
Sprint 0 (init)
MODEOF2
}

# Main wiki generation function — called during init
generate_wiki() {
    local dir="$1"
    local wiki_dir="$dir/.selfmodel/wiki"

    # Ensure wiki subdirectories exist
    mkdir -p "$wiki_dir"/{modules,decisions,patterns,entities}

    # ── 1. schema.md — page format conventions ──────────────────────────────
    cat > "$wiki_dir/schema.md" << 'SCHEMAEOF'
# Wiki Schema

Page format conventions for the project wiki.

---

## Page Structure

Every wiki page follows this skeleton:

```markdown
# Title

## Overview
Brief description: what this is, why it exists.

## Details
In-depth content, code references, diagrams.

## See Also
- [[related-page]]
- [[another-page]]

## Last Updated
Sprint <N> (<date or "init">)
```

## Cross-Link Syntax

Use double-bracket wiki links to reference other pages:
- `[[modules/auth]]` — link to a module page
- `[[decisions/001-database-choice]]` — link to a decision record
- `[[patterns/repository-pattern]]` — link to a pattern page
- `[[entities/user]]` — link to an entity page

## Naming Conventions

- **Module pages**: `modules/<directory-name>.md` — one page per code-bearing top-level directory
- **Decision records**: `decisions/<NNN>-<slug>.md` — numbered, append-only
- **Pattern pages**: `patterns/<pattern-name>.md` — reusable design patterns
- **Entity pages**: `entities/<entity-name>.md` — domain model entities

## Update Rules

1. When a Sprint modifies files in a module, the corresponding `modules/<name>.md` page should be updated.
2. Architectural decisions should be recorded in `decisions/` with rationale and alternatives considered.
3. Updates are logged in `log.md` with timestamp, Sprint reference, and summary.
4. The `index.md` must stay in sync with actual pages — run `selfmodel adapt` to reconcile.

## Lint Rules

1. **Page count vs module count**: every code-bearing directory should have a wiki page.
2. **Stale pages**: pages not updated in the last 10 Sprints are flagged.
3. **Broken internal links**: `[[target]]` must resolve to an existing `.md` file.
4. **Empty pages**: pages with 3 or fewer non-blank lines are flagged as stubs.

## Auto-Sync Spec

Post-merge, compare `git diff --name-only` against `wiki/modules/`. If code in a module directory changed but its wiki page was not updated, append a warning entry to `log.md`:
```
[<timestamp>] WARN: <module> code changed in Sprint <N> but wiki page not updated
```
SCHEMAEOF

    # ── 2. Scan for code-bearing directories ────────────────────────────────
    local module_count=0
    local module_names=()

    for entry in "$dir"/*/; do
        [[ ! -d "$entry" ]] && continue
        local dirname
        dirname=$(basename "$entry")

        # Skip excluded directories
        if [[ "$dirname" =~ $WIKI_EXCLUDE_PATTERN ]]; then
            continue
        fi

        # Check if directory contains code files (up to depth 2)
        local has_code
        has_code=$(_wiki_find_code "$entry" 2 first)
        [[ -z "$has_code" ]] && continue

        # Enforce max 20 modules
        if [[ $module_count -ge 20 ]]; then
            break
        fi

        generate_module_page "$wiki_dir" "$dir" "$dirname"
        module_names+=("$dirname")
        module_count=$((module_count + 1))
    done

    # ── 3. architecture.md from detect_stack results ─────────────────────────
    local stacks_str="${DETECTED_STACKS[*]:-none}"
    local frameworks_str="${DETECTED_FRAMEWORKS[*]:-none}"
    local test_tools_str="${DETECTED_TEST_TOOLS[*]:-none}"

    cat > "$wiki_dir/architecture.md" << ARCHEOF
# Architecture

## Overview
Project architecture seeded from auto-detection. Update this page as the system evolves.

## Project Type
${DETECTED_TYPE:-unknown}

## Tech Stack
- **Languages/Runtimes**: ${stacks_str}
- **Frameworks**: ${frameworks_str}
- **Test Tools**: ${test_tools_str}

## Directory Tree
ARCHEOF

    # Add top-level directory listing (non-hidden, non-excluded)
    for entry in "$dir"/*/; do
        [[ ! -d "$entry" ]] && continue
        local dirname
        dirname=$(basename "$entry")
        if [[ "$dirname" =~ $WIKI_EXCLUDE_PATTERN ]]; then
            continue
        fi
        echo "- \`${dirname}/\`" >> "$wiki_dir/architecture.md"
    done

    cat >> "$wiki_dir/architecture.md" << 'ARCHEOF2'

## Key Architectural Decisions
_Record decisions in `decisions/` and link them here._

## See Also
- [[modules/]] — per-module documentation
- [[decisions/]] — architectural decision records

## Last Updated
Sprint 0 (init)
ARCHEOF2

    # ── 4. index.md listing all generated pages ─────────────────────────────
    cat > "$wiki_dir/index.md" << 'INDEXHDR'
# Wiki Index

Auto-generated page index. Run `selfmodel adapt` to reconcile with actual pages.

---

## Core Pages
- [[schema]] — page format conventions
- [[architecture]] — project architecture overview
- [[log]] — wiki change log

## Module Pages
INDEXHDR

    for mod in "${module_names[@]}"; do
        echo "- [[modules/${mod}]]" >> "$wiki_dir/index.md"
    done

    cat >> "$wiki_dir/index.md" << 'INDEXFTR'

## Decision Records
_None yet. Create `decisions/<NNN>-<slug>.md` to add._

## Patterns
_None yet. Create `patterns/<name>.md` to add._

## Entities
_None yet. Create `entities/<name>.md` to add._
INDEXFTR

    # ── 5. log.md with initial entry ─────────────────────────────────────────
    local ts
    ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    cat > "$wiki_dir/log.md" << LOGEOF
# Wiki Log

Chronological record of wiki changes.

---

[${ts}] INIT: wiki created, ${module_count} module page(s) generated
LOGEOF

    ok "Wiki generated: ${module_count} module page(s), schema, architecture, index, log."
}

# Reconcile wiki during adapt — scan for new modules, update index and log
reconcile_wiki() {
    local dir="$1"
    local wiki_dir="$dir/.selfmodel/wiki"

    # Ensure wiki subdirectories exist
    mkdir -p "$wiki_dir"/{modules,decisions,patterns,entities}

    local new_count=0
    local existing_modules=()
    local all_modules=()

    # Collect existing module pages (strip .md extension)
    for f in "$wiki_dir"/modules/*.md; do
        [[ -f "$f" ]] || continue
        local name
        name=$(basename "$f" .md)
        existing_modules+=("$name")
    done

    # Scan for code-bearing directories
    local total_scanned=0
    for entry in "$dir"/*/; do
        [[ ! -d "$entry" ]] && continue
        local dirname
        dirname=$(basename "$entry")

        if [[ "$dirname" =~ $WIKI_EXCLUDE_PATTERN ]]; then
            continue
        fi

        local has_code
        has_code=$(_wiki_find_code "$entry" 2 first)
        [[ -z "$has_code" ]] && continue

        if [[ $total_scanned -ge 20 ]]; then
            break
        fi

        all_modules+=("$dirname")
        total_scanned=$((total_scanned + 1))

        # Check if module page already exists
        local found=false
        for existing in "${existing_modules[@]}"; do
            if [[ "$existing" == "$dirname" ]]; then
                found=true
                break
            fi
        done

        if ! $found; then
            generate_module_page "$wiki_dir" "$dir" "$dirname"
            new_count=$((new_count + 1))
        fi
    done

    # Rebuild index.md with current state
    cat > "$wiki_dir/index.md" << 'INDEXHDR'
# Wiki Index

Auto-generated page index. Run `selfmodel adapt` to reconcile with actual pages.

---

## Core Pages
- [[schema]] — page format conventions
- [[architecture]] — project architecture overview
- [[log]] — wiki change log

## Module Pages
INDEXHDR

    for mod in "${all_modules[@]}"; do
        echo "- [[modules/${mod}]]" >> "$wiki_dir/index.md"
    done

    # Include any manually-created module pages not in the scan
    for existing in "${existing_modules[@]}"; do
        local in_all=false
        for mod in "${all_modules[@]}"; do
            if [[ "$mod" == "$existing" ]]; then
                in_all=true
                break
            fi
        done
        if ! $in_all; then
            echo "- [[modules/${existing}]]" >> "$wiki_dir/index.md"
        fi
    done

    # Add decision, pattern, entity sections by scanning actual files
    echo "" >> "$wiki_dir/index.md"
    echo "## Decision Records" >> "$wiki_dir/index.md"
    local has_decisions=false
    for f in "$wiki_dir"/decisions/*.md; do
        [[ -f "$f" ]] || continue
        local name
        name=$(basename "$f" .md)
        echo "- [[decisions/${name}]]" >> "$wiki_dir/index.md"
        has_decisions=true
    done
    if ! $has_decisions; then
        echo "_None yet. Create \`decisions/<NNN>-<slug>.md\` to add._" >> "$wiki_dir/index.md"
    fi

    echo "" >> "$wiki_dir/index.md"
    echo "## Patterns" >> "$wiki_dir/index.md"
    local has_patterns=false
    for f in "$wiki_dir"/patterns/*.md; do
        [[ -f "$f" ]] || continue
        local name
        name=$(basename "$f" .md)
        echo "- [[patterns/${name}]]" >> "$wiki_dir/index.md"
        has_patterns=true
    done
    if ! $has_patterns; then
        echo "_None yet. Create \`patterns/<name>.md\` to add._" >> "$wiki_dir/index.md"
    fi

    echo "" >> "$wiki_dir/index.md"
    echo "## Entities" >> "$wiki_dir/index.md"
    local has_entities=false
    for f in "$wiki_dir"/entities/*.md; do
        [[ -f "$f" ]] || continue
        local name
        name=$(basename "$f" .md)
        echo "- [[entities/${name}]]" >> "$wiki_dir/index.md"
        has_entities=true
    done
    if ! $has_entities; then
        echo "_None yet. Create \`entities/<name>.md\` to add._" >> "$wiki_dir/index.md"
    fi

    # Append to log.md
    local ts
    ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    echo "[${ts}] ADAPT: wiki reconciled, ${new_count} new module page(s) added, ${total_scanned} total modules" >> "$wiki_dir/log.md"

    if [[ $new_count -gt 0 ]]; then
        ok "Wiki reconciled: ${new_count} new module page(s) added."
    else
        ok "Wiki reconciled: no new modules detected."
    fi
}

# ─── Generate Playbook ────────────────────────────────────────────────────────
generate_playbook() {
    local dir="${1:-.}"

    # sprint-template.md — only generate if missing (selfmodel update --remote overwrites)
    if [[ ! -f "$dir/.selfmodel/playbook/sprint-template.md" ]]; then
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
    fi

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

    if [[ ! -f "$dir/.selfmodel/playbook/wiki-protocol.md" ]]; then
        info "Generating wiki-protocol.md..."
        generate_wiki_protocol "$dir"
    fi

    ok "Playbook generated."
}

# ─── Generate wiki-protocol.md ──────────────────────────────────────────────
generate_wiki_protocol() {
    local dir="${1:-.}"
    cat > "$dir/.selfmodel/playbook/wiki-protocol.md" << 'WIKIEOF'
# Wiki Protocol

Project knowledge wiki maintenance protocol. Agents and Leader follow these rules to keep the wiki accurate and useful.

---

## Page Format

Every wiki page uses this structure:

```markdown
# Title

## Overview
Brief description: what this is, why it exists.

## Details
In-depth content, code references, architecture notes, diagrams.

## See Also
- [[related-page]]

## Last Updated
Sprint <N> (<date or "init">)
```

### Page Types

| Type | Location | Naming | Purpose |
|------|----------|--------|---------|
| Module | `wiki/modules/<dir-name>.md` | matches top-level directory name | per-module documentation |
| Decision | `wiki/decisions/<NNN>-<slug>.md` | numbered, append-only | architectural decision records |
| Pattern | `wiki/patterns/<pattern-name>.md` | descriptive slug | reusable design patterns |
| Entity | `wiki/entities/<entity-name>.md` | domain noun | domain model entities |

---

## Update Rules

### Sprint-Level Updates

1. **Contract declaration**: Sprint contracts SHOULD include a `## Wiki Impact` section listing wiki pages that need updating.
2. **Agent responsibility**: When a Sprint modifies code in a module, the agent SHOULD update the corresponding `wiki/modules/<name>.md` page with relevant changes.
3. **Leader validation**: During post-merge review (Step 7), Leader checks if code-changed modules have corresponding wiki page updates. Missing updates are logged to `wiki/log.md` as warnings, not treated as blockers.

### Update Workflow

```
1. Agent modifies code in src/auth/
2. Agent updates wiki/modules/src.md (or wiki/modules/auth.md if nested)
3. Agent updates "## Last Updated" to current Sprint number
4. Leader verifies wiki update in post-merge diff review
5. If missed: Leader appends warning to wiki/log.md
```

### Decision Records

- Create a new decision record when making significant architectural choices.
- Decision records are append-only — never modify past decisions.
- Format: `decisions/<NNN>-<descriptive-slug>.md` where NNN is zero-padded sequential.
- Include: context, options considered, chosen option, rationale, consequences.

---

## Lint Rules

These rules detect wiki staleness and inconsistency:

### 1. Page Count vs Module Count
Every code-bearing top-level directory should have a corresponding `wiki/modules/<name>.md` page. Run `selfmodel adapt` to auto-generate missing pages.

**Detection**: Compare `ls -d */` (excluding ignored dirs) against `ls wiki/modules/*.md`.

### 2. Stale Pages
Pages not updated in the last 10 Sprints are flagged as potentially stale.

**Detection**: Parse `## Last Updated` line, extract Sprint number, compare against current Sprint from `team.json`.

### 3. Broken Internal Links
Wiki links (`[[target]]`) must resolve to an existing `.md` file under `wiki/`.

**Detection**: Extract all `[[...]]` references, verify each resolves to a file at `wiki/<reference>.md`.

### 4. Empty Pages
Pages with 3 or fewer non-blank lines are flagged as stubs needing content.

**Detection**: `awk 'NF' <file> | wc -l` for each wiki page.

---

## Auto-Sync Spec

Post-merge automation to detect wiki-code drift:

### Trigger
After each Sprint merge to main.

### Detection Logic
```bash
# 1. Get changed code files from Sprint
changed_dirs=$(git diff --name-only HEAD~1..HEAD | \
  grep -v '^\.' | \
  cut -d/ -f1 | \
  sort -u)

# 2. For each changed dir, check if wiki page was also updated
for dir_name in $changed_dirs; do
    wiki_page="wiki/modules/${dir_name}.md"
    if [ -f ".selfmodel/$wiki_page" ]; then
        # Check if wiki page was in the diff
        if ! git diff --name-only HEAD~1..HEAD | grep -q ".selfmodel/$wiki_page"; then
            # Wiki page exists but was not updated
            echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] WARN: ${dir_name} code changed but wiki page not updated" >> .selfmodel/wiki/log.md
        fi
    fi
done
```

### Output
Warnings are appended to `wiki/log.md`. They are informational — they do not block merges or fail CI.

---

## Wiki Scaffolding

### During `selfmodel init`
1. `create_structure()` creates `wiki/{modules,decisions,patterns,entities}` with `.gitkeep` files.
2. `generate_wiki()` creates:
   - `schema.md` — page format conventions
   - `modules/<name>.md` — skeleton page for each detected code-bearing directory (max 20)
   - `architecture.md` — seeded from `detect_stack` results
   - `index.md` — listing all generated pages
   - `log.md` — with initial INIT entry

### During `selfmodel adapt`
1. If `wiki/` missing → full `generate_wiki()` run.
2. If `wiki/` exists → `reconcile_wiki()`:
   - Scan for new code-bearing directories not yet in `wiki/modules/`.
   - Generate skeleton pages for new modules.
   - Rebuild `index.md` from current state.
   - Append ADAPT entry to `log.md`.

### Excluded Directories
The following directories are never treated as modules:
`.git`, `node_modules`, `__pycache__`, `.venv`, `venv`, `vendor`, `dist`, `build`, `.selfmodel`, `.claude`, `.github`, `.vscode`, `.idea`, `.next`, `.nuxt`, `coverage`, `tmp`, `temp`, `.cache`, `.turbo`, `target`, `out`, `bin`, `obj`
WIKIEOF
}

# ─── Generate Hooks ──────────────────────────────────────────────────────────
# Write hook scripts via Heredoc and merge hooks config into settings.json
generate_hooks() {
    local dir="${1:-.}"
    local hooks_dir="$dir/scripts/hooks"
    local settings_file="$dir/.claude/settings.json"
    local ts
    ts=$(date +%s)

    mkdir -p "$hooks_dir"
    mkdir -p "$dir/.claude"

    # ── A. Generate hook scripts ─────────────────────────────────────────────

    # Helper: backup existing file before overwrite
    _backup_hook() {
        local target="$1"
        local name
        name=$(basename "$target")
        if [[ -f "$target" ]]; then
            local bak="${target}.bak.${ts}"
            cp "$target" "$bak"
            info "Backed up: ${name} → .bak.${ts}"
        fi
    }

    # 1. session-start.sh
    _backup_hook "$hooks_dir/session-start.sh"
    cat > "$hooks_dir/session-start.sh" << 'HOOKEOF'
#!/usr/bin/env bash
# session-start.sh — SessionStart hook
# Session 启动时注入 team.json 和 next-session.md 上下文
# 输出内容会被 Claude Code 自动读取作为启动上下文
# 始终 exit 0，绝不阻断启动

set -euo pipefail

# 项目根目录（hook 从项目根运行）
PROJECT_ROOT="${PWD}"

TEAM_JSON="${PROJECT_ROOT}/.selfmodel/state/team.json"
NEXT_SESSION="${PROJECT_ROOT}/.selfmodel/state/next-session.md"

echo "═══════════════════════════════════════════════════"
echo "📋 Session Start — 自动上下文注入"
echo "═══════════════════════════════════════════════════"

# 注入 team.json
echo ""
echo "── Team State ──"
if [[ -f "${TEAM_JSON}" ]]; then
    cat "${TEAM_JSON}"
else
    echo "（team.json 不存在，跳过）"
fi

# 注入 next-session.md
echo ""
echo "── Next Session Handoff ──"
if [[ -f "${NEXT_SESSION}" ]]; then
    cat "${NEXT_SESSION}"
else
    echo "（next-session.md 不存在，跳过）"
fi

echo ""
echo "── Wiki Index ──"
WIKI_INDEX="${PROJECT_ROOT}/.selfmodel/wiki/index.md"
if [[ -f "${WIKI_INDEX}" ]]; then
    cat "${WIKI_INDEX}"
else
    echo "(wiki not initialized)"
fi

echo ""
echo "── Wiki Recent ──"
WIKI_LOG="${PROJECT_ROOT}/.selfmodel/wiki/log.md"
if [[ -f "${WIKI_LOG}" ]]; then
    tail -10 "${WIKI_LOG}"
fi

echo ""
echo "═══════════════════════════════════════════════════"

exit 0
HOOKEOF
    chmod +x "$hooks_dir/session-start.sh"
    ok "Hook generated: session-start.sh"

    # 2. enforce-leader-worktree.sh
    _backup_hook "$hooks_dir/enforce-leader-worktree.sh"
    cat > "$hooks_dir/enforce-leader-worktree.sh" << 'HOOKEOF'
#!/usr/bin/env bash
# enforce-leader-worktree.sh — PreToolUse hook (matcher: Write|Edit)
# 强制执行「Leader 不下场」规则：白名单外的代码修改被拦截
# 从 stdin 读取 JSON，提取 tool_input.file_path 进行白名单检查
# exit 0 = 放行 | exit 2 = 拦截

set -euo pipefail

# ── 紧急绕过 ──
if [[ "${BYPASS_LEADER_RULES:-0}" == "1" ]]; then
    exit 0
fi

# ── jq 依赖检测：缺失时放行，绝不误拦截 ──
if ! command -v jq &>/dev/null; then
    exit 0
fi

# ── 读取 stdin ──
INPUT="$(cat)"
if [[ -z "${INPUT}" ]]; then
    exit 0
fi

# ── 提取文件路径 ──
FILE_PATH="$(printf '%s' "${INPUT}" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
if [[ -z "${FILE_PATH}" ]]; then
    # 无法提取路径（可能是非文件操作），放行
    exit 0
fi

# ── 白名单规则 ──
# 规范化路径：移除可能的前导 ./ 和绝对路径前缀
NORMALIZED="${FILE_PATH}"
# 去除绝对路径前缀（如果包含项目根路径）
NORMALIZED="${NORMALIZED#"${PWD}/"}"
# 去除前导 ./
NORMALIZED="${NORMALIZED#./}"

# 1. .selfmodel/ 目录（合约、inbox、state、playbook 等）
if [[ "${NORMALIZED}" == .selfmodel/* ]]; then
    exit 0
fi

# 2. .claude/ 目录（settings、watchdog 等）
if [[ "${NORMALIZED}" == .claude/* ]]; then
    exit 0
fi

# 3. scripts/ 目录（hook 脚本、工具脚本）
if [[ "${NORMALIZED}" == scripts/* ]]; then
    exit 0
fi

# 4. playbook/ 目录（规则文件）
if [[ "${NORMALIZED}" == playbook/* ]]; then
    exit 0
fi

# 5. 任何 .md 文件（Leader 可以写文档）
if [[ "${NORMALIZED}" == *.md ]]; then
    exit 0
fi

# 6. .gitignore
if [[ "${NORMALIZED}" == .gitignore ]]; then
    exit 0
fi

# 7. Project infrastructure files (LICENSE, VERSION, CHANGELOG, etc.)
if [[ "${NORMALIZED}" == LICENSE* || "${NORMALIZED}" == VERSION || "${NORMALIZED}" == CHANGELOG* ]]; then
    exit 0
fi

# 8. .github/ directory (issue templates, PR templates, workflows)
if [[ "${NORMALIZED}" == .github/* ]]; then
    exit 0
fi

# 9. assets/ directory (visual assets, diagrams)
if [[ "${NORMALIZED}" == assets/* ]]; then
    exit 0
fi

# ── 白名单外：拦截 ──
{
    echo "🚨 [Hook 拦截] 违反「Leader 不下场」规则"
    echo ""
    echo "被拦截文件: ${FILE_PATH}"
    echo ""
    echo "Leader 角色只负责编排、审查、仲裁，不直接修改业务代码。"
    echo "白名单范围: .selfmodel/、.claude/、scripts/、playbook/、*.md、.gitignore、LICENSE/VERSION/CHANGELOG、.github/、assets/"
    echo ""
    echo "正确做法:"
    echo "  1. 在 .selfmodel/contracts/active/ 下创建 Sprint 合约"
    echo "  2. 在 .selfmodel/inbox/<agent>/ 下写入任务文件"
    echo "  3. 派遣 Agent（Gemini/Codex/Opus）到独立 worktree 中实现代码修改"
    echo ""
    echo "如需紧急绕过，使用: BYPASS_LEADER_RULES=1"
} >&2

exit 2
HOOKEOF
    chmod +x "$hooks_dir/enforce-leader-worktree.sh"
    ok "Hook generated: enforce-leader-worktree.sh"

    # 3. enforce-agent-rules.sh
    _backup_hook "$hooks_dir/enforce-agent-rules.sh"
    cat > "$hooks_dir/enforce-agent-rules.sh" << 'HOOKEOF'
#!/usr/bin/env bash
# enforce-agent-rules.sh — PreToolUse hook (matcher: Bash)
# 强制执行「合约前置」和「Inbox 缓冲通信」规则
# 检测 gemini/codex 调用命令，确保有活跃合约和 inbox 任务文件
# exit 0 = 放行 | exit 2 = 拦截

set -euo pipefail

# ── 紧急绕过 ──
if [[ "${BYPASS_AGENT_RULES:-0}" == "1" ]]; then
    exit 0
fi

# ── jq 依赖检测：缺失时放行，绝不误拦截 ──
if ! command -v jq &>/dev/null; then
    exit 0
fi

# ── 读取 stdin ──
INPUT="$(cat)"
if [[ -z "${INPUT}" ]]; then
    exit 0
fi

# ── 提取 bash 命令 ──
COMMAND="$(printf '%s' "${INPUT}" | jq -r '.tool_input.command // empty' 2>/dev/null)"
if [[ -z "${COMMAND}" ]]; then
    exit 0
fi

# ── 检测是否为 agent 调用命令 ──
HAS_GEMINI=false
HAS_CODEX=false

# 使用 grep 进行大小写敏感匹配
if printf '%s' "${COMMAND}" | grep -q 'gemini'; then
    HAS_GEMINI=true
fi
if printf '%s' "${COMMAND}" | grep -q 'codex'; then
    HAS_CODEX=true
fi

# 不包含 agent 关键词的普通命令，直接放行
if [[ "${HAS_GEMINI}" == "false" && "${HAS_CODEX}" == "false" ]]; then
    exit 0
fi

# ── 合约前置检查 ──
# 检查 .selfmodel/contracts/active/ 下是否有至少一个 .md 文件
ACTIVE_CONTRACT_COUNT=0
if [[ -d ".selfmodel/contracts/active" ]]; then
    while IFS= read -r -d '' _; do
        ACTIVE_CONTRACT_COUNT=$((ACTIVE_CONTRACT_COUNT + 1))
    done < <(find .selfmodel/contracts/active -maxdepth 1 -name "*.md" -print0 2>/dev/null)
fi

if [[ "${ACTIVE_CONTRACT_COUNT}" -eq 0 ]]; then
    {
        echo "🚨 [Hook 拦截] 违反「Sprint 合约制」规则"
        echo ""
        echo "被拦截命令: ${COMMAND}"
        echo ""
        echo "调用 Agent 前必须有活跃的 Sprint 合约。"
        echo ""
        echo "正确做法:"
        echo "  1. 复制 .selfmodel/playbook/sprint-template.md 为模板"
        echo "  2. 在 .selfmodel/contracts/active/ 下创建合约文件"
        echo "  3. 填写目标、交付物、验收标准"
        echo "  4. 然后再调用 Agent"
        echo ""
        echo "如需紧急绕过，使用: BYPASS_AGENT_RULES=1"
    } >&2
    exit 2
fi

# ── Inbox 缓冲检查 ──
if [[ "${HAS_GEMINI}" == "true" ]]; then
    # Gemini CLI 有两种用途：Frontend (inbox/gemini/) 和 Researcher (inbox/research/)
    # 任一 inbox 有 .md 文件即放行
    GEMINI_INBOX_COUNT=0
    for inbox_dir in ".selfmodel/inbox/gemini" ".selfmodel/inbox/research"; do
        if [[ -d "${inbox_dir}" ]]; then
            while IFS= read -r -d '' _; do
                GEMINI_INBOX_COUNT=$((GEMINI_INBOX_COUNT + 1))
            done < <(find "${inbox_dir}" -maxdepth 1 -name "*.md" -print0 2>/dev/null)
        fi
    done

    if [[ "${GEMINI_INBOX_COUNT}" -eq 0 ]]; then
        {
            echo "🚨 [Hook 拦截] 违反「通信缓冲隔离」规则"
            echo ""
            echo "被拦截命令: ${COMMAND}"
            echo ""
            echo "调用 Gemini CLI 前必须将任务上下文写入 inbox 文件。"
            echo ""
            echo "正确做法:"
            echo "  Frontend 任务: 在 .selfmodel/inbox/gemini/ 下创建任务文件"
            echo "  Researcher 任务: 在 .selfmodel/inbox/research/ 下创建查询文件"
            echo ""
            echo "如需紧急绕过，使用: BYPASS_AGENT_RULES=1"
        } >&2
        exit 2
    fi
fi

if [[ "${HAS_CODEX}" == "true" ]]; then
    CODEX_INBOX_COUNT=0
    if [[ -d ".selfmodel/inbox/codex" ]]; then
        while IFS= read -r -d '' _; do
            CODEX_INBOX_COUNT=$((CODEX_INBOX_COUNT + 1))
        done < <(find .selfmodel/inbox/codex -maxdepth 1 -name "*.md" -print0 2>/dev/null)
    fi

    if [[ "${CODEX_INBOX_COUNT}" -eq 0 ]]; then
        {
            echo "🚨 [Hook 拦截] 违反「通信缓冲隔离」规则"
            echo ""
            echo "被拦截命令: ${COMMAND}"
            echo ""
            echo "调用 Codex Agent 前必须将任务上下文写入 inbox 文件。"
            echo ""
            echo "正确做法:"
            echo "  1. 在 .selfmodel/inbox/codex/ 下创建任务 Markdown 文件"
            echo "  2. 写入详细的任务描述、上下文、约束条件"
            echo "  3. CLI 命令中用 Read 指令引用文件"
            echo "  4. 示例: codex exec \"Read .selfmodel/inbox/codex/sprint-N.md and implement\" --full-auto"
            echo ""
            echo "如需紧急绕过，使用: BYPASS_AGENT_RULES=1"
        } >&2
        exit 2
    fi
fi

# 所有检查通过
exit 0
HOOKEOF
    chmod +x "$hooks_dir/enforce-agent-rules.sh"
    ok "Hook generated: enforce-agent-rules.sh"

    # 4. enforce-dispatch-gate.sh (stub — full version via selfmodel update --remote)
    if [[ ! -f "$hooks_dir/enforce-dispatch-gate.sh" ]]; then
        cat > "$hooks_dir/enforce-dispatch-gate.sh" << 'HOOKEOF'
#!/usr/bin/env bash
# enforce-dispatch-gate.sh — stub (run selfmodel update --remote for full version)
# Gates: parallel cap, convergence files, file overlap
exit 0
HOOKEOF
        chmod +x "$hooks_dir/enforce-dispatch-gate.sh"
        ok "Hook stub generated: enforce-dispatch-gate.sh (run 'selfmodel update --remote' for full version)"
    fi

    # 5. enforce-depth-gate.sh (stub — full version via selfmodel update --remote)
    if [[ ! -f "$hooks_dir/enforce-depth-gate.sh" ]]; then
        cat > "$hooks_dir/enforce-depth-gate.sh" << 'HOOKEOF'
#!/usr/bin/env bash
# enforce-depth-gate.sh — stub (run selfmodel update --remote for full version)
# Gates: contract quality, deep-read deps, understanding phase
exit 0
HOOKEOF
        chmod +x "$hooks_dir/enforce-depth-gate.sh"
        ok "Hook stub generated: enforce-depth-gate.sh (run 'selfmodel update --remote' for full version)"
    fi

    # ── B. Merge settings.json ───────────────────────────────────────────────

    local hooks_config
    hooks_config=$(cat << 'JSONEOF'
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash scripts/hooks/session-start.sh"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "bash scripts/hooks/enforce-leader-worktree.sh"
          }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash scripts/hooks/enforce-agent-rules.sh"
          },
          {
            "type": "command",
            "command": "bash scripts/hooks/enforce-dispatch-gate.sh"
          },
          {
            "type": "command",
            "command": "bash scripts/hooks/enforce-depth-gate.sh"
          }
        ]
      }
    ]
  }
}
JSONEOF
    )

    if [[ ! -f "$settings_file" ]]; then
        # No existing settings.json — write directly
        printf '%s\n' "$hooks_config" > "$settings_file"
        ok "settings.json created with hooks config."
    elif command -v jq &>/dev/null; then
        # Existing settings.json + jq available — deep merge (idempotent)
        if ! jq empty "$settings_file" 2>/dev/null; then
            # Invalid JSON — backup and write fresh
            warn "settings.json has invalid JSON. Backing up and writing fresh config."
            cp "$settings_file" "${settings_file}.bak.${ts}"
            printf '%s\n' "$hooks_config" > "$settings_file"
            ok "settings.json replaced (backup: settings.json.bak.${ts})."
        else
            # Deep merge: existing * hooks_config (hooks key is overwritten for idempotency)
            local tmp
            tmp=$(mktemp)
            if jq -s '.[0] * .[1]' "$settings_file" <(printf '%s\n' "$hooks_config") > "$tmp" 2>/dev/null \
               && jq empty "$tmp" 2>/dev/null; then
                mv "$tmp" "$settings_file"
                ok "settings.json hooks merged."
            else
                rm -f "$tmp"
                warn "jq merge failed. settings.json unchanged."
            fi
        fi
    else
        # No jq — cannot safely merge
        if grep -q '"hooks"' "$settings_file" 2>/dev/null; then
            warn "jq not found. settings.json already has hooks config — skipping (manual merge may be needed)."
        else
            warn "jq not found. Writing default settings.json (manual merge may be needed)."
            cp "$settings_file" "${settings_file}.bak.${ts}"
            printf '%s\n' "$hooks_config" > "$settings_file"
        fi
    fi
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
10. **No Interactive** — All commands: CI=true GIT_TERMINAL_PROMPT=0 timeout <N> <cmd>
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
        sed_inplace '/<!-- selfmodel:start -->/,/<!-- selfmodel:end -->/d' "$dir/CLAUDE.md"
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

# ─── CMD: evolve ──────────────────────────────────────────────────────────────

# Establish upstream baseline reference for diffing.
# Priority: git remote "upstream" → upstream-baseline.sha file → no baseline.
# Outputs the baseline ref to stdout; returns 1 if no baseline found.
evolve_establish_baseline() {
    local dir="$1"

    # Option A: upstream remote exists
    if git -C "$dir" remote get-url upstream &>/dev/null; then
        if git -C "$dir" fetch upstream --quiet 2>/dev/null; then
            echo "upstream/main"
            return 0
        fi
        # Fetch failed but remote exists — try anyway
        if git -C "$dir" rev-parse upstream/main &>/dev/null; then
            echo "upstream/main"
            return 0
        fi
    fi

    # Option B: stored baseline SHA
    local sha_file="$dir/.selfmodel/state/upstream-baseline.sha"
    if [[ -f "$sha_file" ]]; then
        local sha
        sha=$(tr -d '[:space:]' < "$sha_file")
        if [[ -n "$sha" ]] && git -C "$dir" rev-parse "$sha" &>/dev/null; then
            echo "$sha"
            return 0
        fi
    fi

    # No baseline available
    return 1
}

# Scan diffs between baseline and HEAD for playbook/hooks/scripts.
# Outputs one line per changed file: <relative_path>\t<+lines>\t<-lines>
evolve_scan_diffs() {
    local dir="$1"
    local baseline="$2"
    local paths=(".selfmodel/playbook/" ".selfmodel/hooks/" "scripts/")

    for scan_path in "${paths[@]}"; do
        local diff_output
        diff_output=$(git -C "$dir" diff --numstat "${baseline}..HEAD" -- "$scan_path" 2>/dev/null) || continue
        if [[ -n "$diff_output" ]]; then
            echo "$diff_output"
        fi
    done
}

# Scan lessons-learned.md for entries with "Result: improved" that lack a
# corresponding diff. Outputs one line per lesson: <sprint_ref>\t<summary>
evolve_scan_lessons() {
    local dir="$1"
    local lessons_file="$dir/.selfmodel/playbook/lessons-learned.md"

    if [[ ! -f "$lessons_file" ]]; then
        return 0
    fi

    # Extract lesson blocks that have "Result: improved" or "Result: 改善"
    local in_block=false
    local block_sprint=""
    local block_lesson=""
    local block_result_improved=false

    while IFS= read -r line; do
        if [[ "$line" =~ ^###\ Sprint ]]; then
            # Emit previous block if it was improved
            if $block_result_improved && [[ -n "$block_sprint" ]]; then
                printf '%s\t%s\n' "$block_sprint" "$block_lesson"
            fi
            block_sprint="${line#\#\#\# }"
            block_lesson=""
            block_result_improved=false
            in_block=true
        elif $in_block; then
            if [[ "$line" =~ ^-\ \*\*Lesson\*\*:\ (.+) ]]; then
                block_lesson="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ Result:.*improv ]] || [[ "$line" =~ Result:.*改善 ]]; then
                block_result_improved=true
            fi
        fi
    done < "$lessons_file"
    # Emit last block
    if $block_result_improved && [[ -n "$block_sprint" ]]; then
        printf '%s\t%s\n' "$block_sprint" "$block_lesson"
    fi
}

# Scan hook-intercepts.log for patterns with 3+ occurrences of same hook+reason.
# Outputs one line per pattern: <hook>\t<reason>\t<count>
evolve_scan_intercepts() {
    local dir="$1"
    local log_file="$dir/.selfmodel/state/hook-intercepts.log"

    if [[ ! -f "$log_file" ]] || [[ ! -s "$log_file" ]]; then
        return 0
    fi

    # Extract hook+reason pairs and count occurrences
    sed -n 's/.*hook=\([^ ]*\).*reason=\([^ ]*\).*/\1\t\2/p' "$log_file" \
        | sort | uniq -c | sort -rn \
        | while IFS= read -r line; do
            local count hook reason
            count=$(printf '%s' "$line" | awk '{print $1}')
            hook=$(printf '%s' "$line" | awk '{print $2}')
            reason=$(printf '%s' "$line" | awk '{print $3}')
            if [[ "$count" -ge 3 ]] && [[ -n "$hook" ]]; then
                printf '%s\t%s\t%s\n' "$hook" "$reason" "$count"
            fi
        done
}

# Run PATH_DETECTION heuristic on a diff string.
# Outputs: <score>\t<reason>
evolve_heuristic_path_detection() {
    local dir="$1"
    local diff_content="$2"

    local toplevel
    toplevel=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null || echo "$dir")
    local project_dir_name
    project_dir_name=$(basename "$toplevel")

    # Count absolute paths in added lines (lines starting with +, not ++)
    # Exclude lines inside fenced code blocks marked as example/template
    # and lines using placeholder syntax
    local path_count=0
    local in_example_block=false

    while IFS= read -r line; do
        if [[ "$line" =~ ^\+.*\`\`\`.*example ]] || [[ "$line" =~ ^\+.*\`\`\`.*template ]]; then
            in_example_block=true
            continue
        fi
        if [[ "$line" =~ ^\+.*\`\`\` ]] && $in_example_block; then
            in_example_block=false
            continue
        fi
        if $in_example_block; then
            continue
        fi

        # Only look at added lines (not header lines ++)
        if [[ "$line" =~ ^\+[^+] ]] || [[ "$line" =~ ^\+$ ]]; then
            # Skip lines with placeholder syntax
            if echo "$line" | grep -qE '<project-root>/|[$]HOME/|~/[.]config/'; then
                continue
            fi
            # Check for absolute paths
            if echo "$line" | grep -qE '/Users/[^/]+/|/home/[^/]+/'; then
                path_count=$((path_count + 1))
            elif [[ -n "$project_dir_name" ]] && echo "$line" | grep -qE "/($project_dir_name)/"; then
                path_count=$((path_count + 1))
            fi
        fi
    done <<< "$diff_content"

    if [[ "$path_count" -eq 0 ]]; then
        printf '0.0\tno absolute paths detected in diff'
    elif [[ "$path_count" -le 2 ]]; then
        printf '%s\tdiff contains %d absolute path reference(s) — likely project-specific' "-0.4" "$path_count"
    else
        printf '%s\tdiff contains %d absolute path references — definitely project-specific' "-0.8" "$path_count"
    fi
}

# Run PROJECT_NAME_DETECTION heuristic on a diff string.
# Outputs: <score>\t<reason>
evolve_heuristic_project_name_detection() {
    local dir="$1"
    local diff_content="$2"

    # Extract project name from git remote and directory
    local project_name_remote project_name_dir
    project_name_remote=$(git -C "$dir" remote get-url origin 2>/dev/null | sed 's/.*\///' | sed 's/\.git$//' || true)
    project_name_dir=$(basename "$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null || echo "$dir")")

    local project_name="${project_name_remote:-$project_name_dir}"

    if [[ -z "$project_name" ]] || [[ "$project_name" == "." ]]; then
        printf '0.0\tcould not determine project name'
        return
    fi

    # Count occurrences in added lines, excluding file paths and metadata fields
    local name_in_logic=0
    local name_in_hardcoded=0

    while IFS= read -r line; do
        # Only check added lines
        if [[ "$line" =~ ^\+[^+] ]]; then
            # Skip lines that are metadata fields (project_name, CHANGELOG entries)
            if echo "$line" | grep -qiE '"project_name"|changelog|"derived from'; then
                continue
            fi
            # Check for project name in non-path context
            # Use awk to strip path-like segments before checking
            local stripped
            stripped=$(printf '%s' "$line" | awk '{gsub(/\/[^ ]*/, ""); print}')
            if echo "$stripped" | grep -qi "$project_name"; then
                # Check if it's in a conditional or hardcoded string
                if echo "$line" | grep -qE "if.*[\"'].*${project_name}|=.*[\"'].*${project_name}|\[.*${project_name}.*\]"; then
                    name_in_hardcoded=$((name_in_hardcoded + 1))
                else
                    name_in_logic=$((name_in_logic + 1))
                fi
            fi
        fi
    done <<< "$diff_content"

    local total=$((name_in_logic + name_in_hardcoded))

    if [[ "$total" -eq 0 ]]; then
        printf '0.0\tno project name references detected'
    elif [[ "$name_in_hardcoded" -gt 0 ]]; then
        printf '%s\tdiff contains project name "%s" in hardcoded strings' "-0.7" "$project_name"
    else
        printf '%s\tdiff contains project name "%s" in logic/conditions' "-0.5" "$project_name"
    fi
}

# Run GENERIC_PATTERN heuristic on a diff string for a playbook file.
# Outputs: <score>\t<reason>
evolve_heuristic_generic_pattern() {
    local diff_content="$1"

    # Check if diff adds new sections (## or ### headings)
    local new_sections=0
    local added_lines=0
    local is_modification=false

    while IFS= read -r line; do
        if [[ "$line" =~ ^\+[^+] ]]; then
            added_lines=$((added_lines + 1))
            if [[ "$line" =~ ^\+###?\ .+ ]]; then
                new_sections=$((new_sections + 1))
            fi
        fi
        if [[ "$line" =~ ^-[^-] ]]; then
            is_modification=true
        fi
    done <<< "$diff_content"

    if [[ "$new_sections" -gt 0 ]] && [[ "$added_lines" -ge 10 ]]; then
        printf '0.8\tnew self-contained section(s) (%d headings, %d lines added) — highly generalizable' "$new_sections" "$added_lines"
    elif [[ "$new_sections" -gt 0 ]]; then
        printf '0.5\tnew section with limited content — generalizable with edits'
    elif $is_modification && [[ "$added_lines" -ge 5 ]]; then
        printf '0.6\tmodification to existing section with generic improvement (%d lines)' "$added_lines"
    elif $is_modification; then
        printf '0.2\tminor modification — low generalizability'
    else
        printf '0.3\tsmall change — uncertain generalizability'
    fi
}

# Run HOOK_FIX heuristic: check if a hook script diff has evidence in intercepts.
# Outputs: <score>\t<reason>
evolve_heuristic_hook_fix() {
    local dir="$1"
    local source_file="$2"

    local log_file="$dir/.selfmodel/state/hook-intercepts.log"
    if [[ ! -f "$log_file" ]] || [[ ! -s "$log_file" ]]; then
        printf '0.1\tno hook intercept log available'
        return
    fi

    # Extract hook name from source file
    local hook_name
    hook_name=$(basename "$source_file" .sh)

    local intercept_count
    intercept_count=$({ grep -c "hook=${hook_name} " "$log_file" || true; } 2>/dev/null | tr -d '[:space:]')
    # Ensure we have a clean integer
    intercept_count="${intercept_count:-0}"
    [[ "$intercept_count" =~ ^[0-9]+$ ]] || intercept_count=0

    if [[ "$intercept_count" -ge 5 ]]; then
        printf '0.9\thook fix backed by %d intercepts — strong evidence' "$intercept_count"
    elif [[ "$intercept_count" -ge 3 ]]; then
        printf '0.7\thook fix backed by %d intercepts — moderate evidence' "$intercept_count"
    elif [[ "$intercept_count" -gt 0 ]]; then
        printf '0.3\thook fix with %d intercept(s) — weak evidence' "$intercept_count"
    else
        printf '0.1\thook change with no intercept log correlation'
    fi
}

# Run SCORING_CALIBRATION heuristic for quality-gates.md changes.
# Outputs: <score>\t<reason>
evolve_heuristic_scoring_calibration() {
    local dir="$1"

    local quality_file="$dir/.selfmodel/state/quality.jsonl"
    if [[ ! -f "$quality_file" ]] || [[ ! -s "$quality_file" ]]; then
        printf '0.3\tno quality data available — speculative calibration'
        return
    fi

    local entry_count
    entry_count=$(wc -l < "$quality_file" | tr -d ' ')

    if [[ "$entry_count" -ge 10 ]]; then
        printf '0.85\tscoring calibration backed by %d quality entries — strong trend data' "$entry_count"
    elif [[ "$entry_count" -ge 5 ]]; then
        printf '0.65\tscoring calibration backed by %d quality entries — moderate data' "$entry_count"
    else
        printf '0.3\tscoring calibration with %d entries — weak/ambiguous trend' "$entry_count"
    fi
}

# Score all applicable heuristics for a given file diff.
# Outputs JSON: {"heuristic":"<name>","score":<float>,"reason":"<string>"}
evolve_score_heuristics() {
    local dir="$1"
    local source_file="$2"
    local diff_content="$3"

    local base_positive=0
    local base_heuristic=""
    local base_reason=""
    local negative_sum=0
    local negative_reasons=""

    # Always run PATH_DETECTION
    local path_result
    path_result=$(evolve_heuristic_path_detection "$dir" "$diff_content")
    local path_score path_reason
    path_score=$(echo "$path_result" | cut -f1)
    path_reason=$(echo "$path_result" | cut -f2-)
    if [[ "$path_score" != "0.0" ]]; then
        negative_sum=$(echo "$negative_sum + $path_score" | bc 2>/dev/null || echo "$path_score")
        negative_reasons="path_detection: $path_reason"
    fi

    # Always run PROJECT_NAME_DETECTION
    local name_result
    name_result=$(evolve_heuristic_project_name_detection "$dir" "$diff_content")
    local name_score name_reason
    name_score=$(echo "$name_result" | cut -f1)
    name_reason=$(echo "$name_result" | cut -f2-)
    if [[ "$name_score" != "0.0" ]]; then
        negative_sum=$(echo "$negative_sum + $name_score" | bc 2>/dev/null || echo "$name_score")
        if [[ -n "$negative_reasons" ]]; then
            negative_reasons="$negative_reasons; project_name: $name_reason"
        else
            negative_reasons="project_name: $name_reason"
        fi
    fi

    # Determine which positive heuristic to run based on file type
    if [[ "$source_file" == *hooks/* ]] || [[ "$source_file" == *enforce-*.sh ]]; then
        local hook_result
        hook_result=$(evolve_heuristic_hook_fix "$dir" "$source_file")
        local hook_score hook_reason
        hook_score=$(echo "$hook_result" | cut -f1)
        hook_reason=$(echo "$hook_result" | cut -f2-)
        # Use awk for float comparison (bc might not be available)
        if awk "BEGIN {exit !($hook_score > $base_positive)}" 2>/dev/null; then
            base_positive="$hook_score"
            base_heuristic="hook_fix"
            base_reason="$hook_reason"
        fi
    fi

    if [[ "$source_file" == *quality-gates* ]]; then
        local cal_result
        cal_result=$(evolve_heuristic_scoring_calibration "$dir")
        local cal_score cal_reason
        cal_score=$(echo "$cal_result" | cut -f1)
        cal_reason=$(echo "$cal_result" | cut -f2-)
        if awk "BEGIN {exit !($cal_score > $base_positive)}" 2>/dev/null; then
            base_positive="$cal_score"
            base_heuristic="scoring_calibration"
            base_reason="$cal_reason"
        fi
    fi

    if [[ "$source_file" == *playbook/* ]] || [[ "$source_file" == *scripts/* ]]; then
        local gen_result
        gen_result=$(evolve_heuristic_generic_pattern "$diff_content")
        local gen_score gen_reason
        gen_score=$(echo "$gen_result" | cut -f1)
        gen_reason=$(echo "$gen_result" | cut -f2-)
        if awk "BEGIN {exit !($gen_score > $base_positive)}" 2>/dev/null; then
            base_positive="$gen_score"
            base_heuristic="generic_pattern"
            base_reason="$gen_reason"
        fi
    fi

    # Default heuristic if nothing matched
    if [[ -z "$base_heuristic" ]]; then
        base_heuristic="generic_pattern"
        base_positive="0.3"
        base_reason="no specific heuristic matched — default score"
    fi

    # Compute final score: base_positive + negative_sum, clamped to [0.0, 1.0]
    local final_score
    final_score=$(awk "BEGIN {
        s = $base_positive + $negative_sum;
        if (s < 0) s = 0;
        if (s > 1) s = 1;
        printf \"%.2f\", s
    }" 2>/dev/null || echo "0.30")

    # Compose combined reason
    local combined_reason="$base_reason"
    if [[ -n "$negative_reasons" ]]; then
        combined_reason="$base_reason; $negative_reasons"
    fi

    # Output as tab-separated: heuristic, score, reason
    printf '%s\t%s\t%s' "$base_heuristic" "$final_score" "$combined_reason"
}

# Append a CANDIDATE entry to evolution.jsonl.
evolve_append_candidate() {
    local dir="$1"
    local source_file="$2"
    local category="$3"
    local summary="$4"
    local description="$5"
    local diff_stats="$6"
    local heuristic="$7"
    local score="$8"
    local reason="$9"
    local evidence_sprints="${10:-[]}"
    local evidence_quality="${11:-null}"
    local evidence_intercepts="${12:-0}"
    local evidence_lesson="${13:-null}"

    local evo_file="$dir/.selfmodel/state/evolution.jsonl"
    local team_file="$dir/.selfmodel/state/team.json"
    local version_file="$dir/VERSION"

    # Generate unique ID: evo-YYYY-MM-DD-NNN
    local today
    today=$(date -u +%Y-%m-%d)
    local existing_today=0
    if [[ -f "$evo_file" ]]; then
        existing_today=$({ grep -c "\"evo-${today}-" "$evo_file" || true; } 2>/dev/null)
    fi
    local seq_num
    seq_num=$(printf '%03d' $((existing_today + 1)))
    local evo_id="evo-${today}-${seq_num}"

    # Get current sprint from team.json
    local current_sprint=0
    if [[ -f "$team_file" ]]; then
        current_sprint=$(jq -r '.current_sprint // 0' "$team_file" 2>/dev/null || echo 0)
    fi

    # Get project name
    local project_name
    project_name=$(git -C "$dir" remote get-url origin 2>/dev/null | sed 's/.*\///' | sed 's/\.git$//' || basename "$dir")

    # Get selfmodel version
    local sm_version="$SELFMODEL_VERSION"
    if [[ -f "$version_file" ]]; then
        sm_version=$(tr -d '[:space:]' < "$version_file")
    fi

    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    # Build JSON entry using jq for correctness
    local json_entry
    json_entry=$(jq -cn \
        --arg id "$evo_id" \
        --arg status "CANDIDATE" \
        --arg category "$category" \
        --arg source_file "$source_file" \
        --arg upstream_file "$source_file" \
        --arg summary "$summary" \
        --arg description "$description" \
        --argjson evidence_sprints "$evidence_sprints" \
        --arg evidence_quality "$evidence_quality" \
        --argjson evidence_intercepts "$evidence_intercepts" \
        --arg evidence_lesson "$evidence_lesson" \
        --arg heuristic "$heuristic" \
        --argjson score "$score" \
        --arg reason "$reason" \
        --arg diff_stats "$diff_stats" \
        --argjson sprint "$current_sprint" \
        --arg detected_at "$timestamp" \
        --arg project_name "$project_name" \
        --arg sm_version "$sm_version" \
        '{
            id: $id,
            status: $status,
            category: $category,
            source_file: $source_file,
            upstream_file: $upstream_file,
            summary: $summary,
            description: $description,
            evidence: {
                sprints_affected: $evidence_sprints,
                quality_trend: (if $evidence_quality == "null" then null else $evidence_quality end),
                hook_intercepts: $evidence_intercepts,
                lessons_learned_ref: (if $evidence_lesson == "null" then null else $evidence_lesson end)
            },
            heuristic: $heuristic,
            generalizability_score: $score,
            generalizability_reason: $reason,
            diff_stats: $diff_stats,
            detected_at_sprint: $sprint,
            detected_at: $detected_at,
            staged_at: null,
            submitted_at: null,
            pr_url: null,
            pr_status: null,
            reviewed_by: null,
            project_name: $project_name,
            selfmodel_version: $sm_version
        }')

    # Append to evolution.jsonl (create if needed)
    echo "$json_entry" >> "$evo_file"
    echo "$evo_id"
}

# Determine the category of a changed file.
evolve_categorize_file() {
    local filepath="$1"
    case "$filepath" in
        .selfmodel/playbook/*)     echo "playbook_patch" ;;
        .selfmodel/hooks/*)        echo "hook_improvement" ;;
        scripts/*.sh)              echo "script_fix" ;;
        scripts/*)                 echo "script_fix" ;;
        *)                         echo "playbook_patch" ;;
    esac
}

# Generate a one-line summary from a diff for a given file.
evolve_summarize_diff() {
    local dir="$1"
    local filepath="$2"
    local diff_content="$3"

    local added removed
    added=$(printf '%s\n' "$diff_content" | { grep -c '^+[^+]' || true; } 2>/dev/null)
    removed=$(printf '%s\n' "$diff_content" | { grep -c '^-[^-]' || true; } 2>/dev/null)

    # Extract first meaningful added line as context
    local first_added
    first_added=$(printf '%s\n' "$diff_content" | grep '^+[^+]' | head -1 | sed 's/^+//' | sed 's/^[[:space:]]*//' | head -c 80)

    local basename_file
    basename_file=$(basename "$filepath")
    echo "Modified $basename_file: $first_added (+${added}/-${removed} lines)"
}

# Main detection logic: scan diffs, run heuristics, write candidates.
evolve_detect() {
    local dir="$1"
    local selfmodel_dir="$dir/.selfmodel"

    info "Starting evolution detection scan..."

    # Step 1: Establish baseline
    local baseline
    if ! baseline=$(evolve_establish_baseline "$dir"); then
        warn "No upstream baseline available."
        warn "Run 'selfmodel update --remote' to establish a baseline,"
        warn "or add a git remote named 'upstream',"
        warn "or write a SHA to .selfmodel/state/upstream-baseline.sha"
        return 1
    fi
    info "Using baseline: $(bold "$baseline")"

    # Step 2: Scan diffs
    local diff_files
    diff_files=$(evolve_scan_diffs "$dir" "$baseline")

    if [[ -z "$diff_files" ]]; then
        info "No diffs found between baseline and HEAD in playbook/hooks/scripts."
    fi

    local candidate_count=0
    local playbook_count=0
    local hook_count=0
    local script_count=0
    local lesson_count=0

    # Step 3: Process each changed file
    if [[ -n "$diff_files" ]]; then
        while IFS=$'\t' read -r added removed filepath; do
            [[ -z "$filepath" ]] && continue

            local category
            category=$(evolve_categorize_file "$filepath")

            # Get full diff for this file
            local file_diff
            file_diff=$(git -C "$dir" diff "${baseline}..HEAD" -- "$filepath" 2>/dev/null)
            if [[ -z "$file_diff" ]]; then
                continue
            fi

            # Run heuristics
            local heuristic_result
            heuristic_result=$(evolve_score_heuristics "$dir" "$filepath" "$file_diff")
            local heuristic_name heuristic_score heuristic_reason
            heuristic_name=$(echo "$heuristic_result" | cut -f1)
            heuristic_score=$(echo "$heuristic_result" | cut -f2)
            heuristic_reason=$(echo "$heuristic_result" | cut -f3-)

            # Generate summary and description
            local summary
            summary=$(evolve_summarize_diff "$dir" "$filepath" "$file_diff")
            summary="${summary:0:120}"
            local description="Detected diff in $filepath against baseline $baseline. $heuristic_reason"
            local basename_for_stats
            basename_for_stats=$(basename "$filepath")
            local diff_stats="+${added} -${removed} lines in ${basename_for_stats}"

            # Check for duplicate (same source_file already CANDIDATE)
            local evo_file="$selfmodel_dir/state/evolution.jsonl"
            if [[ -f "$evo_file" ]]; then
                local existing
                existing=$(jq -r "select(.source_file == \"$filepath\" and .status == \"CANDIDATE\") | .id" "$evo_file" 2>/dev/null | tail -1)
                if [[ -n "$existing" ]]; then
                    continue
                fi
            fi

            # Append candidate
            local evo_id
            evo_id=$(evolve_append_candidate "$dir" "$filepath" "$category" \
                "$summary" "$description" "$diff_stats" \
                "$heuristic_name" "$heuristic_score" "$heuristic_reason")

            candidate_count=$((candidate_count + 1))
            case "$category" in
                playbook_patch) playbook_count=$((playbook_count + 1)) ;;
                hook_improvement) hook_count=$((hook_count + 1)) ;;
                script_fix) script_count=$((script_count + 1)) ;;
            esac

            info "  [$evo_id] $category  score=$heuristic_score  $filepath"
        done <<< "$diff_files"
    fi

    # Step 4: Scan lessons-learned.md for validated lessons
    local lessons
    lessons=$(evolve_scan_lessons "$dir")
    if [[ -n "$lessons" ]]; then
        while IFS=$'\t' read -r sprint_ref lesson_text; do
            [[ -z "$sprint_ref" ]] && continue
            [[ -z "$lesson_text" ]] && continue

            # Check for duplicate lesson candidate
            local evo_file="$selfmodel_dir/state/evolution.jsonl"
            if [[ -f "$evo_file" ]]; then
                local existing
                existing=$(jq -r "select(.evidence.lessons_learned_ref == \"$sprint_ref\" and .status == \"CANDIDATE\") | .id" "$evo_file" 2>/dev/null | tail -1)
                if [[ -n "$existing" ]]; then
                    continue
                fi
            fi

            local summary="Validated lesson: ${lesson_text:0:100}"
            local evo_id
            evo_id=$(evolve_append_candidate "$dir" ".selfmodel/playbook/lessons-learned.md" \
                "new_lesson" "$summary" "Lesson from $sprint_ref validated as improved. $lesson_text" \
                "lesson entry" "generic_pattern" "0.60" \
                "validated lesson with improved result — likely generalizable" \
                "[]" "null" "0" "$sprint_ref")

            candidate_count=$((candidate_count + 1))
            lesson_count=$((lesson_count + 1))
            info "  [$evo_id] new_lesson  score=0.60  $sprint_ref"
        done <<< "$lessons"
    fi

    # Step 5: Scan hook intercepts for recurring patterns
    local intercepts
    intercepts=$(evolve_scan_intercepts "$dir")
    if [[ -n "$intercepts" ]]; then
        while IFS=$'\t' read -r hook reason count; do
            [[ -z "$hook" ]] && continue

            # Check if there's already a hook_improvement candidate for this hook
            local evo_file="$selfmodel_dir/state/evolution.jsonl"
            local hook_script_candidates=0
            if [[ -f "$evo_file" ]]; then
                hook_script_candidates=$(jq -r "select(.source_file | contains(\"$hook\")) | .id" "$evo_file" 2>/dev/null | wc -l | tr -d ' ')
            fi

            if [[ "$hook_script_candidates" -gt 0 ]]; then
                # Already covered by a diff-based candidate; skip standalone intercept entry
                continue
            fi

            local summary="Hook intercept pattern: $hook ($reason, ${count}x)"
            local score="0.70"
            if [[ "$count" -ge 5 ]]; then
                score="0.90"
            fi

            local evo_id
            evo_id=$(evolve_append_candidate "$dir" ".selfmodel/hooks/${hook}.sh" \
                "hook_improvement" "${summary:0:120}" \
                "Recurring hook intercept: hook=$hook reason=$reason repeated $count times" \
                "intercept pattern" "hook_fix" "$score" \
                "hook intercept pattern with $count occurrences — likely false positive to fix" \
                "[]" "null" "$count" "null")

            candidate_count=$((candidate_count + 1))
            hook_count=$((hook_count + 1))
            info "  [$evo_id] hook_improvement  score=$score  $hook ($reason, ${count}x)"
        done <<< "$intercepts"
    fi

    # Step 6: Output summary
    echo ""
    if [[ "$candidate_count" -eq 0 ]]; then
        ok "No evolution candidates detected."
    else
        ok "Detected $candidate_count candidate(s): $playbook_count playbook patch(es), $hook_count hook fix(es), $script_count script fix(es), $lesson_count lesson(s)"
    fi

    return 0
}

# Display evolution pipeline status by reading evolution.jsonl.
# ─── evolve_stage: Interactive classification of CANDIDATE entries ──────────
evolve_stage() {
    local dir="$1"
    local evo_file="$dir/.selfmodel/state/evolution.jsonl"
    local staging_dir="$dir/.selfmodel/state/evolution-staging"

    if [[ ! -f "$evo_file" ]] || [[ ! -s "$evo_file" ]]; then
        info "No evolution entries found. Run 'selfmodel evolve --detect' first."
        return 0
    fi

    # Collect CANDIDATE entries sorted by generalizability_score descending
    local candidates
    candidates=$(jq -c 'select(.status == "CANDIDATE")' "$evo_file" 2>/dev/null \
        | jq -s 'sort_by(-.generalizability_score)' 2>/dev/null)

    local total
    total=$(echo "$candidates" | jq 'length' 2>/dev/null)

    if [[ "$total" -eq 0 || "$total" == "null" ]]; then
        info "No candidates to stage. All entries are already classified."
        return 0
    fi

    info "Found $total CANDIDATE entries to classify."
    echo ""

    local staged_count=0
    local rejected_count=0
    local kept_count=0

    # Resolve baseline for diff display
    local baseline=""
    baseline=$(evolve_establish_baseline "$dir" 2>/dev/null) || true

    local i=0
    while [[ $i -lt $total ]]; do
        local entry
        entry=$(echo "$candidates" | jq -c ".[$i]")

        local evo_id category source_file summary score reason
        evo_id=$(echo "$entry" | jq -r '.id')
        category=$(echo "$entry" | jq -r '.category')
        source_file=$(echo "$entry" | jq -r '.source_file')
        summary=$(echo "$entry" | jq -r '.summary')
        score=$(echo "$entry" | jq -r '.generalizability_score')
        reason=$(echo "$entry" | jq -r '.generalizability_reason')

        echo "════════════════════════════════════════════════════"
        printf "[%d/%d] ${BOLD}%s${NC}  %s  score=%s\n" "$((i + 1))" "$total" "$evo_id" "$category" "$score"
        printf "  File: %s\n" "$source_file"
        printf "  Summary: %s\n" "$summary"
        printf "  Reason: %s\n" "$reason"

        # Show diff preview (first 20 lines)
        if [[ -n "$baseline" ]]; then
            echo "────────────────────────────────────────────────────"
            echo "  Diff preview (first 20 lines):"
            local diff_preview
            diff_preview=$(git -C "$dir" diff "${baseline}..HEAD" -- "$source_file" 2>/dev/null | head -20) || true
            if [[ -n "$diff_preview" ]]; then
                printf '%s\n' "$diff_preview" | sed 's/^/  /'
            else
                echo "  (no diff available — file may be new or baseline unreachable)"
            fi
        fi
        echo "────────────────────────────────────────────────────"

        # Heuristic recommendation
        local recommend
        if awk "BEGIN {exit !($score >= 0.6)}"; then
            recommend="${GREEN}Recommend: Stage${NC}"
        else
            recommend="${YELLOW}Recommend: Skip${NC}"
        fi
        printf "  %b\n" "$recommend"

        # Interactive prompt
        printf "${CYAN}[selfmodel]${NC} [S]tage / [R]eject / [K]eep? "
        read -r choice

        case "${choice,,}" in
            s|stage)
                # Update status to STAGED in evolution.jsonl
                local timestamp
                timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
                local tmp_evo
                tmp_evo=$(mktemp)
                while IFS= read -r line; do
                    local line_id
                    line_id=$(echo "$line" | jq -r '.id' 2>/dev/null)
                    if [[ "$line_id" == "$evo_id" ]]; then
                        echo "$line" | jq -c --arg ts "$timestamp" \
                            '.status = "STAGED" | .staged_at = $ts'
                    else
                        echo "$line"
                    fi
                done < "$evo_file" > "$tmp_evo"
                mv "$tmp_evo" "$evo_file"

                # Generate patch and metadata in staging directory
                local entry_staging_dir="${staging_dir}/${evo_id}"
                mkdir -p "$entry_staging_dir"

                # Generate patch.diff
                if [[ -n "$baseline" ]]; then
                    git -C "$dir" diff "${baseline}..HEAD" -- "$source_file" \
                        > "${entry_staging_dir}/patch.diff" 2>/dev/null || true
                fi

                # Strip project-specific content from patch
                if [[ -f "${entry_staging_dir}/patch.diff" ]]; then
                    local project_root
                    project_root=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null || echo "$dir")
                    # Replace absolute paths with placeholder
                    sed_inplace "s|${project_root}|<project-root>|g" "${entry_staging_dir}/patch.diff"
                    # Replace home directory paths
                    if [[ -n "${HOME:-}" ]]; then
                        sed_inplace "s|${HOME}|~|g" "${entry_staging_dir}/patch.diff"
                    fi
                fi

                # Write metadata.json
                local description evidence_json
                description=$(echo "$entry" | jq -r '.description')
                evidence_json=$(echo "$entry" | jq -c '.evidence')
                jq -cn \
                    --arg id "$evo_id" \
                    --arg category "$category" \
                    --arg summary "$summary" \
                    --arg description "$description" \
                    --argjson evidence "$evidence_json" \
                    --argjson score "$score" \
                    --arg reason "$reason" \
                    --arg source_file "$source_file" \
                    --arg staged_at "$timestamp" \
                    '{
                        id: $id,
                        category: $category,
                        summary: $summary,
                        description: $description,
                        evidence: $evidence,
                        generalizability_score: $score,
                        generalizability_reason: $reason,
                        source_file: $source_file,
                        staged_at: $staged_at
                    }' > "${entry_staging_dir}/metadata.json"

                ok "Staged: $evo_id → ${entry_staging_dir}/"
                staged_count=$((staged_count + 1))
                ;;
            r|reject)
                # Update status to REJECTED_PROJECT_SPECIFIC
                local tmp_evo
                tmp_evo=$(mktemp)
                while IFS= read -r line; do
                    local line_id
                    line_id=$(echo "$line" | jq -r '.id' 2>/dev/null)
                    if [[ "$line_id" == "$evo_id" ]]; then
                        echo "$line" | jq -c '.status = "REJECTED_PROJECT_SPECIFIC"'
                    else
                        echo "$line"
                    fi
                done < "$evo_file" > "$tmp_evo"
                mv "$tmp_evo" "$evo_file"

                warn "Rejected: $evo_id (project-specific)"
                rejected_count=$((rejected_count + 1))
                ;;
            k|keep|"")
                info "Kept: $evo_id (will revisit later)"
                kept_count=$((kept_count + 1))
                ;;
            *)
                warn "Unknown choice '$choice', keeping as CANDIDATE."
                kept_count=$((kept_count + 1))
                ;;
        esac

        echo ""
        i=$((i + 1))
    done

    echo "════════════════════════════════════════════════════"
    ok "Stage complete: $staged_count staged, $rejected_count rejected, $kept_count kept"
}

# ─── evolve_submit: Create upstream PR from STAGED patches ──────────────────
evolve_submit() {
    local dir="$1"
    local evo_file="$dir/.selfmodel/state/evolution.jsonl"
    local staging_dir="$dir/.selfmodel/state/evolution-staging"

    # Pre-check: gh CLI available
    if ! command -v gh &>/dev/null; then
        err "gh CLI is required for PR submission."
        err "Install: https://cli.github.com/"
        return 1
    fi

    # Pre-check: gh authenticated
    if ! gh auth status &>/dev/null 2>&1; then
        err "gh CLI not authenticated. Run 'gh auth login' first."
        return 1
    fi

    if [[ ! -f "$evo_file" ]] || [[ ! -s "$evo_file" ]]; then
        info "No evolution entries found."
        return 0
    fi

    # Collect STAGED entries
    local staged_entries
    staged_entries=$(jq -c 'select(.status == "STAGED")' "$evo_file" 2>/dev/null \
        | jq -s '.' 2>/dev/null)

    local staged_count
    staged_count=$(echo "$staged_entries" | jq 'length' 2>/dev/null)

    if [[ "$staged_count" -eq 0 || "$staged_count" == "null" ]]; then
        info "No staged entries to submit. Run 'selfmodel evolve --stage' first."
        return 0
    fi

    info "Found $staged_count STAGED entries for submission."

    # ── Pre-submission checks ────────────────────────────────────────────────
    local precheck_failed=false

    # Lint .sh patches with shell checker
    local i=0
    while [[ $i -lt $staged_count ]]; do
        local entry
        entry=$(echo "$staged_entries" | jq -c ".[$i]")
        local evo_id source_file
        evo_id=$(echo "$entry" | jq -r '.id')
        source_file=$(echo "$entry" | jq -r '.source_file')

        if [[ "$source_file" == *.sh ]]; then
            local patch_dir="${staging_dir}/${evo_id}"
            if [[ -f "${patch_dir}/patch.diff" ]]; then
                # Check if lint tool is available
                if command -v shellcheck &>/dev/null; then
                    # Run lint on the source file
                    local tmp_file
                    tmp_file=$(mktemp)
                    if [[ -f "$dir/$source_file" ]]; then
                        cp "$dir/$source_file" "$tmp_file"
                        if ! shellcheck -S warning "$tmp_file" &>/dev/null; then
                            warn "Shell lint warnings in $source_file (evo: $evo_id)"
                            shellcheck -S warning "$tmp_file" 2>&1 | head -20
                            precheck_failed=true
                        fi
                    fi
                    rm -f "$tmp_file"
                fi
            fi
        fi

        i=$((i + 1))
    done

    # Path audit: scan patches for absolute paths, secrets patterns
    i=0
    while [[ $i -lt $staged_count ]]; do
        local entry
        entry=$(echo "$staged_entries" | jq -c ".[$i]")
        local evo_id
        evo_id=$(echo "$entry" | jq -r '.id')
        local patch_file="${staging_dir}/${evo_id}/patch.diff"

        if [[ -f "$patch_file" ]]; then
            # Check for absolute paths (excluding <project-root> placeholders)
            local abs_paths
            abs_paths=$(grep -nE '^\+.*(/Users/|/home/|/var/|/opt/|/srv/)' "$patch_file" 2>/dev/null \
                | grep -v '<project-root>' || true)
            if [[ -n "$abs_paths" ]]; then
                warn "Absolute paths found in $evo_id patch:"
                printf '%s\n' "$abs_paths" | head -5
                precheck_failed=true
            fi

            # Check for secrets patterns
            local secrets
            secrets=$(grep -niE '(API_KEY|TOKEN|PASSWORD|SECRET|CREDENTIAL|PRIVATE_KEY)=' "$patch_file" 2>/dev/null \
                | grep '^+' || true)
            if [[ -n "$secrets" ]]; then
                err "Potential secrets found in $evo_id patch:"
                printf '%s\n' "$secrets" | head -5
                precheck_failed=true
            fi
        fi

        i=$((i + 1))
    done

    if [[ "$precheck_failed" == "true" ]]; then
        warn "Pre-submission checks found issues."
        printf "${CYAN}[selfmodel]${NC} Continue despite warnings? [y/N] "
        read -r reply
        if [[ ! "$reply" =~ ^[Yy] ]]; then
            info "Submission aborted. Fix issues and re-run."
            return 0
        fi
    fi

    # ── PR Preview ───────────────────────────────────────────────────────────
    local project_name
    project_name=$(git -C "$dir" remote get-url origin 2>/dev/null \
        | sed 's/.*\///' | sed 's/\.git$//' || basename "$dir")

    local sm_version="$SELFMODEL_VERSION"
    if [[ -f "$dir/VERSION" ]]; then
        sm_version=$(tr -d '[:space:]' < "$dir/VERSION")
    fi

    local current_sprint=0
    if [[ -f "$dir/.selfmodel/state/team.json" ]]; then
        current_sprint=$(jq -r '.current_sprint // 0' "$dir/.selfmodel/state/team.json" 2>/dev/null || echo 0)
    fi

    local pr_title="feat(evolution): improvements from ${project_name} (${staged_count} changes)"

    echo ""
    echo "════════════════════════════════════════════════════"
    echo "  PR Preview"
    echo "════════════════════════════════════════════════════"
    printf "  Title: %s\n" "$pr_title"
    echo "  Changes:"
    echo "────────────────────────────────────────────────────"
    printf "  %-4s %-22s %-30s %s\n" "#" "Category" "File" "Score"

    i=0
    while [[ $i -lt $staged_count ]]; do
        local entry
        entry=$(echo "$staged_entries" | jq -c ".[$i]")
        local evo_id category source_file score
        evo_id=$(echo "$entry" | jq -r '.id')
        category=$(echo "$entry" | jq -r '.category')
        source_file=$(echo "$entry" | jq -r '.source_file')
        score=$(echo "$entry" | jq -r '.generalizability_score')
        printf "  %-4d %-22s %-30s %s\n" "$((i + 1))" "$category" "$source_file" "$score"
        i=$((i + 1))
    done

    echo "════════════════════════════════════════════════════"
    echo ""

    # ── Human confirmation gate ──────────────────────────────────────────────
    printf "${CYAN}[selfmodel]${NC} Submit PR to upstream? [y/N] "
    read -r submit_reply
    if [[ ! "$submit_reply" =~ ^[Yy] ]]; then
        info "Submission cancelled. Entries remain STAGED."
        return 0
    fi

    # ── Build PR body ────────────────────────────────────────────────────────
    local pr_body
    pr_body="## Summary"$'\n'$'\n'
    pr_body+="Community-discovered improvements from project usage (${project_name}, sprint ${current_sprint})."$'\n'$'\n'
    pr_body+="These changes were detected by selfmodel's evolution pipeline, classified as"$'\n'
    pr_body+="generalizable by heuristic analysis, and verified against local sprint data."$'\n'$'\n'
    pr_body+="## Changes"$'\n'$'\n'
    pr_body+="| # | Category | File | Summary | Score |"$'\n'
    pr_body+="|---|----------|------|---------|-------|"$'\n'

    i=0
    while [[ $i -lt $staged_count ]]; do
        local entry
        entry=$(echo "$staged_entries" | jq -c ".[$i]")
        local summary category upstream_file score
        summary=$(echo "$entry" | jq -r '.summary')
        category=$(echo "$entry" | jq -r '.category')
        upstream_file=$(echo "$entry" | jq -r '.upstream_file')
        score=$(echo "$entry" | jq -r '.generalizability_score')
        pr_body+="| $((i + 1)) | ${category} | ${upstream_file} | ${summary} | ${score} |"$'\n'
        i=$((i + 1))
    done

    pr_body+=$'\n'"## Per-Change Details"$'\n'

    i=0
    while [[ $i -lt $staged_count ]]; do
        local entry
        entry=$(echo "$staged_entries" | jq -c ".[$i]")
        local evo_id summary category heuristic score reason description diff_stats
        local sprints_affected quality_trend hook_intercepts lessons_ref
        evo_id=$(echo "$entry" | jq -r '.id')
        summary=$(echo "$entry" | jq -r '.summary')
        category=$(echo "$entry" | jq -r '.category')
        heuristic=$(echo "$entry" | jq -r '.heuristic')
        score=$(echo "$entry" | jq -r '.generalizability_score')
        reason=$(echo "$entry" | jq -r '.generalizability_reason')
        description=$(echo "$entry" | jq -r '.description')
        diff_stats=$(echo "$entry" | jq -r '.diff_stats')
        sprints_affected=$(echo "$entry" | jq -r '.evidence.sprints_affected // []')
        quality_trend=$(echo "$entry" | jq -r '.evidence.quality_trend // "N/A"')
        hook_intercepts=$(echo "$entry" | jq -r '.evidence.hook_intercepts // 0')
        lessons_ref=$(echo "$entry" | jq -r '.evidence.lessons_learned_ref // "N/A"')

        pr_body+=$'\n'"### Change $((i + 1)): ${summary}"$'\n'$'\n'
        pr_body+="**ID**: ${evo_id}"$'\n'
        pr_body+="**Category**: ${category}"$'\n'
        pr_body+="**Heuristic**: ${heuristic} (score: ${score})"$'\n'
        pr_body+="**Reason**: ${reason}"$'\n'$'\n'
        pr_body+="**What changed**: ${description}"$'\n'$'\n'
        pr_body+="**Evidence**:"$'\n'
        pr_body+="- Sprints affected: ${sprints_affected}"$'\n'
        pr_body+="- Quality trend: ${quality_trend}"$'\n'
        pr_body+="- Hook intercepts: ${hook_intercepts}"$'\n'
        pr_body+="- Lessons learned ref: ${lessons_ref}"$'\n'$'\n'
        pr_body+="**Diff stats**: ${diff_stats}"$'\n'
        pr_body+=$'\n'"---"$'\n'

        i=$((i + 1))
    done

    pr_body+=$'\n'"## Testing"$'\n'$'\n'
    pr_body+="- [ ] shellcheck passes on all modified .sh files"$'\n'
    pr_body+="- [ ] \`selfmodel status\` runs without errors after applying changes"$'\n'
    pr_body+="- [ ] No absolute paths or project-specific names in submitted code"$'\n'
    pr_body+="- [ ] Patches apply cleanly to upstream HEAD"$'\n'$'\n'
    pr_body+="## Context"$'\n'$'\n'
    pr_body+="- selfmodel version: ${sm_version}"$'\n'
    pr_body+="- Project sprint count: ${current_sprint}"$'\n'
    pr_body+="- Evolution entries: ${staged_count}"$'\n'

    # ── Create PR via gh ─────────────────────────────────────────────────────

    # Determine upstream repo from remote
    local upstream_repo
    upstream_repo=$(git -C "$dir" remote get-url upstream 2>/dev/null \
        | sed 's|.*github\.com[:/]||' | sed 's/\.git$//') || true

    if [[ -z "$upstream_repo" ]]; then
        # Fall back to origin if no upstream remote
        upstream_repo=$(git -C "$dir" remote get-url origin 2>/dev/null \
            | sed 's|.*github\.com[:/]||' | sed 's/\.git$//') || true
    fi

    if [[ -z "$upstream_repo" ]]; then
        err "Could not determine upstream repository URL."
        return 1
    fi

    # Create a branch for the PR
    local branch_date
    branch_date=$(date -u +%Y%m%d)
    local branch_name="evolution/${project_name}-${branch_date}"

    info "Creating branch: $branch_name"
    if ! git -C "$dir" checkout -b "$branch_name" 2>/dev/null; then
        warn "Branch $branch_name may already exist. Attempting to use it."
        git -C "$dir" checkout "$branch_name" 2>/dev/null || {
            err "Failed to create or switch to branch $branch_name"
            return 1
        }
    fi

    # Apply staged patches
    local apply_failed=false
    i=0
    while [[ $i -lt $staged_count ]]; do
        local entry
        entry=$(echo "$staged_entries" | jq -c ".[$i]")
        local evo_id
        evo_id=$(echo "$entry" | jq -r '.id')
        local patch_file="${staging_dir}/${evo_id}/patch.diff"

        if [[ -f "$patch_file" ]] && [[ -s "$patch_file" ]]; then
            if ! git -C "$dir" apply --check "$patch_file" 2>/dev/null; then
                warn "Patch $evo_id does not apply cleanly. Skipping."
                apply_failed=true
            else
                git -C "$dir" apply "$patch_file" 2>/dev/null || {
                    warn "Failed to apply patch $evo_id."
                    apply_failed=true
                }
            fi
        fi

        i=$((i + 1))
    done

    if [[ "$apply_failed" == "true" ]]; then
        warn "Some patches did not apply. PR will include only successfully applied changes."
    fi

    # Commit applied changes
    git -C "$dir" add -A 2>/dev/null || true
    local has_changes
    has_changes=$(git -C "$dir" diff --cached --name-only 2>/dev/null)

    if [[ -z "$has_changes" ]]; then
        warn "No changes to commit after applying patches."
        git -C "$dir" checkout - 2>/dev/null || true
        return 0
    fi

    git -C "$dir" commit -m "feat(evolution): ${staged_count} improvements from ${project_name}" 2>/dev/null || {
        err "Failed to commit changes."
        git -C "$dir" checkout - 2>/dev/null || true
        return 1
    }

    # Push and create PR
    info "Pushing branch and creating PR..."
    git -C "$dir" push -u origin "$branch_name" 2>/dev/null || {
        err "Failed to push branch. Check your git remote configuration."
        git -C "$dir" checkout - 2>/dev/null || true
        return 1
    }

    local pr_url
    pr_url=$(gh pr create \
        --repo "$upstream_repo" \
        --title "$pr_title" \
        --body "$pr_body" \
        --head "$branch_name" 2>&1) || {
        err "Failed to create PR: $pr_url"
        git -C "$dir" checkout - 2>/dev/null || true
        return 1
    }

    ok "PR created: $pr_url"

    # Return to previous branch
    git -C "$dir" checkout - 2>/dev/null || true

    # ── Update evolution.jsonl: STAGED → SUBMITTED ───────────────────────────
    local submit_timestamp
    submit_timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    local tmp_evo
    tmp_evo=$(mktemp)
    while IFS= read -r line; do
        local line_status
        line_status=$(echo "$line" | jq -r '.status' 2>/dev/null)
        if [[ "$line_status" == "STAGED" ]]; then
            echo "$line" | jq -c \
                --arg ts "$submit_timestamp" \
                --arg url "$pr_url" \
                '.status = "SUBMITTED" | .submitted_at = $ts | .pr_url = $url | .pr_status = "open"'
        else
            echo "$line"
        fi
    done < "$evo_file" > "$tmp_evo"
    mv "$tmp_evo" "$evo_file"

    ok "Updated $staged_count entries to SUBMITTED status."
}

# ─── evolve_track: Monitor submitted PR statuses ───────────────────────────
evolve_track() {
    local dir="$1"
    local evo_file="$dir/.selfmodel/state/evolution.jsonl"

    # Check gh CLI availability
    if ! command -v gh &>/dev/null; then
        err "gh CLI is required for PR tracking."
        err "Install: https://cli.github.com/"
        return 1
    fi

    if [[ ! -f "$evo_file" ]] || [[ ! -s "$evo_file" ]]; then
        info "No evolution entries found."
        return 0
    fi

    # Collect SUBMITTED entries with pr_url
    local submitted
    submitted=$(jq -c 'select(.status == "SUBMITTED" and .pr_url != null)' "$evo_file" 2>/dev/null \
        | jq -s '.' 2>/dev/null)

    local total
    total=$(echo "$submitted" | jq 'length' 2>/dev/null)

    if [[ "$total" -eq 0 || "$total" == "null" ]]; then
        info "No submitted PRs to track."
        return 0
    fi

    info "Tracking $total submitted PRs..."

    local accepted_count=0
    local rejected_count=0
    local pending_count=0

    local i=0
    while [[ $i -lt $total ]]; do
        local entry
        entry=$(echo "$submitted" | jq -c ".[$i]")
        local evo_id pr_url
        evo_id=$(echo "$entry" | jq -r '.id')
        pr_url=$(echo "$entry" | jq -r '.pr_url')

        # Query PR status via gh
        local pr_json
        pr_json=$(gh pr view "$pr_url" --json state,mergedAt,reviews 2>/dev/null) || {
            warn "Could not query PR status for $evo_id ($pr_url)"
            pending_count=$((pending_count + 1))
            i=$((i + 1))
            continue
        }

        local pr_state
        pr_state=$(echo "$pr_json" | jq -r '.state // "UNKNOWN"' 2>/dev/null)

        local new_status=""
        local new_pr_status=""
        local reviewed_by=""

        case "$pr_state" in
            MERGED)
                new_status="ACCEPTED"
                new_pr_status="merged"
                reviewed_by=$(echo "$pr_json" | jq -r '[.reviews[]?.author.login // empty] | unique | join(",")' 2>/dev/null) || true
                accepted_count=$((accepted_count + 1))
                ok "$evo_id: ACCEPTED (merged)"
                ;;
            CLOSED)
                new_status="REJECTED_UPSTREAM"
                new_pr_status="closed"
                reviewed_by=$(echo "$pr_json" | jq -r '[.reviews[]?.author.login // empty] | unique | join(",")' 2>/dev/null) || true
                rejected_count=$((rejected_count + 1))
                warn "$evo_id: REJECTED_UPSTREAM (closed without merge)"
                ;;
            OPEN)
                # Check if changes requested
                local has_changes_requested
                has_changes_requested=$(echo "$pr_json" | jq '[.reviews[]? | select(.state == "CHANGES_REQUESTED")] | length' 2>/dev/null) || true
                if [[ "$has_changes_requested" -gt 0 ]]; then
                    new_pr_status="changes_requested"
                    info "$evo_id: open (changes requested — needs attention)"
                else
                    new_pr_status="open"
                    info "$evo_id: open (pending review)"
                fi
                pending_count=$((pending_count + 1))
                ;;
            *)
                info "$evo_id: unknown state ($pr_state)"
                pending_count=$((pending_count + 1))
                ;;
        esac

        # Update evolution.jsonl if status changed
        if [[ -n "$new_status" || -n "$new_pr_status" ]]; then
            local tmp_evo
            tmp_evo=$(mktemp)
            while IFS= read -r line; do
                local line_id
                line_id=$(echo "$line" | jq -r '.id' 2>/dev/null)
                if [[ "$line_id" == "$evo_id" ]]; then
                    local updated_line="$line"
                    if [[ -n "$new_status" ]]; then
                        updated_line=$(echo "$updated_line" | jq -c --arg s "$new_status" '.status = $s')
                    fi
                    if [[ -n "$new_pr_status" ]]; then
                        updated_line=$(echo "$updated_line" | jq -c --arg ps "$new_pr_status" '.pr_status = $ps')
                    fi
                    if [[ -n "$reviewed_by" ]]; then
                        updated_line=$(echo "$updated_line" | jq -c --arg rb "$reviewed_by" '.reviewed_by = $rb')
                    fi
                    echo "$updated_line"
                else
                    echo "$line"
                fi
            done < "$evo_file" > "$tmp_evo"
            mv "$tmp_evo" "$evo_file"
        fi

        i=$((i + 1))
    done

    echo "────────────────────────────────────────────────────"
    ok "Tracked $total PRs: $accepted_count accepted, $rejected_count rejected, $pending_count pending"
}

# ─── evolve_status: Display evolution pipeline status ───────────────────────
evolve_status() {
    local dir="$1"
    local evo_file="$dir/.selfmodel/state/evolution.jsonl"
    local team_file="$dir/.selfmodel/state/team.json"

    if [[ ! -f "$evo_file" ]] || [[ ! -s "$evo_file" ]]; then
        info "No evolution entries found. Run 'selfmodel evolve --detect' first."
        return 0
    fi

    echo "Evolution Pipeline Status"
    echo "═════════════════════════════════════════"

    # Count by status
    local statuses=("CANDIDATE" "STAGED" "SUBMITTED" "ACCEPTED" "REJECTED_PROJECT_SPECIFIC" "REJECTED_UPSTREAM" "CONFLICT" "SUPERSEDED")
    local total_entries=0
    for status in "${statuses[@]}"; do
        local count
        count=$(jq -r "select(.status == \"$status\") | .id" "$evo_file" 2>/dev/null | wc -l | tr -d ' ')
        if [[ "$count" -gt 0 ]]; then
            printf '  %-30s %d\n' "${status}:" "$count"
            total_entries=$((total_entries + count))
        fi
    done
    echo "  ─────────────────────────────────"
    printf '  %-30s %d\n' "Total:" "$total_entries"

    echo "═════════════════════════════════════════"

    # Timestamps section
    echo "Timestamps"
    echo "─────────────────────────────────────────"

    # Last detect info
    local last_detect_sprint last_detect_date
    last_detect_sprint=$(jq -r '.detected_at_sprint // 0' "$evo_file" 2>/dev/null | sort -rn | head -1)
    last_detect_date=$(jq -r '.detected_at // ""' "$evo_file" 2>/dev/null | sort -r | head -1)
    if [[ -n "$last_detect_date" && "$last_detect_date" != "null" ]]; then
        printf '  Last detect:  Sprint %s (%s)\n' "$last_detect_sprint" "${last_detect_date%%T*}"
    else
        echo "  Last detect:  N/A"
    fi

    # Last submit timestamp
    local last_submit_date
    last_submit_date=$(jq -r 'select(.submitted_at != null) | .submitted_at' "$evo_file" 2>/dev/null | sort -r | head -1)
    if [[ -n "$last_submit_date" && "$last_submit_date" != "null" ]]; then
        printf '  Last submit:  %s\n' "${last_submit_date%%T*}"
    else
        echo "  Last submit:  N/A"
    fi

    # Last staged timestamp
    local last_staged_date
    last_staged_date=$(jq -r 'select(.staged_at != null) | .staged_at' "$evo_file" 2>/dev/null | sort -r | head -1)
    if [[ -n "$last_staged_date" && "$last_staged_date" != "null" ]]; then
        printf '  Last staged:  %s\n' "${last_staged_date%%T*}"
    else
        echo "  Last staged:  N/A"
    fi

    # Next detect estimate (every 10 sprints)
    if [[ -f "$team_file" ]]; then
        local current_sprint last_review
        current_sprint=$(jq -r '.current_sprint // 0' "$team_file" 2>/dev/null)
        last_review=$(jq -r '.evolution.last_review_sprint // 0' "$team_file" 2>/dev/null)
        local next_detect=$((last_review + 10))
        if [[ "$next_detect" -le "$current_sprint" ]]; then
            echo "  Next detect:  now (overdue)"
        else
            printf '  Next detect:  ~Sprint %d\n' "$next_detect"
        fi
    fi

    # Submitted PRs section
    local submitted_prs
    submitted_prs=$(jq -c 'select(.pr_url != null)' "$evo_file" 2>/dev/null | jq -s '.' 2>/dev/null)
    local pr_count
    pr_count=$(echo "$submitted_prs" | jq 'length' 2>/dev/null)

    if [[ "$pr_count" -gt 0 && "$pr_count" != "null" ]]; then
        echo "═════════════════════════════════════════"
        echo "Submitted PRs"
        echo "─────────────────────────────────────────"

        local j=0
        while [[ $j -lt $pr_count ]]; do
            local pr_entry
            pr_entry=$(echo "$submitted_prs" | jq -c ".[$j]")
            local evo_id pr_url pr_status
            evo_id=$(echo "$pr_entry" | jq -r '.id')
            pr_url=$(echo "$pr_entry" | jq -r '.pr_url')
            pr_status=$(echo "$pr_entry" | jq -r '.pr_status // "unknown"')

            local status_icon
            case "$pr_status" in
                open)    status_icon="🔵" ;;
                merged)  status_icon="🟢" ;;
                closed)  status_icon="🔴" ;;
                changes_requested) status_icon="🟡" ;;
                *)       status_icon="⚪" ;;
            esac

            printf '  %s %-24s %s  %s\n' "$status_icon" "$evo_id" "$pr_status" "$pr_url"
            j=$((j + 1))
        done
    fi

    echo "═════════════════════════════════════════"
}

# ─── evolve_interactive: guided pipeline detect → stage → offer submit ────────
evolve_interactive() {
    local dir="$1"

    info "Running interactive evolution pipeline..."
    echo ""

    # Phase 1: detect
    info "Phase 1/3: Detecting evolution candidates..."
    if ! evolve_detect "$dir"; then
        warn "Detection encountered issues. Stopping interactive pipeline."
        return 1
    fi
    echo ""

    # Check if there are any CANDIDATE entries to stage
    local evo_file="$dir/.selfmodel/state/evolution.jsonl"
    local candidate_count=0
    if [[ -f "$evo_file" ]] && [[ -s "$evo_file" ]]; then
        candidate_count=$(jq -c 'select(.status == "CANDIDATE")' "$evo_file" 2>/dev/null | wc -l | tr -d ' ')
    fi

    if [[ "$candidate_count" -eq 0 ]]; then
        info "No candidates to stage. Pipeline complete."
        return 0
    fi

    # Phase 2: stage
    info "Phase 2/3: Staging candidates ($candidate_count found)..."
    confirm "Proceed to interactive staging?" || {
        info "Skipped staging. Run 'selfmodel evolve --stage' later."
        return 0
    }
    evolve_stage "$dir"
    echo ""

    # Check if there are any STAGED entries to submit
    local staged_count=0
    if [[ -f "$evo_file" ]] && [[ -s "$evo_file" ]]; then
        staged_count=$(jq -c 'select(.status == "STAGED")' "$evo_file" 2>/dev/null | wc -l | tr -d ' ')
    fi

    if [[ "$staged_count" -eq 0 ]]; then
        info "No staged entries to submit. Pipeline complete."
        return 0
    fi

    # Phase 3: offer submit
    info "Phase 3/3: $staged_count staged entries ready for upstream submission."
    confirm "Submit staged patches as upstream PR?" || {
        info "Skipped submission. Run 'selfmodel evolve --submit' later."
        return 0
    }
    evolve_submit "$dir"
}

# Main evolve command: parse flags and route.
cmd_evolve() {
    [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]] && {
        echo "Usage: selfmodel evolve [flags]"
        echo ""
        echo "  Evolution pipeline: detect local improvements, classify generalizability,"
        echo "  package patches, and submit PRs to upstream selfmodel."
        echo ""
        echo "  With no flags, runs the interactive pipeline: detect → stage → submit."
        echo ""
        echo "Flags:"
        echo "  --detect     Scan playbook/hooks/scripts diffs against upstream baseline"
        echo "  --status     Show evolution pipeline status (counts, timestamps, PR URLs)"
        echo "  --stage      Interactively classify CANDIDATE entries (Stage/Reject/Keep)"
        echo "  --submit     Create upstream PR from STAGED patches (requires gh CLI)"
        echo "  --track      Monitor submitted PR statuses via gh CLI"
        echo "  --help       Show this help message"
        echo ""
        echo "Examples:"
        echo "  selfmodel evolve                 # Interactive pipeline (default)"
        echo "  selfmodel evolve --detect        # Detection scan only"
        echo "  selfmodel evolve --status        # View pipeline status"
        echo "  selfmodel evolve --stage         # Classify candidates interactively"
        echo "  selfmodel evolve --submit        # Submit staged patches as PR"
        echo "  selfmodel evolve --track         # Check PR status updates"
        return 0
    }

    local dir="."
    local action="interactive"

    # Parse flags
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --detect)  action="detect"; shift ;;
            --status)  action="status"; shift ;;
            --stage)   action="stage"; shift ;;
            --submit)  action="submit"; shift ;;
            --track)   action="track"; shift ;;
            *)  dir="$1"; shift ;;
        esac
    done

    local selfmodel_dir="$dir/.selfmodel"
    if [[ ! -d "$selfmodel_dir" ]]; then
        err "No .selfmodel/ directory found. Run 'selfmodel init' first."
        return 1
    fi

    case "$action" in
        interactive) evolve_interactive "$dir" ;;
        detect)      evolve_detect "$dir" ;;
        status)      evolve_status "$dir" ;;
        stage)       evolve_stage "$dir" ;;
        submit)      evolve_submit "$dir" ;;
        track)       evolve_track "$dir" ;;
        *)
            err "Unknown evolve action: $action"
            return 1
            ;;
    esac
}

# ─── CMD: dashboard (smart default) ──────────────────────────────────────────
cmd_dashboard() {
    local dir="${1:-.}"
    local selfmodel_dir="$dir/.selfmodel"

    # If no .selfmodel/ exists, suggest init and show short help
    if [[ ! -d "$selfmodel_dir" ]]; then
        echo "selfmodel $SELFMODEL_VERSION"
        echo ""
        printf '  %bNo .selfmodel/ found in this project.%b\n' "$YELLOW" "$NC"
        printf '  %b-> Next: selfmodel init%b\n' "$CYAN" "$NC"
        echo ""
        cmd_help_short
        return 0
    fi

    # Run existing status display
    cmd_status "$dir"
    echo ""

    # Suggest next action based on project state
    local suggestion=""

    # Check for DELIVERED contracts awaiting review
    # Contract format: "## Status\nDELIVERED" — match standalone DELIVERED line
    local delivered_count=0
    if [[ -d "$selfmodel_dir/contracts/active" ]]; then
        delivered_count=$(grep -rl '^DELIVERED$' "$selfmodel_dir/contracts/active/"*.md 2>/dev/null \
            | wc -l | tr -d ' ') || delivered_count=0
    fi
    if [[ "$delivered_count" -gt 0 ]]; then
        suggestion="$delivered_count delivered Sprint(s) awaiting review. Run: /selfmodel:review"
    fi

    # Check if plan.md exists
    if [[ -z "$suggestion" && ! -f "$selfmodel_dir/state/plan.md" ]]; then
        suggestion="No orchestration plan found. Run: /selfmodel:plan"
    fi

    # Check evolution overdue
    if [[ -z "$suggestion" && -f "$selfmodel_dir/state/team.json" ]]; then
        local current_sprint last_review
        current_sprint=$(jq -r '.current_sprint // 0' "$selfmodel_dir/state/team.json" 2>/dev/null)
        last_review=$(jq -r '.evolution.last_review_sprint // 0' "$selfmodel_dir/state/team.json" 2>/dev/null)
        local next_detect=$((last_review + 10))
        if [[ "$next_detect" -le "$current_sprint" ]]; then
            suggestion="Evolution review overdue. Run: selfmodel evolve"
        fi
    fi

    # Default: all clear
    if [[ -z "$suggestion" ]]; then
        suggestion="All clear. Run /selfmodel:sprint for next task"
    fi

    printf '  %b-> Next:%b %s\n' "$CYAN" "$NC" "$suggestion"
    echo ""
    cmd_help_short
}

# ─── Help: short reference (8 lines, used by dashboard) ──────────────────────
cmd_help_short() {
    printf '%b%-24s  %-30s%b\n' "$BOLD" "Terminal" "Claude Code" "$NC"
    echo "────────────────────────  ──────────────────────────────"
    printf "%-24s  %-30s\n" "selfmodel init"           "/selfmodel:init"
    printf "%-24s  %-30s\n" "selfmodel status"         "/selfmodel:status"
    printf "%-24s  %-30s\n" "selfmodel update"         "/selfmodel:loop"
    printf "%-24s  %-30s\n" "selfmodel evolve"         "/selfmodel:evolve"
    printf "%-24s  %-30s\n" ""                         "/selfmodel:plan"
    printf "%-24s  %-30s\n" ""                         "/selfmodel:sprint"
    printf "%-24s  %-30s\n" ""                         "/selfmodel:review"
    printf "%-24s  %-30s\n" "selfmodel --help"         "Full reference"
}

# ─── Help: full detailed reference (used by --help) ─────────────────────────
cmd_help_full() {
    echo "selfmodel $SELFMODEL_VERSION — AI Agent Team Workflow"
    echo ""
    echo "Usage: selfmodel [command] [directory]"
    echo ""
    echo "Commands:"
    echo "  init       Initialize selfmodel (idempotent — safe to re-run on existing projects)"
    echo "  update     Update playbook files to latest version"
    echo "               --remote    Fetch latest from GitHub (instead of local templates)"
    echo "               --version   Specify version/tag (default: main)"
    echo "  status     Show team health dashboard"
    echo "  evolve     Evolution pipeline (interactive by default)"
    echo "               --detect    Scan diffs against upstream baseline"
    echo "               --status    Show pipeline status, timestamps, PR URLs"
    echo "               --stage     Classify CANDIDATE entries (Stage/Reject/Keep)"
    echo "               --submit    Submit staged patches as upstream PR"
    echo "               --track     Monitor submitted PR statuses"
    echo ""
    echo "Flags:"
    echo "  -v, --version   Show version"
    echo "  -h, --help      Show this help message"
    echo ""
    echo "Aliases (backward compat):"
    echo "  adapt      -> init (deprecated, prints warning)"
    echo "  dashboard  -> (no args)"
    echo ""
    echo "Claude Code Slash Commands:"
    echo "  /selfmodel:init       Initialize selfmodel"
    echo "  /selfmodel:plan       Create or update orchestration plan"
    echo "  /selfmodel:sprint     Create Sprint contract and dispatch agent"
    echo "  /selfmodel:review     Review a delivered Sprint"
    echo "  /selfmodel:loop       Auto-orchestration loop"
    echo "  /selfmodel:status     View team status and quality trends"
    echo ""
    echo "Examples:"
    echo "  selfmodel                                    # Smart dashboard (default)"
    echo "  selfmodel init                               # Initialize in current directory"
    echo "  selfmodel init ./my-project                  # Initialize in specific directory"
    echo "  selfmodel update                             # Update playbook from local templates"
    echo "  selfmodel update --remote                    # Fetch latest from GitHub"
    echo "  selfmodel update --remote --version v0.3.0   # Fetch specific version"
    echo "  selfmodel evolve                             # Interactive evolution pipeline"
    echo "  selfmodel evolve --detect                    # Detection scan only"
    echo "  selfmodel evolve --status                    # View evolution pipeline status"
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
    local cmd="${1:-dashboard}"
    shift || true

    case "$cmd" in
        dashboard)       check_deps; cmd_dashboard "$@" ;;
        init|setup)      check_deps; cmd_init "$@" ;;
        adapt)           check_deps; cmd_adapt "$@" ;;
        update|sync)     check_deps; cmd_update "$@" ;;
        status)          check_deps; cmd_status "$@" ;;
        evolve)          check_deps; cmd_evolve "$@" ;;
        version|-v|--version) cmd_version "$@" ;;
        help|--help|-h)  cmd_help_full ;;
        *)
            err "Unknown command: $cmd"
            err "Run 'selfmodel --help' for usage."
            exit 1
            ;;
    esac
}

main "$@"
