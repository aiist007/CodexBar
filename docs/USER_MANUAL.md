# CodexBar 使用说明书

## 🎚️ 让你的 Token 永不断货

CodexBar 是一款轻量级的 macOS 菜单栏应用，让你随时掌握各种 AI 编程助手（Codex、Claude、Cursor、Gemini 等）的使用限额和剩余额度。

---

## 📋 目录

1. [产品简介](#产品简介)
2. [系统要求与安装](#系统要求与安装)
3. [首次使用设置](#首次使用设置)
4. [支持的 AI 提供商](#支持的-ai-提供商)
5. [菜单栏图标说明](#菜单栏图标说明)
6. [设置详解](#设置详解)
7. [CLI 命令行工具](#cli-命令行工具)
8. [常见问题](#常见问题)
9. [隐私与权限](#隐私与权限)

---

## 产品简介

CodexBar 是一款专为开发者设计的 macOS 菜单栏工具，它可以：

- 📊 **实时监控**多个 AI 提供商的 Token 使用限额
- ⏰ **显示重置时间**，让你知道何时恢复额度
- 🔔 **状态提醒**，当服务出现故障时及时通知
- 🔒 **隐私优先**，所有数据在本地处理，不存储密码
- 🖥️ **CLI 支持**，提供命令行工具供脚本调用

### 核心特性

- **多提供商支持**：Codex、Claude、Cursor、Gemini、Copilot、Kimi、Kiro 等 15+ 提供商
- **双窗口显示**：5 小时会话窗口 + 7 天周限额窗口
- **智能刷新**：支持手动、1分钟、2分钟、5分钟、15分钟自动刷新
- **合并图标模式**：将多个提供商合并为一个图标，节省菜单栏空间
- **本地成本分析**：扫描本地日志计算过去 30 天的 Token 使用成本

---

## 系统要求与安装

### 系统要求

- **macOS 14+** (Sonoma 或更高版本)
- 已安装相应 AI 工具的 CLI 或浏览器登录状态

### 安装方法

#### 方法一：Homebrew（推荐）

```bash
brew install --cask steipete/tap/codexbar
```

#### 方法二：GitHub Releases 下载

1. 访问 [GitHub Releases 页面](https://github.com/steipete/CodexBar/releases)
2. 下载最新版本的 `CodexBar.app.zip`
3. 解压并拖动到 **应用程序** 文件夹
4. 首次打开时，前往 **系统设置 → 隐私与安全性** 允许运行

#### 方法三：从源码构建

```bash
git clone https://github.com/steipete/CodexBar.git
cd CodexBar
swift build -c release
./Scripts/package_app.sh
open CodexBar.app
```

### Linux 用户

CodexBar 提供 CLI 版本支持 Linux：

```bash
# 通过 Homebrew 安装
brew install steipete/tap/codexbar

# 或下载预编译二进制文件
tar -xzf CodexBarCLI-v<版本>-linux-x86_64.tar.gz
./codexbar --version
```

---

## 首次使用设置

### 第一步：启用提供商

1. 点击菜单栏中的 CodexBar 图标
2. 选择 **设置**（或按 `Cmd + ,`）
3. 进入 **Providers** 标签页
4. 勾选你使用的 AI 提供商（如 Codex、Claude 等）

### 第二步：配置身份验证

根据你启用的提供商，需要完成相应的身份验证：

#### 对于 Codex
- 确保已安装 `codex` CLI 并登录
- 可选：在设置中配置 OpenAI Cookie 以获取更多信息

#### 对于 Claude
- 确保已安装 `claude` CLI 并登录
- 或：在浏览器中登录 claude.ai，CodexBar 会自动读取 Cookie

#### 对于其他提供商
- 参考下方 [支持的 AI 提供商](#支持的-ai-提供商) 章节获取详细配置说明

### 第三步：调整刷新频率

1. 进入 **设置 → General**
2. 选择刷新频率：
   - **Manual**：手动刷新
   - **1 minute**：每分钟刷新
   - **2 minutes**：每 2 分钟刷新（推荐）
   - **5 minutes**：每 5 分钟刷新
   - **15 minutes**：每 15 分钟刷新

---

## 支持的 AI 提供商

CodexBar 支持以下 AI 提供商，每个提供商都有不同的数据获取方式：

### OpenAI Codex

**数据获取方式**：OAuth API → CLI RPC → CLI PTY → Web Dashboard

**配置步骤**：
1. 安装 Codex CLI：`npm install -g @openai/codex`
2. 登录：`codex auth login`
3. 在 CodexBar 设置中启用 Codex 提供商

**可选增强**：
- 在 **设置 → Providers → Codex → OpenAI cookies** 中选择：
  - **Automatic**：自动从浏览器导入 Cookie
  - **Manual**：手动粘贴 Cookie Header
- 这将启用 Dashboard 额外信息：代码审查剩余次数、使用明细、积分历史

**本地成本分析**：
- 扫描 `~/.codex/sessions/**/*.jsonl` 计算过去 30 天成本

---

### Anthropic Claude

**数据获取方式**：OAuth API → Web API (Cookie) → CLI PTY

**配置步骤**：
1. 安装 Claude CLI：`npm install -g @anthropic-ai/claude-cli`
2. 登录：`claude login`
3. 在 CodexBar 设置中启用 Claude 提供商

**Cookie 配置**：
- **Automatic**：自动从 Safari/Chrome/Firefox 导入 `sessionKey` Cookie
- **Manual**：手动粘贴 `Cookie: sessionKey=sk-ant-...` Header

**多账户支持**：
- 在 `~/.codexbar/config.json` 中配置 `tokenAccounts`
- 支持同时监控多个 Claude 账户

**本地成本分析**：
- 扫描 `~/.config/claude/projects/**/*.jsonl`

---

### Google Gemini

**数据获取方式**：OAuth API（通过 Gemini CLI 凭证）

**配置步骤**：
1. 安装 Gemini CLI：`npm install -g @google/gemini-cli`
2. 登录：`gemini auth login`
3. 在 CodexBar 设置中启用 Gemini 提供商

**注意**：Gemini 不支持浏览器 Cookie 方式

---

### GitHub Copilot

**数据获取方式**：GitHub Device Flow OAuth

**配置步骤**：
1. 在 CodexBar 设置中启用 Copilot 提供商
2. 点击 **Authenticate** 开始设备授权流程
3. 按提示在浏览器中完成授权
4. 令牌将自动存储在 Keychain 中

**环境变量方式**：
```bash
export COPILOT_API_TOKEN=your_token_here
codexbar --provider copilot
```

---

### Cursor

**数据获取方式**：浏览器 Cookie

**配置步骤**：
1. 在浏览器中登录 cursor.com
2. 在 CodexBar 设置中启用 Cursor 提供商
3. Cookie Source 选择 **Automatic** 或 **Manual**

**支持的浏览器**：Safari、Chrome、Brave、Edge、Firefox

---

### Kimi (月之暗面)

**数据获取方式**：API Token（JWT）

**配置步骤**：
1. 在浏览器中登录 kimi.com
2. 从开发者工具中获取 `kimi-auth` Cookie
3. 在 CodexBar 设置中粘贴 Token
4. 或设置环境变量：`KIMI_AUTH_TOKEN=your_token`

**显示信息**：
- 周限额使用情况
- 5 小时速率限制（300 分钟）

---

### Kimi K2

**数据获取方式**：API Key

**配置步骤**：
1. 在 CodexBar 设置中输入 API Key
2. 或设置环境变量：`KIMI_K2_API_KEY=your_key`

**显示信息**：
- 基于积分的使用总额（已消耗/剩余）

---

### Kiro (AWS)

**数据获取方式**：CLI 命令

**配置步骤**：
1. 安装 Kiro CLI 并通过 AWS Builder ID 登录
2. 在 CodexBar 设置中启用 Kiro 提供商
3. 确保 `kiro-cli` 在 PATH 中

**显示信息**：
- 月度积分百分比
- 奖励积分

---

### z.ai

**数据获取方式**：API Token

**配置步骤**：
1. 在 CodexBar 设置中输入 API Token
2. 令牌将存储在 Keychain 中
3. 或设置环境变量：`Z_AI_API_KEY=your_key`

**区域选择**：
- 全球：`api.z.ai`
- 中国：`open.bigmodel.cn`

---

### MiniMax

**数据获取方式**：Cookie Header

**配置步骤**：
1. 登录 platform.minimax.io
2. 从浏览器开发者工具复制 Cookie Header
3. 在 CodexBar 设置中粘贴
4. 或设置环境变量：`MINIMAX_COOKIE=your_cookie`

---

### 其他提供商

| 提供商 | 数据获取方式 | 配置说明 |
|--------|-------------|----------|
| **Antigravity** | 本地 LSP 探测 | 需要 Antigravity 应用运行 |
| **Droid/Factory** | Web Cookie + WorkOS | 浏览器登录 factory.ai |
| **Vertex AI** | gcloud OAuth | 运行 `gcloud auth application-default login` |
| **Augment** | Web Cookie | 浏览器登录 augment.ai |
| **Amp** | Web Cookie | 浏览器登录 ampcode.com |
| **JetBrains AI** | 本地 XML 文件 | 自动检测 JetBrains IDE 配置 |
| **OpenCode** | Web Cookie | 浏览器登录 opencode.ai |

---

## 菜单栏图标说明

CodexBar 的菜单栏图标是一个小巧的双栏指示器：

```
┌─────────────┐
│ ████████░░░ │  ← 上栏：5 小时会话窗口
│ ░░░░░░░░░░░ │  ← 下栏：7 天周限额窗口
└─────────────┘
```

### 图标含义

- **上栏（粗条）**：5 小时会话窗口剩余百分比
  - 如果周限额已用完但有积分，会显示为积分条
- **下栏（细线）**：7 天周限额剩余百分比
- **填充程度**：表示剩余百分比（可在设置中切换为"已使用百分比"）
- **变暗/灰色**：数据获取失败或过期
- **状态叠加**：服务故障时显示警告标志

### 点击菜单显示

点击图标展开菜单，显示每个已启用提供商的详细信息：

```
┌─────────────────────────────────────┐
│ 🔵 Codex                    0.6.0   │
│ ├─ Session: 72% left                │
│ │  Resets today at 2:15 PM          │
│ ├─ Weekly: 41% left                 │
│ │  Resets Fri at 9:00 AM            │
│ ├─ Credits: 112.4 left              │
│ └─ Pace: 6% in reserve              │
├─────────────────────────────────────┤
│ 🟣 Claude                  2.0.58   │
│ ├─ Session: 88% left                │
│ ├─ Weekly: 63% left                 │
│ └─ Sonnet: 95% left                 │
├─────────────────────────────────────┤
│ ⚙️  Settings...                     │
│ 🔄 Refresh Now                      │
│ ❌ Quit                             │
└─────────────────────────────────────┘
```

### 合并图标模式

在 **设置 → Advanced → Merge Icons** 中启用后，多个提供商将合并为一个图标：

```
┌─────────────────────────────────────┐
│ 🔵 Codex                    0.6.0   │
│ ...                                 │
├─────────────────────────────────────┤
│ 🟣 Claude                  2.0.58   │
│ ...                                 │
├─────────────────────────────────────┤
│ 🔽 Switch Provider                  │
│ ⚙️  Settings...                     │
└─────────────────────────────────────┘
```

---

## 设置详解

### General（常规设置）

| 选项 | 说明 |
|------|------|
| **Refresh Cadence** | 数据刷新频率：Manual / 1m / 2m / 5m / 15m |
| **Launch at Login** | 开机自动启动 |
| **Show Icon** | 在菜单栏显示图标 |
| **Show Usage as Used** | 图标显示"已使用百分比"而非"剩余百分比" |

### Providers（提供商设置）

每个提供商都有独立的设置面板：

| 选项 | 说明 |
|------|------|
| **Enabled** | 启用/禁用该提供商 |
| **Usage Source** | 数据来源：Auto / OAuth / Web / CLI / API |
| **Cookie Source** | Cookie 获取方式：Automatic / Manual / Off |
| **Cookie Header** | 手动粘贴 Cookie（当 Cookie Source 为 Manual 时） |
| **API Key** | 直接输入 API Key（部分提供商支持） |

### Advanced（高级设置）

| 选项 | 说明 |
|------|------|
| **Merge Icons** | 合并所有提供商为一个图标 |
| **Disable Keychain Access** | 禁用 Keychain 访问（需手动配置所有 Cookie） |
| **Install CLI** | 安装命令行工具到 `/usr/local/bin/codexbar` |
| **Reset Time Display** | 重置时间显示格式：Countdown / Absolute Clock |
| **Display** | 多账户显示方式：Switcher / Stacked |
| **Debug Menu** | 启用调试菜单（查看详细日志） |

---

## CLI 命令行工具

CodexBar 包含一个功能强大的 CLI 工具，适合脚本和自动化使用。

### 安装 CLI

```bash
# 通过应用安装
# 设置 → Advanced → Install CLI

# 或手动链接
ln -sf "/Applications/CodexBar.app/Contents/Helpers/CodexBarCLI" /usr/local/bin/codexbar
```

### 基本用法

```bash
# 显示所有启用的提供商（文本格式）
codexbar

# 显示特定提供商
codexbar --provider codex
codexbar --provider claude
codexbar --provider all

# JSON 输出
codexbar --format json --pretty

# 包含状态信息
codexbar --status
```

### 成本分析命令

```bash
# 显示本地成本分析（过去 30 天）
codexbar cost

# 特定提供商
codexbar cost --provider claude

# JSON 格式
codexbar cost --format json --pretty
```

### 配置验证

```bash
# 验证配置文件
codexbar config validate

# 查看配置
codexbar config dump --pretty
```

### 多账户支持

```bash
# 选择特定账户
codexbar --provider claude --account user@example.com

# 选择账户索引（1-based）
codexbar --provider claude --account-index 1

# 获取所有账户
codexbar --provider claude --all-accounts --format json
```

### 数据来源控制

```bash
# 强制使用 Web
codexbar --provider codex --source web

# 强制使用 CLI
codexbar --provider codex --source cli

# Claude OAuth 模式
codexbar --provider claude --source oauth

# API 模式（支持 API Key 的提供商）
codexbar --provider gemini --source api
```

### 环境变量

```bash
# API Token
export COPILOT_API_TOKEN=your_token
export Z_AI_API_KEY=your_key
export KIMI_AUTH_TOKEN=your_token
export KIMI_K2_API_KEY=your_key
export MINIMAX_COOKIE=your_cookie

# 使用环境变量运行
codexbar --provider copilot --format json
```

### 退出代码

| 代码 | 含义 |
|------|------|
| 0 | 成功 |
| 1 | 未知错误 |
| 2 | 提供商缺失（CLI 未安装） |
| 3 | 解析/格式化错误 |
| 4 | CLI 超时 |

---

## 常见问题

### Q: 为什么菜单栏图标显示为灰色？

**A**: 图标变灰表示数据获取失败或数据过期。可能原因：
- 未登录相应的 AI 工具
- Cookie 已过期
- 网络连接问题
- 点击图标查看具体错误信息

### Q: 如何修复 Keychain 反复提示访问？

**A**: 
1. 打开 **Keychain Access.app**
2. 找到相关项目（如 "Claude Code-credentials" 或 "Chrome Safe Storage"）
3. 双击打开 → **Access Control** 标签
4. 添加 `CodexBar.app` 到 "Always allow access by these applications"
5. 重启 CodexBar

### Q: Safari Cookie 无法读取？

**A**: 
- 前往 **系统设置 → 隐私与安全性 → 完全磁盘访问权限**
- 添加 CodexBar.app
- 重启 CodexBar

### Q: 如何添加多个账户？

**A**: 编辑 `~/.codexbar/config.json`：

```json
{
  "version": 1,
  "providers": [
    {
      "id": "claude",
      "enabled": true,
      "cookieSource": "manual",
      "tokenAccounts": {
        "version": 1,
        "activeIndex": 0,
        "accounts": [
          {
            "id": "account-1",
            "label": "user1@example.com",
            "token": "sessionKey=sk-ant-...",
            "addedAt": 1735123456
          },
          {
            "id": "account-2",
            "label": "user2@example.com",
            "token": "sessionKey=sk-ant-...",
            "addedAt": 1735123456
          }
        ]
      }
    }
  ]
}
```

### Q: 为什么 CodexBar 请求文件夹访问权限？

**A**: CodexBar 需要启动提供商 CLI（如 `codex`、`claude`）。如果这些 CLI 读取项目目录或外部驱动器，macOS 会要求 CodexBar 获得该文件夹/卷的访问权限。这不是后台磁盘扫描，而是由 CLI 的工作目录驱动的。

### Q: 如何完全禁用浏览器 Cookie 导入？

**A**: 
1. 前往 **设置 → Advanced**
2. 勾选 **Disable Keychain Access**
3. 在 **Providers** 中为每个提供商选择 **Cookie Source: Manual** 并手动粘贴 Cookie

### Q: Linux 支持哪些功能？

**A**: Linux 版本仅支持 CLI，不支持浏览器 Cookie 自动导入。数据来源限制为：
- CLI 模式（`--source cli`）
- API 模式（`--source api`，需要 API Key）

### Q: 如何查看详细日志？

**A**: 
```bash
# CLI 详细日志
codexbar --log-level debug

# 应用调试菜单
# 设置 → Advanced → 启用 Debug Menu
```

---

## 隐私与权限

### 数据处理方式

CodexBar 采用**隐私优先**设计：

- ✅ **本地处理**：所有数据在设备上解析，不发送到第三方服务器
- ✅ **不存储密码**：仅复用浏览器 Cookie，不存储密码
- ✅ **可选功能**：浏览器 Cookie 导入是可选的，可完全禁用
- ✅ **透明开源**：代码完全开源，可审计

### 需要的权限

#### 完全磁盘访问（可选）

**用途**：读取 Safari Cookie/本地存储（仅在使用 Safari 时需要）

**替代方案**：使用 Chrome/Firefox Cookie 或 CLI 模式

#### Keychain 访问

**用途**：
- 解密 Chrome Cookie（需要 "Chrome Safe Storage" 密钥）
- 读取 Claude OAuth 凭证
- 存储 z.ai、Copilot 等 API Token
- 缓存 Cookie 避免重复导入

**如何管理**：
- 在 Keychain Access.app 中控制访问权限
- 可随时撤销权限

#### 文件与文件夹访问

**用途**：
- 启动提供商 CLI 时，CLI 可能需要访问工作目录
- 读取本地日志文件进行成本分析

**不请求以下权限**：
- ❌ 屏幕录制
- ❌ 辅助功能
- ❌ 自动化权限

### 文件访问范围

CodexBar 不会扫描整个文件系统，仅读取以下已知位置：

- 浏览器 Cookie 文件（当启用时）
- AI 工具本地日志（`~/.codex/sessions/`、`~/.config/claude/projects/`）
- 配置文件（`~/.codexbar/config.json`）

详细讨论请参阅 [Issue #12](https://github.com/steipete/CodexBar/issues/12)。

---

## 获取帮助

- 📖 **文档**：[GitHub Docs](https://github.com/steipete/CodexBar/tree/main/docs)
- 🐛 **问题反馈**：[GitHub Issues](https://github.com/steipete/CodexBar/issues)
- 🐦 **Twitter**：[@steipete](https://twitter.com/steipete)

---

## 许可证

MIT License © Peter Steinberger

---

**祝你使用愉快，Token 永不断货！** 🎉
