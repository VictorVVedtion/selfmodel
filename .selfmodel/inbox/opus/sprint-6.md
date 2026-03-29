# Sprint 6 任务: selfmodel update --remote

你是 Opus Agent，负责 Sprint 6。

## 必须先读取的文件
1. `/Users/vvedition/Desktop/selfmodel/.selfmodel/contracts/active/sprint-6.md` — 合约
2. `/Users/vvedition/Desktop/selfmodel/.selfmodel/inbox/research/sprint-6-report.md` — 调研报告
3. `/Users/vvedition/Desktop/selfmodel/scripts/selfmodel.sh` — 需要修改的文件

## 具体实现

### 1. 修改 cmd_update 解析 --remote 参数

```bash
cmd_update() {
    local dir="${1:-.}"
    local remote=false
    local version="main"
    
    # Parse flags
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --remote) remote=true; shift ;;
            --version) version="$2"; shift 2 ;;
            *) dir="$1"; shift ;;
        esac
    done
    
    if [[ "$remote" == "true" ]]; then
        remote_update "$dir" "$version"
    else
        # 现有逻辑不变...
    fi
}
```

### 2. 新增 remote_update 函数

```bash
remote_update() {
    local dir="${1:-.}"
    local version="${2:-main}"
    local repo="VictorVVedtion/selfmodel"
    local tarball_url="https://github.com/$repo/archive/refs/heads/$version.tar.gz"
    local tmp_dir
    tmp_dir=$(mktemp -d)
    local ts=$(date +%s)
    
    info "Fetching selfmodel $version from GitHub..."
    
    # 1. 下载 tarball 到临时目录
    if ! curl -f -sS -L --connect-timeout 10 --max-time 60 \
         "$tarball_url" | tar -xz -C "$tmp_dir" 2>/dev/null; then
        err "Failed to download from GitHub. Local files unchanged."
        rm -rf "$tmp_dir"
        return 1
    fi
    
    # 2. 找到解压后的根目录 (selfmodel-main/ 或 selfmodel-v1.0.0/)
    local extracted
    extracted=$(ls -d "$tmp_dir"/selfmodel-* 2>/dev/null | head -1)
    
    # 3. 同步 playbook/ (备份 → 覆盖)
    for f in "$extracted/.selfmodel/playbook/"*.md; do
        local name=$(basename "$f")
        local target="$dir/.selfmodel/playbook/$name"
        if [[ -f "$target" ]]; then
            cp "$target" "${target}.bak.${ts}"
            info "Backed up: playbook/$name"
        fi
        cp "$f" "$target"
        ok "Updated: playbook/$name"
    done
    
    # 4. 同步 hooks (备份 → 覆盖 → chmod)
    for f in "$extracted/scripts/hooks/"*.sh; do
        local name=$(basename "$f")
        local target="$dir/scripts/hooks/$name"
        if [[ -f "$target" ]]; then
            cp "$target" "${target}.bak.${ts}"
        fi
        cp "$f" "$target"
        chmod +x "$target"
        ok "Updated: hooks/$name"
    done
    
    # 5. 合并 settings.json (同 generate_hooks 逻辑)
    
    # 6. 更新 VERSION
    if [[ -f "$extracted/VERSION" ]]; then
        cp "$extracted/VERSION" "$dir/VERSION"
        ok "VERSION updated to $(cat "$dir/VERSION")"
    fi
    
    # 7. 清理
    rm -rf "$tmp_dir"
    ok "Remote update complete! ($version)"
}
```

### 3. 更新 help 文本

```
Commands:
  update   Update playbook files to latest version
           --remote    Fetch latest from GitHub (instead of local templates)
           --version   Specify version/tag (default: main)
```

### 重要约束
- 只修改/新增函数，不改动已有函数的内部逻辑
- 不同步 state/、contracts/、inbox/（项目特有数据）
- CLAUDE.md 不自动同步（结构差异太大，需手动）
- 失败时 local files 必须完好
- 在 worktree 内工作，所有文件操作使用相对于 worktree 的路径

## 完成后
创建 DONE.md。
