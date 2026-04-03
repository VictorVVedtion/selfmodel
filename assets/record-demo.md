# 自我演进系统 (selfmodel) 终端演示录播指南

为了在 GitHub `README.md` 或社交媒体上展示 `selfmodel` 的强大能力，我们需要一个高质量的终端录屏。对于基于终端的代码工具，静态图片缺乏说服力，而高清、文本可选的终端录屏（SVG或视频）能立刻激起极客的好奇心。

我们推荐使用 [Terminalizer](https://github.com/faressoft/terminalizer) 或 [vhs (Charmbracelet)](https://github.com/charmbracelet/vhs) 生成演示动画。

---

## 推荐场景 1：`/selfmodel:loop` 自动化编排

展示 Leader 接收计划、自动切分工作树、并行派遣多个 Agent，最终合并的整个主轴。

### VHS 脚本示例 (`demo-loop.tape`)

```tape
# 设置录制参数
Output assets/demo-loop.gif
Output assets/demo-loop.mp4

# 配置终端外观
Set FontSize 18
Set FontFamily "JetBrains Mono"
Set Width 1200
Set Height 800
Set Theme "TokyoNight"
Set WindowBar Rings

Type "claude"
Enter
Sleep 2s

Type "Hello! We need to implement the new Dashboard component."
Enter
Sleep 1s

# 模拟开始跑循环
Type "/selfmodel:loop"
Enter
Sleep 3s

# 让录屏停留在各种 Agent 被调用的日志输出流上
Sleep 5s
```

## 推荐场景 2：`/rampage` 混沌渗透测试

展示 7 种 Persona 并发攻击目标时的暴力美学，展现本工具不仅仅是写代码，还能守住韧性底线。

### VHS 脚本示例 (`demo-rampage.tape`)

```tape
Output assets/demo-rampage.gif

Set FontSize 16
Set FontFamily "JetBrains Mono"
Set Width 1200
Set Height 600
Set Theme "Dracula"
Set WindowBar Rings

Type "claude"
Enter
Sleep 2s

Type "/rampage https://localhost:3000 --intensity berserk"
Enter

# 等待长一点时间让屏幕打印充满威胁警告的红黄相间的信息
Sleep 8s
```

---

## 如何录制与渲染

1. 下载 `vhs` 工具：
   ```bash
   brew install vhs
   ```
2. 保存上述内容为 `.tape` 文件，比如 `demo-loop.tape`。
3. 把你的终端调整到一个尽量干净的测试仓库路径（包含初始化好的 `.selfmodel` 和伪造的 `plan.md`）。
4. 在同目录下运行：
   ```bash
   vhs < demo-loop.tape
   ```
5. 稍等片刻，你的 `assets/` 目录下就会获得极高画质的 `.gif` 和 `.mp4` 动图了。
6. 在 `README.md` 中引入：
   ```markdown
   ![Selfmodel in Action](assets/demo-loop.gif)
   ```
