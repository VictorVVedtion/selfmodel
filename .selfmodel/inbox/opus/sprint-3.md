# Sprint 3 任务: selfmodel CLI 集成 Hooks 自动生成

你是 Opus Agent，负责 Sprint 3。

## 任务

修改 `scripts/selfmodel.sh`，新增 `generate_hooks()` 函数，使 init/adapt/update 三个命令自动生成 Claude Code hooks。

## 必须先读取的文件

1. `/Users/vvedition/Desktop/selfmodel/.selfmodel/contracts/active/sprint-3.md` — 合约和验收标准
2. `/Users/vvedition/Desktop/selfmodel/.selfmodel/inbox/research/sprint-3-report.md` — 调研报告（合并策略、分发方式、升级策略）
3. `/Users/vvedition/Desktop/selfmodel/scripts/selfmodel.sh` — 需要修改的主文件
4. `/Users/vvedition/Desktop/selfmodel/scripts/hooks/session-start.sh` — 需要内嵌的 hook 内容
5. `/Users/vvedition/Desktop/selfmodel/scripts/hooks/enforce-leader-worktree.sh` — 同上
6. `/Users/vvedition/Desktop/selfmodel/scripts/hooks/enforce-agent-rules.sh` — 同上
7. `/Users/vvedition/Desktop/selfmodel/.claude/settings.json` — 目标 hooks 配置格式

## 具体实现要求

### 1. 新增 `generate_hooks()` 函数

在 `generate_playbook()` 之后添加，包含：

**A. 生成 3 个 hook 脚本**
- 用 Heredoc 将 session-start.sh、enforce-leader-worktree.sh、enforce-agent-rules.sh 的完整内容写入 `$dir/scripts/hooks/`
- `chmod +x` 每个脚本
- 如果旧文件存在，先备份为 `.bak.$(date +%s)` 再覆盖

**B. 合并 settings.json**
- 如果 `.claude/settings.json` 不存在：直接写入完整 hooks 配置
- 如果存在且有 jq：
  - 读取现有配置
  - 用 jq 深度合并（`*` 运算符）注入 hooks
  - 确保幂等：不重复添加同一 hook
- 如果存在但无 jq：警告用户需要手动合并，不覆盖

### 2. 集成到现有命令

- `cmd_init()`: 在 `generate_playbook` 后调用 `generate_hooks`
- `cmd_adapt()`: 在处理完 CLAUDE.md 后调用 `generate_hooks`
- `cmd_update()`: 在更新 playbook 后调用 `generate_hooks`（带备份逻辑）

### 3. 日志输出

使用 selfmodel.sh 已有的 `info()`、`ok()`、`warn()` 函数：
- 生成新 hook: `ok "Hook generated: session-start.sh"`
- 备份旧 hook: `info "Backed up: enforce-leader-worktree.sh → .bak.1711234567"`
- 合并 settings.json: `ok "settings.json hooks merged."`
- 无 jq 降级: `warn "jq not found. Writing default settings.json (manual merge may be needed)."`

## 关键约束
- 不要修改 selfmodel.sh 中已有函数的逻辑，只新增 generate_hooks() 并在 cmd_* 中调用
- Hook 脚本内容必须与 Sprint 2 产出完全一致（从源文件读取后内嵌）
- settings.json 合并必须是幂等的

## 完成后
在 worktree 根目录创建 DONE.md 记录交付物清单。
