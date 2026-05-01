# RFBrowser — AI 增强知识浏览器 架构设计

> **RFBrowser**: 融合浏览（Browse）与知识流（Flow），让信息在获取与组织之间自由流动

---

## 一、产品愿景

### 核心命题

> 人在信息时代如何高效地**获取、组织、关联和自动化处理**知识？

### 三源融合

| 来源 | 解决的问题 | 我们吸收的核心 |
|------|-----------|---------------|
| **Tabbit** | 获取 + 自动化 | AI Agent、上下文引用、Skills、智能标签分组 |
| **Foam** | 组织 + 开放性 | 纯 Markdown、Git 集成、零锁定、开发者友好 |
| **Obsidian** | 关联 + 扩展性 | 双向链接、图谱视图、Canvas、插件生态、Dataview |

### 终极形态

**一个本地优先的 AI 增强知识工作台**——既能像浏览器一样获取信息，又能像 Obsidian 一样组织和关联知识，还能像 Tabbit 一样用 AI 自动化工作流，同时保持 Foam 的开放标准。

### 核心差异化（别人做不到的）

1. **上下文桥（Context Bridge）** — 浏览器与知识库之间的无缝上下文共享。你可以在笔记中 @引用 一个网页，也可以在浏览时 @引用 一条笔记
2. **知识感知 Agent** — Agent 不只是浏览网页，它还能创建笔记、建立链接、自动组织信息
3. **实时图谱** — 图谱在你浏览和保存信息时实时更新
4. **Skill + Plugin 融合** — Skill 可以调用 Plugin，Plugin 可以定义新 Skill
5. **双栏工作流** — 浏览器和编辑器并排，支持拖拽互操作

---

## 二、关键决策记录

| 决策项 | 选择 | 理由 |
|--------|------|------|
| 产品定位 | 双核融合 | 浏览器与知识管理完全融合，不分主次 |
| 技术框架 | Flutter | 三平台（Win/Android/Linux）成熟度最高 |
| AI 策略 | 云端为主 + 本地可选 | 功能优先，Ollama/llama.cpp 作为离线备选 |
| 数据格式 | 纯 Markdown + YAML frontmatter | 零锁定，兼容 Obsidian/Foam 生态 |
| 浏览器引擎 | 内嵌 Chromium（桌面）+ System WebView（Android） | 见下方详细说明 |
| 扩展系统 | 开放插件 + Skills + 模板 | 三者兼备，最大化生态和灵活性 |
| 同步策略 | Git + WebDAV | 去中心化，无服务器成本 |
| UI 语言 | 可切换中英双语 | — |

### 浏览器引擎方案说明

| 平台 | 引擎 | 说明 |
|------|------|------|
| Windows | WebView2 (Chromium) | 系统自带，Chromium 内核 |
| Android | System WebView (Chromium) | 大多数设备基于 Chromium |
| Linux | WebKitGTK / WPE WebKit | 非 Chromium，但功能完整；可选 CEF 后端 |

**技术选型**：使用 `flutter_inappwebview` 作为统一浏览器组件层：
- 支持 Inline WebView、Headless WebView、InApp Browser 三种模式
- Headless 模式用于 Agent 自动化（后台执行网页操作）
- Linux 端使用 WPE WebKit 后端（支持 GPU 纹理直传，性能优于 WebKitGTK）

**Agent 模式**：HeadlessInAppWebView 支持 Android/Windows，Linux 端通过 WPE WebKit 的 headless 模式实现。

---

## 三、系统架构

### 整体分层

```
┌─────────────────────────────────────────────────────────────┐
│                    Presentation Layer                        │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐      │
│  │ Browser  │ │ Editor   │ │  Graph   │ │ Canvas   │      │
│  │  View    │ │  View    │ │  View    │ │  View    │      │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘      │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐      │
│  │ AI Chat  │ │ Agent    │ │ Settings │ │ Plugin   │      │
│  │  Panel   │ │ Monitor  │ │  View    │ │  Store   │      │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘      │
├─────────────────────────────────────────────────────────────┤
│                    Service Layer                             │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐      │
│  │ Browser  │ │Knowledge │ │   AI     │ │  Agent   │      │
│  │ Service  │ │ Service  │ │ Service  │ │ Service  │      │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘      │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐      │
│  │  Sync    │ │ Plugin   │ │  Index   │ │  Skill   │      │
│  │ Service  │ │ Service  │ │ Service  │ │ Service  │      │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘      │
├─────────────────────────────────────────────────────────────┤
│                    Core Engine Layer                         │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐      │
│  │ Markdown │ │  Link    │ │  Graph   │ │ Context  │      │
│  │ Engine   │ │ Resolver │ │ Engine   │ │ Assembler│      │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘      │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐                    │
│  │ Search   │ │ Template │ │  Model   │                    │
│  │ Engine   │ │ Engine   │ │ Router   │                    │
│  └──────────┘ └──────────┘ └──────────┘                    │
├─────────────────────────────────────────────────────────────┤
│                    Data Layer                                │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐      │
│  │  File    │ │  Index   │ │  Cache   │ │  Sync    │      │
│  │  Store   │ │  Store   │ │  Store   │ │  Store   │      │
│  │(Markdown)│ │ (SQLite) │ │(Hive/Isar)│ │ (State)  │      │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘      │
├─────────────────────────────────────────────────────────────┤
│                    Platform Layer                            │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐      │
│  │ WebView  │ │Platform  │ │  System  │ │ Deep     │      │
│  │ (InApp)  │ │ Channels │ │  APIs    │ │  Links   │      │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘      │
└─────────────────────────────────────────────────────────────┘
```

### 模块依赖关系

```
Presentation ──→ Service ──→ Core Engine ──→ Data ──→ Platform
     │              │              │            │          │
     └──────────────┴──────────────┴────────────┴──────────┘
                          Event Bus (跨层通信)
```

---

## 四、核心数据模型

### 4.1 文件结构（Vault）

```
vault/
├── .reflow/                    # 应用配置（类似 .obsidian）
│   ├── config.yaml             # 全局配置
│   ├── plugins/                # 已安装插件
│   ├── skills/                 # 用户定义的 Skills
│   ├── templates/              # 笔记模板
│   ├── themes/                 # 自定义主题
│   ├── cache/                  # 索引缓存（SQLite）
│   │   └── index.db            # 搜索索引 + 图谱数据
│   └── sync/                   # 同步状态
│       ├── git-state.yaml
│       └── webdav-state.yaml
├── daily-notes/                # 日记
│   └── 2026-05-01.md
├── clippings/                  # 网页剪藏
│   └── article-title-20260501.md
├── attachments/                # 附件（图片、PDF等）
│   └── image-20260501.png
└── (用户自定义目录结构)
    └── ...
```

### 4.2 Markdown 文件格式

```markdown
---
title: 量子计算入门
created: 2026-05-01T10:30:00Z
modified: 2026-05-01T11:00:00Z
tags: [量子计算, 物理, 前沿技术]
aliases: [Quantum Computing 101]
source: https://example.com/quantum-computing
source-title: 量子计算完全指南
source-captured: 2026-05-01T10:25:00Z
agent-task: research-quantum
---

# 量子计算入门

## 核心概念

量子计算利用[[量子叠加]]和[[量子纠缠]]进行计算...

## 相关资源

- 来自网页的摘录：@web[quantum-guide#section-2]
- 相关笔记：[[量子算法概述]]
```

### 4.3 核心实体模型

```dart
class Note {
  String id;                    // UUID
  String title;
  String filePath;              // 相对于 vault 的路径
  String content;               // Markdown 原文
  FrontMatter frontMatter;      // YAML 元数据
  List<String> tags;
  List<String> aliases;
  DateTime created;
  DateTime modified;
  String? sourceUrl;            // 来源网页 URL（剪藏）
  String? sourceTitle;          // 来源网页标题
  String? agentTaskId;          // 创建此笔记的 Agent 任务
}

class WebClip {
  String id;
  String url;
  String title;
  String content;               // 提取的正文（Markdown）
  String rawHtml;               // 原始 HTML（可选保存）
  List<String> selectedText;    // 用户划选的文本
  String? screenshot;           // 截图路径
  DateTime captured;
  String noteId;                // 关联的笔记 ID
}

class Link {
  String sourceId;              // 源笔记/网页 ID
  String targetId;              // 目标笔记/网页 ID
  LinkType type;                // wikilink | reference | embed | web-link
  String? context;              // 链接出现的上下文文本
  int? position;                // 链接在文档中的位置
}

class AgentTask {
  String id;
  String name;
  String description;
  TaskStatus status;            // pending | running | paused | completed | failed
  List<AgentStep> steps;        // 执行步骤
  Map<String, dynamic> context; // 任务上下文
  DateTime created;
  DateTime? completed;
  String? result;               // 任务结果
}

class Skill {
  String id;
  String name;
  String description;
  String prompt;                // Skill 的提示词模板
  Map<String, SkillParam> params; // 可配置参数
  String? pluginId;             // 来源插件（如果有）
  bool isBuiltin;               // 是否内置
}

class Plugin {
  String id;
  String name;
  String version;
  String author;
  String description;
  PluginManifest manifest;      // 插件清单
  bool isEnabled;
  List<Skill> providedSkills;   // 插件提供的 Skills
}
```

### 4.4 Context Assembly（上下文组装）

这是 RFBrowser 最核心的创新——将来自不同源的上下文统一组装后传递给 AI：

```dart
class ContextAssembly {
  List<ContextItem> items;

  String toPrompt() {
    // 将所有上下文项组装为 AI 可理解的提示
  }
}

class ContextItem {
  ContextType type;             // note | web-page | selection | screenshot | file | agent-result
  String id;
  String content;               // 文本内容
  String? summary;              // AI 生成的摘要
  Map<String, dynamic> metadata;
}
```

**@引用语法**：
- `@note[笔记标题]` — 引用一条笔记
- `@web[标签页ID#选择区域]` — 引用浏览器中的内容
- `@file[文件路径]` — 引用本地文件
- `@agent[任务ID]` — 引用 Agent 任务结果
- `@clip[剪藏ID]` — 引用网页剪藏

---

## 五、核心引擎设计

### 5.1 Markdown 引擎

**职责**：解析、渲染、序列化 Markdown 文件

```
Markdown 文件
    │
    ├──→ [Parser] ──→ AST (抽象语法树)
    │                     │
    │                     ├──→ [Renderer] ──→ Flutter Widget Tree（预览）
    │                     ├──→ [LinkExtractor] ──→ Link[]（链接提取）
    │                     ├──→ [FrontMatterParser] ──→ YAML Map（元数据）
    │                     └──→ [SearchIndexer] ──→ 倒排索引（搜索）
    │
    └──→ [Serializer] ←── AST（保存回文件）
```

**关键特性**：
- 支持 `[[wikilink]]`、`#heading`、`^block-id` 三级链接
- 支持 `![[note]]` 嵌入引用
- 支持 YAML frontmatter
- 支持自定义语法扩展（通过插件）
- 增量解析：文件修改时只重新解析变更部分

**技术选型**：
- 使用 `flutter_markdown` + 自定义语法扩展
- 或使用 `markdown` Dart 包自行构建渲染管线

### 5.2 Link Resolver（链接解析器）

**职责**：解析所有类型的链接，构建双向链接图

```
输入：[[量子计算入门#核心概念]]
    │
    ├──→ [路径解析] ──→ vault/量子计算入门.md
    ├──→ [标题定位] ──→ ## 核心概念
    └──→ [反向链接更新] ──→ 在目标笔记的 backlinks 中添加记录
```

**链接类型**：

| 语法 | 类型 | 说明 |
|------|------|------|
| `[[note]]` | wikilink | 链接到笔记 |
| `[[note#heading]]` | heading link | 链接到笔记中的标题 |
| `[[note#^block-id]]` | block link | 链接到笔记中的块 |
| `![[note]]` | embed | 嵌入引用笔记内容 |
| `[[note\|alias]]` | alias link | 使用别名显示 |
| `@note[title]` | context ref | 上下文引用（AI 用） |
| `@web[tab#sel]` | web ref | 网页内容引用（AI 用） |

**反向链接**：
- 实时维护反向链接索引（SQLite）
- 支持未链接提及（Unlinked Mentions）— 发现隐式关联

### 5.3 Graph Engine（图谱引擎）

**职责**：构建和可视化知识图谱

```
Notes + Links
    │
    ├──→ [Graph Builder] ──→ 节点 + 边
    │                         │
    │                         ├──→ [Layout Engine] ──→ 力导向布局
    │                         ├──→ [Filter Engine] ──→ 按标签/类型/时间过滤
    │                         └──→ [Cluster Engine] ──→ 自动聚类
    │
    └──→ [Graph Renderer] ──→ Flutter Canvas / CustomPainter
```

**两种视图**：
1. **全局图谱** — 展示整个 Vault 的知识网络
2. **局部图谱** — 展示当前笔记的关联网络（2度关系）

**技术选型**：
- 使用 `graphview` Flutter 包或自建力导向布局
- GPU 加速渲染（Canvas + CustomPainter）
- 大规模图谱（1000+ 节点）使用 LOD（Level of Detail）优化

### 5.4 Context Assembler（上下文组装器）

**职责**：将来自不同源的上下文统一组装，传递给 AI

```
用户输入 + @引用
    │
    ├──→ [引用解析] ──→ ContextItem[]
    │                     │
    │                     ├──→ [内容提取] ──→ 从各源获取实际内容
    │                     ├──→ [相关性排序] ──→ 按相关性排序上下文
    │                     ├──→ [长度裁剪] ──→ 适配模型上下文窗口
    │                     └──→ [格式化] ──→ 组装为统一格式
    │
    └──→ [Prompt Builder] ──→ 最终提示词
```

**上下文源优先级**：
1. 用户当前输入（最高优先级）
2. @引用 的内容
3. 当前打开的笔记/网页
4. 最近的 Agent 任务结果
5. 相关的笔记（通过链接图发现）

### 5.5 Search Engine（搜索引擎）

**职责**：全文搜索 + 语义搜索

```
查询输入
    │
    ├──→ [文本搜索] ──→ SQLite FTS5 倒排索引
    ├──→ [语义搜索] ──→ 向量嵌入 + 余弦相似度
    └──→ [结果合并] ──→ 按相关性排序的结果列表
```

**技术选型**：
- SQLite FTS5 用于全文搜索
- 语义搜索：使用云端 Embedding API（如 OpenAI text-embedding-3）或本地模型
- 向量存储：SQLite + vec 扩展，或独立的向量索引

### 5.6 Model Router（模型路由器）

**职责**：管理多个 AI 模型，智能路由请求

```
AI 请求
    │
    ├──→ [任务分类] ──→ chat | agent | embed | summarize
    │
    ├──→ [模型选择] ──→ 根据任务类型和用户偏好选择模型
    │                     │
    │                     ├──→ 云端：OpenAI / Claude / Gemini / DeepSeek
    │                     └──→ 本地：Ollama / llama.cpp
    │
    └──→ [请求执行] ──→ 统一 API 适配层
```

**模型配置**：
```yaml
models:
  cloud:
    - provider: openai
      models: [gpt-4o, gpt-4o-mini]
      api_key: ${OPENAI_API_KEY}
    - provider: anthropic
      models: [claude-sonnet-4-20250514]
      api_key: ${ANTHROPIC_API_KEY}
    - provider: deepseek
      models: [deepseek-chat, deepseek-reasoner]
      api_key: ${DEEPSEEK_API_KEY}
  local:
    - provider: ollama
      endpoint: http://localhost:11434
      models: [llama3, qwen2.5]
    - provider: llamacpp
      endpoint: http://localhost:8080
      models: [custom-model]

routing:
  chat: cloud:openai:gpt-4o
  agent: cloud:anthropic:claude-sonnet-4-20250514
  embed: cloud:openai:text-embedding-3-small
  summarize: local:ollama:llama3
  fallback: local:ollama:llama3
```

---

## 六、Service 层设计

### 6.1 Browser Service

```dart
abstract class BrowserService {
  // 标签管理
  Future<List<TabGroup>> getTabGroups();
  Future<void> groupTabs(List<TabId> tabIds, String groupName);
  Future<void> autoGroupTabs();                    // AI 自动分组

  // 内容提取
  Future<WebContent> extractContent(TabId tabId);  // 提取网页正文
  Future<String> extractSelection(TabId tabId);    // 提取选中文本
  Future<Uint8List> captureScreenshot(TabId tabId);// 截图

  // 剪藏
  Future<Note> clipToNote(TabId tabId, {ClipMode mode});
  // ClipMode: fullPage | selection | bookmark | simplified

  // Agent 操作
  Future<void> navigateTo(TabId tabId, String url);
  Future<void> clickElement(TabId tabId, String selector);
  Future<void> fillForm(TabId tabId, Map<String, String> fields);
  Future<String> extractData(TabId tabId, String schema);
}
```

### 6.2 Knowledge Service

```dart
abstract class KnowledgeService {
  // 笔记 CRUD
  Future<Note> createNote(String title, {String? folder, String? template});
  Future<Note> getNote(String id);
  Future<void> updateNote(String id, String content);
  Future<void> deleteNote(String id);
  Future<List<Note>> searchNotes(String query);

  // 链接
  Future<List<Link>> getBacklinks(String noteId);
  Future<List<UnlinkedMention>> getUnlinkedMentions(String noteId);
  Future<void> createLink(String sourceId, String targetId, LinkType type);

  // 标签
  Future<List<TagWithCount>> getAllTags();
  Future<List<Note>> getNotesByTag(String tag);

  // 日记
  Future<Note> getOrCreateDailyNote(DateTime date);

  // 图谱
  Future<GraphData> getGlobalGraph({GraphFilter? filter});
  Future<GraphData> getLocalGraph(String noteId, {int depth = 2});
}
```

### 6.3 AI Service

```dart
abstract class AIService {
  // 对话
  Stream<AIResponse> chat(ContextAssembly context, String message);
  Future<AIResponse> chatSync(ContextAssembly context, String message);

  // 上下文引用
  ContextAssembly createContext();
  ContextAssembly addReference(ContextAssembly ctx, ContextItem item);

  // 模型管理
  Future<List<ModelInfo>> getAvailableModels();
  Future<void> setActiveModel(String modelId);
  Future<void> configureModel(ModelConfig config);

  // 本地模型
  Future<bool> isLocalModelAvailable(String modelId);
  Future<void> downloadLocalModel(String modelId);
  Future<void> startLocalModelServer(String modelId);
}
```

### 6.4 Agent Service

```dart
abstract class AgentService {
  // 任务管理
  Future<AgentTask> createTask(String name, String description, ContextAssembly context);
  Future<void> startTask(String taskId);
  Future<void> pauseTask(String taskId);
  Future<void> cancelTask(String taskId);
  Stream<AgentStep> watchTask(String taskId);

  // 预定义任务
  Future<AgentTask> research(String topic, {int depth = 3});
  Future<AgentTask> summarizeUrls(List<String> urls);
  Future<AgentTask> extractDataFromWeb(String url, String schema);
  Future<AgentTask> monitorChanges(String url, String selector);

  // Skill 执行
  Future<AgentTask> executeSkill(String skillId, Map<String, dynamic> params);
}
```

### 6.5 Plugin Service

```dart
abstract class PluginService {
  // 插件生命周期
  Future<List<Plugin>> getInstalledPlugins();
  Future<void> installPlugin(String source);       // URL 或本地路径
  Future<void> uninstallPlugin(String pluginId);
  Future<void> enablePlugin(String pluginId);
  Future<void> disablePlugin(String pluginId);

  // 插件 API
  Future<dynamic> callPluginApi(String pluginId, String method, Map<String, dynamic> args);

  // 插件市场
  Future<List<PluginManifest>> searchPlugins(String query);
  Future<PluginManifest> getPluginDetail(String pluginId);
}
```

### 6.6 Sync Service

```dart
abstract class SyncService {
  // Git 同步
  Future<void> gitInit(String remoteUrl);
  Future<void> gitPull();
  Future<void> gitPush();
  Future<void> gitCommit(String message);
  Future<SyncStatus> getGitStatus();

  // WebDAV 同步
  Future<void> webdavConfigure(String url, String username, String password);
  Future<void> webdavSync();
  Future<SyncStatus> getWebdavStatus();

  // 冲突处理
  Future<List<Conflict>> getConflicts();
  Future<void> resolveConflict(String conflictId, ConflictResolution resolution);
}
```

---

## 七、插件系统设计

### 7.1 插件架构

```
┌─────────────────────────────────────┐
│           Plugin Host               │
│  ┌─────────────────────────────┐    │
│  │      Plugin Sandbox         │    │
│  │  ┌───────┐  ┌───────┐      │    │
│  │  │Plugin │  │Plugin │      │    │
│  │  │  A    │  │  B    │      │    │
│  │  └───┬───┘  └───┬───┘      │    │
│  │      │          │          │    │
│  │      ▼          ▼          │    │
│  │  ┌─────────────────────┐   │    │
│  │  │   Plugin API Bridge │   │    │
│  │  └─────────┬───────────┘   │    │
│  └────────────┼───────────────┘    │
│               │                    │
│               ▼                    │
│  ┌─────────────────────────────┐   │
│  │      Core API Surface       │   │
│  │  Knowledge | Browser | AI   │   │
│  │  Agent | UI | FileSystem    │   │
│  └─────────────────────────────┘   │
└─────────────────────────────────────┘
```

### 7.2 插件清单（manifest.yaml）

```yaml
id: com.reflow.dataview
name: Dataview
version: 1.0.0
author: RFBrowser Community
description: SQL-like queries on your notes
minAppVersion: 0.1.0

permissions:
  - knowledge.read
  - knowledge.query
  - ui.panel
  - ui.command

skills:
  - id: dataview-query
    name: Query Notes
    description: Run a Dataview query
    params:
      - name: query
        type: string
        description: Dataview DQL query
        required: true

commands:
  - id: dataview-refresh
    name: Refresh Queries
    shortcut: "Ctrl+Shift+R"

settings:
  - id: enable-javascript-queries
    name: Enable JavaScript Queries
    type: boolean
    default: false

hooks:
  - event: note.opened
    handler: onNoteOpened
  - event: note.saved
    handler: onNoteSaved
```

### 7.3 插件 API Surface

```dart
abstract class RFBrowserPluginAPI {
  // 知识 API
  KnowledgeAPI get knowledge;
  // 浏览器 API
  BrowserAPI get browser;
  // AI API
  AIAPI get ai;
  // Agent API
  AgentAPI get agent;
  // UI API
  UIAPI get ui;
  // 文件系统 API
  FileSystemAPI get fs;
  // 设置 API
  SettingsAPI get settings;
}

// 示例：Knowledge API
abstract class KnowledgeAPI {
  Future<Note> getNote(String id);
  Future<List<Note>> queryNotes(QuerySpec spec);
  Future<List<Note>> searchNotes(String query);
  Future<Note> createNote(CreateNoteSpec spec);
  Future<void> updateNote(String id, String content);
  Stream<NoteEvent> onNoteChange();
}
```

### 7.4 插件沙箱

- **语言**：插件使用 Dart AOT 编译为独立 isolate，或使用 JavaScript（QuickJS 引擎）
- **权限**：基于 manifest.yaml 声明的权限，运行时检查
- **隔离**：每个插件运行在独立 isolate 中，通过 API Bridge 通信
- **资源限制**：CPU 时间和内存配额，防止恶意插件

### 7.5 Skill 系统

Skill 是用户可自定义的"一键命令"，可以：
- 由用户手动创建（录制操作序列或编写提示词模板）
- 由插件提供（插件 manifest 中声明 skills）
- 由 AI 建议（基于用户行为模式自动推荐）

```yaml
# 内置 Skill 示例
id: summarize-page
name: 总结网页
description: 总结当前打开的网页内容
prompt: |
  请总结以下网页内容，提取关键要点：
  @web[current]
params: []
trigger: command    # command | shortcut | auto
shortcut: "Ctrl+Shift+S"
```

---

## 八、UI 布局设计

### 8.1 主窗口布局（桌面端）

```
┌──────────────────────────────────────────────────────────────────┐
│  Menu Bar  │  Command Bar (⌘K / Ctrl+K)              │ AI Model │
├────────┬───────────────────────────────┬─────────────────────────┤
│        │                               │                         │
│  Tab   │     Main Content Area         │    Right Sidebar        │
│  Group │     (Split View)              │                         │
│  Bar   │  ┌─────────────┬────────────┐│  ┌─ AI Chat ──────────┐│
│        │  │             │            ││  │                     ││
│  ────  │  │  Browser    │  Editor    ││  │  Context: @note[x] ││
│  工作  │  │  View       │  View      ││  │  @web[current]     ││
│  ────  │  │             │            ││  │                     ││
│  学习  │  │             │            ││  │  [AI response...]   ││
│  ────  │  │             │            ││  │                     ││
│  研究  │  │             │            ││  ├─ Backlinks ────────┤│
│  ────  │  │             │            ││  │  ← [[相关笔记1]]    ││
│  阅读  │  │             │            ││  │  ← [[相关笔记2]]    ││
│        │  │             │            ││  ├─ Outline ──────────┤│
│  ────  │  │             │            ││  │  # 标题1            ││
│  收藏  │  │             │            ││  │  ## 标题2           ││
│        │  │             │            ││  └─────────────────────┘│
│        │  └─────────────┴────────────┘│                         │
├────────┴───────────────────────────────┴─────────────────────────┤
│  Status Bar  │  Agent Tasks: [2 running]  │  Sync: ✓ Git  │ LN │
└──────────────────────────────────────────────────────────────────┘
```

### 8.2 主窗口布局（Android 端）

```
┌──────────────────────┐
│  ≡  │ Title  │  AI   │  ← 顶部导航栏
├──────────────────────┤
│                      │
│  Current View        │  ← 单视图（浏览器/编辑器/图谱）
│  (Full Screen)       │
│                      │
│                      │
├──────────────────────┤
│ 🌐 │ 📝 │ 🕸️ │ 🤖 │  ← 底部导航栏
│浏览 │笔记 │图谱 │AI  │
└──────────────────────┘
```

### 8.3 视图模式

| 模式 | 说明 | 快捷键 |
|------|------|--------|
| **浏览器** | 全屏浏览器 | Ctrl+1 |
| **编辑器** | 全屏 Markdown 编辑器 | Ctrl+2 |
| **图谱** | 全屏知识图谱 | Ctrl+3 |
| **Canvas** | 无限画布 | Ctrl+4 |
| **双栏** | 浏览器 + 编辑器并排 | Ctrl+5 |
| **三栏** | 浏览器 + 编辑器 + AI Chat | Ctrl+6 |
| **专注** | 隐藏所有侧栏，仅编辑器 | Ctrl+Shift+F |

### 8.4 Command Bar（命令栏）

类似 VS Code 的 Command Palette，是核心交互入口：

- `Ctrl+K` / `⌘K` 打开
- 支持模糊搜索命令、笔记、标签、Skills
- 支持 AI 自然语言输入（"帮我总结当前网页"）
- 支持快捷操作（"创建笔记"、"切换模型"、"执行 Skill"）

---

## 九、AI Agent 架构

### 9.1 Agent 执行流程

```
用户指令 / Skill 触发
    │
    ├──→ [意图识别] ──→ 确定任务类型
    │
    ├──→ [计划生成] ──→ 生成执行步骤列表
    │                     │
    │                     Step 1: 打开网页 A
    │                     Step 2: 提取关键数据
    │                     Step 3: 创建笔记 B
    │                     Step 4: 建立链接 B → C
    │
    ├──→ [步骤执行] ──→ 逐步执行，每步验证
    │                     │
    │                     ├──→ 浏览器操作（HeadlessInAppWebView）
    │                     ├──→ 知识操作（Knowledge Service）
    │                     ├──→ AI 推理（AI Service）
    │                     └──→ 文件操作（File System）
    │
    ├──→ [结果验证] ──→ 检查每步输出是否符合预期
    │
    └──→ [结果交付] ──→ 通知用户，更新 UI
```

### 9.2 Agent 安全约束

| 约束 | 说明 |
|------|------|
| **操作白名单** | Agent 只能执行预定义的操作类型 |
| **确认门槛** | 涉及删除、发送等危险操作需用户确认 |
| **资源限制** | 单个任务最多执行 50 步，最多打开 10 个标签页 |
| **时间限制** | 单个任务最长运行 30 分钟 |
| **沙箱隔离** | Agent 的浏览器操作在独立标签组中运行 |
| **可撤销** | Agent 创建的内容可一键撤销 |

### 9.3 Agent 预定义任务

| 任务 | 说明 | 示例 |
|------|------|------|
| **深度研究** | 搜索多个来源，综合生成报告 | "研究量子计算的最新进展" |
| **网页摘要** | 打开 URL，提取并总结内容 | "总结这篇文章" |
| **数据提取** | 从网页提取结构化数据 | "提取这个表格的数据" |
| **监控变更** | 定期检查网页变化 | "监控这个页面的价格变化" |
| **批量剪藏** | 批量保存网页为笔记 | "保存这些链接为笔记" |
| **自动整理** | 根据规则整理笔记和标签 | "把未分类的笔记归类" |

---

## 十、同步方案设计

### 10.1 Git 同步

```
Vault (本地)
    │
    ├──→ git init (首次)
    ├──→ git remote add origin <url>
    │
    ├──→ 自动提交（每次保存后延迟 30s）
    │     git add -A && git commit -m "auto: update notes"
    │
    ├──→ 定时拉取（每 5 分钟）
    │     git pull --rebase
    │
    └──→ 手动推送/拉取
          git push / git pull
```

**冲突处理**：
- Markdown 文件级别冲突：自动合并（Git merge）
- 无法自动合并时：生成冲突标记，提示用户手动解决
- `.reflow/cache/` 目录加入 `.gitignore`

### 10.2 WebDAV 同步

```
Vault (本地)
    │
    ├──→ 文件变更检测（WatchService）
    │
    ├──→ 增量上传（仅上传变更文件）
    │     PUT /dav/vault/notes/example.md
    │
    ├──→ 增量下载（ETag 比较）
    │     GET /dav/vault/notes/example.md
    │     If-None-Match: "etag-value"
    │
    └──→ 冲突处理
          本地较新 → 上传覆盖
          远端较新 → 下载覆盖
          双方修改 → 保留两份，标记冲突
```

---

## 十一、国际化（i18n）设计

### 11.1 方案

- 使用 Flutter 内置的 `intl` 包
- 语言文件格式：ARB (Application Resource Bundle)
- 支持运行时切换语言，无需重启

### 11.2 文件结构

```
lib/
  l10n/
    app_en.arb      # 英文
    app_zh.arb      # 中文
    app_zh_CN.arb   # 简体中文（可选，更精确）
```

### 11.3 切换机制

```dart
MaterialApp(
  locale: userPreferredLocale,  // 从设置中读取
  localizationsDelegates: [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ],
  supportedLocales: [
    Locale('en'),
    Locale('zh'),
  ],
);
```

---

## 十二、项目结构

```
reflow/
├── lib/
│   ├── main.dart
│   ├── app.dart                          # MaterialApp 配置
│   ├── l10n/                             # 国际化
│   │   ├── app_en.arb
│   │   └── app_zh.arb
│   │
│   ├── core/                             # 核心引擎
│   │   ├── markdown/
│   │   │   ├── parser.dart
│   │   │   ├── renderer.dart
│   │   │   ├── serializer.dart
│   │   │   └── wikilink_extension.dart
│   │   ├── link/
│   │   │   ├── resolver.dart
│   │   │   ├── backlink_index.dart
│   │   │   └── unlinked_mentions.dart
│   │   ├── graph/
│   │   │   ├── builder.dart
│   │   │   ├── layout_engine.dart
│   │   │   ├── cluster_engine.dart
│   │   │   └── renderer.dart
│   │   ├── search/
│   │   │   ├── fulltext_search.dart
│   │   │   ├── semantic_search.dart
│   │   │   └── index_manager.dart
│   │   ├── context/
│   │   │   ├── assembler.dart
│   │   │   ├── reference_parser.dart
│   │   │   └── priority_ranker.dart
│   │   └── model/
│   │       ├── router.dart
│   │       ├── cloud_adapter.dart
│   │       └── local_adapter.dart
│   │
│   ├── services/                         # 服务层
│   │   ├── browser_service.dart
│   │   ├── knowledge_service.dart
│   │   ├── ai_service.dart
│   │   ├── agent_service.dart
│   │   ├── plugin_service.dart
│   │   ├── skill_service.dart
│   │   ├── sync_service.dart
│   │   ├── template_service.dart
│   │   └── event_bus.dart
│   │
│   ├── data/                             # 数据层
│   │   ├── stores/
│   │   │   ├── file_store.dart
│   │   │   ├── index_store.dart          # SQLite
│   │   │   ├── cache_store.dart          # Hive/Isar
│   │   │   └── sync_store.dart
│   │   ├── models/
│   │   │   ├── note.dart
│   │   │   ├── web_clip.dart
│   │   │   ├── link.dart
│   │   │   ├── agent_task.dart
│   │   │   ├── skill.dart
│   │   │   ├── plugin.dart
│   │   │   └── context_assembly.dart
│   │   └── repositories/
│   │       ├── note_repository.dart
│   │       ├── link_repository.dart
│   │       └── agent_repository.dart
│   │
│   ├── platform/                         # 平台层
│   │   ├── webview/
│   │   │   ├── webview_manager.dart
│   │   │   ├── headless_manager.dart
│   │   │   └── content_extractor.dart
│   │   ├── channels/
│   │   │   ├── file_channel.dart
│   │   │   ├── notification_channel.dart
│   │   │   └── deep_link_channel.dart
│   │   └── system/
│   │       ├── tray_manager.dart
│   │       ├── shortcut_manager.dart
│   │       └── window_manager.dart
│   │
│   ├── plugins/                          # 插件系统
│   │   ├── host/
│   │   │   ├── plugin_host.dart
│   │   │   ├── sandbox.dart
│   │   │   └── api_bridge.dart
│   │   ├── api/
│   │   │   ├── knowledge_api.dart
│   │   │   ├── browser_api.dart
│   │   │   ├── ai_api.dart
│   │   │   ├── agent_api.dart
│   │   │   ├── ui_api.dart
│   │   │   └── fs_api.dart
│   │   └── builtin/                      # 内置插件
│   │       ├── dataview/
│   │       ├── canvas/
│   │       └── daily_notes/
│   │
│   ├── ui/                               # UI 层
│   │   ├── pages/
│   │   │   ├── home_page.dart
│   │   │   ├── browser_page.dart
│   │   │   ├── editor_page.dart
│   │   │   ├── graph_page.dart
│   │   │   ├── canvas_page.dart
│   │   │   ├── settings_page.dart
│   │   │   └── plugin_store_page.dart
│   │   ├── widgets/
│   │   │   ├── tab_group_sidebar.dart
│   │   │   ├── command_bar.dart
│   │   │   ├── ai_chat_panel.dart
│   │   │   ├── backlinks_panel.dart
│   │   │   ├── outline_panel.dart
│   │   │   ├── context_reference_chip.dart
│   │   │   ├── agent_monitor.dart
│   │   │   ├── skill_runner.dart
│   │   │   └── markdown_editor.dart
│   │   ├── theme/
│   │   │   ├── app_theme.dart
│   │   │   ├── dark_theme.dart
│   │   │   └── light_theme.dart
│   │   └── layout/
│   │       ├── main_layout.dart
│   │       ├── split_view.dart
│   │       └── responsive_layout.dart
│   │
│   └── utils/
│       ├── logger.dart
│       ├── constants.dart
│       ├── extensions.dart
│       └── platform_utils.dart
│
├── test/                                 # 测试
│   ├── core/
│   ├── services/
│   ├── data/
│   └── ui/
│
├── android/                              # Android 平台
├── linux/                                # Linux 平台
├── windows/                              # Windows 平台
│
├── assets/                               # 静态资源
│   ├── icons/
│   ├── fonts/
│   └── templates/                        # 默认笔记模板
│
├── pubspec.yaml
├── analysis_options.yaml
└── README.md
```

---

## 十三、技术栈汇总

| 层次 | 技术 | 用途 |
|------|------|------|
| **UI 框架** | Flutter 3.x | 跨平台 UI |
| **语言** | Dart | 主开发语言 |
| **浏览器** | flutter_inappwebview | WebView 集成 |
| **Markdown** | markdown + flutter_markdown | 解析和渲染 |
| **数据库** | SQLite (sqflite) | 索引和搜索 |
| **缓存** | Hive / Isar | 本地键值缓存 |
| **向量搜索** | sqlite-vec / 自建 | 语义搜索 |
| **Git** | git (CLI) + dart_git | 版本控制同步 |
| **WebDAV** | webdav_client | WebDAV 同步 |
| **AI 云端** | http + dio | OpenAI/Claude/Gemini API |
| **AI 本地** | Ollama API / llama.cpp | 本地模型推理 |
| **状态管理** | Riverpod | 响应式状态 |
| **路由** | go_router | 声明式路由 |
| **国际化** | flutter_intl / arb | 中英双语 |
| **插件沙箱** | Isolate / QuickJS | 插件隔离执行 |
| **图谱渲染** | CustomPainter + Canvas | 力导向图 |
| **文件监听** | watcheer / fsevents | 文件变更检测 |

---

## 十四、开发路线图

### Phase 1: 基础框架 (MVP)

**目标**：可运行的应用骨架，基本可用

- [ ] Flutter 项目初始化 + 三平台构建配置
- [ ] 主窗口布局（双栏 + 侧边栏）
- [ ] Markdown 编辑器（基础编辑 + 实时预览）
- [ ] 文件系统 Vault 管理
- [ ] 基础浏览器（flutter_inappwebview 集成）
- [ ] 标签管理（手动分组）
- [ ] AI Chat（云端 API，单模型）
- [ ] 中英双语切换
- [ ] SQLite 索引 + 全文搜索

### Phase 2: 知识核心

**目标**：知识管理能力达到 Obsidian 基础水平

- [ ] `[[wikilink]]` 双向链接 + 反向链接面板
- [ ] 知识图谱视图（全局 + 局部）
- [ ] @引用 系统（上下文引用）
- [ ] 网页剪藏（保存为 Markdown 笔记）
- [ ] AI 自动标签分组
- [ ] 模板系统
- [ ] Daily Notes
- [ ] Git 同步

### Phase 3: AI 增强

**目标**：AI 能力达到 Tabbit 核心水平

- [ ] 多模型切换（OpenAI/Claude/Gemini/DeepSeek）
- [ ] Agent 模式（自动浏览 + 数据提取）
- [ ] Skills 系统（用户自定义宏）
- [ ] 上下文组装器（Context Assembler）
- [ ] AI 深度研究任务
- [ ] 本地模型支持（Ollama）
- [ ] WebDAV 同步

### Phase 4: 生态扩展

**目标**：插件生态 + 高级功能

- [ ] 插件系统（沙箱 + API Surface）
- [ ] Canvas 无限画布
- [ ] Dataview 查询（内置插件）
- [ ] 语义搜索（向量嵌入）
- [ ] 未链接提及
- [ ] 插件市场
- [ ] Skill 市场
- [ ] 主题系统
- [ ] 性能优化（大规模 Vault）

### Phase 5: 打磨与发布

**目标**：生产级质量

- [ ] 无障碍访问
- [ ] 快捷键系统
- [ ] 拖拽互操作（浏览器 ↔ 编辑器）
- [ ] 离线模式完善
- [ ] 自动更新
- [ ] 安装包优化
- [ ] 三平台测试与适配
- [ ] 用户文档
- [ ] 社区建设

---

## 十五、关键风险与缓解

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| Flutter 内嵌浏览器性能 | 中 | 使用 flutter_inappwebview，避免自建 CEF 集成 |
| Linux WebKitGTK 兼容性 | 低 | 提供 CEF 可选后端，WPE WebKit 优化渲染 |
| 插件沙箱安全 | 高 | Isolate 隔离 + 权限声明 + 资源配额 |
| Agent 操作失控 | 高 | 操作白名单 + 确认门槛 + 步数限制 + 可撤销 |
| 大规模 Vault 性能 | 中 | SQLite 索引 + 增量解析 + LOD 渲染 |
| AI API 成本 | 中 | 本地模型备选 + 缓存 + 模型路由优化 |
| 跨平台 UI 一致性 | 低 | Flutter 自绘引擎天然一致，响应式布局 |
