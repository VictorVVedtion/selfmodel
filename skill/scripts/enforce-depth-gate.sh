#!/usr/bin/env bash
# enforce-depth-gate.sh — PreToolUse hook (matcher: Bash)
# 深度验证门禁：三道硬检查防止「生成空壳跳过理解」
# Gate 4: Contract 质量（standard/complex 必须有真实 Code Tour）
# Gate 5: Deep-Read 依赖（sprint 引用的 deep-read 必须已完成）
# Gate 6: 理解阶段（complex sprint Phase B 必须有 understanding.md）
# exit 0 = 放行 | exit 2 = 拦截
# 兼容 bash 3.2+ (macOS 默认)

set -euo pipefail

# ── 紧急绕过 ──
if [[ "${BYPASS_DEPTH_GATE:-0}" == "1" ]]; then
    exit 0
fi

# ── jq 依赖检测 ──
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

if [[ "${IS_AGENT}" == "false" ]]; then
    exit 0
fi

# ── 提取 sprint 编号 ──
SPRINT_NUM="$(printf '%s' "${COMMAND}" | grep -oE 'sprint-[0-9]+' | head -1 | sed 's/sprint-//' || true)"
if [[ -z "${SPRINT_NUM}" ]]; then
    # 无法确定 sprint 编号时放行（可能是 evaluator/researcher 调用）
    exit 0
fi

# ── 查找合约文件 ──
CONTRACT=""
for f in .selfmodel/contracts/active/sprint-"${SPRINT_NUM}"*.md; do
    if [[ -f "${f}" ]]; then
        CONTRACT="${f}"
        break
    fi
done

if [[ -z "${CONTRACT}" ]]; then
    # 合约不存在时放行（enforce-agent-rules.sh 已检查合约存在性）
    exit 0
fi

# ── 解析 Complexity ──
# 在 ## Complexity 后找 simple/standard/complex
COMPLEXITY="standard"  # 默认 standard
COMPLEXITY_LINE="$(sed -n '/^## Complexity/,/^##/{/^## Complexity/d;/^##/d;/^$/d;p;}' "${CONTRACT}" 2>/dev/null | head -1 | tr -d '[:space:]')"
case "${COMPLEXITY_LINE}" in
    simple)   COMPLEXITY="simple" ;;
    standard) COMPLEXITY="standard" ;;
    complex)  COMPLEXITY="complex" ;;
esac

# simple sprint 直接放行，不需要深度检查
if [[ "${COMPLEXITY}" == "simple" ]]; then
    exit 0
fi

# ════════════════════════════════════════
# Gate 4: Contract 质量门禁
# standard/complex 必须有真实 Code Tour
# ════════════════════════════════════════

# 提取 Code Tour section 内容
CODE_TOUR_CONTENT="$(sed -n '/^## Code Tour/,/^## /{/^## Code Tour/d;/^## /d;p;}' "${CONTRACT}" 2>/dev/null || true)"

# 检查是否有真实内容（非模板占位符）
# 模板占位符包含 <file-path>, <lang>, <Leader 提取
HAS_REAL_CODE_TOUR=false
if [[ -n "${CODE_TOUR_CONTENT}" ]]; then
    # 检查是否包含真实文件路径（至少一个不以 < 开头的 ### 行，或包含实际路径如 src/ ./ ）
    if printf '%s' "${CODE_TOUR_CONTENT}" | grep -qE '(src/|lib/|app/|packages/|\.ts|\.js|\.py|\.rs|\.go|\.sh|lines [0-9])'; then
        HAS_REAL_CODE_TOUR=true
    fi
fi

if [[ "${HAS_REAL_CODE_TOUR}" == "false" ]]; then
    {
        echo "🚨 [Hook 拦截] 违反「深度验证」规则 (Gate 4: Contract 质量)"
        echo ""
        echo "被拦截命令: ${COMMAND:0:120}..."
        echo ""
        echo "Sprint ${SPRINT_NUM} Complexity: ${COMPLEXITY}"
        echo "standard/complex Sprint 的合约必须包含真实 Code Tour。"
        echo ""
        echo "当前 Code Tour 状态: $([ -n "${CODE_TOUR_CONTENT}" ] && echo '有内容但是模板占位符' || echo '缺失')"
        echo ""
        echo "正确做法:"
        echo "  1. Leader 先读取参考文件"
        echo "  2. 提取 2-5 个真实代码片段（含文件路径和行号）"
        echo "  3. 写入合约 ## Code Tour section"
        echo "  4. 然后再派发 Agent"
        echo ""
        echo "这不是建议，是硬门禁。你必须先理解代码再派活。"
        echo ""
        echo "如需紧急绕过: BYPASS_DEPTH_GATE=1"
    } >&2
    exit 2
fi

# 检查 Architecture Context（standard/complex 都需要）
ARCH_CONTENT="$(sed -n '/^## Architecture Context/,/^## /{/^## Architecture Context/d;/^## /d;p;}' "${CONTRACT}" 2>/dev/null || true)"
HAS_REAL_ARCH=false
if [[ -n "${ARCH_CONTENT}" ]]; then
    # 检查是否有真实内容（非模板占位符 <一句话>）
    if printf '%s' "${ARCH_CONTENT}" | grep -qvE '<.*>' 2>/dev/null; then
        # 至少 3 行非空内容
        ARCH_LINE_COUNT="$(printf '%s' "${ARCH_CONTENT}" | grep -cvE '^$|^[[:space:]]*$' 2>/dev/null || echo 0)"
        if [[ "${ARCH_LINE_COUNT}" -ge 3 ]]; then
            HAS_REAL_ARCH=true
        fi
    fi
fi

if [[ "${HAS_REAL_ARCH}" == "false" ]]; then
    {
        echo "🚨 [Hook 拦截] 违反「深度验证」规则 (Gate 4: Architecture Context)"
        echo ""
        echo "被拦截命令: ${COMMAND:0:120}..."
        echo ""
        echo "Sprint ${SPRINT_NUM} Complexity: ${COMPLEXITY}"
        echo "standard/complex Sprint 的合约必须包含真实 Architecture Context。"
        echo ""
        echo "需要填写: 所在层次、数据流、邻接模块、命名约定、错误处理模式"
        echo ""
        echo "正确做法:"
        echo "  1. Leader 读取相关代码，理解架构"
        echo "  2. 填写合约 ## Architecture Context section"
        echo "  3. 然后再派发 Agent"
        echo ""
        echo "如需紧急绕过: BYPASS_DEPTH_GATE=1"
    } >&2
    exit 2
fi

# ════════════════════════════════════════
# Gate 5: Deep-Read 依赖门禁
# sprint 引用的 deep-read artifact 必须已存在
# ════════════════════════════════════════

PLAN_FILE=".selfmodel/state/plan.md"
if [[ -f "${PLAN_FILE}" ]]; then
    # 找到当前 Sprint 的 Dependencies 行
    # 格式: - Dependencies: DR1, Sprint 3
    DEPS_LINE="$(sed -n "/^### Sprint ${SPRINT_NUM}:/,/^###/{/^- Dependencies:/p;}" "${PLAN_FILE}" 2>/dev/null | head -1 || true)"

    if [[ -n "${DEPS_LINE}" ]]; then
        # 提取所有 DR 引用
        DR_DEPS="$(printf '%s' "${DEPS_LINE}" | grep -oE 'DR[0-9]+' || true)"

        for dr in ${DR_DEPS}; do
            # 查找 Deep-Read 条目的 Status
            DR_STATUS="$(sed -n "/^### Deep-Read ${dr}:/,/^###/{/^- Status:/p;}" "${PLAN_FILE}" 2>/dev/null | head -1 | sed 's/.*Status: //' | tr -d '[:space:]' || true)"

            if [[ -n "${DR_STATUS}" && "${DR_STATUS}" != "DONE" ]]; then
                # 也检查 Output artifact 是否存在
                DR_OUTPUT="$(sed -n "/^### Deep-Read ${dr}:/,/^###/{/^- Output:/p;}" "${PLAN_FILE}" 2>/dev/null | head -1 | sed 's/.*Output: //' | tr -d '[:space:]' || true)"

                {
                    echo "🚨 [Hook 拦截] 违反「深度验证」规则 (Gate 5: Deep-Read 依赖)"
                    echo ""
                    echo "被拦截命令: ${COMMAND:0:120}..."
                    echo ""
                    echo "Sprint ${SPRINT_NUM} 依赖 ${dr}，但 ${dr} 状态: ${DR_STATUS}"
                    if [[ -n "${DR_OUTPUT}" ]]; then
                        echo "预期产物: ${DR_OUTPUT}"
                        if [[ -f "${DR_OUTPUT}" ]]; then
                            echo "产物文件: 存在 ✓（但 plan.md 未标记 DONE）"
                        else
                            echo "产物文件: 不存在 ✗"
                        fi
                    fi
                    echo ""
                    echo "正确做法:"
                    echo "  1. Leader 先完成 ${dr}（读源码、写提取文档）"
                    echo "  2. 在 plan.md 中标记 ${dr} Status → DONE"
                    echo "  3. 然后再派发 Sprint ${SPRINT_NUM}"
                    echo ""
                    echo "Deep-Read 是不可跳过的深度工作。不读就不能派。"
                    echo ""
                    echo "如需紧急绕过: BYPASS_DEPTH_GATE=1"
                } >&2
                exit 2
            fi
        done
    fi
fi

# ════════════════════════════════════════
# Gate 6: 理解阶段门禁 (complex only)
# Phase B 必须有 understanding.md
# ════════════════════════════════════════

if [[ "${COMPLEXITY}" == "complex" ]]; then
    # 检测是否为 Phase A 调用（Phase A 不需要 understanding.md）
    IS_PHASE_A=false
    if printf '%s' "${COMMAND}" | grep -qiE 'phase.?a|understand.*only|理解阶段|只读'; then
        IS_PHASE_A=true
    fi

    if [[ "${IS_PHASE_A}" == "false" ]]; then
        # Phase B（实现阶段）— 必须有 understanding.md

        # 提取 worktree 路径
        WORKTREE_PATH="$(printf '%s' "${COMMAND}" | grep -oE 'cd [^ &]+' | head -1 | sed 's/cd //' || true)"

        if [[ -n "${WORKTREE_PATH}" ]]; then
            # 展开可能的变量（如 ~ 或 $HOME）
            WORKTREE_PATH="$(eval echo "${WORKTREE_PATH}" 2>/dev/null || echo "${WORKTREE_PATH}")"

            if [[ -d "${WORKTREE_PATH}" ]]; then
                UNDERSTANDING_FILE="${WORKTREE_PATH}/understanding.md"

                if [[ ! -f "${UNDERSTANDING_FILE}" ]]; then
                    {
                        echo "🚨 [Hook 拦截] 违反「深度验证」规则 (Gate 6: 理解阶段)"
                        echo ""
                        echo "被拦截命令: ${COMMAND:0:120}..."
                        echo ""
                        echo "Sprint ${SPRINT_NUM} Complexity: complex"
                        echo "Complex Sprint 的实现阶段（Phase B）必须先有 understanding.md。"
                        echo ""
                        echo "Worktree: ${WORKTREE_PATH}"
                        echo "Expected: ${UNDERSTANDING_FILE}"
                        echo "Status: 不存在 ✗"
                        echo ""
                        echo "正确做法:"
                        echo "  1. 先派发 Phase A（只读理解阶段）"
                        echo "  2. Agent 产出 understanding.md（读了什么、发现什么模式、怎么集成）"
                        echo "  3. Leader 验证 understanding.md"
                        echo "  4. 然后再派发 Phase B（实现阶段）"
                        echo ""
                        echo "不理解就不能写代码。这是硬门禁。"
                        echo ""
                        echo "如需紧急绕过: BYPASS_DEPTH_GATE=1"
                    } >&2
                    exit 2
                fi

                # understanding.md 存在，检查是否有实质内容（至少 10 行非空）
                UNDERSTANDING_LINES="$(grep -cvE '^$|^[[:space:]]*$' "${UNDERSTANDING_FILE}" 2>/dev/null || echo 0)"
                if [[ "${UNDERSTANDING_LINES}" -lt 10 ]]; then
                    {
                        echo "🚨 [Hook 拦截] 违反「深度验证」规则 (Gate 6: 理解阶段 — 内容不足)"
                        echo ""
                        echo "Sprint ${SPRINT_NUM} 的 understanding.md 只有 ${UNDERSTANDING_LINES} 行实质内容。"
                        echo "这看起来像敷衍产出。最低要求: 10 行非空内容。"
                        echo ""
                        echo "understanding.md 必须包含:"
                        echo "  1. Files Read — 具体文件路径和行号"
                        echo "  2. Patterns Found — 至少 2 个现有模式"
                        echo "  3. Integration Plan — 具体的函数/类型/导出引用"
                        echo "  4. Failure Modes — 针对本 Sprint 的具体风险"
                        echo ""
                        echo "如需紧急绕过: BYPASS_DEPTH_GATE=1"
                    } >&2
                    exit 2
                fi
            fi
        fi
    fi
fi

# ── 所有门禁通过 ──
exit 0
