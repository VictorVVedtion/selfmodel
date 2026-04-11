# Next Session Handoff

**Last session**: 2026-04-11 (continued) — Sprint 9 + Sprint 10 via fallback channels

## 一句话状态

Sprint 9 (VERSION 字符串同步, ACCEPT 8.15/10) 和 Sprint 10 (GitHub PR flow 演进, ACCEPT 9.15/10) 两战全胜。Sprint 10 是 selfmodel dogfood 时代的**最后一次本地 merge** ——从 Sprint 11 开始所有 Sprint 必须用新的 `gh pr create + gh pr merge --auto` 流程。所有工作已 push 到 `origin/main @ 657f3b2`（9 commits: `a232375..657f3b2`）。

## 今天做了什么

### Sprint 9 — VERSION string sync (warm-up)

**动机**：`VERSION` 文件=0.4.0，`scripts/selfmodel.sh:8 SELFMODEL_VERSION="0.3.0"`，实际 v0.5.0 era 功能已经在 main 上跑了快一周但从未在 CHANGELOG 里正式登记。

**动作**：
- 合约：`.selfmodel/contracts/archive/sprint-9.md`（simple 复杂度）
- Agent：Opus Agent via Task tool + `isolation: "worktree"` — 4 个 Edit 成功（VERSION、scripts/selfmodel.sh、README.md、CHANGELOG.md）
- Evaluator：**Opus Agent 子通道爆 rate limit**（"resets 5am PT"）→ 切 Gemini CLI → ACCEPT 8.15/10
- E2E：Gemini e2e 通道只覆盖隐式 AC，而 Sprint 9 显式 AC 全是 deterministic bash → **Leader self-run E2E** 10/10 PASS
- Merge：本地 `git merge --no-ff`（Sprint 9 还是旧流程）→ `c7572a5`
- Artifacts commit：`b19214a`

**评分**：8.15（9/9/8/8/8/5）
- Gemini 分数比 Sprint 7/8 (9.15 Opus) 低 1 分，当时担心是 channel bias
- Sprint 10 的 Gemini 评分打脸了这个假设（Sprint 10 拿 9.15）
- 结论：Sprint 9 低分是**范围太小**（纯字符串同步没空间给高分），不是 channel bias

### Sprint 10 — GitHub PR Flow Evolution (the big one)

**动机**：用户的核心诉求 —— 把 Sprint 落地流程从 Leader 本地 `git merge --no-ff` 改成 `gh pr create` + `gh pr merge --auto`。本地 merge 把落地时刻留在 Leader 私盘，没 CI 验证，没 GitHub 纪录，外部协作者看不到 Sprint 门禁在跑。

**动作**：
- **Leader Deep-Read + 设计工作**（Rule 7 clarification 允许）：读完 `dispatch-rules.md` (522 行)、`orchestration-loop.md` (444 行)、`CLAUDE.md` Sprint Lifecycle 段，做 10 个设计决策（D1-D10），起草 6 个 BLOCK verbatim 替换文本
- Artifact：`.selfmodel/artifacts/sprint-10-pr-flow-design.md`（603 行设计文档）
- 合约：`.selfmodel/contracts/archive/sprint-10.md`（standard 复杂度，含真 Code Tour + Architecture Context）
- Inbox：`.selfmodel/inbox/gemini/sprint-10.md`（11 步精准指令，Agent 零自由度）
- Worktree：手动 `git worktree add /Users/vvedition/.zcf/selfmodel/sprint-10-gemini -b sprint/10-gemini`
- Agent：**Gemini CLI**（Opus 仍 rate limited，Gemini 作为 Generator fallback）
  - Gemini 完成 6 个精准 Edit，12 个 validation grep 全过
  - Gemini 中途撞 429 "MODEL_CAPACITY_EXHAUSTED" 但在撞限前已完成编辑
  - Gemini **无法 commit**：macOS Seatbelt 不让写 `/Users/vvedition/Desktop/selfmodel/.git/worktrees/sprint-10-gemini/index.lock`（worktree 的 git 元数据在主仓的 `.git/worktrees/<name>/` 下，不在 worktree 自己的 tree 内）
  - **Leader 从 worktree 做 git add + git commit** — Leader 没沙盒限制 → `a700bab`
- Evaluator：Gemini CLI（Opus 还 rate limited，Opus 子 Agent 还是不可用）
  - Gemini 又撞了一次 429 但还是挤过去完成评审
  - ACCEPT 9.15/10（10/10/9/9/9/6）
- E2E：**跳过**（per `e2e-protocol-v2.md` "跳过 E2E" 规则 #1 — 纯 `.md` 修改）
- Merge：本地 `git merge --no-ff`（Sprint 10 **meta-exception**，最后一次本地 merge）→ `ebbee4c`
- Post-merge smoke：14/14 PASS（12 个新验证 grep + drift test + bash 语法）
- Artifacts commit：`ce0816a`
- Fix-up commit：`657f3b2`（补 active→archive 重命名的 deletion，上一个 commit 漏了）

**评分**：9.15（10/10/9/9/9/6）—— 和 Sprint 7、8 同分
- 这 confirms 了 Gemini 在 standard 复杂度上的校准和 Opus Agent 基本对齐
- Sprint 9 的 8.15 是 "scope ceiling" 不是 "channel bias"

### 3 个值得写入 memory 的新 lesson

1. **Gemini sandbox cannot commit from worktree**（新 findings）
   - 原因：git worktree 的 index/HEAD 存在 `<main-repo>/.git/worktrees/<worktree-name>/`，不在 worktree 自己的 tree 内
   - macOS Seatbelt 只允许 Gemini 写它当前工作目录的子树 + /tmp
   - **应对**：Gemini dispatch 在 worktree 中工作时，**Leader 负责最后的 git add + commit 步**。Gemini 只负责 Edit 文件，不负责提交
   - 或者（未来优化）：用 full clone 而不是 worktree 作为 Gemini 的工作区

2. **Claude Code Agent tool worktree fork 时机**
   - `isolation: "worktree"` 从 **session-start commit** fork，不是从 **dispatch time commit** fork
   - 意味着同一 session 内后续提交到 main 的 contract/inbox 文件**不会**出现在 Agent 的 worktree git 历史里
   - Agent 仍能读到这些文件（大概通过绝对路径读 main repo），但 feature 分支的 git 历史会跳过中间 commits
   - hook 的 `.selfmodel/contracts/active/` 检查依赖 **PWD**，所以在 worktree PWD 下跑命令会看到空目录 → 假失败 → 阻止 Agent 调用
   - **应对**：需要在 worktree 中跑 gemini/codex 前，**先 cd 回 main repo** 或确保 PWD 切换正确

3. **Cross-channel evaluator calibration: Gemini ≈ Opus on standard Sprints**
   - Sprint 9 Gemini 8.15 vs Sprint 7/8 Opus 9.15 一度让人怀疑 Gemini 偏严
   - Sprint 10 Gemini 9.15 = Sprint 7/8 Opus 9.15 —— 打脸该假设
   - 真正的解释：**Sprint 9 太小**（4 文件 23 行字符串同步），没空间给 Integration/Taste/Originality 高分
   - 对更大的设计型 Sprint（Sprint 10 跨 3 文件 +149 行 + 跨文件引用一致性），Gemini 打 9.15 没问题
   - **结论**：Gemini fallback 可以按原分使用，不需要 +1 补偿

## 当前状态（verified clean）

| 项 | 值 |
|---|---|
| Branch | `main` ✓ |
| HEAD | `657f3b2` ✓ |
| origin/main | `657f3b2` (in sync) ✓ |
| Worktrees | 仅 main ✓ |
| Active contracts | 0（空）✓ |
| DELIVERED 未合并 | 无 ✓ |
| quality.jsonl | 8 rows（4 retroactive @ 6.83 + Sprint 7,8 @ 9.15 + Sprint 9 @ 8.15 + Sprint 10 @ 9.15）|
| 当前均分（真实 Sprint 4 个）| 8.98 |

**9 个 new commits push 到 `a232375..657f3b2`**

## Pending — 下一个 session 的任务队列

### 最高优先级（用户核心诉求的 Sprint 11）

**Sprint 11: depth gate Agent tool coverage + literal-grep 误报修复**
→ **这将是 selfmodel 历史上第一个使用新 PR 流程的 Sprint**。如果新流程有设计缺陷，Sprint 11 会立刻暴露。

**范围**（建议）：
- `scripts/hooks/enforce-depth-gate.sh` —— 扩展匹配范围：在 PreToolUse Task matcher 上也检查（不只 Bash），读 Agent tool 的 subagent prompt 判断是否 standard/complex Sprint 派发，需要真 Code Tour
- `scripts/hooks/enforce-agent-rules.sh` —— 修 literal-grep false positive：只匹配命令行首 token `gemini`/`codex`（或 `jq .tool_input.command` 的 argv[0]），不对整体字符串 grep
- `.claude/settings.json` —— 在 PreToolUse 里为 Task matcher 注册两个 hook
- `scripts/tests/test-hook-drift.sh` —— 扩展到覆盖所有 4 个 hook（handoff #4 的诉求）
- `scripts/selfmodel.sh` `generate_hooks()` —— 同步 canonical heredoc

**复杂度**：standard（多文件，跨 hook 协议一致性要求高）

**Sprint 11 的 meta 意义**：
- 第一次走 `git push origin sprint/11-<agent>` + `gh pr create` + `gh pr merge --auto` 的完整新流程
- 第一次 pre-merge smoke（在 rebased worktree 上跑，替代原 post-merge）
- 第一次 `git fetch origin && git merge --ff-only origin/main` 拉回落地后的 main
- 如果流程设计有问题（poll 超时太短？CI 卡住？auto-merge 策略不对？），Sprint 11 会暴露

**Sprint 11 准备工作**（Leader 下个 session 启动时做）：
- 读 `scripts/hooks/enforce-depth-gate.sh`、`enforce-agent-rules.sh` 当前实现
- 读 `.claude/settings.json` 现有 hook 注册格式
- 设计 Task matcher 的 subagent prompt 读取方法（`jq -r '.tool_input.prompt'` from stdin）
- 写 design artifact `.selfmodel/artifacts/sprint-11-hook-coverage-design.md`
- 写 contract 和 inbox task
- 如果 Opus 额度恢复了，用 Opus Agent。如果还没恢复，用 Gemini CLI + 预先起草的 verbatim patches

### 中优先级

4. **泛化 drift test 到全 4 个 hook**（handoff #4 的老任务）—— 可并入 Sprint 11
5. **drift test 接入 post-merge smoke 或 Stop hook**（handoff #5）
6. **Evaluator JSON schema 不一致**（handoff #7）—— 收紧 `evaluator-prompt.md` schema 或让 Leader 的 jq 兼容两种

### 低优先级 / 维护

7. **legacy untracked 文件决策**（handoff #8，继续 skip）
   - `.selfmodel/contracts/archive/sprint-{A,B,C,D,CLI1,CLI2,W1,W2,W3}.md`
   - `.selfmodel/inbox/codex/sprint-{CLI2,D,W3}.md`
   - `.selfmodel/wiki/` 整个目录
8. **team.json session_count 更新**（handoff #9）
9. **Rampage 重跑**（handoff #10）
10. **Sprint 11+ 首次 PR 跑出的 CI workflow 健康检查**（新的）—— 第一次用 gh pr merge --auto 时，看 CI 是不是真的绿了，CI 配置是否需要更新

## Blockers

无。

## Active Worktrees

无（Sprint 9 和 Sprint 10 的 worktree 都已 cleanup）

## Open / Active Sprints

无（Sprint 9 + Sprint 10 全部 archive）

## 关键决策（本会话）

1. **按顺序跑 Sprint 9 → Sprint 10**，Sprint 11 留给下个 session（上下文预算 + 第一次走新流程值得专门一个 session）
2. **Sprint 9 范围保持小**（只做字符串同步），`team.json` 的 `protocol_version` 是 evolution subsystem 独立版本号，不碰
3. **Sprint 10 meta-exception**：定义新 PR 流程的 Sprint 本身最后一次用旧 local merge 流程
4. **Sprint 10 通道 fallback 全套**：Generator=Gemini、Evaluator=Gemini、E2E=skipped、commit 步由 Leader 接手（sandbox 限制）
5. **Scope A 而非 B/C**：Sprint 10 只改 docs，不碰 CI 或加 helper 脚本。CI 验证留给 Sprint 11+ 用新流程时自然触发
6. **Gemini Evaluator 分数按原分使用**（不做 +1 补偿），Sprint 10 的 9.15 验证了这个判断

## 本次有用的 CLI 片段（for Sprint 11 Leader 参考）

### 手动创建 worktree（非 Agent tool 的 Gemini/Codex dispatch）

```bash
mkdir -p /Users/vvedition/.zcf/selfmodel
git worktree add /Users/vvedition/.zcf/selfmodel/sprint-<N>-<agent> -b sprint/<N>-<agent>
```

### Gemini dispatch（worktree 内跑）

```bash
cd /Users/vvedition/.zcf/selfmodel/sprint-<N>-<agent> && \
CI=true GIT_TERMINAL_PROMPT=0 timeout 300 gemini \
  "@/Users/vvedition/.zcf/selfmodel/sprint-<N>-<agent>/.selfmodel/inbox/gemini/sprint-<N>.md 严格执行 Sprint <N> 的步骤。不要改其他文件。不要 paraphrase。" \
  -s --yolo
```

### Gemini 跑完后 Leader 接手 commit（sandbox 限制的 workaround）

```bash
cd /Users/vvedition/.zcf/selfmodel/sprint-<N>-<agent> && \
git add <具体文件列表> && \
git commit -m "sprint-<N>: <description>"
```

### Gemini Evaluator fallback（CLI）

```bash
CI=true GIT_TERMINAL_PROMPT=0 timeout 240 gemini \
  -p "<eval prompt>
Read and execute the evaluation protocol at: /Users/vvedition/Desktop/selfmodel/.selfmodel/inbox/evaluator/sprint-<N>-eval.md
Write JSON to /Users/vvedition/Desktop/selfmodel/.selfmodel/reviews/sprint-<N>-verdict.json." \
  -m gemini-3.1-pro-preview -y
```

### Sprint 10 定义的新 PR 流程（Sprint 11 要首次用）

```bash
# Step 1: rebase
cd /Users/vvedition/.zcf/selfmodel/sprint-11-<agent>
git fetch origin main
git rebase origin/main

# Step 2: rename branch (if harness gave ugly name)
git branch -m sprint/11-<agent>

# Step 3: pre-merge smoke (run contract ## Smoke Test block)

# Step 4: push
git push -u origin sprint/11-<agent>

# Step 5: generate PR body
cat > .selfmodel/reviews/sprint-11-pr-body.md <<'EOF'
<from contract + evaluator + e2e verdicts>
EOF

# Step 6: create PR
gh pr create \
  --base main \
  --head sprint/11-<agent> \
  --title "Sprint 11: <title>" \
  --body-file .selfmodel/reviews/sprint-11-pr-body.md

# Step 7: queue auto-merge
PR=$(gh pr view --json number --jq .number)
gh pr merge "$PR" --merge --delete-branch --auto

# Step 8: poll until MERGED
for i in $(seq 1 60); do
  state=$(gh pr view "$PR" --json state --jq .state)
  [ "$state" = "MERGED" ] && break
  [ "$state" = "CLOSED" ] && { echo "closed without merge"; exit 1; }
  sleep 5
done

# Step 9: ff-only pull
cd /Users/vvedition/Desktop/selfmodel
git fetch origin main
git merge --ff-only origin/main

# Step 10: cleanup
git worktree remove /Users/vvedition/.zcf/selfmodel/sprint-11-<agent>
git branch -D sprint/11-<agent>
```

**第一次跑这套流程可能踩的坑**：
- gh pr merge --auto 可能不 respect 非 admin 的 required checks（如果没有 protected branch rules）
- 5 分钟 poll 可能对某些 CI 不够（.github/workflows/ci.yml 实际需要的时间未验证）
- force-with-lease 在第一次 push 不需要，revise 时才需要
- `git merge --ff-only` 如果 Leader 的本地 main 有未 push 的 commit 会失败（但 Sprint 11 之前 main 应该 clean）

## Context metrics

- 2 个 Sprint merged（9 + 10）
- 9 个 commits pushed to origin/main
- 2 次 Agent 派发（Sprint 9: Opus Agent 初始成功 / Sprint 10: Gemini CLI fallback）
- 2 次 Evaluator 派发（都走 Gemini CLI，都撞 429 但都完成）
- 1 次 E2E（Sprint 9 Leader self-run）+ 1 次 E2E skip（Sprint 10 pure .md）
- 1 个 Leader design artifact（sprint-10-pr-flow-design.md, 603 行）
- 1 次 `git push origin main`（a232375..657f3b2）
- 8 行 quality.jsonl（首次跨通道数据）
- Opus Agent 子通道整个 session 都 rate limited（resets 5am PT，session 期间未恢复）
