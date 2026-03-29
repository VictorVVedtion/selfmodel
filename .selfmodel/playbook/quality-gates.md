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

## Review Protocol

### Step 1: Quick Scan（30 秒）

对 `git diff main...sprint/<N>-<agent>` 逐条检查 10 项自动拒绝触发器。
任一触发 → 立即 Grade F，无需继续评分。

### Step 2: 交叉验证

将 diff 路由到与实现者不同的 Agent 独立审查：

| 实现者 | 审查者 | 方式 |
|---|---|---|
| Codex | Gemini | `gemini "@<diff-file> 审查此代码变更" -s --yolo` |
| Gemini | Leader 直接 | 或路由到 Codex |
| Opus | Gemini | `gemini "@<diff-file> 审查此代码变更" -s --yolo` |

### Step 3: Leader 深度审查

读完整 diff，结合审查者报告，5 维度逐一打分（0-10）。

### Step 4: 判定

加权平均: `weighted = func×0.30 + quality×0.25 + taste×0.20 + complete×0.15 + original×0.10`

| 加权平均 | 判定 | 后续 |
|---|---|---|
| ≥ 7.0 | **ACCEPT** | merge 到 main，归档合约 |
| 5.0 ~ 6.9 | **REVISE** | 写 feedback，agent 在原 worktree 修改 |
| < 5.0 | **REJECT** | 丢弃分支，从头重做 |

---

## Feedback 格式

REVISE 或 REJECT 时写入 `.selfmodel/reviews/sprint-<N>-review.md`：

```
## Sprint <N> Feedback
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
{"sprint":1,"agent":"gemini","scores":{"func":8,"quality":7,"taste":6,"complete":9,"original":7},"weighted":7.4,"verdict":"accept","reviewer":"codex","ts":"2026-03-28T12:00:00Z"}
```
