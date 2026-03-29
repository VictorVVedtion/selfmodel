# Research Query: Sprint 5a

## 研究类型
Type A（快速查询）

## 核心问题
如何用 few-shot 样本校准 LLM Evaluator 的评分，防止长期运行后评分漂移？

## 期望产出
- few-shot 校准样本的最佳格式（满分/及格/不及格各怎么写）
- Anthropic Harness Design 中的 evaluator calibration 具体做法
- 评分漂移（scoring drift）的检测和修正方法

## 约束
- 应用于 5 维度评分体系（Functionality/Code Quality/Design Taste/Completeness/Originality）
- 样本必须基于真实的 Sprint 产出（不用 mock）
