# RFBrowser — 下一阶段设计案：从骨架到血肉

> **版本**: 1.0
> **状态**: Draft
> **设计哲学**: "后端已就绪，前端需要穿上衣服。" — 核心矛盾是 6 个成熟服务对接 40+ 个 Placeholder 页面

---

## 目录

1. [现状诊断](#1-现状诊断)
2. [设计原则](#2-设计原则)
3. [总体架构与数据流](#3-总体架构与数据流)
4. [逐层设计规格](#4-逐层设计规格)
5. [关键组件契约](#5-关键组件契约)
6. [数据流绑定规范](#6-数据流绑定规范)
7. [性能与安全约束](#7-性能与安全约束)
8. [风险与缓解](#8-风险与缓解)
9. [可验证标准](#9-可验证标准)

---

## 1. 现状诊断

### 1.1 完成度矩阵

```
层次        实现状态   覆盖率    说明
─────────────────────────────────────────────────
Core        完整实现   100%     graph_algorithm, link_extractor/resolver,
                               context assembler, markdown_highlighter,
                               editor controllers, sync_scroll

Data        完整实现   100%     16 个 Model, 5 个 Store (HNSW/Vector/
                               Index/Sync/Vault), NoteRepository

Platform    完整实现   100%     agent_webview, headless_manager

Plugins     完整实现   100%     plugin_host, plugin_api, dataview
                               (DQL parser + query engine + renderer)

Services    大部完成    75%     6/8 完整 (ai, agent, browser, knowledge,
                               git_sync, webdav_sync)
                               2 存根 (embedding, shortcut)

UI          骨架存在    15%     SceneSwitcher/SceneScaffold/MainLayout 架构存在
                               40+ 页面/组件均为 Placeholder 文本
```

### 1.2 核心矛盾

> **数据管道已建好，水龙头全是假的。**

- `ai_service.dart` 支持 OpenAI/Anthropic/Ollama 三 Provider 流式对话，但 `ai_chat_panel.dart` 只显示 "AI Chat Placeholder"
- `knowledge_service.dart` 实现完整的笔记 CRUD + 链接解析 + 全文搜索，但 `editor_page.dart` 只有一行占位文本
- `browser_service.dart` 管理标签页/标签组/自动分组，但 `browser_page.dart` 只有一个导航按钮
- `LinkResolver` 可解析所有反向链接，但 `backlinks_panel.dart` 是空面板

### 1.3 保留的正确决策

- **Riverpod Notifier + State + Provider** 模式已贯彻所有服务层
- **Scene 三场景架构** (Capture/Think/Connect) 正确划分了用户心智模型
- **AIFloat 浮动助手** 的设计：每个 Scene 拥有独立 AI 实例，解耦合理
- **设计 Token** (design_tokens.dart) 已定义，可直接引用
- **Markdown 纯文本 + YAML frontmatter** 存储方案零锁定、Git 友好

---

## 2. 设计原则

| 编号 | 原则 | 含义 | 可验证标准 |
|------|------|------|-----------|
| **DP1** | 数据先行 | 每个 UI 组件必须从服务层获取真实数据，禁止硬编码 placeholder | 所有页面至少绑定了 1 个 Riverpod Provider |
| **DP2** | 复用现有接口 | 不修改服务层公开 API 签名，UI 层适配已有接口 | 服务层文件修改行数 = 0 |
| **DP3** | 渐进式对接 | 页面按用户触达频率排序，高频入口先行 | CommandBar → BrowserPage → EditorPage 最先交付 |
| **DP4** | 每个组件一条通路 | 每个 UI 组件必须满足 A-1：至少一个数据流路径到另一组件 | 可用 `flutter test` 验证数据流 |
| **DP5** | 错误可见 | 服务层异常必须在 UI 层以用户可理解的方式呈现，且 dismiss 按钮真实清除状态 (U-1) | 所有 catch 块有 SnackBar/ErrorBanner + 清除按钮 |
| **DP6** | 性能零退化 | 新增 UI 不得引入不必要的 repaint，列表使用 builder 模式，debounce 500ms | `shouldRepaint` 严格比较；`flutter analyze` 0 问题 |

---

## 3. 总体架构与数据流

### 3.1 分层架构图

```
┌─────────────────────────────────────────────────────┐
│                    UI Layer                          │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐             │
│  │ Scenes   │ │ Pages    │ │ Widgets  │             │
│  │ Capture  │ │ Browser  │ │CmdBar    │             │
│  │ Think    │ │ Editor   │ │AIFloat   │             │
│  │ Connect  │ │ Graph    │ │Backlinks │             │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘             │
│       │             │             │                  │
│       └─────────────┼─────────────┘                  │
│                     │  Riverpod Providers            │
│                     ▼                                │
├─────────────────────────────────────────────────────┤
│                  Service Layer                       │
│  ┌────────┐ ┌────────┐ ┌────────┐ ┌──────────┐     │
│  │AI Svc  │ │Agent   │ │Browser │ │Knowledge │     │
│  │        │ │Svc     │ │Svc     │ │Svc       │     │
│  └───┬────┘ └───┬────┘ └───┬────┘ └────┬─────┘     │
│      │          │          │           │            │
│  ┌───┴────┐     │     ┌────┴────┐ ┌───┴──────┐     │
│  │Git Sync│     │     │WebDAV   │ │Embedding │     │
│  │Svc     │     │     │Sync Svc │ │Svc (stub)│     │
│  └────────┘     │     └─────────┘ └──────────┘     │
├─────────────────────────────────────────────────────┤
│                    Core Layer                        │
│  ┌────────┐ ┌────────┐ ┌────────┐ ┌──────────┐     │
│  │Graph   │ │Link    │ │Context │ │Editor    │     │
│  │Engine  │ │Engine  │ │Engine  │ │Engine    │     │
│  └────────┘ └────────┘ └────────┘ └──────────┘     │
├─────────────────────────────────────────────────────┤
│                    Data Layer                        │
│  ┌────────┐ ┌────────┐ ┌────────┐ ┌──────────┐     │
│  │Models  │ │Stores  │ │Repos   │ │Vault     │     │
│  └────────┘ └────────┘ └────────┘ └──────────┘     │
├─────────────────────────────────────────────────────┤
│                 Platform & Plugins                   │
│  ┌────────┐ ┌────────┐ ┌───────────────────────┐    │
│  │WebView │ │Plugin  │ │Builtin Dataview       │    │
│  │Manager │ │Host    │ │                       │    │
│  └────────┘ └────────┘ └───────────────────────┘    │
└─────────────────────────────────────────────────────┘
```

### 3.2 关键数据流路径

#### 路径 A：浏览器 → 剪辑 → 笔记 → 知识图谱（主链路）

```
BrowserPage                         CaptureScene
  │ browser_service                     │
  │ .getTabs()                         │
  ▼                                    ▼
WebView                          ClipToolbar
  │ shouldOverrideUrlLoading           │ clipper_service (已合并到
  │ (S-1 安全过滤)                     │ knowledge_service)
  ▼                                    ▼
用户选中文本/整页               ┌──────────────────┐
  │                            │ NoteRepository    │
  │  触发 ClipToolbar          │ .createNote()    │
  └────────────────────────────┤ .updateNote()    │
                               └──────┬───────────┘
                                      │
                                      ▼
                               Note (Markdown + YAML)
                                      │
                                      ├──► LinkExtractor 提取 [[wikilinks]]
                                      │
                                      ├──► LinkResolver 解析反向链接
                                      │
                                      └──► GraphAlgorithm 构建知识图谱
                                           │
                                           ▼
                                      GraphPage 渲染图谱
                                           │
                                           └──► CanvasPage 展示为无尽画布卡片
```

#### 路径 B：AI 辅助创作（差异化链路）

```
ThinkScene
  │
  ├── InlineAIEditor ──► ai_service.sendMessage() ──► 流式 tokens
  │                                                            │
  │                                                            ▼
  │                                                     MarkdownBody 渲染
  │
  └── @note, @web, @clip 上下文引用 ──► ContextAssembler
                                              │
                                              ▼
                                       组装 Prompt ──► ai_service
```

#### 路径 C：同步链路

```
GitSyncService / WebDAVSyncService
  │
  ├── SyncStore (记录同步状态)
  │
  ├── VaultStore (文件变更检测)
  │
  └── SyncProgress Widget (状态栏实时进度)
       │
       └── SyncConflictDialog (冲突时弹出)
```

---

## 4. 逐层设计规格

### 4.1 UI 层 — Page 组件契约

#### 4.1.1 BrowserPage

```
┌─────────────────────────────────────────┐
│ Tab Bar: [Tab1] [Tab2] [+] [Tab Groups] │  ← browser_service.tabs
├─────────────────────────────────────────┤
│                                         │
│          AgentWebView                   │  ← agent_webview widget
│          (Chromium/WebKit)              │
│                                         │
├─────────────────────────────────────────┤
│ Address Bar: [https://...]  [🔖][✂️]   │  ← browser_service.navigate()
└─────────────────────────────────────────┘
```

**状态管理**：
```dart
// Provider: browserPageProvider
// State: BrowserPageState { tabs: List<BrowserTab>, activeTabId: String }
// Source: browser_service (现有)
```

**关键交互**：
- 新建标签：`browser_service.createTab()`
- 关闭标签：先计算新 active index (C-3)，再 `browser_service.closeTab()`
- URL 导航：`browser_service.navigate(tabId, url)` → `agent_webview.loadUrl()`
- URL 安全过滤：`shouldOverrideUrlLoading` 中检查 `file://`, `javascript:`, `data:` (S-1)
- 剪辑：选中文本 → 触发 CaptureScene 的 ClipToolbar

#### 4.1.2 EditorPage

```
┌─────────────────────────────────────────┐
│ Title: [Note Title...]                  │
├─────────────────────────────────────────┤
│                                         │
│    Markdown Editor                      │  ← HighlightedTextEditingController
│    with syntax highlighting             │     + MarkdownHighlighter
│    [[wikilink]] autocomplete            │
│                                         │
├─────────────────────────────────────────┤
│ Status: [📝 Modified] [500 words]       │  ← NoteRepository.save()
└─────────────────────────────────────────┘
```

**状态管理**：
```dart
// Provider: editorPageProvider
// State: EditorPageState { note: Note?, isModified: bool, wordCount: int }
// Source: knowledge_service (现有), NoteRepository (现有)
```

**关键交互**：
- 加载笔记：`NoteRepository.getNote(id)` → 填充 `TextEditingController`
- 编辑保存：debounce 500ms `NoteRepository.save(note)` + 失焦立即保存 (P-1)
- Wikilink 自动补全：`knowledge_service.searchNotes()` 提供候选项
- 语法高亮：`MarkdownHighlighter.highlight()` → `HighlightedTextEditingController`

#### 4.1.3 GraphPage

```
┌─────────────────────────────────────────┐
│ [Filter Panel]  [Layout Panel]          │
├─────────────────────────────────────────┤
│                                         │
│     Knowledge Graph Visualization       │  ← GraphAlgorithm
│     Nodes = Notes                       │     + LayoutEngine
│     Edges = Links                       │     + FilterEngine
│                                         │
│     Auto-discovered links: dashed       │  ← A-6
│     Manual links: solid                 │
│                                         │
├─────────────────────────────────────────┤
│ [Node Detail Panel]                     │  ← 选中节点时展开
└─────────────────────────────────────────┘
```

**状态管理**：
```dart
// Provider: graphPageProvider
// State: GraphPageState { nodes: List<GraphNode>, edges: List<GraphEdge>,
//          selectedNodeId: String?, filters: GraphFilters, layout: LayoutConfig }
// Source: graph_algorithm (现有), filter_engine (现有), layout_engine (现有)
```

**关键交互**：
- 数据加载：`knowledge_service.getAllNotes()` + `knowledge_service.getAllLinks()` → `GraphAlgorithm.build()`
- 布局：`LayoutEngine.layout(nodes, edges)` → 力导向位置计算
- 筛选：`FilterEngine.apply(filters)` → 按标签/类型/时间过滤
- 节点点击：展开 `NodeDetailPanel` 显示笔记摘要
- 视觉区分：自动发现的 [[wikilink]] 连线使用虚线，手动连线使用实线 (A-6)

#### 4.1.4 AIChatPanel

```
┌─────────────────────────────────────────┐
│ Provider: [Ollama ▼]  Model: [qwen2.5 ▼]│  ← ai_service.availableProviders
├─────────────────────────────────────────┤
│                                         │
│  User: 帮我总结这篇文章的主要观点         │
│                                         │
│  AI: 这篇文章主要讨论了以下观点...        │  ← 流式 tokens (UX-4)
│      █ (cursor blinking)                │
│                                         │
├─────────────────────────────────────────┤
│ [@note] [@web] [@clip]                  │  ← 上下文引用
│ [Message input...              ] [Send]  │
└─────────────────────────────────────────┘
```

**状态管理**：
```dart
// Provider: aiChatProvider
// State: AIChatState { messages: List<ChatMessage>, isStreaming: bool,
//          selectedProvider: String, selectedModel: String }
// Source: ai_service (现有)
```

**关键交互**：
- 发送消息：`ai_service.sendMessage(messages, provider, model)` → 流式 `Stream<String>`
- 中止生成：`ai_service.cancelStream()` (并发防护 C-2：`isLoading` 检查)
- 上下文引用：`@note:Title` 语法 → `ContextAssembler.assemble()` → 注入 Prompt
- Provider 切换：实时切换不丢失当前对话

#### 4.1.5 CanvasPage

```
┌─────────────────────────────────────────┐
│                                         │
│    Infinite Canvas (CustomPaint)        │
│                                         │
│  ┌──────────┐    ┌──────────┐           │
│  │ Note Card │────│ Note Card │          │  ← A-5: 实时渲染 Note 数据
│  │ Title     │    │ Title     │          │
│  │ Preview   │    │ Preview   │          │
│  └──────────┘    └──────────┘           │
│       │                                 │
│       │ (dashed = auto [[wikilink]])    │  ← A-6 视觉区分
│       │                                 │
│  ┌──────────┐                           │
│  │ Note Card │                          │
│  └──────────┘                           │
│                                         │
└─────────────────────────────────────────┘
```

**状态管理**：
```dart
// Provider: canvasPageProvider
// State: CanvasPageState { cards: List<CanvasCard>, connections: List<CanvasConnection>,
//          viewport: Viewport, selectedCardId: String? }
// Source: canvas_model (现有), note_repository (现有)
// 持久化: .json in vault/.rf/ (A-7)
```

**关键交互**：
- 卡片渲染：CanvasCard 绑定 noteId → 实时读取 Note 数据 (A-5)
- 拖拽：内存更新位置 + debounce 500ms 持久化 (P-1)
- 画布变换：`Matrix4` 操作位移动画
- shouldRepaint：严格比较 card positions/connections (P-2)
- 裁剪：`save() → clipRect() → draw → restore()` (U-2)

### 4.2 UI 层 — Widget 组件契约

#### 4.2.1 CommandBar

```dart
// 当前：硬编码建议列表
// 目标：实时搜索笔记 + 标签 + 命令

// Provider: commandBarProvider
// State: CommandBarState { query: String, results: List<SearchResult>, isSearching: bool }
// Source: knowledge_service.searchNotes() (UX-5)
```

**行为规格**：
- 输入 `Ctrl+K` 唤起
- 300ms debounce 后发起搜索
- 结果分类：笔记 / 标签 / 命令 / 浏览器标签
- 选中笔记 → 打开 EditorPage
- 选中命令 → 执行对应操作

#### 4.2.2 AIFloat

```dart
// 当前：每个 Scene 有独立 AIFloat，但内容为 placeholder
// 目标：可折叠浮动助手，上下文感知

// API:
//   AIFloat.expand()   → 展开为完整 AIChatPanel
//   AIFloat.collapse() → 收缩为圆形 FAB
//   AIFloat.setContext(SceneType) → 根据所在 Scene 提供不同快捷操作
```

**Per-Scene 差异化**：
| Scene | AIFloat 默认行为 |
|-------|-----------------|
| Capture | "摘录这段话" / "总结此页面" |
| Think | "帮我续写" / "改进这段文字" |
| Connect | "这些笔记有什么关系？" / "生成报告" |

#### 4.2.3 BacklinksPanel

```dart
// Provider: backlinksProvider
// State: BacklinksState { noteId: String, backlinks: List<Link> }
// Source: LinkResolver (现有, UX-6 确保被调用)
```

#### 4.2.4 NoteSidebar

```dart
// Provider: noteSidebarProvider
// State: NoteSidebarState { vaultPath: String, noteTree: List<NoteTreeNode> }
// Source: VaultStore (现有)
```

### 4.3 服务层 — 存根补齐规格

#### 4.3.1 EmbeddingService

```dart
/// 文本向量化服务
/// 对接 Ollama Embedding API / OpenAI Embeddings API
class EmbeddingService {
  /// 将文本列表转为向量列表
  /// dimension: 根据模型决定 (nomic-embed-text = 768, text-embedding-3-small = 1536)
  Future<List<List<double>>> embed(List<String> texts);

  /// 单个文本向量化
  Future<List<double>> embedSingle(String text);

  /// 计算余弦相似度
  double cosineSimilarity(List<double> a, List<double> b);
}
```

**Provider 支持**：
- Ollama: `POST /api/embed` → `{"model": "nomic-embed-text", "input": [...]}`
- OpenAI: `POST /v1/embeddings` → `{"model": "text-embedding-3-small", "input": [...]}`

#### 4.3.2 ShortcutService

```dart
/// 全局快捷键管理服务
/// 满足 UX-7: Top 5 操作必须有快捷键
class ShortcutService {
  /// 注册快捷键
  void register(String actionId, LogicalKeySet keys, VoidCallback handler);

  /// 注销快捷键
  void unregister(String actionId);

  /// 检测冲突
  List<ShortcutConflict> detectConflicts();

  /// 获取所有已注册快捷键 (用于设置页展示)
  Map<String, ShortcutBinding> getAllBindings();
}

// 默认绑定 (UX-7)
// Ctrl+K    → 搜索 (CommandBar)
// Ctrl+N    → 新建笔记
// Ctrl+S    → 保存当前笔记
// Ctrl+1/2/3 → 切换 Scene (Capture/Think/Connect)
// Ctrl+D    → 打开今日日记
```

---

## 5. 关键组件契约

### 5.1 组件间数据传递协议

| 发送方 | 接收方 | 数据类型 | 传递方式 |
|--------|--------|---------|---------|
| BrowserPage | CaptureScene | `WebClip { url, selectedText, title }` | Riverpod shared state |
| CaptureScene | NoteRepository | `Note` (from clip) | Service call |
| EditorPage | LinkExtractor | `String` (markdown content) | Core engine call |
| LinkExtractor | LinkResolver | `List<ParsedLink>` | Core engine call |
| LinkResolver | BacklinksPanel | `List<Link>` | Riverpod Provider |
| LinkResolver | GraphPage | `List<Link>` | Riverpod Provider |
| ThinkScene | ContextAssembler | `List<ContextRef>` | Core engine call |
| ContextAssembler | ai_service | `String` (assembled prompt) | Service call |
| SyncService | SyncProgress | `SyncState` | Riverpod Provider |

### 5.2 状态隔离原则

```
错误示例（避免）：
  SettingsPage 直接修改 ai_service 的内部状态

正确做法：
  SettingsPage → aiSettingsProvider → ai_service.updateConfig()
                                    → SettingsPage 通过 aiSettingsProvider 观察变化
```

不同变更原因的状态必须在不同 Provider 中 (A-4)：
- `aiSettingsProvider` — AI 配置 (API URL, Key, Model)
- `themeProvider` — 主题配置 (暗色/亮色, 强调色)
- `syncSettingsProvider` — 同步配置 (Git/WebDAV)
- `shortcutSettingsProvider` — 快捷键配置

---

## 6. 数据流绑定规范

### 6.1 Provider 绑定模板

每个 Page 组件必须遵循以下模板：

```dart
class XxxPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(xxxPageProvider);     // 1. 观察状态
    final notifier = ref.read(xxxPageProvider.notifier); // 2. 获取操作接口

    // 3. 根据状态渲染 UI（包含 loading / error / empty / data 四种状态）
    return switch (state) {
      AsyncLoading() => const CircularProgressIndicator(),
      AsyncError(:final error) => ErrorBanner(
        message: error.toString(),
        onDismiss: () => notifier.clearError(), // U-1
      ),
      AsyncData(:final value) when value.isEmpty => EmptyStateGuide(...), // UX-2
      AsyncData(:final value) => RealContent(data: value),
    };
  }
}
```

### 6.2 Loading / Error / Empty / Data 四态处理

```
每个数据驱动的组件必须覆盖四种状态：
┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐
│ Loading  │  │  Error   │  │  Empty   │  │  Data    │
│ Skeleton │  │ + Dismiss│  │ + CTA    │  │ 正常渲染  │
└──────────┘  └──────────┘  └──────────┘  └──────────┘
   C-1 防护      U-1 必须     UX-2 必须     核心逻辑
```

---

## 7. 性能与安全约束

### 7.1 性能约束清单

| ID | 约束 | 检查方式 |
|----|------|---------|
| P-1 | 拖拽/输入不实时写盘，debounce 500ms | Code review |
| P-2 | shouldRepaint 严格数据比较 | `flutter analyze` + test |
| P-3 | SharedPreferences 实例缓存 | Code review |
| UX-4 | AI 流式输出不阻塞 UI 线程 | Manual test |

### 7.2 安全约束清单

| ID | 约束 | 检查方式 |
|----|------|---------|
| S-1 | WebView 过滤 dangerous URL schemes | `shouldOverrideUrlLoading` 检查 |
| S-2 | API Key 使用 flutter_secure_storage | 不在 State 对象中存储 Key |
| S-3 | 文件路径 normalize + validate | 禁止 `..` 逃逸 |

### 7.3 Flutter API 兼容约束

| ID | 约束 | 说明 |
|----|------|------|
| F-1 | DropdownButtonFormField.value 加 ignore 注释 | Flutter 3.41+ |
| F-2 | Matrix4 直接设 entry | translate/scale 已废弃 |
| F-7 | 不在 build() 中无条件赋值 TextEditingController.text | 使用 initState / didChangeDependencies |

---

## 8. 风险与缓解

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|----------|
| UI 对接工作量被低估（40+ 组件） | 高 | Phase 延期 | 按 P0→P1→P2 分批，P0 先交付 |
| flutter_inappwebview 平台兼容问题 | 中 | 浏览器页受阻 | 抽象 WebView 接口层，备选 webview_flutter |
| HNSW 向量精度不达标 | 中 | 搜索体验差 | Phase 3 先跑 benchmark |
| Ollama/OpenAI API 不稳定 | 中 | AI 功能不可用 | 3 次重试 + 降级提示 |
| Git 同步冲突 | 低 | 数据丢失 | 同步前自动备份 |
| 跨平台打包 | 低 | Phase 4 延期 | Phase 1-3 仅聚焦 Windows |

---

## 9. 可验证标准

### 9.1 Phase 目标验证矩阵

```
Phase 1「血肉填充」: 所有页面从 Placeholder → 真实数据绑定
  ✅ 每个 Page 至少有 1 个 Riverpod Provider 绑定
  ✅ 每个 Widget 至少 1 个数据流路径到其他组件 (A-1)
  ✅ 所有 catch 块有 ErrorBanner + dismiss 按钮 (U-1)
  ✅ 空状态有 CTA 引导 (UX-2)
  ✅ flutter analyze 0 issues
  ✅ 53+ 测试全部通过

Phase 2「短板补齐」: 存根服务完善 + 质量加固
  ✅ embedding_service 可调用并返回向量
  ✅ shortcut_service 满足 UX-7 (Top 5)
  ✅ Domain "Solid" 阶段条件全部满足

Phase 3「高级特性」: 创新引擎实施
  ✅ HNSW recall@10 > 0.9
  ✅ AI 流式无 UI jank
  ✅ Plugin 沙箱通过 chaos test

Phase 4「生产就绪」: CI/CD + E2E + 发布
  ✅ CI pipeline < 10 min
  ✅ E2E 覆盖 5 条关键用户旅程
  ✅ Windows/macOS/Linux 三平台包
```

### 9.2 设计验证测试用例

```dart
// test/architecture/data_flow_test.dart
test('BrowserPage → CaptureScene: clip data flows through Riverpod', () {
  final container = createContainer();
  final browserNotifier = container.read(browserPageProvider.notifier);
  final captureState = container.read(captureSceneProvider);

  browserNotifier.clipSelection('selected text', 'https://example.com');
  
  expect(captureState.pendingClip, isNotNull);
  expect(captureState.pendingClip!.text, 'selected text');
});

test('EditorPage → LinkExtractor: wikilinks extracted on save', () {
  final editor = EditorPageState(
    note: Note(content: 'See [[Other Note]] for details'),
  );
  
  final links = LinkExtractor.extract(editor.note.content);
  
  expect(links.length, 1);
  expect(links.first.target, 'Other Note');
});

test('GraphPage nodes: auto links vs manual links visually distinct (A-6)', () {
  final autoEdge = GraphEdge(type: EdgeType.autoDiscovered);
  final manualEdge = GraphEdge(type: EdgeType.manual);
  
  expect(autoEdge.style.dashPattern, isNotNull);
  expect(manualEdge.style.dashPattern, isNull);
});
```

---

> **关联文档**:
> - 开发计划: [next-phase-dev-plan.md](./next-phase-dev-plan.md)
> - 产品愿景: [01-product-vision.md](./01-product-vision.md)
> - 当前架构: [02-architecture.md](./02-architecture.md)
> - UX 重构设计案: [ux-redesign-spec.md](./ux-redesign-spec.md)
