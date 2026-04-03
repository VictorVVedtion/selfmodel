#!/usr/bin/env bash
# selfmodel SWE-bench benchmark — top-level CLI.
#
# Usage:
#   bash benchmark/run.sh setup                          # Install dependencies
#   bash benchmark/run.sh pilot                          # 5 instances, orchestrated
#   bash benchmark/run.sh generate --mode orchestrated --count 10
#   bash benchmark/run.sh evaluate predictions/run-id.jsonl
#   bash benchmark/run.sh compare                        # Compare all runs
#   bash benchmark/run.sh status                         # Show current state
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# ── Colors ────────────────────────────────────────
BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "  ${BOLD}[INFO]${NC} $*"; }
ok()    { echo -e "  ${GREEN}[OK]${NC}   $*"; }
err()   { echo -e "  ${RED}[ERR]${NC}  $*" >&2; exit 1; }

# ── Commands ──────────────────────────────────────
cmd_setup() {
    bash "$SCRIPT_DIR/setup.sh"
}

cmd_pilot() {
    info "Running pilot: 5 instances, orchestrated mode"
    cd "$PROJECT_DIR"
    python3 "$SCRIPT_DIR/generate.py" \
        --mode orchestrated \
        --count 5 \
        --run-id "pilot-$(date +%Y%m%d-%H%M%S)" \
        "$@"
}

cmd_generate() {
    cd "$PROJECT_DIR"
    python3 "$SCRIPT_DIR/generate.py" "$@"
}

cmd_evaluate() {
    bash "$SCRIPT_DIR/evaluate.sh" "$@"
}

cmd_compare() {
    info "Comparing all runs..."
    echo ""
    echo "══════════════════════════════════════════════════════════════"
    printf "  %-40s %8s %8s %8s\n" "Run ID" "Total" "Success" "Rate"
    echo "──────────────────────────────────────────────────────────────"

    for meta in "$SCRIPT_DIR/results/"*-meta.json; do
        [ -f "$meta" ] || continue
        RUN_ID=$(jq -r '.run_id' "$meta")
        TOTAL=$(jq -r '.total_instances' "$meta")
        SUCCESS=$(jq -r '.succeeded' "$meta")
        if [ "$TOTAL" -gt 0 ]; then
            RATE=$(python3 -c "print(f'{$SUCCESS/$TOTAL*100:.1f}%')")
        else
            RATE="N/A"
        fi
        printf "  %-40s %8s %8s %8s\n" "$RUN_ID" "$TOTAL" "$SUCCESS" "$RATE"
    done

    echo "══════════════════════════════════════════════════════════════"

    # If swebench evaluation results exist, show them too
    if [ -d "logs/run_evaluation" ]; then
        echo ""
        info "SWE-bench evaluation results:"
        for run_dir in logs/run_evaluation/*/; do
            [ -d "$run_dir" ] || continue
            RUN=$(basename "$run_dir")
            RESOLVED=$(find "$run_dir" -name "report.json" -exec grep -l '"resolved": true' {} \; 2>/dev/null | wc -l | tr -d ' ')
            TOTAL_EVAL=$(find "$run_dir" -name "report.json" 2>/dev/null | wc -l | tr -d ' ')
            if [ "$TOTAL_EVAL" -gt 0 ]; then
                PCT=$(python3 -c "print(f'{$RESOLVED/$TOTAL_EVAL*100:.1f}%')")
                echo "  $RUN: $RESOLVED/$TOTAL_EVAL resolved ($PCT)"
            fi
        done
    fi
}

cmd_status() {
    echo ""
    echo "══════════════════════════════════════════════"
    echo "  selfmodel SWE-bench Benchmark Status"
    echo "══════════════════════════════════════════════"

    # Predictions
    info "Predictions:"
    if ls "$SCRIPT_DIR/predictions/"*.jsonl &>/dev/null; then
        for f in "$SCRIPT_DIR/predictions/"*.jsonl; do
            COUNT=$(wc -l < "$f" | tr -d ' ')
            echo "  $(basename "$f"): $COUNT instances"
        done
    else
        echo "  (none)"
    fi

    # Workspace
    echo ""
    info "Cloned repos:"
    if ls "$SCRIPT_DIR/workspace/" &>/dev/null 2>&1; then
        for d in "$SCRIPT_DIR/workspace/"*/; do
            [ -d "$d" ] || continue
            SIZE=$(du -sh "$d" 2>/dev/null | cut -f1)
            echo "  $(basename "$d"): $SIZE"
        done
    else
        echo "  (none)"
    fi

    # Results
    echo ""
    info "Run results:"
    if ls "$SCRIPT_DIR/results/"*-meta.json &>/dev/null; then
        for meta in "$SCRIPT_DIR/results/"*-meta.json; do
            RUN_ID=$(jq -r '.run_id' "$meta")
            MODE=$(jq -r '.mode' "$meta")
            TOTAL=$(jq -r '.total_instances' "$meta")
            SUCCESS=$(jq -r '.succeeded' "$meta")
            echo "  $RUN_ID ($MODE): $SUCCESS/$TOTAL succeeded"
        done
    else
        echo "  (none)"
    fi

    echo "══════════════════════════════════════════════"
}

cmd_help() {
    echo ""
    echo "selfmodel SWE-bench Benchmark"
    echo ""
    echo "Usage: bash benchmark/run.sh <command> [options]"
    echo ""
    echo "Commands:"
    echo "  setup                Install dependencies and verify tools"
    echo "  pilot                Quick pilot: 5 instances, orchestrated"
    echo "  generate [options]   Run generation (see generate.py --help)"
    echo "  evaluate <file>      Run SWE-bench evaluation on predictions"
    echo "  compare              Compare all runs side by side"
    echo "  status               Show current benchmark state"
    echo ""
    echo "Examples:"
    echo "  bash benchmark/run.sh setup"
    echo "  bash benchmark/run.sh pilot"
    echo "  bash benchmark/run.sh generate --mode solo-claude --count 10"
    echo "  bash benchmark/run.sh generate --mode orchestrated --repo django/django --count 20"
    echo "  bash benchmark/run.sh evaluate benchmark/predictions/orchestrated-20260329.jsonl"
    echo "  bash benchmark/run.sh compare"
    echo ""
}

# ── Router ────────────────────────────────────────
COMMAND="${1:-help}"
shift 2>/dev/null || true

case "$COMMAND" in
    setup)    cmd_setup "$@" ;;
    pilot)    cmd_pilot "$@" ;;
    generate) cmd_generate "$@" ;;
    evaluate) cmd_evaluate "$@" ;;
    compare)  cmd_compare "$@" ;;
    status)   cmd_status "$@" ;;
    help|-h|--help) cmd_help ;;
    *)
        err "Unknown command: $COMMAND (run 'bash benchmark/run.sh help')"
        ;;
esac
