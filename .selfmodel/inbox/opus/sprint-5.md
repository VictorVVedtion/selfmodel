# Sprint 5 任务: Long-Running Reliability

你是 Opus Agent，负责 Sprint 5。

## 必须先读取的文件

1. `/Users/vvedition/Desktop/selfmodel/.selfmodel/contracts/active/sprint-5.md` — 合约
2. `/Users/vvedition/Desktop/selfmodel/.selfmodel/inbox/research/sprint-5a-report.md` — Evaluator 校准调研
3. `/Users/vvedition/Desktop/selfmodel/.selfmodel/inbox/research/sprint-5b-report.md` — Context Reset 调研
4. `/Users/vvedition/Desktop/selfmodel/.selfmodel/playbook/quality-gates.md` — 需要修改
5. `/Users/vvedition/Desktop/selfmodel/.selfmodel/playbook/sprint-template.md` — 需要修改
6. `/Users/vvedition/Desktop/selfmodel/CLAUDE.md` — Context Management 章节需要更新
7. `/Users/vvedition/Desktop/selfmodel/.selfmodel/contracts/archive/sprint-2.md` — 校准样本来源
8. `/Users/vvedition/Desktop/selfmodel/.selfmodel/contracts/archive/sprint-3.md` — 校准样本来源

## 三个子任务

### 5a: Evaluator 校准 — 修改 quality-gates.md

在现有评分维度之后添加 "Calibration Examples" 章节：

**满分样本 (Sprint 2, 得分 8.9/10)**:
- 引用 Sprint 2 的 hooks 实现
- 逐维度给出分数和 1 句话评语
- 说明为什么是高分

**及格样本 (模拟 7.0/10)**:
- 基于 Sprint 2 假设某些验收标准只部分满足
- 逐维度给出分数
- 说明哪里扣分

**不及格样本 (模拟 4.5/10)**:
- 假设产出包含 TODO、吞异常、泛型命名
- 逐维度给出分数
- 说明为什么直接拒绝

还要添加 "Drift Detection" 规则：
- 连续 5 个 Sprint 平均分 >8.5 → 警告 "评分膨胀"
- 同一维度连续 3 次相同分数 → 警告 "评分固化"

### 5b: Context Reset 协议 — 新建 playbook/context-protocol.md

设计 session 内的 context 管理策略：

**Checkpoint 触发条件** (至少 3 个):
- Context 使用率估算 > 70%
- 完成一个 Sprint 后（自然断点）
- Leader 切换主题/任务方向时

**Checkpoint 内容格式**:
- 当前 Sprint 进度
- 关键决策记录
- 未完成工作清单
- 与 next-session.md 格式兼容

**Reset vs Compaction 决策树**:
- 何时让 Claude Code 自动 compaction
- 何时主动 reset（清除 context + 重新读 CLAUDE.md）
- "Context anxiety" 信号识别

**更新 CLAUDE.md**:
- Context Management 章节添加一行引用 context-protocol.md
- 在 On-Demand Loading 表中添加 context-protocol.md

### 5c: 成本追踪 — 修改 sprint-template.md

在合约模板的 Constraints 之后添加 Cost Tracking 字段：
```markdown
## Cost (Leader 填写，Sprint 完成后)
- Tokens: <estimated total>
- Duration: <wall clock time>
- Agent calls: <number>
- Researcher calls: <number>
```

## 完成后
创建 DONE.md 记录交付物清单。
