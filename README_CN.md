# CodexBar 🎚️ - 愿你的 Token 永不枯竭。

[English](README.md) | 中文版 | [使用说明书](docs/USER_MANUAL.md)

CodexBar 是一款轻量级的 macOS 14+ 菜单栏应用，能够实时显示 Codex、Claude、Cursor、Gemini、Antigravity、Droid (Factory)、Copilot、z.ai、Kimi、Kimi K2、Kiro、Vertex AI、Augment、Amp 和 JetBrains AI 的使用限制（支持会话限额和周限额，视具体提供商而定），并显示各个时间窗口的重置时间。每个服务提供商都有独立的图标（也支持“合并图标”模式）；你可以通过设置面板启用你所使用的服务。该应用没有 Dock 图标，界面极简，在菜单栏中通过动态进度条图标展示状态。


## 安装

### 系统要求
- macOS 14+ (Sonoma)

### GitHub Releases
下载地址：<https://github.com/steipete/CodexBar/releases>

### Homebrew
```bash
brew install --cask steipete/tap/codexbar
```

### Linux (仅限 CLI)
```bash
brew install steipete/tap/codexbar
```
或者从 GitHub Releases 下载 `CodexBarCLI-v<tag>-linux-<arch>.tar.gz`。
Linux 支持通过 Omarchy 实现：社区提供的 Waybar 模块和 TUI，由 `codexbar` 可执行文件驱动。

### 首次运行
- 打开 **Settings (设置) → Providers (服务提供商)** 并启用你使用的服务。
- 安装并登录你依赖的服务源（例如 `codex`、`claude`、`gemini` 命令行工具、浏览器 Cookie 或 OAuth；Antigravity 需要 Antigravity 应用正在运行）。
- 可选：在 **Settings → Providers → Codex → OpenAI cookies (自动或手动)** 中添加 Cookie 以获取更多仪表盘数据。

## 支持的服务提供商

- [Codex](docs/codex.md) — 本地 Codex CLI RPC（带 PTY 备选方案）以及可选的 OpenAI 网页仪表盘额外数据。
- [Claude](docs/claude.md) — OAuth API 或浏览器 Cookie（带 CLI PTY 备选方案）；支持会话和每周使用量。
- [Cursor](docs/cursor.md) — 通过浏览器会话 Cookie 获取订阅方案、使用量及账单重置信息。
- [Gemini](docs/gemini.md) — 使用 Gemini CLI 凭据的 OAuth 配额 API（不使用浏览器 Cookie）。
- [Antigravity](docs/antigravity.md) — 本地语言服务器探测（实验性）；无需外部认证。
- [Droid](docs/factory.md) — 通过浏览器 Cookie 和 WorkOS 令牌流获取 Factory 的使用量及账单信息。
- [Copilot](docs/copilot.md) — GitHub 设备授权流及 Copilot 内部使用量 API。
- [z.ai](docs/zai.md) — 使用 API 令牌（存储于钥匙串）获取配额和 MCP 窗口信息。
- [Kimi](docs/kimi.md) — 使用认证令牌（来自 `kimi-auth` Cookie 的 JWT）获取每周配额和 5 小时频率限制。
- [Kimi K2](docs/kimi-k2.md) — 使用 API 密钥获取基于额度的使用总量。
- [Kiro](docs/kiro.md) — 通过 `kiro-cli /usage` 命令获取 CLI 使用情况；包含每月额度和奖励额度。
- [Vertex AI](docs/vertexai.md) — 通过 Google Cloud gcloud OAuth 跟踪本地 Claude 日志中的令牌成本。
- [Augment](docs/augment.md) — 基于浏览器 Cookie 的认证，支持自动会话保持、额度跟踪和使用情况监控。
- [Amp](docs/amp.md) — 基于浏览器 Cookie 的认证，跟踪 Amp Free 使用情况。
- [JetBrains AI](docs/jetbrains.md) — 从 JetBrains IDE 配置中读取本地基于 XML 的配额，跟踪每月额度。
- 欢迎添加新的服务提供商：[开发指南](docs/provider.md)。

## 图标与截图
菜单栏图标是一个微型的双条计量表：
- **上方的条**：5 小时/会话窗口。如果每周额度缺失或已耗尽但仍有额度余额，它会变成一个较粗的额度条。
- **下方的条**：每周窗口（细线）。
- 错误或数据过期会使图标变暗；状态叠加层会指示异常情况。

## 功能特性
- 多提供商菜单栏，支持单个提供商的开关切换（设置 → 提供商）。
- 会话和每周计量表，带有重置倒计时。
- 可选的 Codex 网页仪表盘增强功能（剩余代码审查次数、使用明细、额度历史）。
- 本地 Codex 和 Claude 成本使用扫描（过去 30 天）。
- 服务提供商状态轮询，在菜单和图标叠加层中显示事件徽章。
- **合并图标模式**：将所有提供商合并为一个状态项并支持快速切换。
- 刷新频率预设（手动、1分钟、2分钟、5分钟、15分钟）。
- 内置命令行工具 (`codexbar`)，适用于脚本和 CI（包括 `codexbar cost --provider codex|claude` 用于查看本地成本）；提供 Linux CLI 版本。
- 隐私优先：默认在本地进行数据解析；浏览器 Cookie 为可选启用且仅用于复用（不存储密码）。

## 隐私说明
担心 CodexBar 会扫描你的磁盘？它不会抓取你的文件系统。只有在启用相关功能时，它才会读取一小部分已知位置（如浏览器 Cookie/本地存储、本地 JSONL 日志）。参见 [issue #12](https://github.com/steipete/CodexBar/issues/12) 中的讨论和审计笔记。

## macOS 权限说明（为什么需要这些权限）
- **完全磁盘访问权限 (可选)**：仅当需要为网页端提供商（如 Codex web、Claude web、Cursor、Droid/Factory）读取 Safari Cookie 或本地存储时才需要。如果你不授予此权限，可以使用 Chrome/Firefox Cookie 或仅限 CLI 的数据源。
- **钥匙串访问 (macOS 提示)**：
  - 导入 Chrome Cookie 需要“Chrome Safe Storage”密钥来解密。
  - Claude OAuth 凭据（由 Claude CLI 写入）会在存在时从钥匙串读取。
  - z.ai API 令牌存储在设置中并保存至钥匙串；Copilot 在设备授权流期间将 API 令牌存储在钥匙串。
  - **如何防止钥匙串弹出窗口？**
    - 打开 **钥匙串访问.app** → 登录钥匙串 → 搜索相关项目（例如 “Claude Code-credentials”）。
    - 打开该项目 → **访问控制** → 在“始终允许这些应用程序访问”下添加 `CodexBar.app`。
    - 建议仅添加 CodexBar（避免选择“允许所有应用程序”以保持安全性）。
    - 保存后重启 CodexBar。
    - 参考截图：![钥匙串访问控制](docs/keychain-allow.png)
  - **如何对浏览器进行相同操作？**
    - 找到浏览器的“Safe Storage”密钥（例如 “Chrome Safe Storage”、“Brave Safe Storage”、“Firefox”、“Microsoft Edge Safe Storage”）。
    - 打开该项目 → **访问控制** → 在“始终允许这些应用程序访问”下添加 `CodexBar.app`。
    - 这样在 CodexBar 为该浏览器解密 Cookie 时就不会弹出提示。
- **文件和文件夹提示 (文件夹/卷访问)**：CodexBar 会启动服务提供商的 CLI（如 codex/claude/gemini/antigravity）。如果这些 CLI 读取项目目录或外部驱动器，macOS 可能会询问 CodexBar 是否允许访问该文件夹/卷。这是由 CLI 的工作目录驱动的，而不是后台磁盘扫描。
- **我们不请求的权限**：不需要屏幕录制、辅助功能或自动化权限；不存储密码（仅在启用时复用浏览器 Cookie）。

## 文档
- 提供商概览: [docs/providers.md](docs/providers.md)
- 提供商开发: [docs/provider.md](docs/provider.md)
- UI 与图标说明: [docs/ui.md](docs/ui.md)
- CLI 参考: [docs/cli.md](docs/cli.md)
- 架构设计: [docs/architecture.md](docs/architecture.md)
- 刷新循环: [docs/refresh-loop.md](docs/refresh-loop.md)
- 状态轮询: [docs/status.md](docs/status.md)
- Sparkle 更新: [docs/sparkle.md](docs/sparkle.md)
- 发布检查清单: [docs/RELEASING.md](docs/RELEASING.md)
- **[中文使用说明书](docs/USER_MANUAL.md)**

## 开发入门
- 克隆仓库并在 Xcode 中打开，或直接运行脚本。
- 运行一次后，在 **Settings → Providers** 中开启所需的服务。
- 安装并登录你依赖的服务源（CLI、浏览器 Cookie 或 OAuth）。
- 可选：设置 OpenAI Cookie（自动或手动）以获取 Codex 仪表盘数据。

## 从源码构建
```bash
swift build -c release          # 开发时使用 debug
./Scripts/package_app.sh        # 在本地构建 CodexBar.app
CODEXBAR_SIGNING=adhoc ./Scripts/package_app.sh  # 临时签名（无苹果开发者账号时使用）
open CodexBar.app
```

开发循环：
```bash
./Scripts/compile_and_run.sh
```

## 相关项目
- ✂️ [Trimmy](https://github.com/steipete/Trimmy) — “粘贴一次，运行一次。” 扁平化多行 Shell 片段，使其能够直接粘贴并运行。
- 🧳 [MCPorter](https://mcporter.dev) — 为模型上下文协议 (MCP) 服务器提供的 TypeScript 工具包和 CLI。
- 🧿 [oracle](https://askoracle.dev) — 遇到困难时询问 Oracle。通过自定义上下文和文件调用 GPT-5 Pro。

## 想要 Windows 版本？
- [Win-CodexBar](https://github.com/Finesssee/Win-CodexBar)

## 致谢
灵感来自 [ccusage](https://github.com/ryoppippi/ccusage) (MIT)，特别是其成本使用跟踪功能。

## 许可证
MIT • Peter Steinberger ([steipete](https://twitter.com/steipete))
