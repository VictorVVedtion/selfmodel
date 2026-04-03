#!/usr/bin/env bash
# SWE-bench evaluation — run official harness on generated predictions.
#
# Usage:
#   bash benchmark/evaluate.sh <predictions_file> [max_workers]
#
# Requires: Docker running, swebench package installed (in .venv).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/results"
VENV_PYTHON="$SCRIPT_DIR/.venv/bin/python3"

info()  { echo "  [INFO] $*"; }
ok()    { echo "  [OK]   $*"; }
err()   { echo "  [ERR]  $*" >&2; exit 1; }
warn()  { echo "  [WARN] $*"; }

# ── Parse args ────────────────────────────────────
PREDICTIONS="${1:-}"
MAX_WORKERS="${2:-4}"

if [ -z "$PREDICTIONS" ]; then
    echo "Usage: bash benchmark/evaluate.sh <predictions.jsonl> [max_workers]"
    echo ""
    echo "Available predictions:"
    ls -la "$SCRIPT_DIR/predictions/"*.jsonl 2>/dev/null || echo "  (none)"
    exit 1
fi

if [ ! -f "$PREDICTIONS" ]; then
    err "Predictions file not found: $PREDICTIONS"
fi

# ── Check venv ────────────────────────────────────
if [ ! -f "$VENV_PYTHON" ]; then
    err "Venv not found. Run: /opt/homebrew/bin/python3.13 -m venv $SCRIPT_DIR/.venv && $SCRIPT_DIR/.venv/bin/pip install swebench datasets"
fi

# ── Auto-detect Docker socket (colima support) ────
if [ -z "${DOCKER_HOST:-}" ]; then
    if [ -S "$HOME/.colima/default/docker.sock" ]; then
        export DOCKER_HOST="unix://$HOME/.colima/default/docker.sock"
        info "Auto-detected colima Docker socket"
    elif [ -S "/var/run/docker.sock" ]; then
        export DOCKER_HOST="unix:///var/run/docker.sock"
    fi
fi

# ── Extract run ID from filename ──────────────────
RUN_ID=$(basename "$PREDICTIONS" .jsonl)

echo "══════════════════════════════════════════════"
echo "  SWE-bench Evaluation"
echo "══════════════════════════════════════════════"
info "Predictions: $PREDICTIONS"
info "Run ID: $RUN_ID"
info "Max workers: $MAX_WORKERS"
info "Docker host: ${DOCKER_HOST:-default}"

# ── Check Docker ──────────────────────────────────
if ! docker info &>/dev/null; then
    err "Docker daemon not running. Start with: colima start"
fi
ok "Docker daemon running"

# ── Count predictions ─────────────────────────────
PRED_COUNT=$(wc -l < "$PREDICTIONS" | tr -d ' ')
EMPTY_COUNT=$("$VENV_PYTHON" -c "
import json
count = 0
with open('$PREDICTIONS') as f:
    for line in f:
        d = json.loads(line)
        if not d.get('model_patch', '').strip():
            count += 1
print(count)
")
info "Total predictions: $PRED_COUNT (empty patches: $EMPTY_COUNT)"

# ── Run evaluation ────────────────────────────────
echo ""
info "Starting SWE-bench evaluation (this may take a while)..."
info "Docker images will be built on first run (~5-10 min per repo)"

mkdir -p "$RESULTS_DIR"

"$VENV_PYTHON" -m swebench.harness.run_evaluation \
    --dataset_name princeton-nlp/SWE-bench_Verified \
    --predictions_path "$PREDICTIONS" \
    --max_workers "$MAX_WORKERS" \
    --run_id "$RUN_ID" \
    --cache_level env \
    --timeout 1800

# ── Parse results ─────────────────────────────────
echo ""
info "Parsing results..."

# Find the results report
REPORT_DIR="logs/run_evaluation/$RUN_ID"
if [ -d "$REPORT_DIR" ]; then
    "$VENV_PYTHON" -c "
import json, os, glob

report_dir = '$REPORT_DIR'
model_dirs = glob.glob(os.path.join(report_dir, '*'))

for model_dir in model_dirs:
    if not os.path.isdir(model_dir):
        continue
    model_name = os.path.basename(model_dir)

    resolved = 0
    applied = 0
    failed = 0
    total = 0

    for inst_dir in glob.glob(os.path.join(model_dir, '*')):
        report_file = os.path.join(inst_dir, 'report.json')
        if os.path.exists(report_file):
            total += 1
            with open(report_file) as f:
                report = json.load(f)
            inst_id = os.path.basename(inst_dir)
            status = report.get(inst_id, {}).get('resolved', False)
            if status:
                resolved += 1
            elif report.get(inst_id, {}).get('applied', False):
                applied += 1
            else:
                failed += 1

    pct = resolved / total * 100 if total else 0
    print(f'Model: {model_name}')
    print(f'  Resolved: {resolved}/{total} ({pct:.1f}%)')
    print(f'  Applied but unresolved: {applied}')
    print(f'  Failed: {failed}')
"
    ok "Results saved in $REPORT_DIR"
else
    warn "Results directory not found. Check swebench output above."
fi

echo ""
echo "══════════════════════════════════════════════"
echo "  Evaluation complete"
echo "══════════════════════════════════════════════"
