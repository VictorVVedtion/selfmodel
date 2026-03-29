# Sprint 6: selfmodel update --remote

## Objective
从 GitHub 拉取最新 playbook + hooks 同步到本地

## Assigned To
opus

## Deliverables
- [ ] `scripts/selfmodel.sh` 更新 — cmd_update 支持 --remote 参数，从 GitHub tarball 拉取最新 playbook + hooks

## Acceptance Criteria
1. `selfmodel update --remote` 从 GitHub tarball 下载 .selfmodel/playbook/*.md 和 scripts/hooks/*.sh 并覆盖本地
2. 下载前备份现有文件为 .bak.<timestamp>
3. 使用 curl -f + tar 管道（零额外依赖）
4. 下载失败时保留本地文件不破坏，输出 warn 日志
5. 支持 VERSION 锁定：默认取 main 分支，可通过 --version <tag> 指定版本
6. `selfmodel update`（无 --remote）行为不变（从本地模板生成）
7. 不覆盖 state/、contracts/、inbox/ 等项目特有数据
8. CLAUDE.md 特殊处理：仅更新 selfmodel:start/end 标记之间的内容（如有），不覆盖用户自定义部分

## Context Files
- /Users/vvedition/Desktop/selfmodel/scripts/selfmodel.sh — 需要修改
- /Users/vvedition/Desktop/selfmodel/.selfmodel/inbox/research/sprint-6-report.md — 调研报告
- /Users/vvedition/Desktop/selfmodel/VERSION — 当前版本号

## Constraints
- Max execution time: 180s
- 只修改 cmd_update 函数和新增 remote_update 辅助函数
- curl + tar 零额外依赖（jq 仅用于 settings.json 合并，已有检测）
- macOS bsdtar 和 Linux GNU tar 兼容
- 仓库 URL: https://github.com/VictorVVedtion/selfmodel

## Worktree
- Branch: sprint/6-opus
- Path: ../.zcf/selfmodel/sprint-6-opus/

## Lifecycle
当前状态: **MERGED**
