#!/usr/bin/env bash
# verify-delivery.sh — 交付验证脚本
# 对比 Sprint 合约声明的文件列表 vs 实际修改的文件
# 用法: ./scripts/verify-delivery.sh <branch-name> [contract-path]
# 示例: ./scripts/verify-delivery.sh sprint-96-gemini
#        ./scripts/verify-delivery.sh sprint-96-gemini .selfmodel/contracts/active/sprint-96.md

set -euo pipefail

# ── 参数解析 ──
BRANCH="${1:-}"
CONTRACT="${2:-}"

if [[ -z "${BRANCH}" ]]; then
    echo "用法: $0 <branch-name> [contract-path]"
    echo "示例: $0 sprint-96-gemini"
    exit 1
fi

# ── 自动查找合约 ──
if [[ -z "${CONTRACT}" ]]; then
    # 从 branch 名提取 sprint 编号，尝试匹配合约
    SPRINT_NUM="$(printf '%s' "${BRANCH}" | grep -oE '[0-9]+' | head -1)"
    if [[ -n "${SPRINT_NUM}" ]]; then
        # 搜索 active 和 archive 目录
        CONTRACT="$(find .selfmodel/contracts/active .selfmodel/contracts/archive \
            -maxdepth 1 -name "*sprint*${SPRINT_NUM}*" -print -quit 2>/dev/null || true)"
    fi
fi

if [[ -z "${CONTRACT}" || ! -f "${CONTRACT}" ]]; then
    echo "❌ 未找到合约文件。请手动指定: $0 ${BRANCH} <contract-path>"
    exit 1
fi

echo "════════════════════════════════════════════════"
echo "🔍 交付验证: ${BRANCH}"
echo "  合约: ${CONTRACT}"
echo "═��══════════════════════════════════════════════"
echo ""

# ── 从合约提取声明的文件 ──
DECLARED_CREATES=()
DECLARED_MODIFIES=()

# 提取 ### Creates 段
while IFS= read -r line; do
    path="$(printf '%s' "${line}" | sed 's/^- //' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')"
    if [[ -n "${path}" ]]; then
        DECLARED_CREATES+=("${path}")
    fi
done < <(sed -n '/^### Creates/,/^###\|^##/{/^### Creates/d;/^###/d;/^##/d;/^$/d;p;}' "${CONTRACT}" 2>/dev/null)

# 提取 ### Modifies ��
while IFS= read -r line; do
    path="$(printf '%s' "${line}" | sed 's/^- //' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')"
    if [[ -n "${path}" ]]; then
        DECLARED_MODIFIES+=("${path}")
    fi
done < <(sed -n '/^### Modifies/,/^###\|^##/{/^### Modifies/d;/^###/d;/^##/d;/^$/d;p;}' "${CONTRACT}" 2>/dev/null)

# 合并所有声明文件
DECLARED_ALL=()
DECLARED_ALL+=("${DECLARED_CREATES[@]+"${DECLARED_CREATES[@]}"}")
DECLARED_ALL+=("${DECLARED_MODIFIES[@]+"${DECLARED_MODIFIES[@]}"}")

# ── 获取实际修改的文件 ──
ACTUAL_FILES=()
while IFS= read -r f; do
    if [[ -n "${f}" ]]; then
        ACTUAL_FILES+=("${f}")
    fi
done < <(git diff --name-only "main...${BRANCH}" 2>/dev/null)

if [[ "${#ACTUAL_FILES[@]}" -eq 0 ]]; then
    echo "⚠️  分支 ${BRANCH} 相对于 main 没有文件差异"
    exit 0
fi

# ── 对比分析 ──
MATCH=0
UNDECLARED=0
MISSING=0

echo "📋 声明的文件:"
for f in "${DECLARED_ALL[@]+"${DECLARED_ALL[@]}"}"; do
    echo "  - ${f}"
done
echo ""

echo "📂 实际修改的文件:"
for f in "${ACTUAL_FILES[@]}"; do
    echo "  - ${f}"
done
echo ""

echo "────────────────────────────────────────────────"
echo "📊 对比结果:"
echo ""

# 检查声明文件是否都被修改
for declared in "${DECLARED_ALL[@]+"${DECLARED_ALL[@]}"}"; do
    found=false
    for actual in "${ACTUAL_FILES[@]}"; do
        if [[ "${actual}" == "${declared}" ]]; then
            found=true
            break
        fi
    done
    if [[ "${found}" == "true" ]]; then
        echo "  ✅ 声明且已修改: ${declared}"
        MATCH=$((MATCH + 1))
    else
        echo "  ⚠️  声明但未修改: ${declared}"
        MISSING=$((MISSING + 1))
    fi
done

# 检查实际修改是否都在声明中
for actual in "${ACTUAL_FILES[@]}"; do
    found=false
    for declared in "${DECLARED_ALL[@]+"${DECLARED_ALL[@]}"}"; do
        if [[ "${actual}" == "${declared}" ]]; then
            found=true
            break
        fi
    done
    if [[ "${found}" == "false" ]]; then
        # 获取变更统计
        stat="$(git diff --stat "main...${BRANCH}" -- "${actual}" 2>/dev/null | tail -1 | sed 's/^[[:space:]]*//')"
        echo "  ⚠️  未声明修改: ${actual} (${stat})"
        UNDECLARED=$((UNDECLARED + 1))
    fi
done

echo ""
echo "────────────────────────────────────────────────"
echo "汇总: ${MATCH} 匹配 | ${MISSING} 声明未改 | ${UNDECLARED} 未声明修改"

if [[ "${UNDECLARED}" -gt 0 ]]; then
    echo ""
    echo "💡 建议: 未声明的文件修改可能是新的收敛文件候选。"
    echo "   考虑将频繁出现的未声明文件加入 dispatch-config.json 的 convergence_files。"
fi

echo "════════���═══════════════════════════════════════"

# 有未声明修改时返回非零（warning，不阻断）
if [[ "${UNDECLARED}" -gt 0 ]]; then
    exit 1
fi
exit 0
