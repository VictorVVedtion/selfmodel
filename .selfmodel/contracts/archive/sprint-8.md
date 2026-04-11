# Sprint 8: Codify Rule 20 — Self-Dogfood

## Status
ACTIVE

## Agent
opus

## Complexity
simple

## Objective
把今天 retroactive audit 学到的教训变成硬规则：在 `CLAUDE.md` 新增 Rule 20 Self-Dogfood + `ABSOLUTELY FORBIDDEN` 段新增一条，在 `.selfmodel/playbook/lessons-learned.md` 新增 R1-R4 retroactive audit + Sprint 7 dogfooding 条目。**精确文本由 Leader 提供**（已由人类批准），Agent 的任务是**用 Edit 工具把它们插入正确位置**，不做任何内容二创。

## Acceptance Criteria

- [ ] `CLAUDE.md` 在 Rule 19 `**Depth Gate**` 整个条目结束之后、`### Leader Decision Principles` 之前的空行处，新增 Rule 20（完整文本见下方 "Exact Text" 段）
- [ ] `CLAUDE.md` 中 `## Danger Zones` → `### ABSOLUTELY FORBIDDEN` 段，在 `- **No serial execution**` 那一行之后，追加一行 `- **No direct-to-main commits on selfmodel codebase**`（完整文本见下方）
- [ ] `.selfmodel/playbook/lessons-learned.md` 在文件末尾追加新条目（完整文本见下方）
- [ ] Rule 20 的文字**逐字**匹配 Leader 提供的文本，不得改写、不得简化、不得扩写
- [ ] ABSOLUTELY FORBIDDEN 新条目格式（前导 `- **`, bold 短语, em dash, 解释句）和段内其他条目一致
- [ ] lessons-learned 新条目的 Format（Sprint / Category / Lesson / Action / Result）和现有条目完全一致
- [ ] 不修改任何其他行，不引入无关空白，不 reflow 未改动段落
- [ ] `git diff main...<worktree-branch>` 只显示 CLAUDE.md 和 lessons-learned.md 两个文件的改动，没有其他文件
- [ ] Sprint 8 merge 后，`grep -n "Self-Dogfood" CLAUDE.md` 返回 Rule 20 所在行，`grep -n "v0.5.0 Retroactive Audit" .selfmodel/playbook/lessons-learned.md` 返回新条目所在行

## Context

### 为什么要这个 Sprint

今天做了 R1-R4 retroactive audit，发现 v0.5.0 到 f0410d7 这 4 个 commit 全部直提 main 绕过了 Sprint 流程。其中 R4 (f0410d7) 静默删除了 `enforce-leader-worktree.sh` Rules 7/8/9 白名单，regression 在 main 上带病 3 天。Sprint 7 走完整 dogfooding 流程修复了它，拿到 9.15/10 ACCEPT，对比 retroactive 平均分 6.83 有 **+2.32 的纪律红利**。

用户批准把这个教训升级成 CLAUDE.md 的硬规则。这个 Sprint 本身就是 Rule 20 的第一次自我验证——用 Sprint 流程来定义 Sprint 流程必须这样走的规则。

### Exact Text (Leader-approved, do not rewrite)

**Text 1** — 新 Rule 20，插入到 CLAUDE.md Rule 19 之后、`### Leader Decision Principles` 之前：

```
20. **Self-Dogfood** — selfmodel 仓库自己的代码修改也必须走 Sprint 流程：contract → worktree → Agent → Evaluator → merge。`enforce-leader-worktree.sh` 白名单（`.selfmodel/`、`.claude/`、`scripts/`、`*.md` 等）是 hook 的最后一道安全网，**不是** Rule 7 的豁免通道。"我知道怎么修"冲动针对 selfmodel 自己代码库时等同于 Rule 7 违规。唯一例外：`BYPASS_LEADER_RULES=1` 紧急修复，且必须在同一会话内以 retroactive audit Sprint 补文档。违例先例：v0.5.0 到 f0410d7 期间 4 个直提 main commit（R1-R4），retroactive 均分 6.83；首次合规 Sprint 7 拿到 9.15，+2.32 分的纪律红利。
```

**Text 2** — ABSOLUTELY FORBIDDEN 新条目，插入到 `- **No serial execution**` 那一行之后：

```
- **No direct-to-main commits on selfmodel codebase** — Leader MUST NOT commit to `scripts/`, `scripts/hooks/`, `skill/scripts/`, or any production code file without going through a Sprint (Rule 20). Whitelist in `enforce-leader-worktree.sh` is the safety net, not the license.
```

**Text 3** — lessons-learned.md 末尾追加的新条目（保持与现有条目格式一致）：

```
### v0.5.0 Retroactive Audit: selfmodel 没在自己身上 dogfood
- **Sprint**: R1-R4（retroactive）+ Sprint 7（首次合规 dogfooding）
- **Category**: architecture
- **Lesson**: selfmodel 定义了 Rule 7/14/15/16/17/18/19 这一整套纪律给用户项目用，但 selfmodel 自己的代码开发（v0.5.0 到 f0410d7 4 个 commit）全部直提 main。直接后果：R4 (`f0410d7`) 在 "regenerated from canonical heredoc" 的幌子下静默删除了 `enforce-leader-worktree.sh` Rules 7/8/9（LICENSE/VERSION/.github/assets 白名单），regression 在 main 上带病运行 3 天，发布和 CI 流程实质冻结。retroactive audit 给 R1-R4 打出平均 6.83 分，其中 R4 仅 5.15（REVISE）。如果走了 Sprint 流程，Evaluator 会在 merge 前 catch 住 canonical heredoc 和 live hook 的 drift——因为这正是 Integration Depth 维度应当检测的。
- **Action**:
  - 事后：生成 retroactive contracts `sprint-R{1,2,3,4}-retroactive.md`，派独立 Evaluator 评分，写入 quality.jsonl（首次有数据），归档为 `.selfmodel/reviews/retroactive-v0.5.0-audit.md`
  - 系统性修复：CLAUDE.md 新增 Rule 20 (Self-Dogfood)，明确 selfmodel 自己代码库的修改不得绕过 Sprint 流程；`ABSOLUTELY FORBIDDEN` 段新增 "No direct-to-main commits on selfmodel codebase"
  - 工具层修复：Sprint 7 派 Opus Agent 走完整流程修复 R4 regression，新增 `scripts/tests/test-hook-drift.sh` 锁死 canonical heredoc 和 live hook 的字节一致性，未来 `selfmodel update` 无法再重现此 bug
  - Evaluator mutation test 证明 drift test 真实生效：注入 `# DRIFT` → test exit 1 + diff，恢复 → exit 0
- **Result**: 改善验证中 — Sprint 7 拿到 9.15/10 ACCEPT，比 retroactive 平均分 +2.32。纪律红利已量化。Sprint 9（depth gate Agent tool 覆盖）+ Sprint 10（VERSION 同步）将继续走相同流程作为第二、第三次验证
```

## Code Tour

### CLAUDE.md (lines 35-37): 插入点 1 — Rule 19 末尾
```markdown
19. **Depth Gate** — Standard/complex Sprints MUST have real Code Tour (not template placeholders) and Architecture Context in the contract before dispatch. Complex Sprints MUST complete Phase A (understanding.md) before Phase B (implementation). Deep-Read dependencies MUST be DONE before dependent Sprints dispatch. **Enforced by `enforce-depth-gate.sh` hook** — dispatch blocked at tool level if contract lacks depth content.

### Leader Decision Principles
```

为什么重要：Rule 20 必须紧接在 Rule 19 之后，保持连续编号。插入点是 Rule 19 最后一行和 `### Leader Decision Principles` heading 之间。Rule 19 下面有一个空行，然后是 heading —— Rule 20 要放在这个空行和 heading 之间（即 Rule 20 + 新空行 + heading）。

### CLAUDE.md (ABSOLUTELY FORBIDDEN 段): 插入点 2
```markdown
## Danger Zones

### Requires Human Approval
...

### ABSOLUTELY FORBIDDEN

- **No contract, no dispatch** — ...
- **No self-review** — ...
- **No skipping review** — ...
- **No raw CLI calls** — ...
- **No main-branch edits** — ...
- **No serial execution** — Independent tasks MUST be parallelized (within rolling batch cap, Rule 17)
```

为什么重要：新条目要紧接在 "No serial execution" 这一行后。现有条目格式都是 `- **<bold phrase>** — <explanation>`，严格一致。

### .selfmodel/playbook/lessons-learned.md (末尾): 插入点 3
```markdown
### 11-Sprint Fan-Out Merge Hell（跨项目通用模式）
- **Category**: architecture
...
- **Result**: 待验证
```

为什么重要：文件末尾目前最后一个条目是 "11-Sprint Fan-Out Merge Hell"，新条目直接追加在它的 Result 行之后（加一个空行分隔）。

## Architecture Context

- **所在层次**: selfmodel 框架规则层（CLAUDE.md）和 playbook 学习记录层（lessons-learned.md）
- **数据流**: CLAUDE.md 是 Leader session start 必读的规则路由，lessons-learned 是 Evolution 周期读取的经验源
- **邻接模块**:
  - `dispatch-rules.md`, `quality-gates.md`, `evaluator-prompt.md` 引用 Iron Rules 编号，新 Rule 20 不改动它们（编号延续即可）
  - Evolution pipeline DETECT 阶段会扫描 lessons-learned，新条目会被视作 CANDIDATE
- **命名约定**: 规则用 Markdown 列表编号 + bold phrase + em dash + 解释（与 Rule 1-19 一致）
- **错误处理模式**: N/A（纯文档）

## Files

### Modifies
- CLAUDE.md
- .selfmodel/playbook/lessons-learned.md

### Out of Scope
- 任何其他文件
- CLAUDE.md 其他段落的重排、修正、润色（即使你发现措辞可以更好，也不要动）
- lessons-learned.md 现有条目的任何改动

## Deliverables
- [ ] CLAUDE.md 新增 Rule 20 + FORBIDDEN 条目
- [ ] lessons-learned.md 新增 R1-R4 + Sprint 7 条目
- [ ] `git diff main...<branch>` 只显示这两个文件

## Smoke Test

```bash
# 1. Rule 20 在位
grep -n "20. \*\*Self-Dogfood\*\*" CLAUDE.md
# Expected: one match, in the Leader Rules section

# 2. FORBIDDEN 条目在位
grep -n "No direct-to-main commits on selfmodel codebase" CLAUDE.md
# Expected: one match, in the Danger Zones section

# 3. lessons-learned 新条目在位
grep -n "v0.5.0 Retroactive Audit" .selfmodel/playbook/lessons-learned.md
# Expected: one match, heading line

# 4. 没有其他文件被改
git diff main...HEAD --stat
# Expected: only CLAUDE.md and .selfmodel/playbook/lessons-learned.md

# 5. Rule 19 还在且顺序正确（sanity check）
grep -n "19. \*\*Depth Gate\*\*" CLAUDE.md
grep -n "20. \*\*Self-Dogfood\*\*" CLAUDE.md
# Expected: 20 > 19
```

Expected: 全部 grep 找到一次匹配，stat 只显示两文件。

## Constraints
- Timeout: 120s
- Agent MUST use the Edit tool for surgical insertion, NOT Write (which would rewrite whole files and risk drift)
- Agent MUST NOT rephrase, simplify, or "improve" the exact text provided
- Agent MUST NOT touch any other line
- Agent MUST NOT add trailing whitespace or blank lines beyond what's needed for separation
- Agent MUST NOT run `git push`
