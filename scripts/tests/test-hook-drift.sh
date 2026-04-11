#!/usr/bin/env bash
# test-hook-drift.sh — regression guard against canonical/live hook drift
#
# 背景：commit f0410d7 (R4) 通过 `selfmodel update` 从 scripts/selfmodel.sh
# 内的 canonical heredoc 重新生成 scripts/hooks/enforce-leader-worktree.sh，
# 静默删除了 3 条白名单规则，因为 heredoc 与 live file 长期未同步。
#
# 本测试在每次运行时从 selfmodel.sh 中抽取 enforce-leader-worktree.sh 的
# canonical heredoc，然后与 live hook 文件 byte-for-byte 比对。任何漂移
# 都会导致 exit 1 + diff 输出，CI 应当在合并前运行此测试。
#
# 用法：
#   bash scripts/tests/test-hook-drift.sh
#
# 退出码：
#   0 = canonical heredoc 与 live hook 一致
#   1 = 漂移（输出 diff）
#   2 = 测试本身出错（缺失文件、抽取失败等）

set -euo pipefail

# ── 解析仓库根目录 ──
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"

LIVE_HOOK="${REPO_ROOT}/scripts/hooks/enforce-leader-worktree.sh"
CANONICAL_SOURCE="${REPO_ROOT}/scripts/selfmodel.sh"

# ── 前置检查 ──
if [[ ! -f "${LIVE_HOOK}" ]]; then
    echo "❌ live hook not found: ${LIVE_HOOK}" >&2
    exit 2
fi

if [[ ! -f "${CANONICAL_SOURCE}" ]]; then
    echo "❌ canonical source not found: ${CANONICAL_SOURCE}" >&2
    exit 2
fi

# ── 抽取 canonical heredoc body ──
# selfmodel.sh 的 generate_hooks() 使用 single-quoted heredoc：
#     cat > "$hooks_dir/enforce-leader-worktree.sh" << 'HOOKEOF'
#     ...body...
#     HOOKEOF
# single-quoted 意味着 heredoc 内容不会被 shell 展开，所以抽取出来的
# 字节流就是 selfmodel.sh 写到磁盘的最终文件内容。
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

EXTRACTED="${TMP_DIR}/canonical-enforce-leader-worktree.sh"

awk '
    # 匹配 enforce-leader-worktree.sh 的 heredoc 起始行
    /cat > "\$hooks_dir\/enforce-leader-worktree\.sh" << '\''HOOKEOF'\''/ {
        capture = 1
        next
    }
    capture && /^HOOKEOF$/ {
        capture = 0
        exit
    }
    capture { print }
' "${CANONICAL_SOURCE}" > "${EXTRACTED}"

if [[ ! -s "${EXTRACTED}" ]]; then
    echo "❌ failed to extract canonical heredoc from ${CANONICAL_SOURCE}" >&2
    echo "   expected sentinel: cat > \"\$hooks_dir/enforce-leader-worktree.sh\" << 'HOOKEOF'" >&2
    exit 2
fi

# ── 字节级比对 ──
if diff -u "${LIVE_HOOK}" "${EXTRACTED}" > "${TMP_DIR}/diff.out"; then
    echo "✅ hook file matches canonical heredoc"
    echo "   live:      ${LIVE_HOOK}"
    echo "   canonical: ${CANONICAL_SOURCE} (generate_hooks heredoc)"
    exit 0
fi

# ── 漂移：报错并打印 diff ──
{
    echo "❌ DRIFT DETECTED between live hook and canonical heredoc"
    echo ""
    echo "   live:      ${LIVE_HOOK}"
    echo "   canonical: ${CANONICAL_SOURCE} (generate_hooks heredoc)"
    echo ""
    echo "── diff (live vs canonical) ──"
    cat "${TMP_DIR}/diff.out"
    echo ""
    echo "Why this matters:"
    echo "  selfmodel update 会从 canonical heredoc 重新生成 live hook。"
    echo "  漂移意味着下一次 update 会静默改写 live hook，可能丢失规则"
    echo "  （参考事故 commit f0410d7，retroactive audit"
    echo "   .selfmodel/reviews/retroactive-v0.5.0-audit.md）。"
    echo ""
    echo "Fix:"
    echo "  1. 决定哪边是真实意图（通常是 live hook）"
    echo "  2. 同步另一边，让两侧 byte-for-byte 一致"
    echo "  3. 重新运行此测试确认 exit 0"
} >&2

exit 1
