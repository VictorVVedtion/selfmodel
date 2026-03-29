### 核心结论

**完全可行。** Claude Code 提供了强大的 Hooks 机制（特别是 `PreToolUse` 和 `SessionStart`），允许我们拦截特定的工具调用（如 `Edit`、`Write`、`Bash` 等）。通过在拦截脚本中读取传入的参数，并返回特定的退出码（**`exit 2` 代表拦截并阻止执行**），我们可以完美地将 `CLAUDE.md` 中的软规则转化为硬约束。

---

### 详细发现：Claude Code Hooks 技术细节

根据最新官方文档和社区实践，以下是 Hooks 机制的技术细节：

1.  **配置格式 (`.claude/settings.json`)**：
    Hooks 配置在项目根目录的 `.claude/settings.json` 中，按生命周期事件分类（`SessionStart`, `PreToolUse`, `PostToolUse` 等）。

2.  **Stdin 数据格式 (JSON Schema)**：
    当 Hook 类型为 `command` 时，Claude Code 会通过标准输入 (`stdin`) 向你的脚本传递一个 JSON 对象。
    ```json
    {
      "session_id": "uuid-string",
      "cwd": "/Users/vvedition/Desktop/selfmodel",
      "tool_name": "Edit",
      "tool_input": {
        "file_path": "src/main.js",
        "old_string": "...",
        "new_string": "..."
      },
      "tool_use_id": "call_123..."
    }
    ```
    *注：如果是 `Bash` 工具，`tool_input` 中将包含 `command` 字段；如果是 `Write` 工具，将包含 `file_path` 和 `content` 字段。*

3.  **Exit Code 语义**：
    *   `exit 0`：检查通过，放行工具执行。
    *   **`exit 2`**：**强制拦截**。在 `PreToolUse` 阶段返回 `2` 会直接中断当前工具的执行，并将你输出到 `stderr` 或 `stdout` 的错误信息返回给 Claude，迫使它改变策略。
    *   其他非零状态码：记录为失败，但通常不会硬拦截工具本身。

4.  **能拦截哪些工具？**
    通过 `matcher` 字段可以使用正则匹配拦截任何工具。包括 `Bash`, `Write`, `Edit`, `Read`, `Grep`, `Glob`, 以及自定义的 `Agent` 工具。

---

### 推荐方案：具体 Hooks 实现

为了满足你的 5 个具体约束，我们需要在 `.claude/settings.json` 中定义规则，并编写极轻量级的 Shell 脚本（利用 `jq` 解析 JSON，执行时间远小于 100ms）。

#### 1. 完整配置：`.claude/settings.json`
```json
{
  "hooks": {
    "SessionStart": [
      {
        "type": "command",
        "command": "bash scripts/hooks/session-start.sh"
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "bash scripts/hooks/enforce-leader-worktree.sh"
          }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash scripts/hooks/enforce-agent-rules.sh"
          }
        ]
      }
    ]
  }
}
```

#### 2. Hook 脚本实现

所有脚本需存放在 `scripts/hooks/` 目录下，并赋予执行权限 (`chmod +x`)。

**A. 强制 Session Start 读取上下文 (`session-start.sh`)**
```bash
#!/bin/bash
# 目标：Session Start 强制读取 next-session.md 和 team.json
# 输出会被 Claude 自动读取作为启动上下文

echo "=== SYSTEM ENFORCEMENT: REQUIRED CONTEXT ==="
echo "Team State:"
cat .selfmodel/state/team.json 2>/dev/null || echo "{}"
echo -e "\nNext Session Goals:"
cat .selfmodel/state/next-session.md 2>/dev/null || echo "No active goals."
echo "============================================"
exit 0
```

**B. Leader 不下场 & Worktree 隔离强制 (`enforce-leader-worktree.sh`)**
```bash
#!/bin/bash
# 目标：拦截 Write/Edit，防止 Leader 直接改代码，确保只能改文档/规范
# 依赖：jq (macOS 可通过 brew install jq 安装)

# 紧急 Bypass 机制
if [ "$BYPASS_LEADER_RULES" = "1" ]; then
    exit 0
fi

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path')

# 允许白名单：规则、文档、脚本、测试区
if [[ "$FILE_PATH" == *".selfmodel/"* || "$FILE_PATH" == *"playbook/"* || "$FILE_PATH" == *"CLAUDE.md"* || "$FILE_PATH" == *"scripts/"* ]]; then
    exit 0
fi

# 如果尝试修改白名单外的代码，直接拦截 (Exit 2)
echo "🚨 [Hook 拦截] 违反《Leader 不下场》规则！" >&2
echo "你当前扮演的是 Leader 角色，被禁止直接修改核心业务代码 ($FILE_PATH)。" >&2
echo "请使用 Bash 调用对应的子 Agent (如 Codex/Gemini) 在独立 worktree 中完成编码工作。" >&2
exit 2
```

**C. 合约前置检查 & Inbox 缓冲检查 (`enforce-agent-rules.sh`)**
```bash
#!/bin/bash
# 目标：拦截非法的 Agent 调用（没有合约、没有 inbox 缓冲）

if [ "$BYPASS_AGENT_RULES" = "1" ]; then exit 0; fi

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')

# 仅拦截对 agent 的调用（假设你是通过 bash 脚本如 selfmodel.sh 调用 agent）
if [[ "$COMMAND" == *"scripts/selfmodel.sh"* || "$COMMAND" == *"gemini"* || "$COMMAND" == *"opus"* ]]; then
    
    # 1. 检查是否有活跃的 Sprint 合约
    ACTIVE_CONTRACTS=$(find .selfmodel/contracts/active -name "*.md" 2>/dev/null | wc -l)
    if [ "$ACTIVE_CONTRACTS" -eq 0 ]; then
        echo "🚨 [Hook 拦截] 违反《Sprint 合约制》！" >&2
        echo "在调用 Agent 前，必须在 .selfmodel/contracts/active/ 下创建当前 Sprint 的合约文件。" >&2
        exit 2
    fi

    # 2. Inbox 缓冲检查 (以 Gemini 为例)
    if [[ "$COMMAND" == *"gemini"* ]]; then
        INBOX_FILES=$(find .selfmodel/inbox/gemini -name "*.md" 2>/dev/null | wc -l)
        if [ "$INBOX_FILES" -eq 0 ]; then
            echo "🚨 [Hook 拦截] 违反《通信缓冲隔离》！" >&2
            echo "调用 Gemini Agent 前，必须将任务上下文和指令写入 .selfmodel/inbox/gemini/ 的 Markdown 文件中。" >&2
            exit 2
        fi
    fi
fi

exit 0
```

---

### 开源框架 / 社区实践

目前 Claude Code 相对较新，社区主要使用 **纯 Shell 脚本** 或 **Node.js** 来实现 Hooks（因为环境依赖最低）。
*   不需要引入重型框架，像上面的 `bash` + `jq` 是目前**最轻量（<20ms 延迟）**且最被推荐的做法。
*   如果你更偏好 TypeScript/Node.js 写法，可以使用原生的 `fs.readFileSync(0, 'utf-8')` 读取 `stdin`，然后 `process.exit(2)` 进行拦截。

### 置信度与风险提示

*   **置信度**：**高 (95%)**。`exit 2` 阻断机制和 `stdin` JSON 传递是官方明确支持的 Hooks 核心特性。
*   **潜在风险**：
    1.  **依赖问题**：Shell 脚本方案严重依赖 `jq` 命令解析 JSON。请确保团队成员和 CI 环境已安装 `jq` (`brew install jq`)。否则 JSON 解析会失败导致误拦截。
    2.  **死循环风险**：如果 Claude 在遇到 `exit 2` 拦截后，尝试反复换种方式执行同一个被拦截的命令，可能会导致 tokens 浪费。**对策**：在 `echo` 出的拦截错误信息中，**务必明确给出下一步该做什么的指令**（比如上面脚本中的：“请使用 Bash 调用对应的子 Agent...”），Claude 读到这个报错就会立即改变行为路径。
    3.  **Bypass 机制**：有时系统重构确实需要 Leader 下场，因此在脚本头部保留了 `BYPASS_LEADER_RULES=1` 的后门，可以通过 `BYPASS_LEADER_RULES=1 claude` 启动以绕过限制。

### 来源 URL
*   [Claude 官方文档: Custom Hooks](https://docs.anthropic.com/en/docs/agents-and-tools/claude-code/hooks)
*   [Claude Code Release & Hook Spec](https://github.com/anthropics/claude-code)
