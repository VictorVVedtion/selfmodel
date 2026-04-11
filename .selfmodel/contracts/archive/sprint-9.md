# Sprint 9: VERSION string sync (drift fix)

## Status
ACTIVE

## Agent
opus

## Complexity
simple

## Objective
把 selfmodel 的版本字符串从当前漂移状态（VERSION=0.4.0 / CLI=0.3.0）统一到 `0.5.0`，匹配实际已在 main 上落地的 v0.5.0 era 功能（depth-first enforcement + sprint-template guard + hook format fix + whitelist restore + Rule 20 Self-Dogfood），并在 CHANGELOG 正式记录 `[0.5.0] - 2026-04-11` 条目。

## Acceptance Criteria
- [ ] `VERSION` 文件内容是字面量 `0.5.0`（无尾随空白以外的字符）
- [ ] `scripts/selfmodel.sh` 第 8 行 `SELFMODEL_VERSION="0.5.0"`（其他行不变）
- [ ] `README.md` 第 13 行 version badge URL 改为 `0.5.0`；`alt` 文本也同步为 `Version 0.5.0`
- [ ] `CHANGELOG.md` 在 `## [0.4.0] - 2026-04-07` 之上新增一个 `## [0.5.0] - 2026-04-11` 条目，内容**必须**与 inbox 任务文件 `### CHANGELOG Entry (Verbatim)` 段一字不差
- [ ] `README.md` 第 83/190/280/358/373/430 行的 `v0.3.0` 字样**保持原样**（这些是历史 feature-since 标记，不是 drift）
- [ ] `bash scripts/selfmodel.sh --version` 在 worktree 中运行，输出第一行是 `selfmodel 0.5.0`
- [ ] `cat VERSION` 在 worktree 中输出 `0.5.0`（允许一个尾随换行）
- [ ] `grep -n '^## \[0.5.0\]' CHANGELOG.md` 返回一行且行号小于 `grep -n '^## \[0.4.0\]' CHANGELOG.md` 返回的行号
- [ ] 未修改 `.selfmodel/` 目录下任何文件

## Context

### 漂移事实（Grep 已确认）

| 位置 | 当前值 | 目标值 |
|------|--------|--------|
| `VERSION` (file) | `0.4.0` | `0.5.0` |
| `scripts/selfmodel.sh:8` | `SELFMODEL_VERSION="0.3.0"` | `SELFMODEL_VERSION="0.5.0"` |
| `README.md:13` badge | `version-0.4.0-green` | `version-0.5.0-green` |
| `CHANGELOG.md` 最新条目 | `[0.4.0]` | 新增 `[0.5.0]` 在顶部 |

### 为什么现在值得做

1. **CLI 常量比 VERSION 还旧** — `selfmodel --version` 报 `0.3.0`，但 `VERSION` 是 `0.4.0`，两个字符串彼此矛盾
2. **实际 main 上已经跑了 v0.5.0 era 功能** — R1-R4 retroactive audit 已经把这些功能命名为 v0.5.0 era，只是从未在 CHANGELOG 里正式登记过
3. **Sprint 7 + Sprint 8 是 v0.5.0 的收尾** — Sprint 7 修复了 R4 的 whitelist regression，Sprint 8 codify 了 Rule 20。都已 push 到 `origin/main`。现在把版本字符串追上是纯字符串同步，无行为改动。

### Out of Scope 解释

以下"v0.3.0"字样**不是** drift，**必须保留**：

- `README.md:83` `selfmodel update --remote --version v0.3.0` —— CLI 语法示例
- `README.md:190` `Dispatch gate (v0.3.0)` —— feature-since 标记（dispatch gate 确实是 0.3.0 引入的）
- `README.md:280` `VERSION` 例子 `0.3.0` —— 目录结构说明中的 historical example
- `README.md:358` `Rolling batch (v0.3.0)` —— feature-since
- `README.md:373` `### Dispatch Gate (v0.3.0)` —— feature-since section heading
- `README.md:430` `selfmodel update [--remote] [--version v0.3.0]` —— CLI 语法示例

`.selfmodel/state/team.json` 的 `protocol_version: "0.3.0"` 是 evolution subsystem 的独立版本号，本 Sprint **不碰**。

`skill/references/evolution-protocol.md:285` 和 `.selfmodel/playbook/evolution-protocol.md:285` 的 `Example: 0.3.0` 是 docs 示例文本，本 Sprint **不碰**。

## Files

### Creates
_无_

### Modifies
- VERSION
- scripts/selfmodel.sh
- README.md
- CHANGELOG.md

### Out of Scope
- .selfmodel/ 任何文件
- README.md 第 83/190/280/358/373/430 行的历史 v0.3.0 字样
- skill/references/evolution-protocol.md
- .selfmodel/playbook/evolution-protocol.md
- .selfmodel/state/team.json
- scripts/selfmodel.sh 第 8 行以外的任何行

## Constraints
- Timeout: 120s
- Agent MUST work in worktree, NOT edit main directly
- Agent MUST use Edit tool with precise `old_string`/`new_string`, not Write for the 4 modified files
- Agent MUST insert CHANGELOG entry **verbatim** from inbox task file
- Agent MUST NOT touch any other `v0.3.0` or `v0.4.0` string in the repo
- Agent MUST run `bash scripts/selfmodel.sh --version` from within worktree and report the first line of stdout before declaring DELIVERED

## Deliverables
- [ ] 4 文件修改完成
- [ ] `--version` 自测通过（第一行 = `selfmodel 0.5.0`）
- [ ] git diff 在 worktree 中显示恰好 4 个文件修改，无其他变动

## Smoke Test

Leader 在 merge 后执行（worktree 内也应通过）:

```bash
# 1. VERSION file
test "$(cat VERSION | tr -d '\n')" = "0.5.0" && echo "  ✅ VERSION" || { echo "  ❌ VERSION"; exit 1; }

# 2. CLI constant
grep -q '^SELFMODEL_VERSION="0.5.0"$' scripts/selfmodel.sh && echo "  ✅ CLI const" || { echo "  ❌ CLI const"; exit 1; }

# 3. CLI version output
first_line="$(bash scripts/selfmodel.sh --version 2>/dev/null | head -1)"
test "$first_line" = "selfmodel 0.5.0" && echo "  ✅ --version" || { echo "  ❌ --version got: $first_line"; exit 1; }

# 4. README badge
grep -q 'version-0.5.0-green' README.md && echo "  ✅ README badge" || { echo "  ❌ README badge"; exit 1; }

# 5. CHANGELOG entry exists and precedes 0.4.0
line_new=$(grep -n '^## \[0.5.0\]' CHANGELOG.md | head -1 | cut -d: -f1)
line_old=$(grep -n '^## \[0.4.0\]' CHANGELOG.md | head -1 | cut -d: -f1)
test -n "$line_new" && test "$line_new" -lt "$line_old" && echo "  ✅ CHANGELOG order" || { echo "  ❌ CHANGELOG order ($line_new vs $line_old)"; exit 1; }

# 6. historical v0.3.0 markers untouched
historical_count=$(grep -c 'v0.3.0' README.md)
test "$historical_count" -ge 5 && echo "  ✅ historical markers preserved ($historical_count)" || { echo "  ❌ historical markers touched ($historical_count)"; exit 1; }

# 7. .selfmodel/ untouched
git diff --name-only main...HEAD | grep -q '^\.selfmodel/' && { echo "  ❌ .selfmodel/ was touched"; exit 1; } || echo "  ✅ .selfmodel/ untouched"

echo "✅ all smoke checks passed"
```

Expected: 全部 ✅，exit 0。
