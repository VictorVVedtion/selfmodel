# Quality Gates

质量门禁。Leader 审查 Sprint 交付物时必须查阅本文件。

---

## 5 维度评分体系

| 维度 | 权重 | 说明 |
|---|---|---|
| Functionality | 30% | 合约验收标准是否全部满足 |
| Code Quality | 25% | Iron Rules 合规性 |
| Design Taste | 20% | 命名、架构、抽象层次的品味 |
| Completeness | 15% | 错误处理、边界条件、分支覆盖 |
| Originality | 10% | 方案的优雅程度，非显而易见的解法 |

### Functionality（30%）

- **10/10**: 验收标准逐条通过，边界输入（空值/极端值/并发）处理完整，无 regression
- **7/10**: 核心功能通过，1-2 个边界场景未覆盖但不影响正常使用
- **<5 自动拒绝**: 验收标准有未通过项，或核心路径崩溃

### Code Quality（25%）

- **10/10**: Iron Rules 全满足，零 anti-pattern，代码风格与项目一致
- **7/10**: 铁律满足，有 1-2 处风格不一致但不影响可读性
- **<5 自动拒绝**: 含 TODO/FIXME，含 mock 数据，含异常吞没，编译失败

### Design Taste（20%）

- **10/10**: 命名读起来像散文，函数职责单一，抽象层次清晰，架构值得截图
- **7/10**: 命名准确但不优雅，结构合理但有 1 处可以更好的抽象
- **<5 自动拒绝**: 泛型命名（data/handler/utils/temp），God function，无抽象

### Completeness（15%）

- **10/10**: 所有 I/O 有错误处理，所有 if 有 else（或 guard clause），类型完整
- **7/10**: 主路径错误处理完整，1-2 个次要路径缺少 catch
- **<5 自动拒绝**: 主路径缺少错误处理，文件/网络操作无 try-catch

### Originality（10%）

- **10/10**: 方案优雅且非显而易见，利用语言特性减少代码量 30%+
- **7/10**: 方案正确清晰，采用标准最佳实践
- **<5 自动拒绝**: 暴力实现，复制粘贴，未利用已有工具

---

## 自动拒绝触发器

以下任一触发 = Grade F，Sprint 从头重做：

1. 含 `// TODO` / `# TODO` / `FIXME` / `HACK` / `XXX`
2. 含 mock 数据、placeholder、fake content（`Lorem ipsum`、`test@test.com`、`foo/bar`）
3. 含 `except: pass` / `catch {}` / 空 catch 块 / 异常吞没
4. 编译失败 / build 失败 / 主入口 import 报错
5. I/O / 网络 / 文件操作缺少错误处理
6. 变量名 < 3 字符（`i/j/k`、`x/y/z`、`n/m` 除外）
7. 单函数 > 50 行未拆分（不含空行和注释）
8. Dead code（被注释掉的代码块）或 unused import
9. 硬编码 secrets / API keys / credentials
10. 强类型语言缺少类型注解（TypeScript 的 `any` 视为缺失）

---

## AI Slop 检测

以下模式是 AI 生成代码的典型低质量特征。Evaluator 应在 Code Quality 维度扣分：

1. **过度注释** — 每行代码配一行注释解释显而易见的逻辑
2. **样板化结构** — 不必要的 abstract class / interface / factory pattern
3. **防御性废话** — `if (value !== null && value !== undefined && value !== "")` 链
4. **同义词堆砌** — `getData` / `fetchData` / `retrieveData` 做同一件事
5. **无意义抽象层** — 只有一个实现的 interface，只调用一次的 helper
6. **解释型命名** — `thisIsTheUserNameFromTheDatabase` 过于冗长
7. **模板化错误处理** — 所有 catch 块用同一段 `console.error(err); throw err`
8. **AI 客气话** — 代码注释中出现 "This function elegantly handles..." 等自我评价

扣分标准：
- 1-2 处 → Code Quality -0.5
- 3-4 处 → Code Quality -1.0
- 5+ 处 → 视为系统性问题，Code Quality 直接 ≤6

---

## Review Protocol

### Step 1: Quick Scan（30 秒，Leader 执行）

对 `git diff main...sprint/<N>-<agent>` 逐条检查 10 项自动拒绝触发器。
任一触发 → 立即 Grade F，跳过 Evaluator（节省调用成本）。

### Step 2: 准备 Evaluator 输入（Leader 执行）

构建 eval 输入文件 `.selfmodel/inbox/evaluator/sprint-<N>-eval.md`：
1. 复制合约中的验收标准和 Scoring Rubric
2. **聚焦区域 diff**（非全量 diff）:
   - 只附加与 Deliverables 直接相关的文件 diff：`git diff main...sprint/<N>-<agent> -- <file1> <file2>`
   - 对于超出 Deliverables 范围的文件变更，附加 `--stat` 摘要即可
   - 大 diff 仍遵循 evaluator-prompt.md 中的 Diff Size Limits
3. 附加校准锚点（满分 8.9 和不及格 4.1 的评分表，来自本文件 Calibration Examples）
4. 写入文件

详细输入格式参见 `playbook/evaluator-prompt.md` Input Protocol 章节。

### Step 3: Dispatch Independent Evaluator

按 `evaluator-prompt.md` 的调用协议分派独立 Evaluator：

| 通道 | 方式 | 适用场景 |
|---|---|---|
| Opus Agent（主通道） | Agent tool, read-only, skeptical prompt | 默认，校准稳定 |
| Gemini CLI（备用通道） | `gemini -p "$(cat eval-file)" -y` | 怀疑模型偏见时，或 Opus 超时 |
| Leader self-fallback | Leader 自评，标注降级 | 两通道均失败 |

Evaluator 返回 JSON verdict（schema 见 evaluator-prompt.md）。

### Step 4: 解析 Verdict（Leader 执行）

1. 验证 JSON 格式正确
2. 验证 `weighted` 与各维度分数的加权计算一致（容差 ±0.1）
3. 检查 `auto_reject_triggered` 与 `auto_reject_reasons` 的一致性
4. JSON 格式错误 → 从 Evaluator 文本输出提取关键信息，Leader 补全结构

### Step 4.5: E2E Verdict 合并（v2）

如果当前 Sprint 派发了 E2E Agent v2，在 Evaluator verdict 解析后执行合并：

1. 解析 E2E Verdict JSON v2（含分层结果 + regression + flaky）
2. 按以下规则合并 Evaluator 与 E2E 结果：

| Evaluator | E2E | Regression | 最终 | 理由 |
|-----------|-----|------------|------|------|
| ACCEPT | PASS | None/Warning | ACCEPT | 完美/非关键回归 |
| ACCEPT | PASS | Blocker | REVISE | 有阻塞性回归（测试减少/coverage 骤降） |
| ACCEPT | FAIL | - | REVISE | 看着好但跑不起来，blocking_failures 加入 must_fix |
| ACCEPT | 未派发 | - | ACCEPT | 不需要 E2E |
| REVISE | PASS/FAIL | - | REVISE | 合并 must_fix + blocking_failures |
| REJECT | 任何 | - | REJECT | 代码质量太差 |
| 任何 | FAIL(build) | - | REJECT | 编译失败覆盖 Evaluator |

3. FLAKY 场景不影响 verdict（不视为 FAIL），但记录到 flaky_report
4. 如果 E2E FAIL 导致升级（ACCEPT → REVISE），将 `blocking_failures` 作为额外 `must_fix` 项写入 feedback
5. 详细协议见 `e2e-protocol-v2.md`

### Step 5: 判定（Leader 机械执行）

加权平均: `weighted = func×0.30 + quality×0.25 + taste×0.20 + complete×0.15 + original×0.10`

| 加权平均 | 判定 | 后续 |
|---|---|---|
| ≥ 7.0 | **ACCEPT** | merge 到 main，归档合约 |
| 5.0 ~ 6.9 | **REVISE** | 写 feedback（`must_fix` from verdict），agent 在原 worktree 修改 |
| < 5.0 | **REJECT** | 丢弃分支，从头重做 |

**关键原则**: Leader 机械执行 Evaluator verdict，不重新打分。
**Override**: Leader 可覆盖 verdict 的唯一条件：有明确证据证明 Evaluator 误判。覆盖必须在 review 文件中记录理由。

---

## Feedback 格式

REVISE 或 REJECT 时写入 `.selfmodel/reviews/sprint-<N>-review.md`：

```
## Sprint <N> Feedback
### Evaluator
- Channel: opus-agent | gemini | self-fallback
- Raw Verdict: .selfmodel/reviews/sprint-<N>-verdict.json
- Leader Override: None | <理由>
### Grade: <A/B/C/D/F>
### Scores
| Dimension | Score | Notes |
|---|---|---|
| Functionality | /10 | <说明> |
| Code Quality | /10 | <说明> |
| Design Taste | /10 | <说明> |
| Completeness | /10 | <说明> |
| Originality | /10 | <说明> |
| **Weighted** | **/10** | |
### Must Fix（阻塞合并）
- file:line — <问题>
### Should Fix（下个 Sprint）
- <建议>
### Praise
- <做得好的>
```

---

## Calibration Examples

校准样本基于真实 Sprint 产出，用于锚定 Evaluator 的评分尺度。Evaluator 必须先输出 `<Rationale>`（逐维度推导），再给分数。

### 满分样本：Sprint 2 — Hooks 工作流强制执行（8.9/10）

**任务**: 实现 Claude Code Hooks，将 CLAUDE.md 软规则变为硬约束（session-start 注入、worktree 拦截、agent 规则检测）

**产出**: 3 个完整 hook 脚本 + settings.json 配置，shellcheck 无警告，jq 用法正确，支持 BYPASS 紧急绕过

| 维度 | 分数 | 评语 |
|---|---|---|
| Functionality | 9/10 | 8 条验收标准全部通过，白名单拦截/放行逻辑零误判，边界输入（空 stdin、jq 缺失）均有降级处理 |
| Code Quality | 9/10 | shellcheck 零警告，错误处理完整（每个 jq 调用都有 fallback），变量命名语义清晰 |
| Design Taste | 9/10 | 拦截消息不仅报错还引导正确行为，BYPASS 用环境变量而非配置文件，优雅且安全 |
| Completeness | 8/10 | 主路径和主要边界全覆盖，唯一扣分：settings.json 合并在极端嵌套 JSON 下可能需更健壮的深度合并 |
| Originality | 9/10 | 白名单用 glob 模式匹配而非硬编码路径列表，settings.json 合并策略简洁可靠 |

**加权**: 9x0.30 + 9x0.25 + 9x0.20 + 8x0.15 + 9x0.10 = **8.9**

**为什么是高分**: 产出是完整可用的工程代码，不是骨架或 demo。每个 hook 都处理了真实运行环境的边界情况。

---

### 及格样本：Sprint 2 变体 — 部分验收标准未满足（7.0/10）

**假设场景**: 同一 Sprint 2 任务，但产出有以下不足：
- settings.json 合并逻辑在已有用户配置时会覆盖而非合并
- enforce-agent-rules.sh 对 codex 关键词遗漏检测
- 拦截消息只输出 "blocked"，无引导信息

| 维度 | 分数 | 评语 |
|---|---|---|
| Functionality | 7/10 | 核心拦截功能工作，但 settings.json 合并会丢失用户配置，codex 调用未拦截 |
| Code Quality | 7/10 | shellcheck 通过，错误处理基本完整，但 settings.json 操作缺少备份机制 |
| Design Taste | 6/10 | 拦截消息生硬（"blocked"），用户无法理解为什么被拦截和如何修正 |
| Completeness | 7/10 | 主路径覆盖，但 codex 关键词遗漏属于需求理解不完整 |
| Originality | 8/10 | 白名单设计思路合理，但实现未充分利用 |

**加权**: 7x0.30 + 7x0.25 + 6x0.20 + 7x0.15 + 8x0.10 = **7.0**

**扣分关键**: 验收标准部分遗漏（Functionality 扣分主因），拦截消息缺乏引导性（Design Taste 扣分主因）。

---

### 不及格样本：Sprint 3 变体 — 严重质量问题（4.1/10）

**假设场景**: Sprint 3 CLI 集成任务，但产出有以下严重问题：
- `generate_hooks()` 函数体内留有 `# TODO: implement jq fallback`
- hook 脚本内容用 `echo "placeholder"` 代替真实逻辑
- 变量命名使用 `tmp`、`data`、`result` 等泛型名
- settings.json 写入无错误处理
- 与现有 selfmodel.sh 代码风格不一致

| 维度 | 分数 | 评语 |
|---|---|---|
| Functionality | 4/10 | 核心功能未实现（TODO 占位），生成的 hook 脚本是空壳 |
| Code Quality | 3/10 | 含 TODO、placeholder，变量名泛型化，文件操作无错误处理 — 触发自动拒绝规则 |
| Design Taste | 4/10 | 泛型命名，与项目现有风格断裂，无日志输出 |
| Completeness | 5/10 | 函数骨架存在但关键分支全缺失 |
| Originality | 6/10 | 整体思路合理但执行完全没跟上 |

**加权**: 4x0.30 + 3x0.25 + 4x0.20 + 5x0.15 + 6x0.10 = **4.1**（触发自动拒绝规则直接 Grade F）

**为什么直接拒绝**: 含 TODO 和 placeholder 触发自动拒绝规则（#1、#2）。

---

## Drift Detection

评分漂移检测规则。Leader 每次审查完成后检查 `quality.jsonl` 历史数据。

### 评分膨胀检测

**触发条件**: 连续 5 个 Sprint 的加权平均分 > 8.5

**处置**: Leader 抽取最近 1 个 Sprint 产出，用校准样本重新对标。分数下降 > 1.0 分则确认膨胀，需要：
1. 回顾最近 3 次评审的 Rationale，检查是否存在"合理化辩护"
2. 在 `lessons-learned.md` 记录膨胀事件和修正措施
3. 下次评审强制引用校准样本对标

### 跨 Evaluator 一致性检测

**触发条件**: 同一 Sprint 被不同 Evaluator 通道（Opus vs Gemini）评审，分数差异 > 1.5

**处置**:
1. 取两个评分的较低值作为最终分数
2. 在 `lessons-learned.md` 记录跨模型分歧
3. 分析分歧维度，调整该维度的 Evaluator prompt 校准文本

### 评分固化检测

**触发条件**: 同一维度连续 3 次给出完全相同的分数

**处置**: 固化意味着 Evaluator 区分度丧失。Leader 必须：
1. 检查该维度的评分标准是否仍适用
2. 对比校准样本中该维度的分数分布
3. 下次评审特别关注该维度，给出具体差异化评语

### 防漂移最佳实践

1. **Rationale 前置**: 先写逐维度推导，再给分数。先推导后打分降低漂移概率
2. **锚点对标**: 每次评审前快速浏览满分样本（8.9）和不及格样本（4.1），校准心理尺度
3. **定期回测**: 每 10 个 Sprint 随机抽 2 个历史产出重新评分，对比原始分数

---

## Quality Log

每次审查追加到 `.selfmodel/state/quality.jsonl`：
```json
{"sprint":1,"agent":"gemini","evaluator":"opus-agent","scores":{"func":8,"quality":7,"taste":6,"complete":9,"original":7},"weighted":7.4,"verdict":"accept","leader_override":null,"e2e_agent":"opus-agent","e2e_verdict":"PASS","e2e_atoms":{"total":9,"passed":7,"failed":0,"flaky":1,"blocked":1,"explicit_pass":"4/5","implicit_pass":"4/4"},"e2e_change_profile":"backend_only","e2e_depth":"standard","e2e_regressions":0,"final_verdict":"accept","ts":"2026-03-28T12:00:00Z"}
```

---

## 日志维护

| 文件 | 轮转策略 | 理由 |
|------|----------|------|
| `quality.jsonl` | 保留全部 | 审计需要，Evolution 分析依赖完整历史 |
| `orchestration.log` | 保留最近 500 行 | 诊断用途，超大文件影响读取速度 |
| `hook-intercepts.log` | 保留最近 200 行 | Hook 拦截记录，Leader 每 10 sprint 审查后可清理 |
| `evolution.jsonl` | 保留全部 | 进化记录不可丢失 |

轮转命令（Leader 在 Sprint 50+ 后可选执行）：
```bash
tail -500 .selfmodel/state/orchestration.log > .selfmodel/state/orchestration.log.tmp \
  && mv .selfmodel/state/orchestration.log.tmp .selfmodel/state/orchestration.log
```
