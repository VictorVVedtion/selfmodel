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

## Quality Log

每次审查追加到 `.selfmodel/state/quality.jsonl`：
```json
{"sprint":1,"agent":"gemini","scores":{"func":8,"quality":7,"taste":6,"complete":9,"original":7},"weighted":7.4,"verdict":"accept","reviewer":"codex","ts":"2026-03-28T12:00:00Z"}
```
