### 核心结论

针对 `selfmodel` CLI 在零依赖（bash + jq）环境下自动生成和更新 Claude Code hooks 的需求，核心结论如下：

1. **配置合并 (settings.json)**：使用 `jq` 的深度合并（`*`）或数组追加去重策略，可以完美保留用户的自定义配置。不建议使用覆盖写入。
2. **脚本分发**：**Heredoc（方案 A）** 是最适合零依赖 bash 工具的分发方式。它保证了 CLI 与 Hook 脚本版本的绝对一致性，且支持离线环境。
3. **版本升级**：采用 **文件头部注入版本号 + 原始内容哈希校验** 的增量更新策略。如果检测到用户修改了官方 Hook，采取“备份旧文件、写入新文件”的非破坏性升级。

---

### 详细发现（含代码示例）

#### 1. settings.json 安全合并策略
Claude Code 的 `settings.json` 可能包含用户个人的偏好设置。如果在 `init` 或 `update` 时直接覆盖，会造成用户数据丢失。

*   **如果 Hooks 配置是对象 (Object 键值对) 形式**：
    使用 `jq` 的 `*` 运算符可以进行深度合并（Deep Merge）。它会递归合并对象，遇到同名基本类型时右侧覆盖左侧。
    ```bash
    # 假设需要合并的配置内容
    NEW_SETTINGS='{"customCommands": {"selfmodel-hook": "./scripts/hooks/enforce.sh"}}'
    
    if [ -f ".claude/settings.json" ]; then
      # 使用 jq 深度合并，并将结果写回
      jq -s '.[0] * .[1]' .claude/settings.json <(echo "$NEW_SETTINGS") > .claude/settings.json.tmp
      mv .claude/settings.json.tmp .claude/settings.json
    else
      echo "$NEW_SETTINGS" > .claude/settings.json
    fi
    ```

*   **如果 Hooks/Commands 配置是数组 (Array) 形式**：
    数组无法通过 `*` 完美合并（会按索引替换）。需要使用 `+` 追加，并配合 `unique_by` 按照命令名称去重。
    ```bash
    NEW_HOOK='{"name": "enforce-rules", "command": "bash ./scripts/hooks/enforce-agent-rules.sh"}'
    
    # 将新 hook 注入数组，如果原文件没有 customCommands 则默认为空数组 []
    jq --argjson new_hook "$NEW_HOOK" '
      .customCommands = ((.customCommands // []) + [$new_hook] | unique_by(.name))
    ' .claude/settings.json > tmp.json && mv tmp.json .claude/settings.json
    ```

#### 2. Hook 脚本分发方式对比
*   **方案 A (Heredoc 内嵌)**：在 `selfmodel.sh` 中直接用 `cat << 'EOF' > hook.sh` 写入。
    *   *优势*：单文件分发，即插即用；完全无网络依赖；CLI 更新时 Hook 内容自然跟随更新。
    *   *劣势*：会导致 CLI 脚本体积变大。
*   **方案 B (GitHub Raw 下载)**：使用 `curl` 下载。
    *   *优势*：CLI 脚本极度精简；Hooks 可以独立发版更新。
    *   *劣势*：强依赖网络（受限于国内 GitHub 访问网络环境）；可能存在下载失败导致 `init` 流程中断的风险。
*   **方案 C (模板化生成)**：类似方案 A，但加入 `sed` 等变量替换。
    *   *优势*：高度可定制（例如动态注入当前项目绝对路径）。
    *   *劣势*：增加了维护复杂度。

#### 3. 版本升级的增量更新逻辑
为了安全地更新脚本，需要知道：当前脚本是什么版本？用户是否修改过它？
最佳实践是在生成的 Hook 脚本头部添加类似元数据的注释：
```bash
#!/usr/bin/env bash
# SELFMODEL_HOOK_VERSION=1.0.0
# SELFMODEL_HOOK_HASH=e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
```

**更新检测逻辑：**
1. 读取现存 Hook 的 `VERSION`。如果小于当前 CLI 要写入的版本，则触发更新逻辑。
2. 提取除前 3 行（元数据行）之外的代码，计算其 SHA256 Hash。
3. 对比计算出的 Hash 与现存脚本头部记录的 `HASH`。
    *   **匹配**：说明用户未修改，直接静默覆盖为新版本。
    *   **不匹配**：说明用户魔改了代码。将其备份为 `hook.sh.bak` 或 `hook.sh.local`，然后写入官方新版本，并给出 CLI 警告提示。

---

### 推荐方案

综合“零依赖”和“安全性”的约束，推荐以下实现路径：

**1. 采用 Heredoc + 变量替换 的方式生成脚本 (方案 A + 微量 C)**
在 `selfmodel.sh` 中统一定义：
```bash
function generate_enforce_hook() {
  local target_file="scripts/hooks/enforce-agent-rules.sh"
  mkdir -p "$(dirname "$target_file")"
  
  # 写入文件，注意 EOF 外层没有引号，允许内部使用外部变量（如果需要），若不需要替换则用 'EOF'
  cat << 'EOF' > "$target_file"
#!/usr/bin/env bash
# @selfmodel-version: 1.1.0
# [这里放入具体的脚本逻辑...]
EOF
  chmod +x "$target_file"
}
```

**2. settings.json 采用 `jq` 容错注入**
使用前文提到的 `jq` 数组合并及去重策略，确保多次执行 `selfmodel init/update` 具有幂等性（Idempotence），不会导致同一条 hook 出现多次。

**3. “安全第一”的更新策略**
不引入复杂的 Hash 计算（因为不同系统的 `sha256sum` 或 `shasum` 表现不一，可能破坏零依赖特性）。推荐一种更符合 bash 哲学的极简方案：
*   每次执行 `update` 时，如果发现旧版本 hook 存在，统一将其重命名为 `.bak.<timestamp>`。
*   强制写入最新的 Heredoc 脚本。
*   终端输出日志提醒用户：“已更新 Hook，旧版本已备份至 scripts/hooks/enforce-agent-rules.sh.bak.168... 如果你有自定义修改，请手动迁移”。

---

### 置信度
**高 (95%)**。该方案完全基于 POSIX 标准 bash 及 `jq` 的内置能力，符合目前主流前端及 CLI 工具（如 Husky）管理 hooks 的最佳实践。

### 风险
1. **jq 依赖缺失**：虽然 `jq` 非常普及，但并非所有纯净版系统（特别是较老的 macOS 或精简版 Linux 容器）都默认安装。如果 `settings.json` 为空，可直接用 `echo` 写入原生 JSON 字符串来作为降级方案（Fallback）。
2. **JSON 格式破坏**：如果用户手写的 `.claude/settings.json` 存在语法错误（如多余的逗号），`jq` 命令会执行失败。脚本中需要捕获 `jq` 的非零退出码，并在失败时向用户发出明确警告，而不是清空原文件。建议在修改前先对原 json 文件做 `cp` 备份。
