# E2E Verification Protocol v2 — 原子验证引擎

运行时验证协议 v2。Leader 在步骤 6 中需要 E2E 验证时查阅本文件。

核心原则：**验证的原子单元是验收标准（AC），不是工具层（Layer）。**
每条 AC 对应一个原子验证，每个原子验证产生一条证据。verdict = AND(所有原子验证)。

---

## 角色定义

| 属性 | 值 |
|------|-----|
| 角色 | E2E Verifier v2（第 7 角色） |
| 执行者 | Opus Agent（主通道，claude-opus-4-6） |
| 降级 | Gemini CLI（仅隐式 AC） |
| 职责 | 解析验收标准为原子验证，逐条执行，逐条举证 |
| 时机 | 与 Evaluator 并行（步骤 6） |
| 超时 | quick 60s / standard 300s / deep 600s |
| 输出 | Verdict JSON v2（AC 映射 + 证据链 + delta） |

---

## 触发条件（同 v1）

### 需要 E2E（任一满足）

1. 交付物包含可运行入口（server、CLI、带 main 的脚本）
2. 验收标准含运行时动词：runs / renders / responds / starts / serves / outputs / displays / passes tests
3. Sprint 修改了 `detected_stack.test_tools` 相关文件
4. 合约含 `## E2E Depth` 部分

### 跳过 E2E（所有成立）

1. 纯文档修改（仅 `.md` 文件）
2. 纯类型定义/接口/无运行时影响的配置（测试文件修改被触发条件 3 覆盖）
3. 研究型 Sprint（Researcher 角色）
4. Leader 显式标注 `E2E: skip`

---

## Dispatch 格式

Leader 写入 `.selfmodel/inbox/e2e/sprint-<N>.md`：

```markdown
# E2E Verification: Sprint <N>

## Context
- Sprint: <N>
- Worktree: <absolute path>
- Contract: <absolute path to sprint contract>

## Depth
quick | standard | deep | auto

## Notes
<可选：Leader 想额外强调的验证点>
```

Agent 自主：读合约 → 解析 AC → 探测环境 → 逐条验证 → 报告。

**Depth 控制**:
| Depth | 验证范围 | Timeout |
|-------|---------|---------|
| quick | 仅隐式 AC（build + smoke） | 60s |
| standard | 隐式 AC + 全部显式 AC | 300s |
| deep | 隐式 + 显式 + 扩展验证（perf/security/visual） | 600s |
| auto | Agent 根据 change_profile 推断 | 按推断 |

---

## 原子验证模型

### 两类 AC

**显式 AC** — 合约中的 `## Acceptance Criteria` 逐条列出的验收标准。
每条 AC 是一个原子验证单元。Agent 解析 AC 文本，推断验证方法和预期结果。

```
合约 AC#1: "运行 npm run build 编译通过"
  → 原子验证: { command: "npm run build", expect: "exit 0", method: "bash" }

合约 AC#3: "API /api/health 返回 200"
  → 原子验证: { command: "curl -s -o /dev/null -w '%{http_code}' http://localhost:3000/api/health", expect: "200", method: "integration", requires: "server_running" }

合约 AC#5: "仪表盘页面渲染组件网格"
  → 原子验证: { navigate: "/dashboard", check: "querySelector('.widget-grid') !== null", method: "browser", evidence: "screenshot" }
```

**隐式 AC** — 不写在合约中但始终验证的基线要求。

| 隐式 AC | 验证方法 | 条件 |
|---------|---------|------|
| 交付文件存在 | `test -f <path>` for each deliverable | 始终 |
| Import 链完整 | 静态分析 import 语句 | 始终 |
| 编译通过 | detected_stack 对应的 build 命令 | 始终（除非显式 AC 已覆盖） |
| 类型检查通过 | `tsc --noEmit` / 等价工具 | 有 TypeScript/强类型语言 |
| 现有测试不回归 | `npm test` / `pytest` / `go test` | 有测试框架 |
| 无新增安全漏洞 | `npm audit` / 依赖审计 | depth=deep 或有 DEPS 变更 |
| 无 secrets 泄露 | grep diff 中的敏感关键词 | depth=deep 或有 BACKEND 变更 |

### AC 解析算法

```
Phase 0: UNDERSTAND

1. 读合约 → 提取 Acceptance Criteria 列表
2. 读 git diff → 提取 Deliverables 文件列表
3. 读 detected_stack → 推断可用工具
4. 分类变更文件 → 计算 change_profile

Phase 1: DECOMPOSE

FOR each 显式 AC:
  解析 AC 文本 → 推断:
    - method: bash | integration | browser | visual | manual
    - command: 具体执行命令
    - expect: 预期结果（exit code / 输出模式 / 元素存在）
    - requires: 前置条件（server_running / docker / browser）
    - evidence_type: stdout | screenshot | json_report

生成隐式 AC 列表（基于 detected_stack + change_profile）

合并 → 全部原子验证列表，按依赖排序:
  1. 文件存在（无依赖）
  2. 编译/构建（依赖文件存在）
  3. 测试套件（依赖编译通过）
  4. Server/API（依赖编译通过 + 环境就绪）
  5. Browser/Visual（依赖 Server 运行中）
  6. Security/Performance（依赖编译通过）
```

### 依赖与阻断

原子验证之间存在依赖关系。依赖的 AC 失败 → 被依赖的 AC 标记 BLOCKED：

```
AC: "文件存在" FAIL
  → AC: "编译通过" BLOCKED (reason: deliverable files missing)
  → AC: "测试通过" BLOCKED
  → AC: "API 返回 200" BLOCKED
  → ...所有下游 BLOCKED

AC: "编译通过" FAIL
  → AC: "测试通过" BLOCKED
  → AC: "API 返回 200" BLOCKED
  → AC: "页面渲染" BLOCKED
  但: AC: "npm audit 通过" 不受影响（不依赖编译产物运行）
```

阻断规则：
- BLOCKED AC 不执行，不计入 FAIL，在 verdict 中标注 `blocked_by`
- 只有实际执行且失败的 AC 才计入 FAIL
- 这保证 verdict 精确反映"哪条 AC 是根因"

---

## Agent 执行流程

```
UNDERSTAND → PROBE → DECOMPOSE → SETUP → EXECUTE → RETRY → TEARDOWN → REPORT

Phase 0: UNDERSTAND
  读合约 + diff + detected_stack
  提取显式 AC 列表 + 文件变更列表

Phase 1: PROBE
  探测运行环境:
    node/python/docker/db/redis/.env/test_tools/browser
  输出 environment_manifest

Phase 2: DECOMPOSE
  解析每条显式 AC → 原子验证
  生成隐式 AC → 原子验证
  按依赖排序
  根据 environment_manifest 标记不可执行的 AC 为 SKIP
  根据 depth 裁剪（quick 仅隐式，standard 全部，deep 扩展）

Phase 3: SETUP
  按需搭建:
    node_modules 缺失 → CI=true npm ci
    .env 缺失 → cp .env.example .env
    需要 server → 启动 + 健康检查轮询（30s 超时）
    需要 docker → docker compose up -d
  setup 失败 → 受影响 AC 标记 SKIP(setup_failed)

Phase 4: EXECUTE
  按依赖顺序逐条执行原子验证:
    运行命令 → 捕获 exit_code + stdout + stderr
    对比预期结果 → PASS / FAIL
    收集证据（stdout / screenshot / json）
    IF FAIL && 有下游依赖 → 下游 AC 标记 BLOCKED

Phase 5: RETRY
  对 FAIL 的非确定性 AC 重试 1 次:
    确定性 AC（文件存在/编译）不重试
    非确定性 AC（server 响应/browser 渲染）重试
    重试 PASS → 标记 FLAKY（不阻塞，记录）
    重试 FAIL → 确认真故障

Phase 6: TEARDOWN
  kill 后台进程
  docker compose down（如启动过）

Phase 7: REPORT
  构建 Verdict JSON v2
  保存 artifacts 到 .selfmodel/artifacts/sprint-<N>/
  计算历史 delta（如有基线）
```

---

## Verdict JSON v2 Schema

```json
{
  "$schema": "e2e-verdict-v2",
  "sprint": "<N>",
  "agent": "opus-agent",
  "timestamp": "<ISO 8601>",

  "analysis": {
    "change_profile": "<docs_only|style_only|backend_only|frontend_only|fullstack|...>",
    "depth": "<quick|standard|deep|auto>",
    "files_changed": 12,
    "lines_changed": 347,
    "explicit_ac_count": 5,
    "implicit_ac_count": 4,
    "total_atoms": 9
  },

  "environment": {
    "node": "<version or null>",
    "docker": false,
    "test_runner": "<jest|vitest|pytest|null>",
    "browser": "<chrome_mcp|playwright|null>",
    "db": "<running|not_running|null>",
    "setup_actions": ["npm ci"],
    "setup_duration_seconds": 15
  },

  "atoms": [
    {
      "id": "explicit-1",
      "source": "explicit",
      "ac": "运行 npm run build 编译通过",
      "ac_index": 1,
      "method": "bash",
      "command": "npm run build",
      "expect": "exit 0",
      "status": "PASS",
      "exit_code": 0,
      "duration_seconds": 8.3,
      "evidence": "Compiled successfully. 0 errors.",
      "artifact": "build.log",
      "depends_on": ["implicit-files"],
      "blocked_by": null,
      "retry": false,
      "flaky": false
    },
    {
      "id": "explicit-3",
      "source": "explicit",
      "ac": "API /api/health 返回 200",
      "ac_index": 3,
      "method": "integration",
      "command": "curl -s -o /dev/null -w '%{http_code}' http://localhost:3000/api/health",
      "expect": "200",
      "status": "PASS",
      "exit_code": 0,
      "duration_seconds": 1.2,
      "evidence": "HTTP 200",
      "artifact": null,
      "depends_on": ["explicit-1"],
      "blocked_by": null,
      "retry": false,
      "flaky": false
    },
    {
      "id": "explicit-5",
      "source": "explicit",
      "ac": "仪表盘页面渲染组件网格",
      "ac_index": 5,
      "method": "browser",
      "command": "chrome_mcp: navigate(/dashboard) + querySelector('.widget-grid')",
      "expect": "element exists",
      "status": "FLAKY",
      "exit_code": null,
      "duration_seconds": 5.7,
      "evidence": "Widget grid found on 2nd attempt",
      "artifact": "dashboard.png",
      "depends_on": ["explicit-3"],
      "blocked_by": null,
      "retry": true,
      "flaky": true,
      "flaky_evidence": {
        "first": "FAIL - loading spinner timeout",
        "second": "PASS - widget-grid found, 6 children",
        "likely_cause": "Race condition in data fetch"
      }
    },
    {
      "id": "implicit-files",
      "source": "implicit",
      "ac": "交付文件存在",
      "ac_index": null,
      "method": "bash",
      "command": "test -f src/api/dashboard.ts && test -f src/components/WidgetGrid.tsx",
      "expect": "exit 0",
      "status": "PASS",
      "exit_code": 0,
      "duration_seconds": 0.1,
      "evidence": "all 3 deliverable files exist",
      "artifact": null,
      "depends_on": [],
      "blocked_by": null,
      "retry": false,
      "flaky": false
    },
    {
      "id": "implicit-security",
      "source": "implicit",
      "ac": "无新增 critical 漏洞",
      "ac_index": null,
      "method": "bash",
      "command": "npm audit --json",
      "expect": "critical == 0",
      "status": "PASS",
      "exit_code": 0,
      "duration_seconds": 3.1,
      "evidence": "critical:0, high:0, moderate:2",
      "artifact": "npm-audit.json",
      "depends_on": [],
      "blocked_by": null,
      "retry": false,
      "flaky": false
    }
  ],

  "summary": {
    "total": 9,
    "passed": 7,
    "failed": 0,
    "flaky": 1,
    "skipped": 0,
    "blocked": 1,
    "explicit_pass_rate": "4/5 (1 flaky)",
    "implicit_pass_rate": "4/4"
  },

  "delta": {
    "baseline_sprint": "<N-1 or null>",
    "metrics": {
      "build_time": { "previous": 7.1, "current": 8.3, "delta": "+16.9%", "status": "ok" },
      "test_count": { "previous": 45, "current": 48, "delta": "+3", "status": "improved" }
    },
    "regressions": [],
    "improvements": ["test_count +3"]
  },

  "verdict": "PASS | FAIL",
  "has_regression": false,
  "blocking_failures": [],
  "flaky_report": [],

  "artifacts": {
    "directory": ".selfmodel/artifacts/sprint-<N>/",
    "files": ["build.log", "dashboard.png", "npm-audit.json", "verdict.json"]
  },

  "notes": "<runtime observations>"
}
```

**Verdict 判定规则**:
- 任一显式 AC FAIL → verdict FAIL
- 任一隐式 AC(build 类) FAIL → verdict FAIL
- 所有 AC PASS/FLAKY/SKIP/BLOCKED → verdict PASS
- FLAKY 不阻塞，但记录
- BLOCKED 不计入 FAIL（根因在其依赖的 AC）

---

## Verdict 合并规则 v2

| Evaluator | E2E | Regression | 最终 | 理由 |
|-----------|-----|------------|------|------|
| ACCEPT | PASS | None/Warning | ACCEPT | 完美/非关键回归 |
| ACCEPT | PASS | Blocker | REVISE | 阻塞性回归 |
| ACCEPT | FAIL | - | REVISE | AC 未满足，blocking_failures 加入 must_fix |
| ACCEPT | 未派发 | - | ACCEPT | 不需要 E2E |
| REVISE | PASS/FAIL | - | REVISE | 合并 must_fix |
| REJECT | 任何 | - | REJECT | 代码质量太差 |
| 任何 | FAIL(build) | - | REJECT | 编译失败覆盖 |

FLAKY 不影响 verdict，记录到 flaky_report。

---

## Historical Delta

Agent 在 Phase 7 对比 `.selfmodel/artifacts/sprint-(N-1)/verdict.json`：

| Metric | 回归判定 |
|--------|---------|
| Build time | >20% 慢 → warning |
| Bundle size | >10% 增长 → warning |
| Test count | 减少 → blocker |
| Test coverage | 下降 >5% → blocker |
| npm audit critical | 增加 → blocker |

Blocker → verdict 升级为 REVISE。Warning → 记录不影响 verdict。

---

## Artifact Management

```
.selfmodel/artifacts/sprint-<N>/
├── verdict.json           # 完整 verdict
├── build.log              # 编译输出
├── tests.log              # 测试输出
├── *.png                  # Browser 截图
├── npm-audit.json         # 安全审计
└── manifest.json          # 元数据（timestamp, change_profile, environment）
```

---

## Backpressure 协议

1. 第一次超时 → 相同通道重试
2. 第二次超时 → 降级深度（deep→standard→quick）
3. 第三次失败 → 仅隐式 AC，降级 Gemini CLI
4. 第四次失败 → 跳过 E2E，记录到 lessons-learned.md

---

## Agent 调用模板

### Opus Agent（主通道）

```
Agent tool:
  prompt: |
    You are the E2E Verification Agent v2 (Opus 4.6).
    Mission: verify delivered code works at runtime. Do NOT modify code.

    CORE PRINCIPLE: The atom of verification is the Acceptance Criterion.
    Parse every AC from the contract. Each AC becomes one atomic verification
    with one command, one expected result, and one piece of evidence.
    Also verify implicit ACs (files exist, build passes, tests pass, no vulns).

    Workflow: UNDERSTAND → PROBE → DECOMPOSE → SETUP → EXECUTE → RETRY → TEARDOWN → REPORT

    For each AC:
      1. Parse the AC text → infer method + command + expected result
      2. Check dependencies (does this AC need server running? browser?)
      3. Execute and capture evidence
      4. If FAIL and non-deterministic → retry once → FLAKY if passes

    Constraints: no code modification, no global installs, no prod APIs, no git push.
    Save artifacts to: .selfmodel/artifacts/sprint-<N>/
    Verification file: <path>
    Output ONLY valid JSON matching E2E Verdict v2 schema.
  isolation: "worktree"
  model: opus
```

### Gemini CLI（降级，仅隐式 AC）

```bash
cd <worktree-path> && \
CI=true GIT_TERMINAL_PROMPT=0 timeout 120 gemini \
  "@<path>/inbox/e2e/sprint-<N>.md Verify only implicit ACs (files exist, build passes). Output JSON." \
  -s --yolo
```
