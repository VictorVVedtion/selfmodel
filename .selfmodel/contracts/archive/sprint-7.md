# Sprint 7: Restore enforce-leader-worktree.sh whitelist Rules 7/8/9

## Status
ACTIVE

## Agent
opus

## Complexity
standard

## Objective
恢复 R4 (`f0410d7`) 静默删除的 Leader-worktree hook 白名单 Rules 7/8/9（LICENSE/VERSION/CHANGELOG, `.github/*`, `assets/*`），修复 canonical heredoc 漂移的根因，并加一个回归测试在未来的 `selfmodel update` 不再重放这个 bug。

## Acceptance Criteria
- [ ] `scripts/hooks/enforce-leader-worktree.sh` 恢复 Rules 7/8/9，与 `git show f0410d7^:scripts/hooks/enforce-leader-worktree.sh` 对应段落字节一致（允许微小格式调整但语义不变）
- [ ] `scripts/hooks/enforce-leader-worktree.sh` 的错误提示文案（第 77 行"白名单范围: ..."）更新，列出全部 9 类允许路径
- [ ] `scripts/selfmodel.sh` 中 `generate_hooks()` 的 `enforce-leader-worktree.sh` heredoc 模板同步增加 Rules 7/8/9，与 live file 保持等价
- [ ] 新增 `scripts/tests/test-hook-drift.sh`：对比 live hook 文件和 canonical heredoc（用 selfmodel.sh 函数生成临时文件 diff），drift 时返回非 0
- [ ] `scripts/tests/test-hook-drift.sh` 可通过 `bash scripts/tests/test-hook-drift.sh` 独立执行，加 exec 权限
- [ ] 运行 `bash scripts/tests/test-hook-drift.sh` 在本 Sprint merge 后返回 exit 0（live 和 canonical 一致）
- [ ] 手动烟雾测试：用 `echo '{"tool_input":{"file_path":"VERSION"}}' | scripts/hooks/enforce-leader-worktree.sh` 返回 exit 0（不再拦截）
- [ ] 同样 smoke：`.github/workflows/ci.yml` 和 `assets/diagram.svg` 路径也返回 exit 0
- [ ] 白名单外路径（如 `src/main.ts`）仍返回 exit 2

## Context

### 事故背景

Retroactive audit 发现 commit `f0410d7` (chore: selfmodel update regenerated team.json + leader-worktree hook) 在 "regenerating from canonical heredoc" 的幌子下悄悄删除了三条白名单规则。canonical heredoc 在 `scripts/selfmodel.sh` 里只包含 Rules 1-6，从未同步过用户手动加在 live file 里的 Rules 7-9。R4 的 regen 动作把 live 从 9 rules → 6 rules。

结果：从 2026-04-08 开始，Leader 编辑 `LICENSE`/`VERSION`/`CHANGELOG`/`.github/*`/`assets/*` 都被 hook 拦截，发布和 CI 配置修改流程实质上被冻结。

完整审计：`.selfmodel/reviews/retroactive-v0.5.0-audit.md`

### Pre-R4 的三条规则（这是要恢复的目标）

```bash
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
```

用 `git show f0410d7^:scripts/hooks/enforce-leader-worktree.sh` 获取完整 pre-R4 版本作为参考。

## Code Tour

### scripts/hooks/enforce-leader-worktree.sh (lines 32-68): 当前白名单结构
```bash
# ── 白名单规则 ──
NORMALIZED="${FILE_PATH}"
NORMALIZED="${NORMALIZED#"${PWD}/"}"
NORMALIZED="${NORMALIZED#./}"

# 1. .selfmodel/ 目录
if [[ "${NORMALIZED}" == .selfmodel/* ]]; then
    exit 0
fi

# 2. .claude/ 目录
if [[ "${NORMALIZED}" == .claude/* ]]; then
    exit 0
fi

# ... Rules 3-6 ...
```

为什么重要：新增的 Rules 7/8/9 必须遵循同样的结构（一个注释头 + 一个 if + exit 0）。正则选择器风格与 Rules 1-6 一致（`== pattern*` 或 `== pattern`）。

### scripts/selfmodel.sh (lines ~1640-1745): canonical heredoc
```bash
# 2. enforce-leader-worktree.sh
_backup_hook "$hooks_dir/enforce-leader-worktree.sh"
cat > "$hooks_dir/enforce-leader-worktree.sh" << 'HOOKEOF'
#!/usr/bin/env bash
# enforce-leader-worktree.sh — PreToolUse hook
...
# 6. .gitignore
if [[ "${NORMALIZED}" == .gitignore ]]; then
    exit 0
fi
# ── 白名单外：拦截 ──
...
HOOKEOF
chmod +x "$hooks_dir/enforce-leader-worktree.sh"
```

为什么重要：heredoc 是 canonical source of truth——`selfmodel update` 会用它重新生成 live hook。修复必须落在 heredoc 里，否则下次 update 又会退化。heredoc 结尾用 `HOOKEOF`（普通的 single-quoted heredoc 避免 shell 展开）。

## Architecture Context

- **所在层次**: Claude Code PreToolUse hook layer，拦截 Write/Edit 工具调用
- **数据流**: stdin JSON → jq 提取 file_path → 白名单匹配 → exit 0 放行 or exit 2 拦截
- **邻接模块**:
  - `.claude/settings.json`: 注册 hook 到 PreToolUse matcher `Write|Edit`
  - `scripts/selfmodel.sh` `generate_hooks()`: 从 canonical heredoc 生成 hook 文件
  - `scripts/selfmodel.sh` `_backup_hook()`: 每次 regen 前备份
  - 其他 hook 脚本（enforce-dispatch-gate, enforce-depth-gate, enforce-agent-rules）：共享 stdin JSON 协议和 exit 码约定
- **命名约定**: 函数 `lower_snake_case`，变量局部 `UPPER_SNAKE_CASE`，字符串规则 `== pattern*`
- **错误处理模式**: `set -euo pipefail` + 对 jq 依赖的 graceful fallback（第 14-17 行缺失 jq → exit 0 放行，绝不误拦截）

## Files

### Creates
- scripts/tests/test-hook-drift.sh

### Modifies
- scripts/hooks/enforce-leader-worktree.sh
- scripts/selfmodel.sh

### Out of Scope
- skill/scripts/enforce-leader-worktree.sh（如果存在镜像文件，同步但不扩展）
- .selfmodel/* 任何文件
- 其他 hook 脚本
- VERSION / LICENSE / CHANGELOG 本身的内容（下一个 Sprint 处理）

## Deliverables
- [ ] live hook 恢复 Rules 7/8/9，错误提示文案更新
- [ ] canonical heredoc 同步新增 Rules 7/8/9
- [ ] test-hook-drift.sh 脚本和测试通过
- [ ] smoke test 命令在合约里列出，merge 后 Leader 执行验证

## Smoke Test

```bash
# 1. drift check passes
bash scripts/tests/test-hook-drift.sh
# Expected: exit 0, output "✅ hook file matches canonical heredoc"

# 2. whitelist accepts the 3 restored categories
for path in VERSION LICENSE CHANGELOG.md .github/workflows/ci.yml assets/logo.svg; do
  if echo "{\"tool_input\":{\"file_path\":\"$path\"}}" | scripts/hooks/enforce-leader-worktree.sh; then
    echo "  ✅ $path passes"
  else
    echo "  ❌ $path blocked (should not be)"
    exit 1
  fi
done

# 3. non-whitelisted path still blocks
if echo '{"tool_input":{"file_path":"src/main.ts"}}' | scripts/hooks/enforce-leader-worktree.sh 2>/dev/null; then
  echo "  ❌ src/main.ts should have been blocked"
  exit 1
else
  echo "  ✅ src/main.ts correctly blocked"
fi
```

Expected: 全部 ✅，无 ❌，exit 0。

## Constraints
- Timeout: 180s
- Agent MUST work in worktree, NOT edit main directly
- Agent MUST NOT touch `.selfmodel/` directory
- Agent MUST NOT add new whitelist rules beyond the 3 being restored
- Agent MUST run the drift test and smoke test locally before declaring DELIVERED
