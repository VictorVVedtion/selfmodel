# Sprint 2: Claude Code Hooks 工作流强制执行

## Objective
通过 Hooks 将 CLAUDE.md 软规则变为硬约束

## Assigned To
opus

## Deliverables
- [ ] `scripts/hooks/session-start.sh` — Session 启动时注入 team.json + next-session.md 上下文
- [ ] `scripts/hooks/enforce-leader-worktree.sh` — PreToolUse:Write|Edit，白名单外代码修改拦截
- [ ] `scripts/hooks/enforce-agent-rules.sh` — PreToolUse:Bash，检测 gemini/codex 调用需有合约+inbox
- [ ] `.claude/settings.json` — hooks 配置（如已存在则合并，不覆盖现有设置）

## Acceptance Criteria
1. `session-start.sh` 执行时输出 team.json 和 next-session.md 内容，exit 0
2. `enforce-leader-worktree.sh` 对白名单路径（.selfmodel/、CLAUDE.md、scripts/、playbook/）放行 exit 0
3. `enforce-leader-worktree.sh` 对白名单外路径（如 src/main.js）拦截 exit 2，stderr 包含拦截提示
4. `enforce-agent-rules.sh` 对包含 `gemini` 的 bash 命令，若无活跃合约则 exit 2
5. `enforce-agent-rules.sh` 对不包含 agent 关键词的普通 bash 命令放行 exit 0
6. 所有 hook 脚本执行时间 < 100ms
7. 支持 BYPASS_LEADER_RULES=1 环境变量紧急绕过
8. settings.json 的 hooks 配置正确引用脚本路径

## Scoring Rubric
| Dimension | Weight | 10/10 |
|---|---|---|
| Functionality | 30% | 所有 5 条验收标准通过，无误拦截 |
| Code Quality | 25% | shellcheck 无警告，jq 用法正确，错误处理完整 |
| Design Taste | 20% | 拦截消息清晰明确，引导 Claude 正确行为 |
| Completeness | 15% | 边界情况处理：文件不存在、jq 未安装、空 stdin |
| Originality | 10% | 白名单设计合理，bypass 机制优雅 |

## Context Files
- /Users/vvedition/Desktop/selfmodel/CLAUDE.md
- /Users/vvedition/Desktop/selfmodel/.selfmodel/playbook/dispatch-rules.md
- /Users/vvedition/Desktop/selfmodel/.selfmodel/inbox/research/sprint-2-report.md
- /Users/vvedition/Desktop/selfmodel/.selfmodel/state/team.json

## Constraints
- Max execution time: 180s
- 非交互执行（三层静默防护）
- 禁止 TODO / mock / placeholder
- 每个 hook 脚本执行 < 100ms
- 必须支持 macOS (Darwin)
- 依赖: jq（脚本开头检测，缺失时 exit 0 放行而非拦截）
- settings.json 如已存在，必须读取现有内容并合并 hooks 字段

## Worktree
- Branch: sprint/2-opus
- Path: ../.zcf/selfmodel/sprint-2-opus/

## Lifecycle
DRAFT → ACTIVE → DELIVERED → REVIEWED → MERGED | REJECTED
当前状态: **ACTIVE**
