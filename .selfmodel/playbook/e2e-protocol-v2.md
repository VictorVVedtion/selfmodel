# E2E Verification Protocol v2 — 智能验证引擎

运行时验证协议 v2。Leader 在步骤 6 中需要 E2E 验证时查阅本文件。
v2 核心转变：Agent 不再是命令执行器，而是自主推理验证策略的智能引擎。

---

## 角色定义

| 属性 | 值 |
|------|-----|
| 角色 | E2E Verifier v2（第 7 角色） |
| 执行者 | Opus Agent（主通道，claude-opus-4-6） |
| 降级 | Gemini CLI（仅 Layer 0-1） |
| 职责 | 自主分析 diff + 验收标准，生成验证策略，执行多层验证，报告结构化证据 |
| 触发 | 条件式 — 同 v1 |
| 时机 | 与 Evaluator 并行（步骤 6） |
| 超时 | quick 60s / standard 300s / deep 600s |
| 输出 | Verdict JSON v2（分层场景 + 证据 + delta + artifacts） |

---

## 触发条件（同 v1）

### 需要 E2E（任一满足）

1. 交付物包含可运行入口（server、CLI、带 main 的脚本）
2. 验收标准含运行时动词：runs / renders / responds / starts / serves / outputs / displays / passes tests
3. Sprint 修改了 `detected_stack.test_tools` 相关文件
4. 合约含 `## E2E Scenarios` 或 `## E2E Depth` 部分

### 跳过 E2E（所有成立）

1. 纯文档修改（仅 `.md` 文件）
2. 纯类型定义/接口/无运行时影响的配置（测试文件修改被触发条件 3 覆盖）
3. 研究型 Sprint（Researcher 角色）
4. Leader 显式标注 `E2E: skip`

---

## Dispatch 格式（v2 极简）

Leader 只需写入最小化 dispatch 文件到 `.selfmodel/inbox/e2e/sprint-<N>.md`：

```markdown
# E2E Verification: Sprint <N>

## Context
- Sprint: <N>
- Worktree: <absolute path to worktree>
- Contract: <absolute path to sprint contract>

## Depth
auto | quick | standard | deep

## Notes
<可选：Leader 想额外强调的验证点>
```

Agent 自主完成剩余工作：读合约 → 读 diff → 探测环境 → 生成场景 → 执行 → 报告。

**Depth 含义**:
| Depth | Layers | Timeout | 适用场景 |
|-------|--------|---------|---------|
| quick | 0-1 | 60s | 快速构建检查 |
| standard | 0-3 + 7 | 300s | 大部分 Sprint |
| deep | 0-7 全部 | 600s | 关键 feature / release 前 |
| auto | 由 Agent 推断 | 按推断 depth | 默认 |

---

## Agent 执行流程（7 Phase）

### Phase 0: UNDERSTAND

Agent 读取合约和 diff，提取验证目标：

```
1. 读 Sprint 合约 → 提取 acceptance criteria
2. 运行 git diff main...<branch> --stat → 理解变更范围
3. 运行 git diff main...<branch> → 理解变更内容
4. 读 team.json → 获取 detected_stack
5. 计算 change_profile → 决定验证深度
```

### Phase 1: PROBE

环境探测，输出 environment_manifest：

```bash
# Agent 自动执行以下探测
node --version 2>/dev/null          # Node.js
python3 --version 2>/dev/null       # Python
docker --version 2>/dev/null        # Docker
test -d node_modules                # 依赖已装？
test -f .env || test -f .env.local  # 环境变量？
test -f docker-compose.yml          # 可启动基础设施？
pg_isready 2>/dev/null              # PostgreSQL？
redis-cli ping 2>/dev/null          # Redis？
```

### Phase 2: PLAN

Auto-Scenario Engine 生成验证计划（详见下节）。

### Phase 3: SETUP

按需搭建环境：
- `node_modules` 缺失 → `CI=true npm ci`
- `.env` 缺失但 `.env.example` 存在 → `cp .env.example .env`
- `docker-compose.yml` 存在且 Layer 3 激活 → `docker compose up -d`
- 等待健康检查（最多 30s，每 2s 轮询）
- setup 失败 → 记录 SETUP_FAILED，受影响 Layer 全部 SKIP

### Phase 4: EXECUTE

按 Verification Pyramid 自底向上执行（详见下节）。

### Phase 5: RETRY + FLAKY

对失败场景执行智能重试：
- Layer 0-1 失败不重试（确定性结果）
- 其他层失败 → 重试 1 次
- 重试通过 → 标记 FLAKY（不阻塞 verdict，但记录）
- 重试失败 → 确认真故障

### Phase 6: TEARDOWN

```bash
# 停止后台进程
kill %% 2>/dev/null
# 停止 Docker（如果 setup 阶段启动过）
docker compose down 2>/dev/null
# 不清理 node_modules（worktree 本身会被清理）
```

### Phase 7: REPORT

构建 Verdict JSON v2，保存 artifacts。

---

## Auto-Scenario Engine

### Change Profile 分类算法

```
INPUT: git diff --stat + detected_stack + acceptance_criteria + depth_hint

STEP 1: 分类变更文件
  .md / .txt / .rst                     → DOC
  .css / .scss / .less / .svg           → STYLE
  .test.* / .spec.* / __test__          → TEST
  .ts / .tsx / .jsx / .vue / .svelte    → FRONTEND
  .py / .go / .rs / .java / route.*     → BACKEND
  .json / .yaml / .toml / .env*         → CONFIG
  Dockerfile / docker-compose*          → INFRA
  package.json / requirements.txt / go.mod → DEPS

STEP 2: 推断 change_profile
  全部 DOC                 → profile=docs_only,    depth=minimal,   layers=[0]
  全部 STYLE               → profile=style_only,   depth=visual,    layers=[0,1,5]
  全部 TEST                → profile=test_only,    depth=test,      layers=[0,1,2]
  全部 CONFIG (无 .env)    → profile=config_only,  depth=minimal,   layers=[0,1]
  有 DEPS                  → profile=deps_update,  depth=security,  layers=[0,1,2,7]
  有 BACKEND 无 FRONTEND   → profile=backend_only, depth=api,       layers=[0,1,2,3,7]
  有 FRONTEND 无 BACKEND   → profile=frontend_only,depth=ui,        layers=[0,1,2,4,5]
  有 FRONTEND + BACKEND    → profile=fullstack,    depth=full,      layers=[0,1,2,3,4,5,6,7]
  有 INFRA                 → profile=infra,        depth=integration,layers=[0,1,2,3]

STEP 3: 验收标准关键词强制覆盖
  "renders" / "displays" / "UI" / "visible"   → 强制激活 Layer 4,5
  "API" / "endpoint" / "responds" / "HTTP"     → 强制激活 Layer 3
  "performance" / "lighthouse" / "fast"         → 强制激活 Layer 6
  "secure" / "audit" / "vulnerability"          → 强制激活 Layer 7
  "passes tests" / "test suite"                 → 强制激活 Layer 2
  "builds" / "compiles" / "type check"          → 强制激活 Layer 1

STEP 4: depth_hint 覆盖（最高优先级）
  quick    → cap layers at [0,1],           timeout=60s
  standard → cap layers at [0,1,2,3,7],     timeout=300s
  deep     → all layers,                    timeout=600s
  auto     → use computed (default)
```

### 场景生成规则

Agent 在每个激活 Layer 中，根据 detected_stack 和 diff 自动推断具体命令：

| Layer | 信号 | 推断命令 |
|-------|------|---------|
| 0: Smoke | diff 中每个新/改文件 | `test -f <path>` + import 静态分析 |
| 1: Build | detected_stack | package.json → `npm run build` + `npx tsc --noEmit`; Cargo.toml → `cargo build`; go.mod → `go build ./...` |
| 2: Test Suite | detected_stack.test_tools | jest → `npx jest --passWithNoTests`; vitest → `npx vitest run`; pytest → `python -m pytest`; go → `go test ./...` |
| 3: Integration | diff 中的 route/server 文件 | 启动 server → curl health → curl 变更路由 → 验证状态码 |
| 4: Browser E2E | diff 中的 page/component | Chrome MCP navigate → screenshot → console check → element verify |
| 5: Visual | Layer 4 截图 + 基线 | Opus 多模态视觉对比（AI 推理级，非像素 diff） |
| 6: Performance | web 框架 detected | Lighthouse CI → 分数; `du -sh dist/` → bundle size |
| 7: Security | 任何 DEPS/BACKEND 变更 | `npm audit --json`; secrets grep; license check |

---

## Verification Pyramid

### 8 层结构

```
Layer 7: Security     ─┐
Layer 6: Performance   │ 上层（gate: Layer 1）
─────────────────────  │
Layer 5: Visual       ─┤ 浏览器层（gate: Layer 3）
Layer 4: Browser E2E  ─┘
─────────────────────
Layer 3: Integration     中层（gate: Layer 2）
─────────────────────
Layer 2: Test Suite      核心层（gate: Layer 1）
─────────────────────
Layer 1: Build           基础层（gate: Layer 0）
─────────────────────
Layer 0: Smoke           最底层（无 gate）
```

### Gate 规则

| Gate | 通过条件 | 失败影响 |
|------|---------|---------|
| 0→1 | Layer 0 无 FAIL | Layer 1-7 SKIP |
| 1→2 | Layer 1 无 FAIL | Layer 2-5 SKIP（6-7 仍可跑） |
| 2→3 | Layer 2 无 FAIL（SKIP 可接受） | Layer 3-5 SKIP |
| 3→4,5 | Layer 3 server 场景 PASS | Layer 4-5 SKIP |

**特殊依赖**:
- Layer 6-7 的 gate 是 Layer 1（非 Layer 3），server 没起也能跑 npm audit
- Layer 4-5 串行（Browser 不并行）
- Layer 6-7 可与 Layer 4-5 并行

### Layer 详述

#### Layer 0: Smoke — 文件存在 + import 解析

```bash
test -f <path> && echo "EXISTS" || echo "MISSING"
# Agent 读取 import 语句推理路径是否存在
```

#### Layer 1: Build — 编译 + 静态分析

根据 detected_stack 选择：npm run build / npx tsc --noEmit / cargo build / go build ./...

#### Layer 2: Test Suite — 项目已有测试

根据 detected_stack.test_tools 选择。项目无测试 → SKIP（不视为失败）。

#### Layer 3: Integration — Server + API 验证

启动 server（后台） → 健康检查轮询 → curl 变更路由 → 验证状态码 → kill server。

#### Layer 4: Browser E2E — Chrome MCP 交互验证

Chrome MCP 流程：
1. `tabs_create_mcp` → 新 tab
2. `navigate` → 导航到变更页面
3. `computer(screenshot)` → 截图证据
4. `read_console_messages` → 控制台错误
5. `find` / `javascript_tool` → 关键元素验证
6. 可选 `resize_window` → 响应式测试（375x812 / 768x1024 / 1440x900）

降级链: Chrome MCP → Playwright → curl + HTML 静态分析

#### Layer 5: Visual Regression — AI 视觉对比

Opus 多模态读取当前截图 vs 基线截图，推理是有意变更还是意外回归。
首次运行 → 保存基线，Layer 5 SKIP。

#### Layer 6: Performance — Bundle + Lighthouse

`du -sh dist/` + Lighthouse (如可用)。

#### Layer 7: Security — 审计 + Secrets

`npm audit --json` + `grep -iE "password|secret|api_key"` on diff files。

---

## Artifact Management

### 目录结构

```
.selfmodel/artifacts/
├── sprint-<N>/
│   ├── manifest.json          # 验证元数据
│   ├── layer0-smoke.log       # 各层日志
│   ├── layer1-build.log
│   ├── layer2-tests.log
│   ├── layer3-integration.log
│   ├── layer4-*.png           # Browser 截图
│   ├── layer4-console.log     # Browser 控制台
│   ├── layer6-bundle-size.json
│   ├── layer7-npm-audit.json
│   └── verdict.json           # 完整 verdict v2
└── latest -> sprint-<N>/      # 符号链接
```

---

## Historical Delta

Agent 在 Phase 7 自动对比 `.selfmodel/artifacts/sprint-(N-1)/manifest.json`：

| Metric | 回归判定 |
|--------|---------|
| Build time | >20% 慢 → warning |
| Bundle size | >10% 增长 → warning |
| Test count | 减少 → blocker |
| Test coverage | 下降 >5% → blocker |
| Lighthouse score | 下降 >5 → warning |
| npm audit critical | 增加 → blocker |

Blocker regression → verdict 升级为 REVISE。Warning → 记录不影响 verdict。

---

## Verdict 合并规则 v2

| Evaluator | E2E | Regression | 最终 | 理由 |
|-----------|-----|------------|------|------|
| ACCEPT | PASS | None/Warning | ACCEPT | 完美/非关键回归 |
| ACCEPT | PASS | Blocker | REVISE | 有阻塞性回归 |
| ACCEPT | FAIL | - | REVISE | 看着好但跑不起来 |
| ACCEPT | 未派发 | - | ACCEPT | 不需要 E2E |
| REVISE | PASS/FAIL | - | REVISE | 合并 must_fix |
| REJECT | 任何 | - | REJECT | 代码质量太差 |
| 任何 | FAIL(build) | - | REJECT | 编译失败覆盖 |

FLAKY 不影响 verdict，但记录到 flaky_report。

---

## Backpressure 协议

1. 第一次超时 → 相同通道重试
2. 第二次超时 → 降级深度（deep→standard→quick）
3. 第三次失败 → 仅 Layer 0-1，降级 Gemini CLI
4. 第四次失败 → 跳过 E2E，记录到 lessons-learned.md

---

## Agent 调用模板

### Opus Agent（主通道）

```
Agent tool:
  prompt: |
    You are the E2E Verification Agent v2 (Opus 4.6).
    Your mission: VERIFY that delivered code works at runtime. You do NOT modify code.
    YOUR KEY ADVANTAGE: You can READ the diff, UNDERSTAND intent from acceptance
    criteria, and VERIFY behavior dynamically. No pre-written test scripts needed.
    Workflow: UNDERSTAND → PROBE → PLAN → SETUP → EXECUTE → RETRY → TEARDOWN → REPORT
    Constraints: no code modification, no global installs, no prod APIs, no git push.
    Save artifacts to: .selfmodel/artifacts/sprint-<N>/
    Verification file: <path to inbox/e2e/sprint-N.md>
    Output ONLY valid JSON matching E2E Verdict v2 schema.
  isolation: "worktree"
  model: opus
```

### Gemini CLI（降级，仅 Layer 0-1）

```bash
cd <worktree-path> && \
CI=true GIT_TERMINAL_PROMPT=0 timeout 120 gemini \
  "@<path>/inbox/e2e/sprint-<N>.md Execute only Layer 0 and Layer 1. Output JSON." \
  -s --yolo
```
