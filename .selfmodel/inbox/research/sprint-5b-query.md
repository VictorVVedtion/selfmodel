# Research Query: Sprint 5b

## 研究类型
Type A（快速查询）

## 核心问题
长时间运行的 AI agent 系统中，context reset vs compaction 的最佳策略是什么？如何设计 session 内的 checkpoint + reset 协议？

## 期望产出
- Context reset vs compaction 的优劣对比和适用场景
- "Context anxiety" 的识别信号和缓解方法
- Session 内 checkpoint 的触发条件和交接文件格式
- Claude Code / Agent SDK 的 automatic compaction 机制细节

## 约束
- 应用于 Claude Code 环境（自动 compaction 已存在）
- 需要与现有 next-session.md 跨 session 交接机制兼容
