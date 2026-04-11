# Task: Sprint 9 — VERSION string sync

## Contract
`.selfmodel/contracts/active/sprint-9.md`

## 身份与规则

你是 Opus Agent（worktree-isolated）。你是 Senior Fullstack 角色，这次任务是 **simple 复杂度的字符串同步 Sprint**。

**禁止**：
- 修改 `.selfmodel/` 任何文件
- 修改 `scripts/selfmodel.sh` 第 8 行以外的任何行
- 修改 `README.md` 第 13 行以外涉及 `v0.3.0` 或 `0.3.0` 的行
- 使用 `git reset --hard` / `git clean -f` / `git push` / `rm -rf`
- 擅自在 CHANGELOG 里用自己的措辞（正文**必须**字节一致地复制下面的 Verbatim 块）
- 添加任何额外文件
- 运行任何 install / update 命令

## 任务背景

运行 `cat VERSION`、`grep SELFMODEL_VERSION scripts/selfmodel.sh`、`grep 'version-0\.4\.0' README.md` 会发现版本字符串彼此矛盾：

| 位置 | 当前 | 目标 |
|------|------|------|
| `VERSION` | `0.4.0` | `0.5.0` |
| `scripts/selfmodel.sh:8` | `SELFMODEL_VERSION="0.3.0"` | `SELFMODEL_VERSION="0.5.0"` |
| `README.md:13` badge | `version-0.4.0-green` + `Version 0.4.0` | `version-0.5.0-green` + `Version 0.5.0` |
| `CHANGELOG.md` 顶部 | `## [0.4.0] - 2026-04-07` | 新增 `## [0.5.0] - 2026-04-11` 在 [0.4.0] 之上 |

`v0.5.0` era 功能（depth-first enforcement、sprint-template guard、hook format fix、whitelist restore、Rule 20 Self-Dogfood）都已经落在 main 上，只是字符串没追上。这是字符串同步 Sprint，不是功能 Sprint。

## 执行步骤

### Step 1 — 读当前状态

```bash
cat VERSION
sed -n '8p' scripts/selfmodel.sh
sed -n '13p' README.md
head -10 CHANGELOG.md
```

确认 4 处漂移与合约一致。

### Step 2 — Edit VERSION

用 Edit tool：
- `file_path`: `VERSION`
- `old_string`: `0.4.0`
- `new_string`: `0.5.0`

### Step 3 — Edit scripts/selfmodel.sh

用 Edit tool：
- `file_path`: `scripts/selfmodel.sh`
- `old_string`: `SELFMODEL_VERSION="0.3.0"`
- `new_string`: `SELFMODEL_VERSION="0.5.0"`

**Warning**: `grep -c '0.3.0' scripts/selfmodel.sh` 会返回 2（还有一行是 `--version v0.3.0` 的 CLI usage 示例）。**只改第 8 行的 SELFMODEL_VERSION 常量，不改 usage 示例**。因为 `SELFMODEL_VERSION="0.3.0"` 在文件中只出现一次，Edit 会精确匹配。

### Step 4 — Edit README.md (line 13 badge)

用 Edit tool：
- `file_path`: `README.md`
- `old_string`: `  <img src="https://img.shields.io/badge/version-0.4.0-green.svg?style=flat-square" alt="Version 0.4.0">`
- `new_string`: `  <img src="https://img.shields.io/badge/version-0.5.0-green.svg?style=flat-square" alt="Version 0.5.0">`

这是整行替换，包含两处 `0.4.0` → `0.5.0`（URL 参数 + alt 文本），以及两个前导空格的缩进。

### Step 5 — Edit CHANGELOG.md (insert [0.5.0] entry)

用 Edit tool：
- `file_path`: `CHANGELOG.md`
- `old_string`: `## [0.4.0] - 2026-04-07`
- `new_string`: 下面 `### CHANGELOG Entry (Verbatim)` 段的完整内容 + `\n\n## [0.4.0] - 2026-04-07`

具体：把 `## [0.4.0] - 2026-04-07` 替换为 `<verbatim-entry>\n\n## [0.4.0] - 2026-04-07`（注意中间有**一个空行**隔开）。

### CHANGELOG Entry (Verbatim)

**以下文本**（从 `## [0.5.0] - 2026-04-11` 开始，到最后一行 bullet 结束）**必须字节一致地**作为新 `old_string` / `new_string` 操作的插入内容。不要改写、不要补充、不要翻译。

```markdown
## [0.5.0] - 2026-04-11

### Added
- **Depth-First Workflow Enforcement** (`enforce-depth-gate.sh`) — hook-enforced gate blocking dispatch of standard/complex Sprints whose contracts lack real Code Tour + Architecture Context. Complex Sprints MUST complete Phase A (`understanding.md`) before Phase B implementation.
- **Sprint Complexity Field** (`simple | standard | complex`) — determines required contract sections and dispatch protocol. Contracts gained `## Complexity`, `## Code Tour`, `## Architecture Context`, `## Understanding Checkpoint`, `## Files`, and `## Smoke Test` sections.
- **Two-Phase Dispatch** for complex Sprints — Phase A produces `understanding.md` in the worktree, Leader validates, then Phase B implementation begins. Prevents drive-by implementation without codebase comprehension.
- **Deep-Read Mode** — Leader extracts patterns to `.selfmodel/artifacts/` for complex Sprint dependencies, bridging Rule 7 ("no implementation") with the need to understand existing code.
- **Iron Rule 19: Depth Gate** — hook-enforced, blocks dispatch at tool level when standard/complex contracts lack depth content.
- **Iron Rule 20: Self-Dogfood** — selfmodel's own code changes MUST go through Sprint flow. `enforce-leader-worktree.sh` whitelist is a safety net, not a Rule 7 exemption. Only exception: `BYPASS_LEADER_RULES=1` emergency fix, which must be followed by a retroactive audit Sprint in the same session.
- **Hook Drift Test** (`scripts/tests/test-hook-drift.sh`) — extracts canonical heredoc from `scripts/selfmodel.sh` and diffs against live hook files, exits non-zero on drift. Prevents silent hook regression during `selfmodel update`.
- **Retroactive Audit Protocol** — `sprint-R{N}-retroactive.md` contracts for auditing commits that bypassed Sprint flow. First run audited v0.5.0 era (R1-R4) and wrote 4 rows to `quality.jsonl` (mean 6.83/10), archived to `.selfmodel/reviews/retroactive-v0.5.0-audit.{md,json}`.

### Fixed
- **enforce-leader-worktree.sh whitelist regression** (Sprint 7) — R4 (`f0410d7`) silently removed Rules 7/8/9 (LICENSE/VERSION/CHANGELOG, `.github/*`, `assets/*`) during canonical heredoc regen, freezing the release workflow for 3 days. Restored byte-for-byte from `f0410d7^`. First fully compliant dogfood Sprint — scored 9.15/10 vs retroactive mean 6.83 (+2.32 discipline dividend).
- **`generate_playbook()` sprint-template.md overwrite** (R2) — added `if-not-exists` guard matching `dispatch-rules.md`/`quality-gates.md` pattern, preventing depth-gate fields from being wiped on every `selfmodel update`.
- **`.claude/settings.json` hook entry format** (R3) — normalized PreToolUse hook structure.

### Changed
- **Lessons learned protocol** (`.selfmodel/playbook/lessons-learned.md`) — new v0.5.0 retroactive audit entry documenting "why Sprint discipline matters" with quantified +2.32 discipline dividend.
```

### Step 6 — 本地验证（在 worktree 内运行）

```bash
# 1. VERSION
test "$(cat VERSION | tr -d '\n')" = "0.5.0" && echo "  ok VERSION" || { echo "  FAIL VERSION"; exit 1; }

# 2. CLI constant
grep -q '^SELFMODEL_VERSION="0.5.0"$' scripts/selfmodel.sh && echo "  ok CLI const" || { echo "  FAIL CLI const"; exit 1; }

# 3. CLI --version output
first_line="$(bash scripts/selfmodel.sh --version 2>/dev/null | head -1)"
test "$first_line" = "selfmodel 0.5.0" && echo "  ok --version" || { echo "  FAIL --version got: $first_line"; exit 1; }

# 4. README badge
grep -q 'version-0.5.0-green' README.md && echo "  ok README badge" || { echo "  FAIL README badge"; exit 1; }

# 5. CHANGELOG ordering
line_new=$(grep -n '^## \[0.5.0\]' CHANGELOG.md | head -1 | cut -d: -f1)
line_old=$(grep -n '^## \[0.4.0\]' CHANGELOG.md | head -1 | cut -d: -f1)
test -n "$line_new" && test "$line_new" -lt "$line_old" && echo "  ok CHANGELOG order ($line_new < $line_old)" || { echo "  FAIL CHANGELOG order ($line_new vs $line_old)"; exit 1; }

# 6. historical v0.3.0 markers preserved
historical_count=$(grep -c 'v0.3.0' README.md)
test "$historical_count" -ge 5 && echo "  ok historical markers ($historical_count kept)" || { echo "  FAIL historical markers ($historical_count found, expected >= 5)"; exit 1; }

# 7. .selfmodel/ untouched
touched_selfmodel=$(git diff --name-only main...HEAD 2>/dev/null | grep -c '^\.selfmodel/' || true)
test "$touched_selfmodel" = "0" && echo "  ok .selfmodel/ untouched" || { echo "  FAIL .selfmodel/ touched ($touched_selfmodel files)"; exit 1; }

# 8. exactly 4 files changed
changed_count=$(git diff --name-only main...HEAD 2>/dev/null | wc -l | tr -d ' ')
test "$changed_count" = "4" && echo "  ok exactly 4 files changed" || { echo "  FAIL $changed_count files changed (expected 4)"; git diff --name-only main...HEAD; exit 1; }

echo "all local checks passed"
```

### Step 7 — Commit

```bash
git add VERSION scripts/selfmodel.sh README.md CHANGELOG.md
git commit -m "chore(sprint-9): sync version strings to 0.5.0

- VERSION: 0.4.0 → 0.5.0
- scripts/selfmodel.sh SELFMODEL_VERSION: 0.3.0 → 0.5.0
- README.md badge: 0.4.0 → 0.5.0
- CHANGELOG.md: add [0.5.0] - 2026-04-11 entry for v0.5.0 era features

Reflects work already in main:
- Depth-first enforcement (R1)
- Sprint-template guard (R2)
- Hook format fix (R3)
- Whitelist restore (Sprint 7)
- Rule 20 Self-Dogfood (Sprint 8)

No behavior change, pure string sync."
```

### Step 8 — 报告 DELIVERED

输出必须包含以下块（Leader 会解析）：

```
STATUS: DELIVERED

Files changed:
  M VERSION
  M scripts/selfmodel.sh
  M README.md
  M CHANGELOG.md

--version output: <粘贴 Step 6 第 3 项实际输出的 first_line>

Local checks: all 8 passed
Commit: <git rev-parse --short HEAD>
```

## Allowed Tools
Read, Grep, Edit, Bash（仅限 git diff / git log / git add / git commit / bash scripts/selfmodel.sh --version / 上述 Step 6 验证命令 / sed -n / grep / cat）

## Forbidden Tools
Write（4 文件全部是已存在的，用 Edit），TodoWrite 以外的 Task， rm, git reset, git push, git clean, mv, cp

## Timeout
120s

## Success Criteria
所有 8 条 Step 6 验证 pass + 4 文件修改 + 1 commit + STATUS: DELIVERED 输出。
