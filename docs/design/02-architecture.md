# RFBrowser — 系统架构

---

## 整体分层

```
┌─────────────────────────────────────────────────────────────┐
│                    Presentation Layer                        │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐      │
│  │ Browser  │ │ Editor   │ │  Graph   │ │ Canvas   │      │
│  │  View    │ │  View    │ │  View    │ │  View    │      │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘      │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐      │
│  │ AI Chat  │ │ Agent    │ │ Settings │ │ Welcome  │      │
│  │  Panel   │ │ Monitor  │ │  View    │ │  Page    │      │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘      │
├─────────────────────────────────────────────────────────────┤
│                    Service Layer                             │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐      │
│  │ Browser  │ │Knowledge │ │   AI     │ │  Agent   │      │
│  │ Service  │ │ Service  │ │ Service  │ │ Service  │      │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘      │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐      │
│  │  Git     │ │ WebDAV   │ │ Clipper  │ │  Skill   │      │
│  │  Sync    │ │  Sync    │ │ Service  │ │ Service  │      │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘      │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐      │
│  │ Shortcut │ │ Settings │ │ Plugin   │ │ QuickMove│      │
│  │ Service  │ │ Service  │ │ Registry │ │ Service  │      │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘      │
├─────────────────────────────────────────────────────────────┤
│                    Core Engine Layer                         │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐      │
│  │ Markdown │ │  Link    │ │  Graph   │ │ Context  │      │
│  │Highlighter│ │Resolver │ │ Engine   │ │ Assembler│      │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘      │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐                    │
│  │ Editor   │ │  Model   │ │  Canvas  │                    │
│  │Controller│ │ Discovery│ │  Model   │                    │
│  └──────────┘ └──────────┘ └──────────┘                    │
├─────────────────────────────────────────────────────────────┤
│                    Data Layer                                │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐      │
│  │  Note    │ │  Index   │ │  Vault   │ │  Sync    │      │
│  │Repository│ │  Store   │ │  Store   │ │  Store   │      │
│  │(Markdown)│ │ (SQLite) │ │(Metadata)│ │ (Conflict)│      │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘      │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐                    │
│  │  Vector  │ │  HNSW    │ │QuickMove │                    │
│  │  Store   │ │  Index   │ │  Store   │                    │
│  └──────────┘ └──────────┘ └──────────┘                    │
├─────────────────────────────────────────────────────────────┤
│                    Platform Layer                            │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐      │
│  │ Inline   │ │ Headless │ │  Window  │ │  Secure  │      │
│  │ WebView  │ │ WebView  │ │  Manager │ │  Store   │      │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘      │
└─────────────────────────────────────────────────────────────┘
```

### 模块依赖关系

```
Presentation ──→ Service ──→ Core Engine ──→ Data ──→ Platform
     │              │              │            │          │
     └──────────────┴──────────────┴────────────┴──────────┘
                     Riverpod (响应式依赖注入 + 跨层通信)
```

---

## 项目结构

```
rfbrowser/
├── lib/
│   ├── main.dart
│   ├── app.dart                          # MaterialApp + 主题 + Vault 初始化
│   ├── l10n/                             # 国际化
│   │   ├── app_en.arb
│   │   ├── app_zh.arb
│   │   ├── app_localizations.dart
│   │   ├── app_localizations_en.dart
│   │   └── app_localizations_zh.dart
│   │
│   ├── core/                             # 核心引擎（纯 Dart，无 Flutter 依赖）
│   │   ├── context/                      #   AI 上下文组装
│   │   │   ├── assembler.dart            #     上下文组装器
│   │   │   ├── content_extractor.dart    #     内容提取
│   │   │   ├── priority_ranker.dart      #     上下文优先级排序
│   │   │   ├── reference_parser.dart     #     @引用 解析
│   │   │   └── token_budget.dart         #     Token 预算管理
│   │   ├── editor/                       #   编辑器引擎
│   │   │   ├── highlighted_text_editing_controller.dart
│   │   │   ├── markdown_highlighter.dart
│   │   │   └── sync_scroll_controller.dart
│   │   ├── graph/                        #   图谱引擎
│   │   │   ├── filter_engine.dart        #     链接过滤
│   │   │   ├── graph_algorithm.dart      #     图算法
│   │   │   └── layout_engine.dart        #     力导向布局
│   │   ├── link/                         #   链接引擎
│   │   │   ├── link_extractor.dart       #     [[wiki-link]] 提取
│   │   │   └── link_resolver.dart        #     链接解析 + 标题索引
│   │   └── model/                        #   模型路由
│   │       ├── ai_provider.dart          #     AI Provider/Model 配置
│   │       ├── canvas_model.dart         #     画布数据模型
│   │       └── model_discovery.dart      #     模型自动发现
│   │
│   ├── services/                         # 服务层（业务逻辑）
│   │   ├── browser_service.dart          #   标签页管理
│   │   ├── knowledge_service.dart        #   笔记 CRUD + 链接 + 索引
│   │   ├── ai_service.dart               #   AI 聊天 + 流式响应
│   │   ├── agent_service.dart            #   多步骤 Agent 执行
│   │   ├── git_sync_service.dart         #   Git 同步
│   │   ├── webdav_sync_service.dart      #   WebDAV 同步
│   │   ├── clipper_service.dart          #   网页剪藏（整页/选中/书签）
│   │   ├── canvas_service.dart           #   画布状态管理
│   │   ├── skill_service.dart            #   Skills 管理
│   │   ├── quick_move_service.dart       #   Quick Move 管理
│   │   ├── shortcut_service.dart         #   快捷键配置
│   │   ├── settings_service.dart         #   应用设置 + AI 配置
│   │   ├── connectivity_service.dart     #   在线/离线 + 同步队列
│   │   ├── embedding_service.dart        #   向量嵌入
│   │   ├── template_service.dart         #   笔记模板
│   │   ├── plugin_registry_service.dart  #   插件注册
│   │   ├── update_check_service.dart     #   更新检查
│   │   ├── tantivy_bridge.dart           #   全文搜索桥接
│   │   └── database_init.dart            #   数据库初始化
│   │
│   ├── data/                             # 数据层
│   │   ├── stores/                       #   数据存储
│   │   │   ├── vault_store.dart          #     Vault 元数据
│   │   │   ├── index_store.dart          #     SQLite 全文索引
│   │   │   ├── sync_store.dart           #     同步状态
│   │   │   ├── quick_move_store.dart     #     Quick Move 持久化
│   │   │   ├── hnsw_index.dart           #     向量相似度检索
│   │   │   └── vector_store.dart         #     向量存储
│   │   ├── models/                       #   数据模型
│   │   │   ├── note.dart
│   │   │   ├── link.dart
│   │   │   ├── link_type.dart
│   │   │   ├── agent_task.dart
│   │   │   ├── skill.dart
│   │   │   ├── quick_move.dart
│   │   │   ├── browser_tab.dart
│   │   │   ├── web_clip.dart
│   │   │   ├── drag_data.dart
│   │   │   ├── graph_stat.dart
│   │   │   ├── context_assembly.dart
│   │   │   ├── sync_conflict.dart
│   │   │   ├── tab_group_proposal.dart
│   │   │   └── unlinked_mention.dart
│   │   └── repositories/                 #   数据仓库
│   │       └── note_repository.dart      #     笔记读写（Markdown ↔ SQLite）
│   │
│   ├── platform/                         # 平台层
│   │   └── webview/
│   │       ├── agent_webview.dart        #   内联 WebView
│   │       └── headless_manager.dart     #   无头浏览器管理器
│   │
│   ├── plugins/                          # 插件系统
│   │   ├── host/
│   │   │   └── plugin_host.dart          #   插件宿主
│   │   ├── api/
│   │   │   └── plugin_api.dart           #   插件 API 定义
│   │   └── builtin/                      #   内置插件
│   │       └── dataview/                 #     Dataview 查询引擎
│   │           ├── dql_parser.dart
│   │           ├── query_engine.dart
│   │           └── result_renderer.dart
│   │
│   └── ui/                               # UI 层
│       ├── pages/
│       │   ├── browser_page.dart
│       │   ├── editor_page.dart
│       │   ├── graph_page.dart
│       │   ├── canvas_page.dart
│       │   ├── ai_chat_panel.dart
│       │   ├── settings_page.dart
│       │   ├── welcome_page.dart
│       │   └── settings/                 #   设置子模块
│       │       ├── ai_settings_section.dart
│       │       ├── theme_settings_section.dart
│       │       ├── sync_settings_section.dart
│       │       ├── shortcut_settings_section.dart
│       │       ├── quick_moves_settings_section.dart
│       │       ├── editor_settings_section.dart
│       │       ├── language_settings_section.dart
│       │       ├── component_settings_section.dart
│       │       └── about_section.dart
│       ├── widgets/
│       │   ├── command_bar.dart          #   命令/搜索栏
│       │   ├── note_sidebar.dart         #   笔记列表
│       │   ├── backlinks_panel.dart      #   反向链接面板
│       │   ├── tab_group_sidebar.dart    #   标签页分组
│       │   ├── agent_monitor.dart        #   Agent 监控
│       │   ├── split_pane.dart           #   可拖拽分割面板
│       │   ├── graph_stats_card.dart     #   图谱统计
│       │   ├── create_note_dialog.dart
│       │   ├── create_quick_move_dialog.dart
│       │   ├── settings_dialogs.dart
│       │   ├── settings_section.dart
│       │   ├── sync_conflict_dialog.dart
│       │   ├── sync_progress.dart
│       │   └── color_picker_dialog.dart
│       ├── theme/
│       │   └── app_theme.dart
│       └── layout/
│           └── main_layout.dart         #   主布局（工具栏 + 分屏 + 状态栏）
│
├── test/                                 # 测试
├── android/                              # Android 平台
├── linux/                                # Linux 平台
├── windows/                              # Windows 平台
│
├── docs/                                 # 设计文档
│   └── design/
│       ├── 01-product-vision.md
│       ├── 02-architecture.md
│       ├── 03-data-models.md
│       ├── 04-core-engines.md
│       └── 05-services.md
│
├── .github/
│   ├── workflows/ci.yml                  # CI/CD 管道
│   └── ISSUE_TEMPLATE/                   # Issue 模板
│
├── AGENTS.md                             # AI Agent 工作规则
├── CONTRIBUTING.md                       # 贡献指南
├── CODE_OF_CONDUCT.md                    # 行为准则
├── LICENSE                               # MIT 许可证
├── pubspec.yaml
└── README.md
```

---

## 技术栈汇总

| 层次 | 技术 | 用途 |
|------|------|------|
| **UI 框架** | Flutter 3.x | 跨平台 UI |
| **语言** | Dart 3.x | 主开发语言 |
| **浏览器** | flutter_inappwebview | WebView 集成（Chromium/WebKit） |
| **Markdown** | markdown + flutter_markdown | 解析和渲染 |
| **数据库** | SQLite (sqflite) | 全文索引和链接查询 |
| **缓存** | Hive | 本地键值缓存 |
| **向量搜索** | HNSW + 向量存储 | 语义搜索 |
| **Git** | git CLI | 版本控制同步 |
| **WebDAV** | Dio HTTP client | WebDAV 同步 |
| **AI 云端** | Dio | OpenAI-compatible API |
| **状态管理** | Riverpod | 响应式状态 + 代码生成 |
| **路由** | go_router | 声明式路由（已引入，暂未重度使用） |
| **国际化** | Flutter gen-l10n + ARB | 中英双语 |
| **图谱渲染** | CustomPainter + Canvas | 力导向图 + 环形布局 |
| **文件监听** | watcher | Markdown 文件变更检测 |
| **安全存储** | flutter_secure_storage | API Key 加密存储 |
| **窗口管理** | window_manager | 桌面窗口控制 |
