# Research Query: Sprint 6

## 研究类型
Type A（快速查询）

## 核心问题
bash 脚本如何从 GitHub 仓库拉取特定目录的文件并安全覆盖本地？需要：
1. 用 curl/wget 从 GitHub raw URL 下载单个文件的最佳实践
2. 如何批量下载一个目录下的所有 .md 文件（GitHub API vs raw URL vs git archive）
3. 下载失败时的降级策略（网络问题、仓库不可达）
4. 如何处理版本：下载特定 tag/branch 的文件

## 约束
- 必须 zero-dependency（curl 在 macOS/Linux 预装）
- 不能依赖 git clone（太重，只需要 playbook/ 目录）
- 需要支持 private repo（可选，通过 token）
