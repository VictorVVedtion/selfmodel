#!/usr/bin/env bash
# SWE-bench benchmark setup — install dependencies and verify tools.
set -euo pipefail

info()  { echo "  [INFO] $*"; }
ok()    { echo "  [OK]   $*"; }
err()   { echo "  [ERR]  $*" >&2; }
warn()  { echo "  [WARN] $*"; }

echo "══════════════════════════════════════════════"
echo "  selfmodel benchmark — setup"
echo "══════════════════════════════════════════════"

# ── Python dependencies ──────────────────────────
info "Installing Python dependencies..."
pip install --quiet datasets swebench 2>/dev/null || {
    warn "pip install failed, trying pip3..."
    pip3 install --quiet datasets swebench
}
ok "Python packages installed (datasets, swebench)"

# ── Verify CLI tools ─────────────────────────────
echo ""
info "Checking CLI tools..."

check_tool() {
    local name="$1"
    local cmd="$2"
    if command -v "$cmd" &>/dev/null; then
        ok "$name found: $(command -v "$cmd")"
        return 0
    else
        warn "$name not found ($cmd)"
        return 1
    fi
}

TOOLS_OK=0
check_tool "Claude Code" "claude"  || TOOLS_OK=1
check_tool "Gemini CLI"  "gemini"  || TOOLS_OK=1
check_tool "Codex CLI"   "codex"   || TOOLS_OK=1
check_tool "Docker"      "docker"  || TOOLS_OK=1
check_tool "jq"          "jq"      || TOOLS_OK=1
check_tool "git"         "git"     || TOOLS_OK=1

if [ "$TOOLS_OK" -eq 1 ]; then
    warn "Some tools missing — certain modes may not work"
fi

# ── Verify Docker ────────────────────────────────
echo ""
if command -v docker &>/dev/null; then
    if docker info &>/dev/null; then
        ok "Docker daemon running"
    else
        warn "Docker installed but daemon not running (needed for evaluation)"
    fi
fi

# ── Create directories ───────────────────────────
echo ""
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$SCRIPT_DIR"/{workspace,predictions,results,inbox}
ok "Directories created"

# ── Quick dataset test ───────────────────────────
echo ""
info "Testing dataset access..."
python3 -c "
from datasets import load_dataset
ds = load_dataset('princeton-nlp/SWE-bench_Verified', split='test')
print(f'  [OK]   Dataset loaded: {len(ds)} instances')
" 2>/dev/null || warn "Dataset access failed — check network/HuggingFace access"

echo ""
echo "══════════════════════════════════════════════"
echo "  Setup complete. Run:"
echo "    python benchmark/generate.py --dry-run --count 5"
echo "══════════════════════════════════════════════"
