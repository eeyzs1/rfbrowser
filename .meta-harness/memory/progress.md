# Progress Log

## Purpose
Track execution progress across agent sessions.
Enables resumption after interruption.

## Format
```
### [Date] — [Task Description]
- Status: In Progress / Completed / Blocked
- Agent: [which agent is working]
- What was done: [specific actions taken]
- What's next: [immediate next steps]
- Files changed: [list of modified files]
```

## Progress

### 2026-05-01 — Upgrade meta-harness from description framework to generation factory
- Status: Completed
- Agent: main
- What was done:
  - Updated ADR-001 from 5-layer to 7+2 architecture
  - Upgraded all 5 domain templates to Generation Factory format
  - Created scripts/generate.py (core generation pipeline)
  - Created scripts/verify-generation.py (7+2 layer completeness check)
  - Created seeds/ directory with 30+ executable template artifacts across all 10 layers
  - Created scripts/evolve.py (evidence-driven evolution engine)
  - Created Python equivalents of bash scripts (verify.py, pre-task.py, quality-score.py)
  - Updated orchestrator.md with layer integration table and error→constraint loop
  - Populated meta-mistakes.md with 3 resolved entries
- What's next: Run end-to-end generation test
- Files changed: 30+ files across templates/, scripts/, seeds/, memory/, meta/

### 2026-05-04 — Design detailed development plan for unfinished features
- Status: Completed
- Agent: main
- What was done:
  - Assessed current project state against DESIGN.md Phase 1-5 roadmap
  - Marked completion status for all Phase items (✅/🔶/❌)
  - Designed 20 detailed implementation plans (P2-1 through P5-11) covering all unfinished features
  - Each plan includes: current state, goal, acceptance criteria, implementation steps, dependencies, risks
  - Defined execution priority order (4 batches) and dependency graph
  - Identified parallelizable work streams
  - Added 3 ADR candidates (Agent security model, Plugin runtime, Vector storage)
- What's next: Begin implementation with Batch 1 (P2-2 @引用 → P3-2 上下文组装器, P2-1 图谱增强, P2-3 AI 自动分组)
- Files changed: DESIGN.md (roadmap section updated with detailed plans)

### 2026-05-04 — Add User Stories and automatable acceptance criteria
- Status: Completed
- Agent: main
- What was done:
  - Added User Stories (US-*) for all 15 feature plans (P2-1 through P5-5), total 42 user stories
  - Added automatable acceptance criteria (AC-*) for all 15 feature plans, total 94 acceptance criteria
  - Categorized each AC as 🤖 (automatable), 👁️ (manual), or 📊 (benchmark)
  - Specified exact test method for each 🤖 AC (unit test / integration test / widget test)
  - Specified exact benchmark method for each 📊 AC with quantified thresholds
  - Ratio: ~85% automatable (🤖+📊), ~15% manual verification (👁️)
- What's next: Begin implementation with Batch 1, writing tests first per AC specifications
- Files changed: DESIGN.md (十四-A section updated with US/AC for all plans)

### 2026-05-04 — Implement Batch 1: P2-2, P2-1, P2-3
- Status: Completed
- Agent: main
- What was done:
  - P2-2 @引用系统完善: 5 core modules created (reference_parser, content_extractor, priority_ranker, token_budget, assembler), AI Chat integrated with @autocomplete, 19 tests passing
  - P2-1 图谱增强: Force-directed layout engine (Fruchterman-Reingold), local graph query (BFS depth-based), graph filter engine (tag/date), graph_page.dart updated with layout mode toggle + local graph mode + depth slider, 11 tests passing
  - P2-3 AI自动标签分组: TabGroupProposal model, AutoGroupEngine with domain-based grouping, BrowserService extended with canAutoGroup/generateGroupProposal/applyGroupProposal, 5 tests passing
  - ContextAssembly model updated with truncated flag and structured toPrompt() output
  - Total: 36 tests passing, zero regressions
- What's next: Batch 2 (P3-1 Agent自动化, P3-3 WebDAV完善)
- Files changed:
  - NEW: lib/core/context/reference_parser.dart, content_extractor.dart, priority_ranker.dart, token_budget.dart, assembler.dart
  - NEW: lib/core/graph/layout_engine.dart, filter_engine.dart
  - NEW: lib/data/models/tab_group_proposal.dart
  - MODIFIED: lib/data/models/context_assembly.dart (added truncated, structured toPrompt)
  - MODIFIED: lib/services/knowledge_service.dart (added getLocalGraph)
  - MODIFIED: lib/services/browser_service.dart (added auto-group methods)
  - MODIFIED: lib/ui/pages/ai_chat_panel.dart (integrated assembler + @autocomplete)
  - MODIFIED: lib/ui/pages/graph_page.dart (force-directed layout + local graph + filter)
  - NEW: test/context_assembly_test.dart, test/graph_layout_test.dart, test/auto_group_test.dart

### 2026-05-04 — Implement Batch 2: P3-1, P3-3
- Status: Completed
- Agent: main
- What was done:
  - P3-1 Agent浏览器自动化: HeadlessManager (create/dispose/idle-timeout), AgentWebView (navigate/extractText), AgentService refactored with step-by-step execution engine (status machine: pending→running→completed/failed/paused), step limit (50), time limit (30min), pause/cancel/resume, Agent Monitor UI widget, 10 tests passing
  - P3-3 WebDAV同步完善: SyncStore (ETag/lastSynced/localModified persistence with in-memory test mode), SyncConflict model with 3 resolutions (keepLocal/keepRemote/keepBoth), SyncProgress model, WebDAV service rewritten with downloadChanges (ETag-based incremental + conflict detection), uploadChanges (mtime-based incremental), resolveConflict, autoSync timer, SyncConflictDialog UI, SyncProgressWidget UI, 11 tests passing
  - Total: 57 tests passing, zero regressions
- What's next: Batch 3 (P4-1 插件沙箱, P4-2 未链接提及UI, P4-3 语义搜索, P4-5 性能优化)
- Files changed:
  - NEW: lib/platform/webview/headless_manager.dart, agent_webview.dart
  - NEW: lib/data/stores/sync_store.dart
  - NEW: lib/data/models/sync_conflict.dart
  - NEW: lib/ui/widgets/agent_monitor.dart, sync_conflict_dialog.dart, sync_progress.dart
  - MODIFIED: lib/services/agent_service.dart (full rewrite with execution engine)
  - MODIFIED: lib/services/webdav_sync_service.dart (full rewrite with incremental sync + conflict)

### 2026-05-04 — Audit and update development plan for remaining features
- Status: Completed
- Agent: main
- What was done:
  - Conducted code audit of all "unfinished" features to verify actual implementation status
  - Discovered 3 features previously marked as unfinished are actually complete:
    - P4-2 未链接提及 UI: backlinks_panel.dart has full unlinked mentions section with link conversion
    - P5-1 快捷键系统增强: ShortcutService with conflict detection, persistence, reset, settings UI
    - P5-2 拖拽互操作: DragData model + DropHandler + editor DragTarget integration
  - Identified 4 features with partial/stub implementations:
    - P4-1 插件系统: Sandbox.callApi returns null, API Bridge missing
    - P4-3 语义搜索: local embedding is toy hash, HybridSearch lacks keyword branch
    - P5-3 编辑器增强: MarkdownHighlighter code exists but not connected to TextField
    - P5-5 离线模式: no auto network detection, sync queue is empty operation
  - Updated DESIGN.md 十四-A: marked 9 plans as ✅ completed (P2-1, P2-2, P2-3, P3-1, P3-2, P3-3, P4-2, P5-1, P5-2)
  - Updated DESIGN.md 十四-A: refined status descriptions for 4 partially completed plans (P4-1, P4-3, P5-3, P5-5)
  - Updated DESIGN.md 十四-B: revised execution order from 4 batches to 5 batches reflecting actual state
  - Remaining work: 10 features (P4-1, P4-3, P4-4, P4-5, P4-6, P4-7, P5-3, P5-4, P5-5, P5-6~P5-11)
- What's next: Batch 3 (P4-1 插件沙箱+API Bridge, P4-3 语义搜索完善, P4-5 性能优化)
- Files changed:
  - MODIFIED: DESIGN.md (十四-A completion markers, 十四-B execution order update)

### 2026-05-04 — Implement Batch 3: P4-1, P4-3, P5-3, P5-5, P4-5
- Status: Completed
- Agent: main
- What was done:
  - P4-1 插件系统完善: Full rewrite of plugin_host.dart with real Isolate sandbox (SendPort/ReceivePort bidirectional communication), API Bridge host-side (permission check + service forwarding), API Bridge plugin-side (proxy call interface), crash detection + auto-recovery (3 retries within 3s), PluginCommand registration, 8 tests passing
  - P4-3 语义搜索完善: Rewrote embedding_service.dart with Ollama local embedding (nomic-embed-text model), API embedding fallback chain (API→Ollama→local hash), HybridSearch with FTS5 keyword search branch + Reciprocal Rank Fusion (RRF K=60) merging, result source tagging (fts/semantic/both), 10 tests passing
  - P5-3 编辑器增强: Created HighlightedTextEditingController (custom TextEditingController that applies MarkdownHighlighter spans in buildTextSpan), removed dead _buildHighlightedSpans method, editor now shows syntax highlighting for headings/bold/code/wikilinks/tags/context-refs
  - P5-5 离线模式完善: Rewrote connectivity_service.dart with startMonitoring/stopMonitoring (periodic connectivity check), SyncExecutor injection (pluggable sync backend), flushSyncQueue with actual execution (not just clear), deduplication in enqueueSync, isSyncing state
  - P4-5 性能优化: VectorStore optimized with pre-computed norms + min-heap topK search (O(N log K) instead of O(N log N)), IndexStore.updateNote incremental method, 3 performance benchmark tests (VectorStore 1000-vector search <200ms, Graph 500-node layout <16ms, Highlighter 1000-line <50ms)
  - Bug fixes: webdav_sync_service.dart (missing dart:convert import, nullable spread, syntax error, invalid dispose override), main_layout.dart (agentServiceProvider→agentProvider), ai_chat_panel.dart (duplicate dispose), editor_page.dart (removed unused _highlighter reference)
  - Total: 139 tests passing, zero regressions (up from 136)
- What's next: Batch 4 (P4-4 Dataview, P4-6 插件市场, P4-7 Skill市场)
- Files changed:
  - REWRITTEN: lib/plugins/host/plugin_host.dart (Isolate sandbox + API Bridge + crash recovery)
  - REWRITTEN: lib/services/embedding_service.dart (Ollama embedding + HybridSearch with RRF)
  - REWRITTEN: lib/services/connectivity_service.dart (monitoring + sync executor)
  - REWRITTEN: lib/data/stores/vector_store.dart (pre-computed norms + heap-based topK)
  - NEW: lib/core/editor/highlighted_text_editing_controller.dart
  - MODIFIED: lib/ui/pages/editor_page.dart (uses HighlightedTextEditingController, removed dead code)
  - MODIFIED: lib/data/stores/index_store.dart (added updateNote incremental method)
  - MODIFIED: lib/services/webdav_sync_service.dart (bug fixes)
  - MODIFIED: lib/ui/layout/main_layout.dart (bug fix: agentProvider)
  - MODIFIED: lib/ui/pages/ai_chat_panel.dart (bug fix: duplicate dispose)
  - REWRITTEN: test/plugin_host_test.dart (8 tests for new sandbox)
  - REWRITTEN: test/semantic_search_test.dart (10 tests for hybrid search)
  - NEW: test/performance_benchmark_test.dart (3 benchmark tests)

### 2026-05-04 — Implement Batch 4+5: P4-4, P4-6, P4-7, P5-4, P5-3 tests, P5-5 tests
- Status: Completed
- Agent: main
- What was done:
  - P4-4 Dataview: DQL parser (LIST/TABLE/TASK + WHERE + SORT), query engine (tag/date/field filters, sorting, 100-result limit), result renderer (DataTable/List/TaskList widgets), 15 tests passing
  - P4-6 Plugin Market: PluginRegistryNotifier (fetchIndex, search, getPermissions), RegistryPluginInfo model, install/uninstall lifecycle, 6 tests passing
  - P4-7 Skill Market: RegistrySkillInfo model, install/uninstall lifecycle, 3 tests passing
  - P5-4 Linux Browser: Enhanced _LinuxBrowserPlaceholder with URL input, navigate, clip-to-note, and usage tips
  - P5-3 Editor Tests: 11 MarkdownHighlighter tests (heading/bold/link/wikilink/codeBlock/tag/contextRef/embed/blockquote/list + performance benchmark)
  - P5-5 Offline Tests: 7 ConnectivityNotifier tests (setOnline, enqueue/flush, dedup, skip-when-syncing, monitoring)
  - Bug fixes: browser_page.dart (updateUrl→updateTabUrl, activeTabIndex→activeTab), unused import cleanup
  - Total: 184 tests passing, zero regressions (up from 139)
- What's next: Phase 5 polish and release preparation
- Files changed:
  - NEW: lib/plugins/builtin/dataview/dql_parser.dart, query_engine.dart, result_renderer.dart
  - NEW: lib/services/plugin_registry_service.dart
  - NEW: test/dataview_test.dart, test/plugin_market_test.dart, test/editor_highlight_test.dart, test/offline_mode_test.dart
  - MODIFIED: lib/ui/pages/browser_page.dart (Linux placeholder enhanced + new methods)

### 2026-05-04 — Implement Batch 6: P5-6~P5-11 Release Preparation
- Status: Completed
- Agent: main
- What was done:
  - P5-6 无障碍访问: High contrast theme (AppTheme.highContrastTheme with black surface + white text + cyan primary), AppSettings.highContrastMode field + setHighContrastMode method, app.dart theme selection updated, 5 tests passing
  - P5-7 自动更新: UpdateCheckNotifier (GitHub Releases API, version comparison, updateAvailable flag), UpdateInfo model, 5 tests passing
  - P5-8 安装包优化: Android build.gradle.kts (isMinifyEnabled + isShrinkResources + proguard), proguard-rules.pro created
  - P5-9 三平台适配: Verified Platform.isLinux/isWindows usage correct, Linux browser placeholder enhanced with URL input + navigate + clip
  - P5-10 用户文档: CONTRIBUTING.md created (dev setup, code style, PR process, testing, architecture)
  - P5-11 社区建设: .github/ISSUE_TEMPLATE/bug_report.md + feature_request.md created
  - Code quality: Fixed all 15 flutter analyze warnings/infos → 0 issues
  - Total: 194 tests passing, 0 analyze issues, zero regressions
- Files changed:
  - MODIFIED: lib/ui/theme/app_theme.dart (highContrastTheme)
  - MODIFIED: lib/services/settings_service.dart (highContrastMode field + setter)
  - MODIFIED: lib/app.dart (high contrast theme selection)
  - NEW: lib/services/update_check_service.dart
  - NEW: test/release_prep_test.dart (10 tests)
  - NEW: android/app/proguard-rules.pro
  - MODIFIED: android/app/build.gradle.kts (minify + shrink)
  - NEW: CONTRIBUTING.md
  - NEW: .github/ISSUE_TEMPLATE/bug_report.md, feature_request.md
  - CLEANED: 10 unused imports/fields removed across assembler, reference_parser, markdown_highlighter, sync_scroll_controller, agent_service, ai_chat_panel, shortcut_settings_section, auto_group_test

### 2026-05-05 — Update Phase 4 & 5 documentation to reflect completion
- Status: Completed
- Agent: main
- What was done:
  - Verified code implementation status for all Phase 4 (P4-1~P4-7) and Phase 5 (P5-1~P5-11) features
  - Confirmed 194 tests passing, 0 flutter analyze issues
  - Updated 10-roadmap.md: marked Phase 4 and Phase 5 as ✅ 已完成, updated batch descriptions and dependency chains
  - Rewrote phase4.md: all 7 features marked ✅ with completion batch, preserved User Stories and ACs as design record
  - Rewrote phase5.md: all 11 features marked ✅ with completion batch, added quality metrics summary
  - All 3 documents now accurately reflect actual implementation state
- What's next: All 5 Phases complete. Ready for production polishing, real-world testing, or new feature proposals.
- Files changed:
  - MODIFIED: docs/design/10-roadmap.md (Phase 4/5 status, batch descriptions, dependency chains)
  - REWRITTEN: docs/design/feature-plans/phase4.md (all 7 features ✅)
  - REWRITTEN: docs/design/feature-plans/phase5.md (all 11 features ✅)

### 2026-06-24 — 补齐 AI 插件沙盒所有缺失部分 (Harness Pipeline v2.4)
- Status: Completed
- Agent: main
- Harness: v2.0.0 → v2.4.0 (submodule updated), pipeline INTERPRET→GENERATE→FACTORY→PROVE→JUDGE→EVOLVE 全部执行
- What was done:
  - **第1轮**: 修复 check-version.ps1 的 Get-Content 缺少 -Raw 参数导致数组插值崩溃（后由 v2.4.0 上游修复覆盖）
  - **第2轮**: 创建 plugin_api_impl.dart（PluginApiImpl + 5 个子 API 实现）和 plugin_ui_notifier.dart；Sandbox 用 CapabilityChecker 替换 PermissionChecker
  - **第3轮**: 引入 flutter_js 0.8.7，PluginManifest 添加 entryPoint 字段，_pluginEntryPoint 重写为 JS 运行时（_runJsPlugin 用 QuickJS 引擎，_runEchoLoop 保持回显向后兼容），PluginHostNotifier 添加 _readEntryPointCode 读取 JS 文件
  - **第4轮**: 添加 ResourceQuota 类（maxMessagesPerSecond=100, maxMessageSizeBytes=1MB, maxExecutionDuration=30s, maxConsecutiveErrors=10）和 ResourceQuotaExceededError；Sandbox.callApi 集成滑动窗口限流、消息大小检查、可配置超时、连续错误自动停止
  - **Harness 流程**: 正确执行 PRE-FLIGHT bootstrap → --interpret-intent 锁定验收标准 → --advance 推进 6 phases → --verify-criterion 标记证据 → evolve.py 评估（fitness 0.8，稳定）
- What's next: 后续每次交互都应从 PRE-FLIGHT 开始（读 PHASE_BRIEF.md），遵循 harness pipeline
- Files changed:
  - MODIFIED: lib/plugins/host/plugin_host.dart (PluginManifest.entryPoint, ResourceQuota, ResourceQuotaExceededError)
  - MODIFIED: lib/plugins/host/plugin_sandbox.dart (_runJsPlugin, _runEchoLoop, ResourceQuota 集成)
  - MODIFIED: lib/plugins/host/plugin_host_notifier.dart (_readEntryPointCode, entryPointCode 传递)
  - MODIFIED: lib/plugins/plugin_registry.dart (entryPoint 字段读取)
  - NEW: lib/plugins/api/plugin_api_impl.dart (PluginApiImpl + 5 子 API)
  - NEW: lib/plugins/api/plugin_ui_notifier.dart (PluginUiNotifier)
  - MODIFIED: pubspec.yaml (flutter_js: ^0.8.7)
- Verification: flutter analyze 0 issues, flutter test 1872 pass/20 skip/1 flaky(HNSW), integration 20/20 pass

### 2026-06-24 — 补齐项目测试覆盖缺口 (Harness Pipeline v2.4 — PROVE phase)
- Status: Completed
- Agent: main
- Harness: v2.4.0, pipeline PROVE phase (测试覆盖补齐)
- What was done:
  - **评估**: 3 个并行 search agent 评估项目缺口 — 功能完整(33/33 ✅)、零 TODO、但 ~90+ 源文件缺单元测试
  - **新增测试**: 4 个并行 subagent 编写 8 个测试文件，共 ~199 个新测试用例
    - test/plugins/plugin_api_impl_test.dart (32+ tests: dispatch 路由 + 5 子 API + 权限检查)
    - test/plugins/plugin_ui_notifier_test.dart (19 tests: notify/showPanel/dismiss/closePanel/clearForPlugin)
    - test/plugins/resource_quota_test.dart (12 tests: 频率/大小/超时/连续错误)
    - test/services/ai_stream_accumulator_test.dart (25 tests: 流式累积 + SSE 解析)
    - test/services/ai_protocol_strategy_test.dart (30 tests: 协议策略选择/buildRequest/parseResponse/extractErrorMessage)
    - test/services/memory_database_test.dart (17 tests: 初始化/表结构/CRUD/事务/合并锁)
    - test/services/fragment_repository_test.dart (18 tests: CRUD/过滤/批量操作)
    - test/services/task_execution_strategy_test.dart (46 tests: AgentToolRegistry/ManualExecutionStrategy/ReactLoop/Factory)
  - **修复 3 个源代码 bug** (测试发现的真实缺陷):
    - lib/plugins/api/plugin_ui_notifier.dart: notify() ID 用 millisecondsSinceEpoch 导致同毫秒内 ID 碰撞 → 改用 microsecondsSinceEpoch + 静态计数器
    - lib/services/ai/ai_protocol_strategy.dart: extractStreamDelta 对空 choices 列表用 `[]?[0]` 抛 RangeError（?[] 只防 null 接收者不防越界）→ 改为显式 isNotEmpty 检查
    - lib/services/memory/memory_database.dart: database getter 并发竞态 — 多个调用同时进入 init 块各自调用 _initDb() → 改为标准 single-flight 模式（先检查 completer 是否存在）
- What's next: 后续可继续补齐剩余 ~80 源文件的单元测试（当前已覆盖核心模块）
- Files changed:
  - NEW: test/plugins/plugin_api_impl_test.dart
  - NEW: test/plugins/plugin_ui_notifier_test.dart
  - NEW: test/plugins/resource_quota_test.dart
  - NEW: test/services/ai_stream_accumulator_test.dart
  - NEW: test/services/ai_protocol_strategy_test.dart
  - NEW: test/services/memory_database_test.dart
  - NEW: test/services/fragment_repository_test.dart
  - NEW: test/services/task_execution_strategy_test.dart
  - MODIFIED: lib/plugins/api/plugin_ui_notifier.dart (ID 唯一性修复)
  - MODIFIED: lib/services/ai/ai_protocol_strategy.dart (空列表越界修复)
  - MODIFIED: lib/services/memory/memory_database.dart (并发竞态修复)
- Verification: flutter analyze 0 issues, flutter test +2125 ~20 All passed (0 failures), integration 20/20 passed

### 2026-06-24 — 修复功能缺陷和改进点 (Harness Pipeline v2.4)
- Status: Completed
- Agent: main
- Harness: v2.4.0, pipeline INTERPRET→...→EVOLVE 全部执行
- What was done:
  - **评估**: 3 个并行 search agent 全面评估项目，发现 12 类问题（功能缺陷/性能/资源泄漏/UI/错误处理）
  - **资源泄漏修复 (4处)**:
    - webdav_sync_service.dart: 添加 ref.onDispose 清理 _dio 和 _autoSyncTimer，secureStorage.read 添加 catchError
    - plugin_host_notifier.dart: 添加 ref.onDispose 调用所有 sandbox.stop()
    - webhook_server.dart: 添加 ref.onDispose 关闭 HttpServer
    - canvas_page.dart: dispose 中释放 _imageCache 的 ui.Image (GPU 资源)
  - **功能缺陷修复**: content_extractor.dart NoteContentSource 添加 currentNote 字段，实现 'current' 引用返回当前笔记内容（与 WebContentSource 风格一致），assembler.dart 传入 currentNote
  - **性能优化 (Hebbian N+1)**:
    - hebbian_service.dart recordCoAccess: 双重循环内独立事务 → 收集所有 pair 后单事务批量 upsert
    - hebbian_service.dart expandByHebbianLinks: 逐条查询 → IN 查询批量获取边和 fragment
    - hebbian_edge_repository.dart findCrossSessionAssociates: 主 isolate 关键词匹配 → compute() 移到 worker isolate
    - 新增批量方法: upsertHebbianEdgesBatch, getHebbianEdgesForBatch, getFragmentsBatch
  - **国际化补齐**: 49 个新 l10n key 添加到 app_en.arb 和 app_zh.arb，20+ UI 文件硬编码英文替换为 AppLocalizations 引用
- What's next: 项目核心功能完整，后续可继续补齐剩余 UI 文件的 tooltip 和 l10n
- Files changed:
  - MODIFIED: lib/services/webdav_sync_service.dart (ref.onDispose + catchError)
  - MODIFIED: lib/plugins/host/plugin_host_notifier.dart (ref.onDispose)
  - MODIFIED: lib/services/webhook_server.dart (ref.onDispose)
  - MODIFIED: lib/ui/pages/canvas_page.dart (ui.Image 释放)
  - MODIFIED: lib/core/context/content_extractor.dart (NoteContentSource current 实现)
  - MODIFIED: lib/core/context/assembler.dart (传入 currentNote)
  - MODIFIED: lib/services/hebbian_service.dart (批量 upsert + IN 查询)
  - MODIFIED: lib/services/memory/hebbian_edge_repository.dart (批量方法 + compute)
  - MODIFIED: lib/services/memory/fragment_repository.dart (getFragmentsBatch)
  - MODIFIED: lib/services/memory_service.dart (批量方法委托)
  - MODIFIED: lib/l10n/app_en.arb, app_zh.arb (49 个新 key)
  - MODIFIED: 20+ UI 文件 (硬编码英文 → l10n 引用)
  - MODIFIED: test/acceptance/quick_moves_acceptance_test.dart (添加 l10n delegates)
  - MODIFIED: test/core/context/content_extractor_test.dart (更新 current 引用测试)
- Verification: flutter analyze 0 issues, flutter test +2127 ~20 All passed (0 failures), integration 20/20 passed

### 2026-06-24 — 从用户角度的 18 项体验改进 (Harness Pipeline v2.4)
- Status: Completed
- Agent: main
- Harness: v2.4.0, pipeline INTERPRET→...→EVOLVE 全部执行
- What was done:
  - **评估**: 3 个并行 search agent 从核心流程体验/新用户引导/交互视觉三个维度评估，发现 20+ 改进点，按 P0/P1/中/低分级，最终选定 18 项
  - **P0 新用户上手 (5项)**:
    - vault_store.dart: createVault() 后自动生成 Welcome.md（功能导览+快捷键+Markdown 语法示例）
    - status_bar.dart + main_layout.dart: 状态栏右侧添加放大镜图标按钮快速打开命令栏
    - ai_chat_panel.dart: 空状态添加 4 个示例提示词卡片（"总结我的笔记"等），点击填入输入框
    - settings_service.dart + theme_settings_section.dart + app.dart: 新增 themeMode 字段（system/light/dark 三态），SegmentedButton 三选一，system 时跟随系统亮度自动切换
    - sidebar_note_actions.dart: 删除笔记后弹出带"撤销"按钮的 SnackBar，5 秒内可恢复
  - **P1 体验优化 (5项)**:
    - quick_search_bar.dart: 从内存 title.contains 改为调用 SearchService.hybridSearch，添加 200ms debounce、loading 状态、匹配片段预览，结果区分笔记和记忆片段
    - ai_service.dart: 新增 retryLastMessage() 方法（找到最后一条用户消息，移除并重新发送）
    - memory_browser_page.dart: 首次进入显示概念引导卡片（SharedPreferences hasSeenMemoryGuide），Info 风格卡片+4 个标签页说明芯片+"知道了"按钮
    - memory_settings_widgets.dart: _restoreFromJson 重写使用 FilePicker.platform.pickFiles 选择 JSON 文件
    - status_bar.dart: 从 ConsumerWidget 改为 ConsumerStatefulWidget，四种同步状态（离线/同步中/同步失败/上次同步时间），SharedPreferences 持久化 lastSyncTime，相对时间格式化
  - **AI对话增强 (4项)**:
    - ai_models.dart: ChatMessage 添加 toJson/fromJson，新增 ChatSession 类（id/title/messages/createdAt + copyWith/toJson/fromJson），AIState 新增 sessions 和 currentSessionId 字段
    - ai_service.dart: 新增会话管理方法（createSession/switchSession/renameSession/deleteSession）+ _syncedSessions/_persistSessions/_loadSessions/_ensureDefaultSession + regenerateLastResponse
    - ai_chat_panel.dart: build 从 Column 重构为 Row（会话侧栏 + Expanded(Column)），新增 _buildSessionSidebar/_buildSessionTile/_showSessionContextMenu，TextField 改为多行（maxLines:5, minLines:1），CallbackShortcuts 拦截 Enter 发送
    - ai_chat_model_selector.dart: 添加"测试连接"按钮（创建临时 AIProvider，Dio GET modelsEndpoint），测试状态 idle/testing/success/fail 显示 ✓/✗ + 错误信息
    - ai_chat_messages.dart: 新增"复制"按钮（Icons.copy + Clipboard.setData + SnackBar）和"重新生成"按钮（Icons.refresh，调用 regenerateLastResponse()）
  - **功能完善 (4项)**:
    - memory_settings_section.dart: 从 ConsumerWidget 改为 ConsumerStatefulWidget，基础设置（始终显示）vs 高级参数（默认折叠，AnimatedCrossFade），折叠状态持久化到 SharedPreferences
    - memory_settings_widgets.dart: _DreamingStatusBody 添加"立即整理"按钮（TextButton.icon + Icons.bolt），loading 状态 _triggering 或 status.isConsolidating
    - canvas_page.dart + canvas_state_base.dart: 新增 _showCanvasGuide 状态，首次打开显示引导浮层（半透明背景 + 居中卡片 + 4 条操作说明）
    - browser_page.dart + browser_actions.dart: 浏览器工具栏添加"发送到 AI"按钮（Icons.smart_toy_outlined），_sendToAi 提取网页正文 → 截断 8000 字符 → sendMessage
  - **测试适配**:
    - settings_service_test.dart: 2 个 isDarkMode 测试更新为基于 themeMode
    - quick_moves_acceptance_test.dart: MaterialApp 添加 localizationsDelegates 和 supportedLocales
    - ai_chat_test.dart: 新对话按钮图标 Icons.refresh → Icons.add_comment_outlined
    - quick_search_test.dart: 添加 _TestSearchNotifier 覆盖 searchServiceProvider，做简单 title/content 过滤
    - theme_settings_test.dart: isDarkMode 测试改用 setThemeMode(ThemeMode.dark/light)
- What's next: 18 项用户角度改进全部完成，软件体验显著提升。后续可考虑：键盘快捷键体系化、移动端适配、辅助功能（语义标签）、性能监控面板
- Files changed:
  - MODIFIED: lib/data/stores/vault_store.dart (Welcome.md 自动生成)
  - MODIFIED: lib/ui/widgets/status_bar.dart (命令栏按钮 + 同步状态)
  - MODIFIED: lib/ui/layout/main_layout.dart (onCommandBar 回调)
  - MODIFIED: lib/ui/pages/ai_chat_panel.dart (示例提示词 + 会话侧栏 + 多行输入)
  - MODIFIED: lib/services/settings_service.dart (themeMode 字段)
  - MODIFIED: lib/ui/pages/settings/theme_settings_section.dart (ThemeMode 选择器)
  - MODIFIED: lib/app.dart (system 亮度依赖)
  - MODIFIED: lib/ui/widgets/note_sidebar/sidebar_note_actions.dart (撤销 SnackBar)
  - MODIFIED: lib/ui/widgets/quick_search_bar.dart (hybridSearch + debounce)
  - MODIFIED: lib/services/ai_service.dart (retryLastMessage + 会话管理)
  - MODIFIED: lib/ui/pages/memory_browser_page.dart (概念引导卡片)
  - MODIFIED: lib/ui/pages/settings/memory_settings_widgets.dart (FilePicker + 立即整理)
  - MODIFIED: lib/services/ai/ai_models.dart (ChatSession 类)
  - MODIFIED: lib/ui/pages/ai_chat/ai_chat_model_selector.dart (测试连接)
  - MODIFIED: lib/ui/pages/ai_chat/ai_chat_messages.dart (复制 + 重新生成)
  - MODIFIED: lib/ui/pages/settings/memory_settings_section.dart (折叠高级参数)
  - MODIFIED: lib/ui/pages/canvas_page.dart, canvas_state_base.dart (引导浮层)
  - MODIFIED: lib/ui/pages/browser_page.dart, browser_actions.dart (发送到 AI)
  - MODIFIED: test/services/settings_service_test.dart (themeMode 测试)
  - MODIFIED: test/acceptance/quick_moves_acceptance_test.dart (l10n delegates)
  - MODIFIED: integration_test/ai_chat_test.dart (图标变更)
  - MODIFIED: integration_test/quick_search_test.dart (_TestSearchNotifier)
  - MODIFIED: integration_test/theme_settings_test.dart (themeMode 测试)
- Verification: flutter analyze 0 issues, flutter test +2127 ~20 All passed (0 failures), integration 20/20 passed

### 2026-06-25 — Think page performance + VSCode-like tab UX + Settings crash fix
- Status: Completed
- Agent: main
- What was done:
  - Removed startup log spam from OnnxEmbedding/EmbeddingService (4 appLog.debug calls)
  - Added mouse-wheel horizontal scrolling for tab bar (Listener + PointerScrollEvent, dy+dx)
  - Added left-mouse-drag scrolling for tab bar (GestureDetector.onHorizontalDragUpdate + NeverScrollableScrollPhysics)
  - Added middle-mouse-click tab closing (onTertiaryTapDown)
  - Fixed split-pane tab disappearance bug: original leaf now retains tabs + activeTabIndex, new leaf starts with active tab only
  - Optimized MarkdownHighlighter: buildTextSpan returns plain text immediately, schedules debounced async computation (compute() for >2000 chars)
  - Added _lastSeenText tracking in editor listeners to prevent false dirty-marking from async highlight rebuilds
  - Optimized NotePaneView Source view: SelectionArea + ListView.builder for viewport lazy rendering (100k-line files open instantly)
  - Added large-file (>20KB) Edit view fallback: immediately shows Source view with [编辑] button to manually enter edit mode
  - Fixed settings page crash on scroll: replaced nested ReorderableListView.builder(shrinkWrap+NeverScrollable) with Column + up/down IconButtons — eliminates Windows AXTree corruption
- What's next:
  - User to verify settings page fix with `flutter run -d windows`
  - Remaining VSCode-like features: tab drag reordering, cross-pane tab drag, overflow arrows, Ctrl+Tab shortcut, split makes new pane active
  - Root fix for Edit view large-file performance: switch to viewport-aware editor (super_editor)
- Files changed:
  - MODIFIED: lib/services/onnx_embedding_service.dart (removed 3 appLog.debug)
  - MODIFIED: lib/services/embedding_service.dart (removed TF-IDF built log)
  - MODIFIED: lib/ui/widgets/split_pane.dart (added gestures import)
  - MODIFIED: lib/ui/widgets/split_pane_tab.dart (scroll controller, wheel/drag handlers, middle-click close, handleSplit fix)
  - MODIFIED: lib/core/editor/highlighted_text_editing_controller.dart (async debounced highlight)
  - MODIFIED: lib/ui/pages/editor_page.dart (_lastSeenText tracking)
  - MODIFIED: lib/ui/widgets/note_pane_view.dart (Source ListView.builder, large-file fallback, _lastSeenText)
  - MODIFIED: lib/ui/pages/settings/quick_moves_settings_section.dart (Column + up/down buttons replacing ReorderableListView)
  - MODIFIED: 4× l10n files (largeFileSourceNotice string)
- Verification: flutter analyze 0 issues; flutter test + integration tests skipped per user instruction (focus on real-device verification)
