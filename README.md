# RFBrowser — AI 驱动的知识浏览器

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-3.27+-blue?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.11+-blue?logo=dart)
![License](https://img.shields.io/badge/license-MIT-green)
![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux%20%7C%20Android-lightgrey)

</div>

> **浏览、思考、连接、自动化。** 一个本地优先、AI 增强的知识工作台——将网页研究、笔记记录、知识图谱和 AI 自动化融合在一个应用中。

---

## 什么是 RFBrowser？

RFBrowser 将**浏览器**与**知识管理系统**融合在一起。你可以：

- 🌐 **浏览网页**——多标签页 WebView（基于 Chromium 引擎）
- ✍️ **撰写笔记**——纯 Markdown 编辑器，支持 `[[wiki-links]]`
- 🕸️ **可视化连接**——交互式知识图谱
- 🤖 **与 AI 对话**——在对话中引用你的笔记和网页内容
- 🎨 **自由头脑风暴**——无限画布
- ⚡ **自动化**——通过 AI Agent 和快捷指令自动执行重复任务
- 🔄 **跨设备同步**——通过 Git 或 WebDAV 同步，无供应商锁定

**可以理解为：Obsidian + ChatGPT + 网页浏览器 + 无限画布——全部在一个应用里。**

> ⚠️ **注意**：目前仅在 **Windows** 平台上进行了充分测试。Linux 和 Android 平台已支持构建，但尚未经过完整测试，可能存在未知问题。

---

## 功能特性

### 核心面板——自由组合

| 面板 | 功能 | 使用场景 |
|-------|-------------|------------------|
| 🌐 **浏览器** | 多标签页 WebView（Chromium 引擎） | 研究文章、文档、网页内容 |
| ✍️ **编辑器** | Markdown 编辑器，支持分屏预览 + `[[链接]]` | 写笔记、日记、文档 |
| 🕸️ **图谱** | 力导向 / 环形布局展示笔记链接关系 | 发现笔记之间的隐藏关联 |
| 🤖 **AI 对话** | 流式对话，支持 OpenAI 兼容 API | 摘要、翻译、头脑风暴、代码审查 |
| 🎨 **画布** | 无限空间，放置卡片和连线 | 思维导图、项目规划、可视化思考 |
| 📋 **笔记列表** | 侧边栏笔记搜索与导航 | 浏览和组织你的知识库 |
| 🔗 **反向链接** | 反向链接 / 外链面板 | 查看哪些笔记引用了当前笔记 |

### 强力工具

- 🔍 **命令栏**（`Ctrl+K`）：搜索笔记、执行命令、触发快捷指令
- ⚡ **快捷指令**：自定义斜杠命令，将上下文（页面内容、选中文字、笔记）发送给 AI
- 🧠 **AI Agent**：自建 Agent 引擎，支持 3 种任务模式（手动/AI 计划/ReAct 循环），12 个内置工具，插件可扩展
- 📎 **网页剪藏**：一键将整页、选中内容或书签保存为笔记
- 🔌 **插件系统**：通过 `BuiltinPlugin` 接口编写 Dart 插件，运行在独立沙箱中
- 🎯 **Skill 技能**：用 YAML 文件定义 AI 提示词模板，零代码扩展 AI 能力
- 📅 **日记**：一键创建每日日记

### 扩展系统

RFBrowser 提供两套扩展机制，你可以根据需要选择：

#### Plugin 插件（代码级扩展）

插件可以扩展应用的核心功能——注册命令、渲染 UI 面板、调用知识库/浏览器/AI API。每个插件运行在独立 Dart Isolate 沙箱中，崩溃自动恢复。

| 能力 | 说明 |
|------|------|
| **命令** | 注册可被命令栏（`Ctrl+K`）搜索到的命令 |
| **UI 面板** | 渲染自定义窗口面板 |
| **API 调用** | 通过沙箱调用知识库、浏览器、AI 服务 |
| **Skill 声明** | 插件可以自带 Skill，供 AI Chat 使用 |
| **Agent 工具** | 通过 AgentAPI 注册自定义 Agent 工具 |
| **权限** | 5 种权限（knowledge/read/write、browser、ai、ui），运行时检查 |

> 内置示例：[HelloWorld 插件](lib/plugins/builtin/hello_world/hello_world_plugin.dart) 展示了完整的插件生命周期。

编写插件步骤：
```dart
// 1. 继承 BuiltinPlugin
class MyPlugin extends BuiltinPlugin {
  // 2. 声明 manifest（权限、元信息）
  PluginManifest get manifest => PluginManifest(
    id: 'my-plugin', name: 'My Plugin',
    permissions: [Permission.knowledgeRead, Permission.uiPanel],
  );
  // 3. 注册命令
  List<PluginCommand> get commands => [
    PluginCommand(id: 'my.do', label: 'Do Something', pluginId: 'my-plugin'),
  ];
  // 4. 可选：声明 Skill 供 AI 使用
  List<Skill> get skills => [
    Skill(id: 'my.skill', name: 'My Skill', prompt: '...', pluginId: 'my-plugin'),
  ];
  // 5. 注册到 PluginRegistry
}
// 6. 在 PluginRegistry._builtinPlugins 中添加：MyPlugin(),
```

#### Skill 技能（零代码扩展）

Skill 是 AI 提示词模板——无需写代码，只需一个 YAML 文件即可为 AI Chat 添加新能力。创建的 Skill 会自动出现在 AI 对话面板的 Skill Picker 中。

放置位置：`<你的知识库>/.rfbrowser/skills/<skill名称>.yaml`

```yaml
# 示例：创建一个翻译 Skill
id: my-translate
name: 翻译笔记
description: 将当前笔记翻译为目标语言
prompt: |
  将以下笔记翻译成 {{target_language}}：
  @note[current]
```

| Skill 来源 | 说明 |
|------------|------|
| **内置 Skills** | 7 个开箱即用（摘要、研究、大纲、标签等） |
| **插件 Skills** | 插件自带，随插件自动加载 |
| **自定义 Skills** | 放在 `.rfbrowser/skills/` 目录下的 YAML 文件 |

### AI Agent 引擎

RFBrowser 内置了一个自建 Agent 引擎，让 AI 可以自主执行多步骤任务。

#### 三种任务模式

| 模式 | 说明 | 适用场景 |
|------|------|---------|
| **手动 (Manual)** | 用户定义每一步，Agent 按顺序执行 | 流程明确的固定任务 |
| **AI 计划 (AI Planned)** | 用户给目标，AI 自动生成计划并执行 | 目标明确但步骤不确定 |
| **ReAct 循环** | AI 自主思考→行动→观察循环，直到完成 | 需要多轮探索的复杂任务 |

#### 12 个内置工具

| 工具 | 功能 | 破坏性 |
|------|------|--------|
| `navigate` | 无头浏览器导航到 URL | ❌ |
| `extract_text` | 从网页提取文本 | ❌ |
| `create_note` | 创建笔记 | ❌ |
| `search_notes` | 搜索笔记 | ❌ |
| `ai_reason` | AI 推理/总结/问答 | ❌ |
| `web_clip` | 剪藏网页为笔记 | ❌ |
| `update_note` | 更新笔记内容 | ❌ |
| `list_notes` | 列出笔记（可按标签过滤） | ❌ |
| `get_tags` | 获取所有标签 | ❌ |
| `move_note` | 移动笔记到文件夹 | ❌ |
| `rename_note` | 重命名笔记 | ❌ |
| `delete_note` | 删除笔记 | ⚠️ 是 |

#### 使用方式

1. **浮层面板**：点击右下角 🤖 按钮，输入目标，选择模式，点击执行
2. **命令栏**：输入 `research <主题>` 触发 ReAct 研究
3. **REST API**：通过 Webhook 服务器（默认端口 18765）外部调用
4. **插件扩展**：通过 `AgentAPI.registerTool()` 注册自定义工具

---
     
### 同步与便携性

- 💾 **本地优先**：所有笔记存储为纯 `.md` 文件，存放在你掌控的文件夹中（知识库/Vault）
- 🔄 **Git 同步**：版本历史 + 推送到任意 Git 远程仓库
- ☁️ **WebDAV 同步**：自动同步（可配置间隔）到你自己的服务器
- 🌍 **无锁定**：兼容 Obsidian、Foam、VS Code——直接打开任意 Vault 文件夹
- 🌐 **国际化**：支持中文和英文界面，运行时切换

### 安全

- API 密钥存储在平台级安全存储中（不在状态对象中）
- WebView URL 协议过滤（拦截 `file://`、`javascript:`、`data://`）
- 路径遍历防护
- 破坏性操作需要二次确认

---

## 截图

<!-- 在此添加截图！建议截图内容： -->
<!-- - 浏览器 + 编辑器 + AI 对话的分屏主界面 -->
<!-- - 知识图谱视图 -->
<!-- - 无限画布 -->
<!-- - 命令栏使用演示 -->

*(截图即将添加——欢迎贡献！)*

---

## 快速开始（用户）

### 下载

| 平台 | 下载 | 测试状态 |
|----------|----------|----------|
| 🪟 **Windows** | [Latest Release](../../releases) → `rfbrowser-windows.zip` | ✅ 已测试 |
| 🐧 **Linux** | [Latest Release](../../releases) → `rfbrowser-linux.tar.gz` | ⚠️ 未充分测试 |
| 🤖 **Android** | [Latest Release](../../releases) → `rfbrowser-android.apk` | ⚠️ 未充分测试 |

### 首次启动

1. **打开或创建知识库**——选择电脑上的任意文件夹（或新建一个）。你的 Markdown 笔记将存放在这里。
2. **开始浏览**——在浏览器面板中打开网页。
3. **剪藏内容**——右键保存页面或选中内容为笔记。
4. **链接笔记**——使用 `[[笔记标题]]` 语法。链接会自动出现在知识图谱中。
5. **与 AI 对话**——在 设置 → AI 中配置 API 密钥，然后发送消息。AI 可以通过上下文引用看到你的笔记和当前网页内容。

---

## 开发

### 环境要求

- **Flutter SDK** `>= 3.27.0`（[安装指南](https://flutter.dev/docs/get-started/install)）
- **Dart** `>= 3.11.0`（Flutter 自带）
- 平台相关：
  - **Windows**：Visual Studio 2022，勾选"使用 C++ 的桌面开发"
  - **Linux**：`clang`、`cmake`、`ninja`、`pkg-config`、`libgtk-3-dev`、`libsecret-1-dev`
  - **Android**：Android Studio + Android SDK

### 克隆并运行

```bash
# 克隆仓库
git clone https://github.com/YOUR_USERNAME/rfbrowser.git
cd rfbrowser

# 安装依赖
flutter pub get

# 生成本地化文件
flutter gen-l10n

# 在对应平台上运行
flutter run -d windows    # Windows（推荐，已充分测试）
flutter run -d linux      # Linux（未充分测试）
flutter run -d android    # Android（未充分测试）
```

### 项目结构

```
rfbrowser/
├── lib/
│   ├── main.dart                    # 应用入口
│   ├── app.dart                     # MaterialApp + 主题 + Vault 初始化
│   ├── core/                        # 纯 Dart 引擎（不依赖 Flutter）
│   │   ├── context/                 #   AI 提示词上下文组装
│   │   ├── editor/                  #   Markdown 高亮、同步滚动
│   │   ├── graph/                   #   力导向布局、过滤器
│   │   ├── link/                    #   Wiki 链接提取器、解析器
│   │   └── model/                   #   AI 模型/路由配置
│   ├── data/                        # 数据层（模型、仓库、存储）
│   │   ├── models/                  #   Note, Link, AgentTask, Skill 等
│   │   ├── repositories/            #   笔记持久化（Markdown ↔ 数据库）
│   │   └── stores/                  #   索引、缓存、同步状态
│   ├── services/                    # 业务逻辑服务
│   │   ├── ai_service.dart          #   对话消息、流式传输、AI 提供商
│   │   ├── agent_service.dart       #   Agent 任务调度（3 种模式）
│   │   ├── agent/                   #   Agent 子模块
│   │   │   ├── agent_tool.dart      #     工具基类 + ToolResult
│   │   │   ├── agent_tool_registry.dart # 工具注册与执行
│   │   │   ├── builtin_tools.dart   #     12 个内置工具
│   │   │   ├── plan_generator.dart  #     LLM 计划生成 + ReAct 循环
│   │   │   └── agent_persistence.dart #  任务持久化
│   │   ├── webhook_server.dart      #   REST API 服务器
│   │   ├── browser_service.dart     #   标签页管理、WebView 状态
│   │   ├── knowledge_service.dart   #   笔记 CRUD、链接、索引
│   │   ├── git_sync_service.dart    #   Git 推送/拉取/初始化
│   │   └── webdav_sync_service.dart #   WebDAV 上传/下载
│   ├── ui/                          # 表现层
│   │   ├── layout/main_layout.dart  #   分屏面板、快捷键
│   │   ├── pages/                   #   浏览器、编辑器、图谱、画布、设置
│   │   └── widgets/                 #   命令栏、反向链接、笔记侧边栏等
│   ├── plugins/                     # 插件系统
│   ├── platform/                    # WebView 管理器（内联 + 无头）
│   └── l10n/                        # 中英文 ARB 文件
├── test/                            # 单元测试和组件测试
├── docs/                            # 架构与设计文档
├── .github/
│   ├── workflows/ci.yml             # CI/CD 流水线（分析、测试、构建）
│   └── ISSUE_TEMPLATE/              # Bug 报告和功能请求模板
└── pubspec.yaml
```

更深入的架构说明请参阅 [`docs/design/02-architecture.md`](docs/design/02-architecture.md)。

### 常用命令

```bash
# 代码生成（Riverpod providers）
dart run build_runner build

# 运行所有测试
flutter test

# 运行 Agent 百炼集成测试（需要 .env 中的 API Key）
flutter test test/agent_bailian_integration_test.dart

# 运行测试并生成覆盖率报告
flutter test --coverage

# 代码格式化
dart format lib/ test/

# 静态分析
flutter analyze
```

### 集成测试配置

Agent 集成测试需要阿里百炼 API Key。配置步骤：

1. 复制 `.env.example` 为 `.env`：
   ```bash
   cp .env.example .env
   ```

2. 编辑 `.env`，填入真实的 API Key：
   ```
   BAILIAN_API_KEY=sk-your-real-key-here
   ```

3. 运行测试：
   ```bash
   flutter test test/agent_bailian_integration_test.dart
   ```

> `.env` 文件已在 `.gitignore` 中，不会被提交到仓库。如果没有 API Key，需要网络的测试会自动跳过，不需要 Key 的测试（工具验证、持久化）仍会正常运行。

---

## 技术栈

| 层级 | 技术 | 用途 |
|-------|-----------|---------|
| **框架** | Flutter 3.x | 跨平台 UI |
| **语言** | Dart 3.x | 应用逻辑 |
| **WebView** | `flutter_inappwebview` | 嵌入式 Chromium 浏览器 |
| **Markdown** | `markdown` + `flutter_markdown` | 解析与渲染 |
| **数据库** | SQLite (`sqflite`) | 全文搜索与链接索引 |
| **缓存** | Hive | 本地键值缓存 |
| **HTTP** | Dio | 调用 AI 提供商的 REST API |
| **状态管理** | Riverpod | 响应式状态 + 代码生成 |
| **路由** | go_router | 声明式导航 |
| **同步** | Git CLI + WebDAV (Dio) | 多设备同步 |
| **安全存储** | `flutter_secure_storage` | API 密钥加密 |
| **图谱** | CustomPainter + Canvas | 力导向图渲染 |

### 支持的 AI 提供商

任何兼容 OpenAI API 的服务——包括：
- **阿里百炼**（Qwen 系列，推荐国内用户）
- OpenAI（GPT-4o、GPT-4 等）
- Anthropic（通过兼容代理使用 Claude）
- Google Gemini（通过兼容端点）
- Ollama（本地模型）
- LM Studio、LocalAI、vLLM 等

---

## 参与贡献

欢迎各种形式的贡献！参与方式：

1. **阅读** [`CONTRIBUTING.md`](CONTRIBUTING.md) 了解贡献指南
2. **找到 Issue**——寻找标记为 `good first issue` 的问题
3. **Fork 并创建分支**——从 `main` 创建功能分支
4. **编码并测试**——确保 `flutter test` 和 `flutter analyze` 通过
5. **提交 PR**——描述你的改动并关联相关 Issue

### 适合开始贡献的方向

- 🖼️ **截图**——截取应用截图并添加到 README
- 📝 **文档**——改进文档，添加代码注释
- 🧪 **测试**——提高未测试模块的覆盖率
- 🎨 **UI 打磨**——修复细微的视觉不一致
- 🐛 **Bug 修复**——查看 Issues 页面

---

## 社区

- 📖 [架构文档](docs/design/)
- 🐛 [报告 Bug](../../issues/new?template=bug_report.md)
- 💡 [请求功能](../../issues/new?template=feature_request.md)
- 💬 讨论区——即将上线！

---

## 许可证

[MIT](LICENSE) © 2024-2026 RFBrowser Contributors

---

<p align="center">
  <sub>基于 Flutter 构建。数据留在本地。知识随你成长。</sub>
</p>