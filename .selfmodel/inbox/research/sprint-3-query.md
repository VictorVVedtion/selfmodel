# Research Query: Sprint 3

## 研究类型
Type A（快速查询）

## 核心问题
selfmodel CLI（scripts/selfmodel.sh）在 init/adapt/update 时如何自动生成 Claude Code hooks 配置？需要考虑：已有 settings.json 的合并策略、hooks 脚本的分发方式、版本升级时的增量更新。

## 调研范围

### 1. settings.json 合并策略
- 用户可能已有自己的 `.claude/settings.json`（含自定义 hooks、其他设置）
- `selfmodel init` 生成时如何不覆盖用户已有配置？
- `selfmodel update` 更新 hooks 时如何保留用户自定义的其他 hooks？
- jq 的 JSON 深度合并最佳实践（`*` operator vs `+` vs 自定义 merge 逻辑）

### 2. Hook 脚本分发方式
- 方案 A: 脚本内容内嵌在 selfmodel.sh 中（heredoc），init 时写出
- 方案 B: 从 GitHub raw 下载最新脚本
- 方案 C: 脚本模板化，根据项目类型生成不同版本
- 哪种方式最适合 zero-dependency 的 bash 工具？

### 3. 版本升级的增量更新
- 用户已有 hooks v1，selfmodel update 后怎么升级到 v2？
- 如何检测 hooks 是否过期？（版本号？文件 hash？）
- 用户自定义修改了 hook 脚本怎么办？覆盖 vs 跳过 vs 备份？

## 上下文
selfmodel.sh 当前有 init/adapt/update 三个命令，生成 .selfmodel/ 目录结构、team.json、CLAUDE.md、playbook 文件。但不生成 hooks（scripts/hooks/ + .claude/settings.json）。需要把 Sprint 2 的 3 个 hook 脚本集成到 CLI 的自动生成流程中。

## 期望产出
- [ ] settings.json 安全合并的 jq 命令
- [ ] 推荐的 hook 分发方式
- [ ] 版本升级策略

## 约束
- 必须兼容 selfmodel.sh 现有的 bash + jq 技术栈
- 不能引入新依赖
- 不能破坏用户已有的 .claude/settings.json
