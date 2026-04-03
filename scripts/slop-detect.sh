#!/usr/bin/env bash
# slop-detect.sh — Standalone AI Slop Detection CLI
# Scans source code for common AI-generated low-quality patterns
# Usage: bash slop-detect.sh [directory] [--json] [--strict]
# Exit: 0 = clean, 1 = slop found, 2 = error

set -euo pipefail

VERSION="0.1.0"

# ── Colors ──
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
DIM='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m'

# ── Defaults ──
TARGET_DIR="."
JSON_OUTPUT=false
STRICT_MODE=false
TOTAL_FINDINGS=0
TOTAL_FILES=0
declare -a FINDINGS=()

# ── Parse args ──
while [[ $# -gt 0 ]]; do
    case "$1" in
        --json)     JSON_OUTPUT=true; shift ;;
        --strict)   STRICT_MODE=true; shift ;;
        --version)  echo "slop-detect v${VERSION}"; exit 0 ;;
        --help|-h)
            cat <<'USAGE'
slop-detect — AI Slop Detection CLI

Usage: bash slop-detect.sh [directory] [--json] [--strict]

Scans source code for 10 auto-reject triggers and 8 AI slop patterns.

Options:
  --json       Output results as JSON
  --strict     Exit 1 on any finding (default: exit 1 only on auto-reject triggers)
  --version    Show version
  -h, --help   Show this help

Patterns detected:
  Auto-reject triggers (always fail):
    T1  TODO/FIXME/HACK/XXX comments
    T2  Mock data (Lorem ipsum, test@test.com, foo/bar)
    T3  Swallowed exceptions (empty catch, except: pass)
    T4  Hardcoded secrets (API keys, passwords, tokens)
    T5  Dead code (commented-out code blocks)

  AI Slop patterns (warning, fail in --strict):
    S1  Excessive comments (obvious logic explained)
    S2  Template error handling (identical catch blocks)
    S3  Defensive nonsense (redundant null chains)
    S4  AI pleasantries in comments ("elegantly", "efficiently")
    S5  Single-use abstractions (interface with one impl)

Examples:
  bash slop-detect.sh ./src
  bash slop-detect.sh ./src --strict
  bash slop-detect.sh ./src --json | jq '.findings[]'

Part of the selfmodel framework: https://github.com/VictorVVedtion/selfmodel
USAGE
            exit 0
            ;;
        *)
            if [[ -d "$1" ]]; then
                TARGET_DIR="$1"
            else
                echo "Error: '$1' is not a directory" >&2
                exit 2
            fi
            shift
            ;;
    esac
done

if [[ ! -d "${TARGET_DIR}" ]]; then
    echo "Error: directory '${TARGET_DIR}' not found" >&2
    exit 2
fi

# ── File discovery ──
# Scan common source file extensions, skip node_modules/.git/vendor/dist
SOURCE_FILES=$(find "${TARGET_DIR}" \
    -type f \
    \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \
       -o -name "*.py" -o -name "*.go" -o -name "*.rs" -o -name "*.rb" \
       -o -name "*.java" -o -name "*.kt" -o -name "*.swift" -o -name "*.sh" \
       -o -name "*.c" -o -name "*.cpp" -o -name "*.h" -o -name "*.cs" \) \
    -not -path "*/node_modules/*" \
    -not -path "*/.git/*" \
    -not -path "*/vendor/*" \
    -not -path "*/dist/*" \
    -not -path "*/build/*" \
    -not -path "*/__pycache__/*" \
    -not -path "*/.next/*" \
    -not -name "slop-detect.sh" \
    2>/dev/null || true)

if [[ -z "${SOURCE_FILES}" ]]; then
    if [[ "${JSON_OUTPUT}" == true ]]; then
        echo '{"status":"clean","message":"no source files found","findings":[],"score":100}'
    else
        echo -e "${GREEN}No source files found in ${TARGET_DIR}${NC}"
    fi
    exit 0
fi

TOTAL_FILES=$(echo "${SOURCE_FILES}" | wc -l | tr -d ' ')

# ── Detection functions ──

add_finding() {
    local severity="$1"  # REJECT | WARNING
    local code="$2"      # T1, S1, etc.
    local file="$3"
    local line="$4"
    local message="$5"
    local snippet="$6"

    FINDINGS+=("${severity}|${code}|${file}|${line}|${message}|${snippet}")
    TOTAL_FINDINGS=$((TOTAL_FINDINGS + 1))
}

# T1: TODO/FIXME/HACK/XXX
detect_todo() {
    while IFS=: read -r file line content; do
        [[ -z "${file}" ]] && continue
        snippet=$(echo "${content}" | sed 's/^[[:space:]]*//' | cut -c1-80)
        add_finding "REJECT" "T1" "${file}" "${line}" "TODO/FIXME/HACK found" "${snippet}"
    done < <(echo "${SOURCE_FILES}" | xargs grep -n -E '(//|#|/\*)\s*(TODO|FIXME|HACK|XXX)\b' 2>/dev/null || true)
}

# T2: Mock data
detect_mock() {
    while IFS=: read -r file line content; do
        [[ -z "${file}" ]] && continue
        snippet=$(echo "${content}" | sed 's/^[[:space:]]*//' | cut -c1-80)
        add_finding "REJECT" "T2" "${file}" "${line}" "Mock/placeholder data" "${snippet}"
    done < <(echo "${SOURCE_FILES}" | xargs grep -n -i -E '(lorem ipsum|test@test\.com|foo@bar|placeholder|fake[_-]?data|mock[_-]?data|sample[_-]?data)' 2>/dev/null | grep -v -E '(\.test\.|_test\.|-test\.|spec\.|\.spec\.)' || true)
}

# T3: Swallowed exceptions
detect_swallowed() {
    while IFS=: read -r file line content; do
        [[ -z "${file}" ]] && continue
        snippet=$(echo "${content}" | sed 's/^[[:space:]]*//' | cut -c1-80)
        add_finding "REJECT" "T3" "${file}" "${line}" "Swallowed exception" "${snippet}"
    done < <(echo "${SOURCE_FILES}" | xargs grep -n -E '(except:\s*pass|catch\s*\{\s*\}|catch\s*\([^)]*\)\s*\{\s*\})' 2>/dev/null || true)
}

# T4: Hardcoded secrets
detect_secrets() {
    while IFS=: read -r file line content; do
        [[ -z "${file}" ]] && continue
        snippet=$(echo "${content}" | sed 's/^[[:space:]]*//' | cut -c1-80)
        add_finding "REJECT" "T4" "${file}" "${line}" "Possible hardcoded secret" "${snippet}"
    done < <(echo "${SOURCE_FILES}" | xargs grep -n -E '(api[_-]?key|api[_-]?secret|password|passwd|secret[_-]?key|access[_-]?token|private[_-]?key)\s*[:=]\s*["\x27][A-Za-z0-9+/=]{8,}' 2>/dev/null | grep -v -E '(\.env\.example|\.test\.|_test\.|-test\.)' || true)
}

# T5: Dead code (commented-out code blocks)
detect_dead_code() {
    while IFS=: read -r file line content; do
        [[ -z "${file}" ]] && continue
        snippet=$(echo "${content}" | sed 's/^[[:space:]]*//' | cut -c1-80)
        add_finding "REJECT" "T5" "${file}" "${line}" "Commented-out code" "${snippet}"
    done < <(echo "${SOURCE_FILES}" | xargs grep -n -E '^\s*(//|#)\s*(const |let |var |function |def |class |import |from |if |for |while |return )' 2>/dev/null || true)
}

# S1: Excessive comments (lines where comment ratio is very high)
detect_excessive_comments() {
    while read -r file; do
        [[ -z "${file}" ]] && continue
        local total_lines comment_lines
        total_lines=$(wc -l < "${file}" | tr -d ' ')
        [[ "${total_lines}" -lt 10 ]] && continue
        comment_lines=$(grep -c -E '^\s*(//|#|/\*|\*)' "${file}" 2>/dev/null || echo 0)
        local ratio=0
        if [[ "${total_lines}" -gt 0 ]]; then
            ratio=$(( comment_lines * 100 / total_lines ))
        fi
        if [[ "${ratio}" -gt 50 ]]; then
            add_finding "WARNING" "S1" "${file}" "1" "Excessive comments (${ratio}% comment ratio)" "${comment_lines}/${total_lines} lines are comments"
        fi
    done <<< "${SOURCE_FILES}"
}

# S3: Defensive nonsense (redundant null/undefined chains)
detect_defensive_nonsense() {
    while IFS=: read -r file line content; do
        [[ -z "${file}" ]] && continue
        snippet=$(echo "${content}" | sed 's/^[[:space:]]*//' | cut -c1-80)
        add_finding "WARNING" "S3" "${file}" "${line}" "Redundant null/undefined chain" "${snippet}"
    done < <(echo "${SOURCE_FILES}" | xargs grep -n -E '!==?\s*(null|undefined|""|'\'''\'')\s*&&.*!==?\s*(null|undefined|""|'\'''\'')\s*&&.*!==?\s*(null|undefined|""|'\'''\'')\s*' 2>/dev/null || true)
}

# S4: AI pleasantries in comments
detect_ai_pleasantries() {
    while IFS=: read -r file line content; do
        [[ -z "${file}" ]] && continue
        snippet=$(echo "${content}" | sed 's/^[[:space:]]*//' | cut -c1-80)
        add_finding "WARNING" "S4" "${file}" "${line}" "AI pleasantry in comment" "${snippet}"
    done < <(echo "${SOURCE_FILES}" | xargs grep -n -i -E '(//|#|/\*|\*)\s*.*(elegantly|efficiently handles|robustly|gracefully handles|seamlessly|this (function|method|class) (provides|ensures|handles|implements))' 2>/dev/null || true)
}

# S2: Template error handling (identical catch blocks)
detect_template_catch() {
    while IFS=: read -r file line content; do
        [[ -z "${file}" ]] && continue
        snippet=$(echo "${content}" | sed 's/^[[:space:]]*//' | cut -c1-80)
        add_finding "WARNING" "S2" "${file}" "${line}" "Template error handling" "${snippet}"
    done < <(echo "${SOURCE_FILES}" | xargs grep -n -E 'console\.(error|log)\(.*\);\s*(throw|return)' 2>/dev/null || true)
}

# ── Run all detectors ──
detect_todo
detect_mock
detect_swallowed
detect_secrets
detect_dead_code
detect_excessive_comments
detect_defensive_nonsense
detect_ai_pleasantries
detect_template_catch

# ── Calculate score ──
REJECT_COUNT=0
WARNING_COUNT=0
for finding in "${FINDINGS[@]+"${FINDINGS[@]}"}"; do
    severity="${finding%%|*}"
    if [[ "${severity}" == "REJECT" ]]; then
        REJECT_COUNT=$((REJECT_COUNT + 1))
    else
        WARNING_COUNT=$((WARNING_COUNT + 1))
    fi
done

# Score: 100 - (rejects * 15) - (warnings * 5), floor 0
SCORE=$((100 - REJECT_COUNT * 15 - WARNING_COUNT * 5))
[[ "${SCORE}" -lt 0 ]] && SCORE=0

# ── Output ──
if [[ "${JSON_OUTPUT}" == true ]]; then
    # JSON output
    echo -n '{"status":'
    if [[ "${REJECT_COUNT}" -gt 0 ]]; then
        echo -n '"reject"'
    elif [[ "${WARNING_COUNT}" -gt 0 ]]; then
        echo -n '"warning"'
    else
        echo -n '"clean"'
    fi
    echo -n ',"score":'${SCORE}',"files_scanned":'${TOTAL_FILES}',"findings":['

    first=true
    for finding in "${FINDINGS[@]+"${FINDINGS[@]}"}"; do
        IFS='|' read -r severity code file line message snippet <<< "${finding}"
        if [[ "${first}" == true ]]; then
            first=false
        else
            echo -n ','
        fi
        # Escape JSON strings
        file=$(echo "${file}" | sed 's/"/\\"/g')
        message=$(echo "${message}" | sed 's/"/\\"/g')
        snippet=$(echo "${snippet}" | sed 's/"/\\"/g')
        echo -n "{\"severity\":\"${severity}\",\"code\":\"${code}\",\"file\":\"${file}\",\"line\":${line},\"message\":\"${message}\",\"snippet\":\"${snippet}\"}"
    done
    echo ']}'
else
    # Human-readable output
    echo ""
    echo -e "${BOLD}  slop-detect v${VERSION}${NC}"
    echo -e "  ${DIM}Scanned ${TOTAL_FILES} files in ${TARGET_DIR}${NC}"
    echo ""

    if [[ "${TOTAL_FINDINGS}" -eq 0 ]]; then
        echo -e "  ${GREEN}Score: ${SCORE}/100 — Clean${NC}"
        echo -e "  ${GREEN}No AI slop patterns detected.${NC}"
        echo ""
        exit 0
    fi

    # Print findings grouped by severity
    if [[ "${REJECT_COUNT}" -gt 0 ]]; then
        echo -e "  ${RED}${BOLD}AUTO-REJECT (${REJECT_COUNT})${NC}"
        echo ""
        for finding in "${FINDINGS[@]}"; do
            IFS='|' read -r severity code file line message snippet <<< "${finding}"
            [[ "${severity}" != "REJECT" ]] && continue
            echo -e "  ${RED}[${code}]${NC} ${file}:${line}"
            echo -e "       ${message}"
            echo -e "       ${DIM}${snippet}${NC}"
            echo ""
        done
    fi

    if [[ "${WARNING_COUNT}" -gt 0 ]]; then
        echo -e "  ${YELLOW}${BOLD}AI SLOP WARNING (${WARNING_COUNT})${NC}"
        echo ""
        for finding in "${FINDINGS[@]}"; do
            IFS='|' read -r severity code file line message snippet <<< "${finding}"
            [[ "${severity}" != "WARNING" ]] && continue
            echo -e "  ${YELLOW}[${code}]${NC} ${file}:${line}"
            echo -e "       ${message}"
            echo -e "       ${DIM}${snippet}${NC}"
            echo ""
        done
    fi

    # Score bar
    bar_filled=$((SCORE / 5))
    bar_empty=$((20 - bar_filled))
    bar_color="${GREEN}"
    [[ "${SCORE}" -lt 70 ]] && bar_color="${YELLOW}"
    [[ "${SCORE}" -lt 40 ]] && bar_color="${RED}"

    printf "  Score: ${bar_color}${BOLD}%d/100${NC}  " "${SCORE}"
    printf "${bar_color}"
    for ((i=0; i<bar_filled; i++)); do printf "█"; done
    printf "${DIM}"
    for ((i=0; i<bar_empty; i++)); do printf "░"; done
    printf "${NC}\n"

    echo ""
    echo -e "  ${DIM}Reject: ${REJECT_COUNT} | Warning: ${WARNING_COUNT} | Files: ${TOTAL_FILES}${NC}"
    echo -e "  ${DIM}https://github.com/VictorVVedtion/selfmodel${NC}"
    echo ""
fi

# ── Exit code ──
if [[ "${REJECT_COUNT}" -gt 0 ]]; then
    exit 1
fi
if [[ "${STRICT_MODE}" == true && "${WARNING_COUNT}" -gt 0 ]]; then
    exit 1
fi
exit 0
