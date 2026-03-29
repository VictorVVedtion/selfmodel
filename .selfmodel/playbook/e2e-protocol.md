> **DEPRECATED** — 本文件为 v1 协议，已被 `e2e-protocol-v2.md` 取代。新 Sprint 请使用 v2 协议。

# E2E Verification Protocol

运行时验证协议。Leader 在步骤 6 中需要 E2E 验证时查阅本文件。

---

## 角色定义

| 属性 | 值 |
|------|-----|
| 角色 | E2E Verifier（第 7 角色） |
| 执行者 | Opus Agent（主通道，claude-opus-4-6）/ Gemini CLI（降级通道，仅 build 验证） |
| 职责 | 验证代码在运行时能正常工作。只验证，不修改代码 |
| 触发 | 条件式 — 非所有 Sprint 都需要 E2E |
| 时机 | 与 Evaluator 并行（步骤 6 中同时派发） |
| 超时 | 300s（与 Researcher 相同） |
| 输出 | JSON verdict（scenarios pass/fail + evidence） |

---

## 触发条件

### 需要 E2E（任一条件满足）

1. 交付物包含可运行入口（server、CLI、带 main 的脚本）
2. 验收标准含运行时动词：`runs` / `renders` / `responds` / `starts` / `serves` / `outputs` / `displays` / `passes tests`
3. Sprint 修改了 `detected_stack.test_tools` 相关文件（项目有 jest/vitest/pytest 等）
4. 合约含 `## E2E Scenarios` 部分（Leader 显式指定）

### 跳过 E2E（所有条件成立）

1. 纯文档修改（仅 `.md` 文件）
2. 纯类型定义/接口/无运行时影响的配置（测试文件修改被触发条件 3 覆盖，不视为纯配置）
3. 研究型 Sprint（Researcher 角色）
4. Leader 显式标注 `E2E: skip`

---

## 调用通道

### Opus Agent（主通道 — claude-opus-4-6）

```
Agent tool:
  prompt: |
    You are the E2E verification agent. You verify that delivered code works at runtime.
    You do NOT modify any code. You only run commands and report results.
    Read the verification file and execute each scenario.
    Output ONLY valid JSON matching the schema in the file.
    Verification file: <absolute-path-to-inbox/e2e/sprint-N.md>
  isolation: "worktree"
  model: opus
```

### Gemini CLI（降级通道，仅 build 验证）

```bash
cd <worktree-path> && \
CI=true GIT_TERMINAL_PROMPT=0 timeout 120 gemini \
  "@/Users/vvedition/Desktop/selfmodel/.selfmodel/inbox/e2e/sprint-<N>.md Execute verification scenarios" \
  -s --yolo
```

降级通道仅执行 build 验证场景，跳过 server/cli/ui 场景。

---

## E2E 任务文件格式

路径: `.selfmodel/inbox/e2e/sprint-<N>.md`

```markdown
# E2E Verification: Sprint <N>

## Section 1: Context
- Sprint: <N>
- Agent: <who implemented>
- Worktree: <path to worktree with delivered code>
- Contract: <path to sprint contract>

## Section 2: Scenarios

### Build Verification
- Command: <build command, e.g. npm run build>
- Expected: exit 0, no errors in stderr
- Timeout: 60s

### Test Suite (if applicable)
- Command: <test command, e.g. npm test>
- Expected: all tests pass
- Timeout: 120s

### Server Start (if applicable)
- Setup: <start command, e.g. npm start &>
- Wait: <health check, e.g. curl -s http://localhost:3000/health>
- Expected: HTTP 200 within 10s
- Teardown: <kill server>

### CLI Execution (if applicable)
- Command: <cli command with args>
- Expected: <expected output pattern or exit code>
- Timeout: 30s

### UI Render (if applicable)
- Setup: <start dev server>
- Check: <verification command or screenshot>
- Expected: <success condition>
- Teardown: <cleanup>

## Section 3: Constraints
- Do NOT modify any source code
- Do NOT install global dependencies
- Do NOT call production APIs
- Report exact stdout/stderr (first 500 chars) as evidence
- If a scenario requires unavailable dependencies, mark as SKIP with reason

## Section 4: Output Schema
Output ONLY valid JSON:
{
  "sprint": "<N>",
  "agent": "opus-agent | gemini",
  "scenarios": [
    {
      "name": "Build Verification",
      "type": "build | test-suite | server | cli | ui",
      "status": "PASS | FAIL | SKIP | TIMEOUT",
      "command": "<executed command>",
      "exit_code": 0,
      "duration_seconds": 12,
      "evidence": "<first 500 chars of stdout/stderr>",
      "error": null
    }
  ],
  "summary": {
    "total": 4,
    "passed": 3,
    "failed": 1,
    "skipped": 0,
    "timed_out": 0
  },
  "verdict": "PASS | FAIL",
  "blocking_failures": [
    {
      "scenario": "<name>",
      "reason": "<why it failed>",
      "severity": "blocker | warning"
    }
  ],
  "notes": "<runtime behavior observations>"
}
```

---

## 验证场景类型

| 类型 | 说明 | 成功条件 |
|------|------|----------|
| `build` | 编译/构建 | exit 0，无 error |
| `test-suite` | 运行项目测试 | 全部 pass |
| `server` | 启动服务 + 健康检查 | HTTP 200 within timeout |
| `cli` | 执行 CLI 命令 | 预期输出/exit code |
| `ui` | 启动 dev server + 渲染检查 | 页面可访问，关键元素存在 |

---

## Verdict 合并规则

E2E verdict 与 Evaluator verdict 合并，由 Leader 在步骤 6.f 执行：

| Evaluator | E2E | 最终 | 理由 |
|-----------|-----|------|------|
| ACCEPT | PASS | ACCEPT | 代码好且能跑 |
| ACCEPT | FAIL | REVISE | 看着好但跑不起来，E2E failure 加入 must_fix |
| ACCEPT | 未派发 | ACCEPT | 不需要 E2E，Evaluator 判定生效 |
| REVISE | PASS | REVISE | 能跑但代码质量有问题 |
| REVISE | FAIL | REVISE | 两方面都有问题，合并 must_fix |
| REJECT | 任何 | REJECT | 代码质量太差，E2E 无关紧要 |
| 任何 | FAIL(build) | REJECT | 编译失败是灾难性的，覆盖 Evaluator |

**核心原则**: E2E FAIL 可以升级 verdict（ACCEPT -> REVISE），但不能降级（REJECT 无论如何仍是 REJECT）。Build failure 是唯一例外 — 编译都不过直接 REJECT。

---

## Backpressure 协议

1. **第一次超时** -> 相同通道重试（相同超时）
2. **第二次超时** -> 精简场景（仅 build 验证），降级到 Gemini CLI
3. **第三次失败** -> 跳过 E2E，仅用 Evaluator 判定，记录到 `lessons-learned.md`

降级链: `Opus Agent (full)` -> `Opus Agent (retry)` -> `Gemini CLI (build only)` -> `skip`

---

## 超时指南

| 场景 | Timeout | 说明 |
|------|---------|------|
| E2E 验证（完整） | 300s | build + test + server 启动验证 |
| E2E 验证（仅 build） | 120s | 降级通道，仅编译检查 |
| 单个场景超时 | 60s | 单个 scenario 内部超时 |
