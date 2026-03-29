#!/usr/bin/env bash
# selfmodel — AI Agent Team 工作流初始化与适配工具
# Usage: selfmodel <init|adapt|update|version> [options]
# Requires: jq (for JSON processing). macOS + Linux.
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
    agents+=', "e2e": {"status": "idle", "role": "e2e_verifier", "verifications_completed": 0, "pass_rate": 0, "last_sprint": null, "config": {"engine": "opus-agent", "timeout": 300, "requires_worktree": true, "fallback_engine": "gemini-cli"}}'

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

    # .gitkeep for empty directories
    for d in contracts/active contracts/archive inbox/gemini inbox/codex inbox/opus inbox/research inbox/evaluator inbox/e2e reviews; do
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

    # 5. Sync selfmodel.sh itself (backup → overwrite → chmod)
    if [[ -f "$extracted/scripts/selfmodel.sh" ]]; then
        local target="$dir/scripts/selfmodel.sh"
        if [[ -f "$target" ]]; then
            cp "$target" "${target}.bak.${ts}"
            info "Backed up: selfmodel.sh → .bak.${ts}"
        fi
        cp "$extracted/scripts/selfmodel.sh" "$target"
        chmod +x "$target"
        ok "Updated: selfmodel.sh"
        sync_count=$((sync_count + 1))
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

    # 8. NOT synced: state/, contracts/, inbox/ (project-specific data)
    #    These directories contain per-project state and must not be overwritten.

    # 9. Cleanup
    rm -rf "$tmp_dir"

    echo ""
    ok "Remote update complete! ($version, $sync_count files synced)"
}

# ─── CMD: version ─────────────────────────────────────────────────────────────
cmd_version() {
    echo "selfmodel $SELFMODEL_VERSION"
}

# ─── CMD: status ──────────────────────────────────────────────────────────────
cmd_status() {
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
        "evaluator-prompt.md" "e2e-protocol.md" "orchestration-loop.md" "research-protocol.md" \
        "context-protocol.md" "lessons-learned.md")
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

    echo "═══════════════════════════════════════════════════"
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

# ── 白名单外：拦截 ──
{
    echo "🚨 [Hook 拦截] 违反「Leader 不下场」规则"
    echo ""
    echo "被拦截文件: ${FILE_PATH}"
    echo ""
    echo "Leader 角色只负责编排、审查、仲裁，不直接修改业务代码。"
    echo "白名单范围: .selfmodel/、.claude/、scripts/、playbook/、*.md、.gitignore"
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

    # ── B. Merge settings.json ───────────────────────────────────────────────

    local hooks_config
    hooks_config=$(cat << 'JSONEOF'
{
  "hooks": {
    "SessionStart": [
      {
        "type": "command",
        "command": "bash scripts/hooks/session-start.sh"
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

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
    local cmd="${1:-help}"
    shift || true

    case "$cmd" in
        init)    check_deps; cmd_init "$@" ;;
        adapt)   check_deps; cmd_adapt "$@" ;;
        update)  check_deps; cmd_update "$@" ;;
        status)  check_deps; cmd_status "$@" ;;
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
            echo "             --remote    Fetch latest from GitHub (instead of local templates)"
            echo "             --version   Specify version/tag (default: main)"
            echo "  status   Show team health dashboard"
            echo "  version  Show version"
            echo ""
            echo "Examples:"
            echo "  selfmodel init                       # Initialize in current directory"
            echo "  selfmodel init ./my-project          # Initialize in specific directory"
            echo "  selfmodel adapt                      # Adapt to existing project"
            echo "  selfmodel update                     # Update playbook from local templates"
            echo "  selfmodel update --remote            # Fetch latest from GitHub (main branch)"
            echo "  selfmodel update --remote --version v0.3.0  # Fetch specific version"
            ;;
        *)
            err "Unknown command: $cmd"
            err "Run 'selfmodel help' for usage."
            exit 1
            ;;
    esac
}

main "$@"
