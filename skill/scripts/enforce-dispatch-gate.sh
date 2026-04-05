#!/usr/bin/env bash
# enforce-dispatch-gate.sh — PreToolUse hook (matcher: Bash)
# 滚动批次调度门禁：三道硬检查防止扇出合并地狱
# Gate 1: 并行上限（active contracts < max_parallel）
# Gate 2: 收敛文件门禁（同一收敛文件不得被多个 active Sprint 同时修改）
# Gate 3: 文件重叠检查（active Sprint 之间不得有共享文件）
# exit 0 = 放行 | exit 2 = 拦截
# 兼�� bash 3.2+ (macOS 默认)

set -euo pipefail

# ── 紧急绕过 ──
if [[ "${BYPASS_DISPATCH_GATE:-0}" == "1" ]]; then
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
IS_AGENT=false
if printf '%s' "${COMMAND}" | grep -q 'gemini'; then
    IS_AGENT=true
fi
if printf '%s' "${COMMAND}" | grep -q 'codex'; then
    IS_AGENT=true
fi

# 不是 agent 调用，直接放行
if [[ "${IS_AGENT}" == "false" ]]; then
    exit 0
fi

# ── 配置路径 ──
CONFIG=".selfmodel/state/dispatch-config.json"
CONTRACTS_DIR=".selfmodel/contracts/active"

# 配置文件不存在时放行（项目未初始化调度门禁）
if [[ ! -f "${CONFIG}" ]]; then
    exit 0
fi

# 合约目录不存在时放行
if [[ ! -d "${CONTRACTS_DIR}" ]]; then
    exit 0
fi

# ── 读取配置 ──
MAX_PARALLEL="$(jq -r '.max_parallel // 3' "${CONFIG}" 2>/dev/null)"

# ── 统计 active 合约 ──
ACTIVE_CONTRACTS=()
while IFS= read -r -d '' contract; do
    ACTIVE_CONTRACTS+=("${contract}")
done < <(find "${CONTRACTS_DIR}" -maxdepth 1 -name "*.md" -print0 2>/dev/null)
ACTIVE_COUNT="${#ACTIVE_CONTRACTS[@]}"

# ════════════════════════════════════════
# Gate 1: 并行上限
# ════════════════════════════════════════
if [[ "${ACTIVE_COUNT}" -gt "${MAX_PARALLEL}" ]]; then
    CONTRACT_NAMES=""
    for c in "${ACTIVE_CONTRACTS[@]}"; do
        CONTRACT_NAMES="${CONTRACT_NAMES}    - $(basename "${c}" .md)\n"
    done
    {
        echo "🚨 [Hook 拦截] 违反「滚动批次」规则 (Gate 1: 并行上限)"
        echo ""
        echo "被拦截命令: ${COMMAND:0:120}..."
        echo ""
        echo "当前 ACTIVE 合约数: ${ACTIVE_COUNT}"
        echo "上限 (max_parallel): ${MAX_PARALLEL}"
        echo "活跃合约:"
        printf '%b' "${CONTRACT_NAMES}"
        echo ""
        echo "正确做法:"
        echo "  1. 先合并已完成的 Sprint (review → merge → archive)"
        echo "  2. 将已 MERGED 的合约移到 .selfmodel/contracts/archive/"
        echo "  3. 空出 slot 后再派发新 Sprint"
        echo ""
        echo "如需紧急绕过: BYPASS_DISPATCH_GATE=1"
    } >&2
    exit 2
fi

# ── 辅助函数：从合约 Markdown 中提取 Files 段的文件列表 ──
# 解析 ### Creates 和 ### Modifies 下的 "- path/to/file" 行
extract_files_from_contract() {
    local contract_path="$1"

    # 提取 ### Creates 段
    sed -n '/^### Creates/,/^###\|^##/{/^### Creates/d;/^###/d;/^##/d;/^$/d;p;}' \
        "${contract_path}" 2>/dev/null | sed 's/^- //' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//'

    # 提取 ### Modifies 段
    sed -n '/^### Modifies/,/^###\|^##/{/^### Modifies/d;/^###/d;/^##/d;/^$/d;p;}' \
        "${contract_path}" 2>/dev/null | sed 's/^- //' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//'
}

# ── 使用 temp 目录存储每个合约的文件列表（bash 3.2 兼容，避免 declare -A）──
TMPDIR_GATE="$(mktemp -d)"
trap 'rm -rf "${TMPDIR_GATE}"' EXIT

for contract in "${ACTIVE_CONTRACTS[@]}"; do
    basename_c="$(basename "${contract}" .md)"
    extract_files_from_contract "${contract}" | grep -v '^$' > "${TMPDIR_GATE}/${basename_c}.files" 2>/dev/null || true
done

# ── 读取收敛文件列表 ──
CONVERGENCE_FILES=()
while IFS= read -r cf; do
    if [[ -n "${cf}" ]]; then
        CONVERGENCE_FILES+=("${cf}")
    fi
done < <(jq -r '.convergence_files[]? // empty' "${CONFIG}" 2>/dev/null)

# ════════════════════════════════════════
# Gate 2: 收敛文件门禁
# ════════════════════════════════════════
if [[ "${#CONVERGENCE_FILES[@]}" -gt 0 ]]; then
    for cf in "${CONVERGENCE_FILES[@]}"; do
        touching_contracts=()
        for ffile in "${TMPDIR_GATE}"/*.files; do
            [[ -f "${ffile}" ]] || continue
            if grep -qxF "${cf}" "${ffile}" 2>/dev/null; then
                touching_contracts+=("$(basename "${ffile}" .files)")
            fi
        done

        if [[ "${#touching_contracts[@]}" -ge 2 ]]; then
            {
                echo "🚨 [Hook 拦截] 违反「收敛文件门禁」规则 (Gate 2)"
                echo ""
                echo "被拦截命令: ${COMMAND:0:120}..."
                echo ""
                echo "收敛文件: ${cf}"
                echo "同时修改该文件的 ACTIVE Sprint:"
                for tc in "${touching_contracts[@]}"; do
                    echo "    - ${tc}"
                done
                echo ""
                echo "收敛文件同一时间只允许一个 ACTIVE Sprint 触碰。"
                echo ""
                echo "正确做法:"
                echo "  1. 先合并正在修改该文件的 Sprint"
                echo "  2. 释放收敛文件后再派发新 Sprint"
                echo "  3. 或将两个 Sprint 合并为一个"
                echo ""
                echo "如需紧急绕过: BYPASS_DISPATCH_GATE=1"
            } >&2
            exit 2
        fi
    done
fi

# ════════════════════════════════════════
# Gate 3: 文件重叠检查
# ════════════════════════════════════════
FILE_LIST=()
for ffile in "${TMPDIR_GATE}"/*.files; do
    [[ -f "${ffile}" ]] || continue
    FILE_LIST+=("${ffile}")
done
NUM_FILES="${#FILE_LIST[@]}"

for ((i=0; i<NUM_FILES; i++)); do
    for ((j=i+1; j<NUM_FILES; j++)); do
        file_a="${FILE_LIST[$i]}"
        file_b="${FILE_LIST[$j]}"
        name_a="$(basename "${file_a}" .files)"
        name_b="$(basename "${file_b}" .files)"

        # 跳过空文件
        [[ -s "${file_a}" ]] || continue
        [[ -s "${file_b}" ]] || continue

        # 求交集
        overlapping="$(comm -12 \
            <(sort -u "${file_a}") \
            <(sort -u "${file_b}") 2>/dev/null)" || true

        if [[ -n "${overlapping}" ]]; then
            {
                echo "🚨 [Hook 拦截] 违反「文件重叠」规则 (Gate 3)"
                echo ""
                echo "被拦截命令: ${COMMAND:0:120}..."
                echo ""
                echo "文件重叠检测:"
                echo "  Sprint A: ${name_a}"
                echo "  Sprint B: ${name_b}"
                echo "  共享文件:"
                printf '%s\n' "${overlapping}" | while read -r f; do
                    echo "    - ${f}"
                done
                echo ""
                echo "两个 ACTIVE Sprint 不得修改相同文件。"
                echo ""
                echo "正确做法:"
                echo "  1. 合并为一个 Sprint"
                echo "  2. 或串行执行：先完成一个，再派发另一个"
                echo "  3. 将共享文件加入 convergence_files 列表"
                echo ""
                echo "如需紧急绕过: BYPASS_DISPATCH_GATE=1"
            } >&2
            exit 2
        fi
    done
done

# ── 所有门禁通过 ──
exit 0
