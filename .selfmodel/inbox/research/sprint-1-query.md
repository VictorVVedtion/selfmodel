# Research Query: Sprint 1

## 研究类型
Type B（技术调研）

## 核心问题
AI 编程工作流框架如何实现项目自适应初始化？需要调研现有方案，找到最适合 selfmodel（多 AI agent 编排系统）的初始化模式。

## 调研范围

### 1. AI 编程工具的项目初始化模式
- **Cursor Rules** (.cursorrules) — 怎么生成项目规则？有没有自适应扫描？
- **Aider** (.aider.conf.yml) — 项目配置怎么初始化？
- **Claude Code** (CLAUDE.md) — 官方推荐的项目初始化流程？
- **Cline / Continue / Windsurf** — 它们的项目规则文件怎么生成？
- **OpenAI Codex CLI** (AGENTS.md) — 项目适配机制？

### 2. 自适应 Scaffolding 最佳实践
- create-next-app / create-react-app 的技术栈检测逻辑
- Yeoman generators 的项目适配模式
- Nx / Turborepo 的 workspace 自动识别
- cookiecutter / copier 的模板参数化方案

### 3. 多 Agent 编排框架的项目适配
- CrewAI / AutoGen / LangGraph — 它们怎么根据项目类型配置 agent team？
- 有没有"扫描项目 → 自动推荐 agent 组合"的模式？

## 上下文
selfmodel 是一个多 AI agent 团队编排框架（Claude Opus Leader + Gemini Frontend + Codex Backend + Opus Fullstack + Researcher）。我们需要让其他开发者能：
1. 在已有项目中运行 `selfmodel adapt` 自动生成适配的工作流配置
2. 从零运行 `selfmodel init` 引导式搭建新项目

## 期望产出
- [ ] 各工具的初始化/适配机制对比表
- [ ] 项目类型自动检测的最佳实践（扫描哪些文件、识别哪些信号）
- [ ] 推荐的 selfmodel 初始化架构方案
- [ ] 有没有可以直接复用的开源实现

## 约束
- 初始化脚本需要 zero-dependency（纯 bash 或单文件可执行）
- 必须支持 macOS 和 Linux
- 输出格式必须兼容 selfmodel 现有的 CLAUDE.md + playbook/ 结构
