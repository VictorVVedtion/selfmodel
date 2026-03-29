关于使用 Bash 脚本从 GitHub 仓库特定目录拉取文件并安全覆盖本地的调研报告如下：

### 核心结论
1. **单文件下载**：使用 `curl` 请求 GitHub Raw URL 是最轻便、零依赖的选择。
2. **批量下载（目录/模式匹配）**：在不引入第三方依赖（如 `jq` 处理 JSON）且不克隆全库的情况下，**最佳方案是拉取仓库的 Tarball（源码压缩包），然后利用 `tar` 命令在内存中按目录或文件后缀按需解压**。这种方式仅产生一次网络请求，速度极快。
3. **安全性**：永远先将文件下载到临时目录（或使用临时后缀），验证返回码成功后再进行原子替换（`mv`），以防止网络中断损坏本地已有文件。

---

### 1. 单个文件的最佳实践 (curl / wget)

使用 `curl` 结合 GitHub Raw URL 是业界标准做法：

```bash
# 目标 URL 格式: https://raw.githubusercontent.com/<USER>/<REPO>/<BRANCH_OR_TAG>/<PATH>

curl -f -sS -L -o "local_file.md" "https://raw.githubusercontent.com/user/repo/v1.0.0/playbook/file.md"
```

**关键参数解析：**
* `-f` (`--fail`): **至关重要**。如果 HTTP 请求失败（如 404 Not Found 或 403 Forbidden），`curl` 不会输出报错页面的 HTML 内容到文件中，而是直接返回非 0 的退出码，便于脚本捕获错误。
* `-sS` (`--silent --show-error`): 隐藏下载进度条，但在发生错误时依然打印错误信息。
* `-L` (`--location`): 跟随 HTTP 重定向（GitHub 可能会产生重定向）。
* `-o`: 指定输出文件路径。

**访问私有仓库 (Private Repo)：**
通过 Personal Access Token (PAT) 在 Header 中传入：
```bash
curl -H "Authorization: token YOUR_GITHUB_TOKEN" \
     -f -sS -L -o "local_file.md" \
     "https://raw.githubusercontent.com/user/repo/main/playbook/file.md"
```

---

### 2. 批量下载目录下的所有 `.md` 文件

由于要求 **Zero-Dependency**（不能使用 `jq` 解析 GitHub API 的 JSON），且不使用 `git clone`，我们有三种思路，**首推 Tarball 方案**。

#### 对比与推荐
| 方案 | 优点 | 缺点 | 适用场景 |
| --- | --- | --- | --- |
| **GitHub API** | 精确到单个文件 | 需要解析 JSON 获取文件列表，纯 bash 解析脆弱（不用 `jq` 的情况下极易出错）。 | 确切知道文件名列表，或允许安装 `jq`。 |
| **Raw URL 循环** | 简单直接 | 需要预先硬编码文件名列表，或者产生大量 404 试探请求。 | 目录内文件固定不变且数量极少。 |
| **Tarball + tar 解压 (推荐)** | **一次网络请求**，原生自带，支持按路径和通配符提取。 | 会消耗对应仓库完整压缩包的流量（相对于克隆仍小得多）。 | 批量下载整个目录或特定后缀文件。 |

#### 具体实现：Tarball 方案 (零依赖批量拉取)
通过下载仓库的 tar.gz 压缩包，并通过管道直接给 `tar`，只解压出 `playbook/` 目录的内容。

```bash
REPO="user/repo"
VERSION="main" # 可以是 tag 或 branch
TARGET_DIR="playbook"

# 下载压缩包并提取目标目录的内容
# --strip-components=1 会去掉解压出来的顶层目录 (repo-main/)
curl -H "Authorization: token $GITHUB_TOKEN" \
     -f -sS -L "https://github.com/$REPO/archive/refs/heads/$VERSION.tar.gz" | \
     tar -xz --include="*/$TARGET_DIR/*.md" --strip-components=2 -C ./local_target_dir/
```
*(注：macOS 的 `bsdtar` 支持 `--include` 模式匹配，如果是 GNU `tar` 可能需要使用 `--wildcards`。为兼容性，可以直接解压整个 `playbook/` 目录再在本地进行 `.md` 过滤。)*

---

### 3. 下载失败时的降级策略与安全覆盖

为了避免网络中断、仓库临时不可达导致本地文件被破坏，应当实施 **“临时目录下载 -> 校验 -> 原子替换”** 的策略，并加入重试机制。

```bash
MAX_RETRIES=3
RETRY_DELAY=5
URL="https://raw.githubusercontent.com/user/repo/main/playbook/rules.md"
TARGET_FILE="./playbook/rules.md"
TMP_FILE="${TARGET_FILE}.tmp"

download_with_retry() {
    local attempt=1
    while [ $attempt -le $MAX_RETRIES ]; do
        echo "Attempt $attempt to download..."
        # 加上超时机制: --connect-timeout 10 (连接超时), --max-time 30 (总下载超时)
        if curl -f -sS -L --connect-timeout 10 --max-time 30 -o "$TMP_FILE" "$URL"; then
            # 成功后进行原子替换
            mv "$TMP_FILE" "$TARGET_FILE"
            echo "Download successful and overwritten safely."
            return 0
        else
            echo "Download failed. Retrying in $RETRY_DELAY seconds..."
            rm -f "$TMP_FILE" # 清理残余临时文件
            sleep $RETRY_DELAY
            attempt=$((attempt + 1))
        fi
    done
    
    echo "Error: Failed to download after $MAX_RETRIES attempts."
    # 降级策略：保留本地旧文件，记录日志并报警，或使用预置的 fallback 静态文件
    return 1
}

download_with_retry
```

---

### 4. 版本控制策略

为了保证脚本的稳定性和不可变性（Idempotency），不建议使用可变的 `main` 或 `master` 分支，而是锁定到具体的 **Tag** 或 **Commit SHA**。

**最佳实践：**
```bash
# ❌ 不稳定：文件随时可能被上游更新破坏本地兼容性
URL="https://raw.githubusercontent.com/user/repo/main/playbook/rules.md"

# ✅ 推荐：使用指定的 Tag 版本 (如 v1.2.0)
URL="https://raw.githubusercontent.com/user/repo/v1.2.0/playbook/rules.md"

# ✅ 最严谨：使用具体的 Commit SHA (绝对不可变)
URL="https://raw.githubusercontent.com/user/repo/a1b2c3d4e5f6g7h8i9j0/playbook/rules.md"
```
**实现方式**：可以在你的 Bash 脚本顶部定义一个变量 `REPO_VERSION="v2.0.1"`，在需要更新依赖库或 playbook 时，手动修改该版本号，或通过传入环境变量来控制。
