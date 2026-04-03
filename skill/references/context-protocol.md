# Context Management Protocol

Session 内的 context 管理策略。长时间运行时按需加载本文件。

---

## Checkpoint Triggers

以下任一条件满足时，Leader 必须执行 checkpoint：

| # | Trigger | Signal | Action |
|---|---------|--------|--------|
| 1 | **Context > 70%** | Claude statusline `context_window.used_percentage > 70` 或对话轮次 > 25 | 写 checkpoint → 考虑 reset |
| 2 | **Sprint 完成** | Agent 交付 + Leader 审查完毕 | 写 checkpoint（自然断点） |
| 3 | **方向切换** | 用户切换到不相关的任务/话题 | 写 checkpoint → reset |
| 4 | **Context Anxiety 信号** | 重复提问已回答的问题、虚构不存在的文件路径、循环修复同一错误 | 强制 reset |

---

## Checkpoint 格式

Checkpoint 写入 `.selfmodel/state/next-session.md`，格式与跨 session 交接一致：

```markdown
# Checkpoint — <timestamp>

## Current Sprint
- Sprint <N>: <status> (ACTIVE / DELIVERED / REVIEWED)
- Agent: <agent name>
- Progress: <what's done, what's left>

## Key Decisions Made
- <decision 1 and why>
- <decision 2 and why>

## Pending Work
- [ ] <task 1>
- [ ] <task 2>

## Critical Context
- <anything that would be lost on reset>

## Active Worktrees
- <worktree path> → <branch> → <status>
```

---

## Reset vs Compaction Decision Tree

```
Context usage approaching limit?
├── < 70%  → Let Claude Code auto-compaction handle it. No action needed.
├── 70-85% → Write checkpoint. Continue if work is nearly done. Reset if starting new Sprint.
└── > 85%  → Write checkpoint immediately. Reset.

Context Anxiety detected?
├── No  → Continue. Monitor.
└── Yes → Write checkpoint. Force reset. Re-read CLAUDE.md + checkpoint on restart.

Sprint just completed?
├── Starting new Sprint → Reset recommended (clean slate for new task)
└── Continuing same Sprint → Let compaction handle it
```

### Compaction Limitations

Claude Code 的自动 compaction 会压缩历史消息，但：
- **不会给 clean slate** — 模型仍然"感觉到"之前的上下文长度
- **Context anxiety 仍会持续** — 模型可能提前收尾、遗漏细节、循环修复
- **关键约束可能被压缩掉** — 早期对话中的重要决策会被摘要化

### Reset 优势

- 真正的 clean slate — 模型从零开始，注意力 100% 集中
- 重新读取 CLAUDE.md — 重新内化所有 Iron Rules
- checkpoint 文件包含所有关键上下文 — 信息不丢失

---

## Externalization Rules

关键信息必须外部化，不依赖聊天历史：

| 信息类型 | 外部化目标 |
|----------|-----------|
| 架构决策 | `playbook/lessons-learned.md` |
| Sprint 进度 | `state/next-session.md` |
| 团队状态 | `state/team.json` |
| 质量评分 | `state/quality.jsonl` |
| 未完成工作 | `contracts/active/` |
| 关键约束 | CLAUDE.md 或 playbook/ |
| Rampage 韧性报告 | `.gstack/rampage-reports/` + `.selfmodel/artifacts/rampage-sprint-*.json` |

**原则**: 如果一条信息在 context reset 后会丢失且无法从文件系统恢复，它必须立即被外部化。

---

## Session 内操作速查

```
正常工作中 → 无需操作，让 Claude Code 自动 compaction
Sprint 完成 → 写 checkpoint 到 next-session.md
开始新 Sprint → 推荐 reset (/clear)，然后重新读 CLAUDE.md + next-session.md
发现 context anxiety → 立即写 checkpoint → /clear → 重启
```
