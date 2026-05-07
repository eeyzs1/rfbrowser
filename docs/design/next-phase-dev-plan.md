# RFBrowser — 下一阶段详细开发计划

> **依赖设计案**: [next-phase-design-spec.md](./next-phase-design-spec.md)
> **预估总工时**: 8-12 周（按单人全职计）
> **策略**: 增量交付，每个 Epic 独立可验证，高频入口先行

---

## Epic 总览

| Epic | 名称 | Phase | 优先级 | 依赖 | 预估工时 | 关键交付 |
|------|------|-------|--------|------|---------|---------|
| G1  | CommandBar 真实搜索 | P1 | P0 | 无 | 3d | 搜索实际数据，非硬编码 |
| G2  | AIChatPanel 流式对话 | P1 | P0 | 无 | 3d | 三 Provider 对话 + streaming |
| G3  | EditorPage 笔记编辑 | P1 | P0 | 无 | 3d | Markdown 编辑/高亮/保存 |
| G4  | BrowserPage 标签页管理 | P1 | P0 | 无 | 3d | WebView + 标签管理 |
| G5  | GraphPage 知识图谱 | P1 | P1 | G1,G3 | 4d | 真实图谱渲染+交互 |
| G6  | CanvasPage 无尽画布 | P1 | P1 | G3,G5 | 4d | 卡片+连线+拖拽 |
| G7  | Scene 三场景内容填充 | P1 | P1 | G2,G4 | 3d | Capture/Think/Connect 完整 |
| G8  | Widget 组件群对接 | P1 | P1 | G1,G3,G5 | 4d | Sidebar/Backlinks/StatusBar/Empty |
| G9  | Settings 设置页对接 | P1 | P2 | G1-G8 | 3d | 8 个设置分区真实配置 |
| G10 | EmbeddingService 实现 | P2 | P0 | G9 | 2d | 向量化 API + 相似度计算 |
| G11 | ShortcutService 实现 | P2 | P0 | 无 | 2d | 全局快捷键 + UX-7 审计 |
| G12 | 性能与安全加固 | P2 | P1 | G4,G6 | 3d | 监控埋点 + 安全审计 |
| G13 | 高级特性实施 | P3 | P1 | G5,G10 | 2w | 流式优化/布局升级/基准 |
| G14 | 插件与同步加固 | P3 | P2 | G10,G11 | 1.5w | 沙箱/Git合并/QuickMove |
| G15 | 生产就绪 | P4 | P2 | 全部 | 1.5w | CI/E2E/文档/打包 |

---

## Phase 1：「血肉填充」— UI 层与数据层对接

> **目标**: 消除所有 Placeholder，每个页面拥有真实数据和交互
> **输入**: 6 个成熟服务 (ai, agent, browser, knowledge, git_sync, webdav_sync)
> **输出**: 所有页面可交互，flutter analyze 0 问题，测试全通过

---

### Epic G1: CommandBar 真实搜索

> **目标**: CommandBar 从硬编码建议变为实时搜索真实笔记数据
> **依赖**: 无
> **验收标准文件**: `test/ui/command_bar_test.dart`

#### User Story G1-US1: 用户搜索真实笔记

**作为** 知识工作者
**我想要** 在 CommandBar 中输入关键词搜索我的所有笔记
**以便** 快速找到并打开需要的笔记，无需在文件系统中翻找

#### 验收标准 G1-AC1: 搜索返回真实数据

```dart
test('G1-AC1: CommandBar search returns real notes from knowledge_service', () async {
  final container = createContainer();
  final commandBar = container.read(commandBarProvider.notifier);
  final knowledge = container.read(knowledgeServiceProvider);

  // 预设存在一篇笔记
  await knowledge.createNote(Note(title: 'Flutter Performance Tips', content: '...'));

  // 执行搜索
  await commandBar.search('Flutter');
  final state = container.read(commandBarProvider);

  expect(state.results.any((r) => r.title.contains('Flutter Performance Tips')), isTrue);
});
```

#### 验收标准 G1-AC2: 300ms debounce

```dart
test('G1-AC2: search debounced at 300ms', () async {
  final container = createContainer();
  final commandBar = container.read(commandBarProvider.notifier);

  commandBar.onQueryChanged('Fl');
  commandBar.onQueryChanged('Flu');
  commandBar.onQueryChanged('Flut');

  // 300ms 内不应触发多次搜索
  // 使用 fake_async 验证 debounce 行为
  await FakeAsync().run((async) {
    commandBar.onQueryChanged('Flutter');
    async.elapse(const Duration(milliseconds: 100));
    expect(container.read(commandBarProvider).isSearching, isFalse);
    async.elapse(const Duration(milliseconds: 250));
    expect(container.read(commandBarProvider).isSearching, isTrue);
  });
});
```

#### 验收标准 G1-AC3: 结果分类展示

```dart
test('G1-AC3: search results categorized by type', () async {
  final state = CommandBarState(
    results: [
      SearchResult(type: SearchResultType.note, title: 'Note A'),
      SearchResult(type: SearchResultType.tag, title: 'flutter'),
      SearchResult(type: SearchResultType.command, title: 'New Daily Note'),
    ],
  );

  final groups = state.groupedResults;
  expect(groups[SearchResultType.note]!.length, 1);
  expect(groups[SearchResultType.tag]!.length, 1);
  expect(groups[SearchResultType.command]!.length, 1);
});
```

#### 验收标准 G1-AC4: Ctrl+K 唤起

```dart
testWidgets('G1-AC4: Ctrl+K opens CommandBar', (tester) async {
  await tester.pumpWidget(const App());
  expect(find.byType(CommandBar), findsNothing);
  
  await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
  await tester.pump();
  
  expect(find.byType(CommandBar), findsOneWidget);
});
```

#### 失效文件列表
- `lib/ui/widgets/command_bar.dart` — 重写

---

### Epic G2: AIChatPanel 流式对话

> **目标**: AIChatPanel 对接 ai_service 实现真实对话，支持流式输出和三 Provider 切换
> **依赖**: 无
> **验收标准文件**: `test/ui/ai_chat_panel_test.dart`

#### User Story G2-US1: 用户与 AI 对话

**作为** 知识工作者
**我想要** 在 AI 面板中发送消息并获得流式 AI 回复
**以便** 借助 AI 辅助阅读、写作和知识整理

#### 验收标准 G2-AC1: 发送消息并获得流式响应

```dart
test('G2-AC1: sending message triggers streaming response', () async {
  final container = createContainer();
  final aiChat = container.read(aiChatProvider.notifier);
  
  await aiChat.sendMessage('Hello');
  
  // 用户消息立即出现
  final stateAfterSend = container.read(aiChatProvider);
  expect(stateAfterSend.messages.last.role, 'user');
  expect(stateAfterSend.isStreaming, isTrue);
  
  // 流式 token 到达
  await container.read(aiChatProvider.notifier).onTokenReceived('Hi');
  final stateAfterToken = container.read(aiChatProvider);
  expect(stateAfterToken.messages.last.role, 'assistant');
  expect(stateAfterToken.messages.last.content, contains('Hi'));
});
```

#### 验收标准 G2-AC2: 并发防护

```dart
test('G2-AC2: cannot send while streaming (C-2)', () async {
  final container = createContainer();
  final aiChat = container.read(aiChatProvider.notifier);
  
  await aiChat.sendMessage('First');
  expect(container.read(aiChatProvider).isStreaming, isTrue);
  
  // 第二次发送应该被拒绝
  expect(() => aiChat.sendMessage('Second'), throwsA(isA<ConcurrentOperationException>()));
});
```

#### 验收标准 G2-AC3: Provider 切换不丢对话

```dart
test('G2-AC3: switching provider keeps conversation history', () async {
  final container = createContainer();
  final aiChat = container.read(aiChatProvider.notifier);
  
  await aiChat.sendMessage('Hello');
  aiChat.switchProvider('openai');
  
  final state = container.read(aiChatProvider);
  expect(state.messages.length, greaterThanOrEqualTo(2));
  expect(state.selectedProvider, 'openai');
});
```

#### 验收标准 G2-AC4: 中止生成

```dart
test('G2-AC4: cancel stops streaming and keeps partial response', () async {
  final container = createContainer();
  final aiChat = container.read(aiChatProvider.notifier);
  
  await aiChat.sendMessage('Tell me a story');
  await aiChat.onTokenReceived('Once upon');
  aiChat.cancelStream();
  
  final state = container.read(aiChatProvider);
  expect(state.isStreaming, isFalse);
  expect(state.messages.last.content, 'Once upon');
});
```

#### 失效文件列表
- `lib/ui/pages/ai_chat_panel.dart` — 重写

---

### Epic G3: EditorPage 笔记编辑

> **目标**: EditorPage 具备完整的 Markdown 编辑、语法高亮、自动保存、Wikilink 自动补全
> **依赖**: 无
> **验收标准文件**: `test/ui/editor_page_test.dart`

#### User Story G3-US1: 用户编辑笔记

**作为** 知识工作者
**我想要** 在编辑器中打开、编辑、保存 Markdown 笔记，并享受语法高亮
**以便** 高效撰写和组织知识内容

#### 验收标准 G3-AC1: 加载并显示笔记

```dart
test('G3-AC1: editor loads and displays note content', () async {
  final container = createContainer();
  final editor = container.read(editorPageProvider.notifier);
  final noteRepo = container.read(noteRepositoryProvider);
  
  final note = await noteRepo.createNote(Note(title: 'Test', content: '# Hello\nWorld'));
  await editor.openNote(note.id);
  
  final state = container.read(editorPageProvider);
  expect(state.note!.title, 'Test');
  expect(state.note!.content, '# Hello\nWorld');
});
```

#### 验收标准 G3-AC2: Debounce 保存

```dart
test('G3-AC2: save is debounced 500ms after edit (P-1)', () async {
  final container = createContainer();
  final editor = container.read(editorPageProvider.notifier);
  
  await editor.openNote('test-note-id');
  
  // 快速连续编辑
  editor.onContentChanged('line 1');
  editor.onContentChanged('line 1\nline 2');
  editor.onContentChanged('line 1\nline 2\nline 3');
  
  // 500ms 内不应触发保存
  await Future.delayed(const Duration(milliseconds: 200));
  expect(container.read(editorPageProvider).lastSavedAt, isNull);
  
  // 500ms 后触发保存
  await Future.delayed(const Duration(milliseconds: 400));
  expect(container.read(editorPageProvider).lastSavedAt, isNotNull);
});
```

#### 验收标准 G3-AC3: Wikilink 自动补全

```dart
test('G3-AC3: typing [[ triggers wikilink autocomplete', () async {
  final container = createContainer();
  final editor = container.read(editorPageProvider.notifier);
  final knowledge = container.read(knowledgeServiceProvider);
  
  await knowledge.createNote(Note(title: 'Other Note'));
  await editor.openNote('current-note-id');
  
  editor.onContentChanged('See [[');
  
  final state = container.read(editorPageProvider);
  expect(state.autocompleteSuggestions, contains('Other Note'));
});
```

#### 验收标准 G3-AC4: 失焦立即保存

```dart
test('G3-AC4: save on focus loss even before debounce', () async {
  final container = createContainer();
  final editor = container.read(editorPageProvider.notifier);
  
  await editor.openNote('test-note-id');
  editor.onContentChanged('quick edit');
  editor.onFocusLost(); // 失焦 — 不等 debounce
  
  expect(container.read(editorPageProvider).isSaved, isTrue);
});
```

#### 失效文件列表
- `lib/ui/pages/editor_page.dart` — 重写

---

### Epic G4: BrowserPage 标签页管理

> **目标**: BrowserPage 对接 browser_service + agent_webview，实现多标签、URL 导航、安全过滤
> **依赖**: 无
> **验收标准文件**: `test/ui/browser_page_test.dart`

#### User Story G4-US1: 用户浏览网页

**作为** 知识工作者
**我想要** 在应用中浏览网页、管理多个标签页
**以便** 在进行研究时无需切换到外部浏览器

#### 验收标准 G4-AC1: 多标签管理

```dart
test('G4-AC1: tabs created, switched, and closed correctly', () async {
  final container = createContainer();
  final browser = container.read(browserPageProvider.notifier);
  
  await browser.createTab();
  await browser.createTab();
  expect(container.read(browserPageProvider).tabs.length, 3); // 1 initial + 2 new
  
  // 关闭标签：先计算新 index (C-3)
  await browser.closeTab('tab-2');
  expect(container.read(browserPageProvider).tabs.length, 2);
});
```

#### 验收标准 G4-AC2: URL 安全过滤

```dart
test('G4-AC2: dangerous URL schemes are blocked (S-1)', () {
  final filter = BrowserPageNotifier();
  
  expect(filter.shouldBlockUrl('javascript:alert(1)'), isTrue);
  expect(filter.shouldBlockUrl('file:///etc/passwd'), isTrue);
  expect(filter.shouldBlockUrl('data:text/html,<script>alert(1)</script>'), isTrue);
  expect(filter.shouldBlockUrl('https://example.com'), isFalse);
});
```

#### 验收标准 G4-AC3: 地址栏导航

```dart
test('G4-AC3: address bar navigates active tab', () async {
  final container = createContainer();
  final browser = container.read(browserPageProvider.notifier);
  
  await browser.navigateTo('https://example.com');
  
  final state = container.read(browserPageProvider);
  final activeTab = state.tabs.firstWhere((t) => t.id == state.activeTabId);
  expect(activeTab.url, 'https://example.com');
});
```

#### 失效文件列表
- `lib/ui/pages/browser_page.dart` — 重写

---

### Epic G5: GraphPage 知识图谱

> **目标**: GraphPage 渲染真实知识图谱，含节点/连线/筛选/详情
> **依赖**: G1 (CommandBar), G3 (EditorPage)
> **验收标准文件**: `test/ui/graph_page_test.dart`

#### User Story G5-US1: 用户查看知识图谱

**作为** 知识工作者
**我想要** 可视化查看所有笔记之间的关联关系
**以便** 发现隐含的知识连接和知识盲区

#### 验收标准 G5-AC1: 图谱从真实数据构建

```dart
test('G5-AC1: graph built from real notes and links', () async {
  final container = createContainer();
  final graph = container.read(graphPageProvider.notifier);
  final knowledge = container.read(knowledgeServiceProvider);
  
  await knowledge.createNote(Note(title: 'A', content: 'See [[B]]'));
  await knowledge.createNote(Note(title: 'B', content: ''));
  
  await graph.loadGraph();
  
  final state = container.read(graphPageProvider);
  expect(state.nodes.length, 2);
  expect(state.edges.length, 1);
});
```

#### 验收标准 G5-AC2: 自动/手动链接视觉区分

```dart
test('G5-AC2: auto-discovered links dashed, manual links solid (A-6)', () async {
  final container = createContainer();
  final graph = container.read(graphPageProvider.notifier);
  
  await graph.loadGraph();
  
  final state = container.read(graphPageProvider);
  final autoEdge = state.edges.firstWhere((e) => e.isAutoDiscovered);
  final manualEdge = state.edges.firstWhere((e) => !e.isAutoDiscovered);
  
  expect(autoEdge.strokeStyle, EdgeStrokeStyle.dashed);
  expect(manualEdge.strokeStyle, EdgeStrokeStyle.solid);
});
```

#### 验收标准 G5-AC3: 节点选中展示详情

```dart
test('G5-AC3: node click shows detail panel', () async {
  final container = createContainer();
  final graph = container.read(graphPageProvider.notifier);
  
  await graph.loadGraph();
  graph.selectNode('node-A');
  
  final state = container.read(graphPageProvider);
  expect(state.selectedNodeId, 'node-A');
  expect(state.showDetailPanel, isTrue);
});
```

#### 失效文件列表
- `lib/ui/pages/graph_page.dart` — 重写
- `lib/ui/widgets/filter_panel.dart` — 重写
- `lib/ui/widgets/node_detail_panel.dart` — 重写

---

### Epic G6: CanvasPage 无尽画布

> **目标**: CanvasPage 实现真实的卡片放置、连线、拖拽、视口变换
> **依赖**: G3 (EditorPage), G5 (GraphPage)
> **验收标准文件**: `test/ui/canvas_page_test.dart`

#### User Story G6-US1: 用户在画布上自由组织知识

**作为** 知识工作者
**我想要** 在一个无限画布上放置笔记卡片、手动连线，自由布局知识
**以便** 以空间化、可视化的方式理解和组织知识

#### 验收标准 G6-AC1: 卡片绑定真实 Note 数据

```dart
test('G6-AC1: canvas card renders live note data (A-5)', () async {
  final container = createContainer();
  final canvas = container.read(canvasPageProvider.notifier);
  final noteRepo = container.read(noteRepositoryProvider);
  
  final note = await noteRepo.createNote(Note(title: 'Canvas Note', content: 'Preview...'));
  
  canvas.addCard(note.id, Offset(100, 200));
  
  final state = container.read(canvasPageProvider);
  final card = state.cards.firstWhere((c) => c.noteId == note.id);
  expect(card.title, 'Canvas Note');
  expect(card.preview, contains('Preview'));
});
```

#### 验收标准 G6-AC2: shouldRepaint 严格比较

```dart
test('G6-AC2: shouldRepaint respects actual data changes (P-2)', () {
  final painter = CanvasPainter(
    cards: [CanvasCard(noteId: '1', position: Offset(0, 0))],
    connections: [],
  );
  
  final same = CanvasPainter(
    cards: [CanvasCard(noteId: '1', position: Offset(0, 0))],
    connections: [],
  );
  
  final different = CanvasPainter(
    cards: [CanvasCard(noteId: '1', position: Offset(10, 10))],
    connections: [],
  );
  
  expect(painter.shouldRepaint(same), isFalse);
  expect(painter.shouldRepaint(different), isTrue);
});
```

#### 验收标准 G6-AC3: 裁剪顺序正确

```dart
test('G6-AC3: clipping happens BEFORE drawing (U-2)', () {
  final canvasMock = MockCanvas();
  final painter = CanvasPainter(cards: [...], connections: [...]);
  
  painter.paint(canvasMock, Size(800, 600));
  
  // save → clip → draw → restore 必须按序调用
  verifyInOrder([
    canvasMock.save(),
    canvasMock.clipRect(any),
    // draw operations...
    canvasMock.restore(),
  ]);
});
```

#### 验收标准 G6-AC4: 持久化到文件系统

```dart
test('G6-AC4: canvas persists to .json in vault/.rf/ (A-7)', () async {
  final container = createContainer();
  final canvas = container.read(canvasPageProvider.notifier);
  
  canvas.addCard('note-1', Offset(100, 200));
  await canvas.persist();
  
  final file = File('vault/.rf/canvas-state.json');
  expect(await file.exists(), isTrue);
  
  final json = jsonDecode(await file.readAsString());
  expect(json['cards'][0]['noteId'], 'note-1');
});
```

#### 失效文件列表
- `lib/ui/pages/canvas_page.dart` — 重写
- `lib/ui/widgets/canvas_painter.dart` — 重写

---

### Epic G7: Scene 三场景内容填充

> **目标**: Capture/Think/Connect 三个场景拥有真实的内部组件和交互
> **依赖**: G2 (AIChatPanel), G4 (BrowserPage)
> **验收标准文件**: `test/ui/scene_integration_test.dart`

#### User Story G7-US1: 用户在三场景之间自然流转

**作为** 知识工作者
**我想要** 在捕捉、思考、连接三个场景间顺畅切换，每个场景服务于不同认知阶段
**以便** 信息获取→加工→关联的自然流程不被工具打断

#### 验收标准 G7-AC1: Capture Scene 包含 ClipToolbar + AI 摘要

```dart
testWidgets('G7-AC1: CaptureScene renders ClipToolbar and AI summary', (tester) async {
  await tester.pumpWidget(
    const ProviderScope(child: MaterialApp(home: CaptureScene())),
  );
  
  expect(find.byType(ClipToolbar), findsOneWidget);
  expect(find.byType(AIFloat), findsOneWidget);
});
```

#### 验收标准 G7-AC2: Think Scene 包含内联 AI + Wikilink 补全

```dart
testWidgets('G7-AC2: ThinkScene renders InlineAIEditor and QuickSearchBar', (tester) async {
  await tester.pumpWidget(
    const ProviderScope(child: MaterialApp(home: ThinkScene())),
  );
  
  expect(find.byType(InlineAIEditor), findsOneWidget);
  expect(find.byType(QuickSearchBar), findsOneWidget);
});
```

#### 验收标准 G7-AC3: Connect Scene 包含图谱 + 筛选 + 详情

```dart
testWidgets('G7-AC3: ConnectScene renders Graph + FilterPanel + NodeDetail', (tester) async {
  await tester.pumpWidget(
    const ProviderScope(child: MaterialApp(home: ConnectScene())),
  );
  
  expect(find.byType(FilterPanel), findsOneWidget);
  expect(find.byType(NodeDetailPanel), findsOneWidget);
});
```

#### 失效文件列表
- `lib/ui/scenes/capture/capture_scene.dart` — 重写
- `lib/ui/scenes/think/think_scene.dart` — 重写
- `lib/ui/scenes/connect/connect_scene.dart` — 重写
- `lib/ui/widgets/clip_toolbar.dart` — 重写
- `lib/ui/widgets/inline_ai_editor.dart` — 重写

---

### Epic G8: Widget 组件群对接

> **目标**: Sidebar / Backlinks / StatusBar / EmptyState 等余下基础设施组件对接真实数据
> **依赖**: G1, G3, G5
> **验收标准文件**: `test/ui/widgets_integration_test.dart`

#### User Story G8-US1: 用户通过侧栏和反向链接导航知识

**作为** 知识工作者
**我想要** 通过侧栏浏览笔记列表，通过反向链接面板查看引用当前笔记的其他笔记
**以便** 在知识网络中自由穿梭，不遗漏任何关联信息

#### 验收标准 G8-AC1: NoteSidebar 显示真实目录树

```dart
test('G8-AC1: NoteSidebar shows real note tree from VaultStore', () async {
  final container = createContainer();
  final vaultStore = container.read(vaultStoreProvider);
  
  await vaultStore.addNote(Note(title: 'Subfolder/Note A', path: 'Subfolder/Note A.md'));
  await vaultStore.addNote(Note(title: 'Note B', path: 'Note B.md'));
  
  final sidebar = container.read(noteSidebarProvider.notifier);
  await sidebar.loadTree();
  
  final state = container.read(noteSidebarProvider);
  expect(state.noteTree.length, 2);
  expect(state.noteTree.first.children.length, 1);
});
```

#### 验收标准 G8-AC2: BacklinksPanel 显示真实反向链接

```dart
test('G8-AC2: BacklinksPanel shows real backlinks via LinkResolver (UX-6)', () async {
  final container = createContainer();
  final knowledge = container.read(knowledgeServiceProvider);
  
  await knowledge.createNote(Note(title: 'Source', content: 'links to [[Target]]'));
  await knowledge.createNote(Note(title: 'Target', content: ''));
  
  final backlinks = container.read(backlinksProvider.notifier);
  await backlinks.loadForNote('Target');
  
  final state = container.read(backlinksProvider);
  expect(state.backlinks.length, 1);
  expect(state.backlinks.first.sourceTitle, 'Source');
});
```

#### 验收标准 G8-AC3: StatusBar 显示实时服务状态

```dart
test('G8-AC3: StatusBar reflects service states', () async {
  final container = createContainer();
  final statusBar = container.read(statusBarProvider.notifier);
  
  statusBar.updateSyncStatus(SyncStatus.inProgress);
  
  final state = container.read(statusBarProvider);
  expect(state.syncStatus, SyncStatus.inProgress);
  expect(state.aiConnectionStatus, isNotNull);
});
```

#### 验收标准 G8-AC4: 空状态有 CTA 引导

```dart
testWidgets('G8-AC4: empty vault shows guide with CTA (UX-2)', (tester) async {
  await tester.pumpWidget(
    const ProviderScope(child: MaterialApp(home: EmptyVaultGuide())),
  );
  
  expect(find.text('Create your first note'), findsOneWidget);
  expect(find.byType(ElevatedButton), findsWidgets);
});
```

#### 失效文件列表
- `lib/ui/widgets/note_sidebar.dart` — 重写
- `lib/ui/widgets/backlinks_panel.dart` — 重写
- `lib/ui/widgets/status_bar.dart` — 重写
- `lib/ui/widgets/empty_vault_guide.dart` — 重写

---

### Epic G9: Settings 设置页对接

> **目标**: 所有设置分区对接真实配置后端，配置变更实时生效
> **依赖**: G1-G8
> **验收标准文件**: `test/ui/settings_page_test.dart`

#### User Story G9-US1: 用户配置应用

**作为** 知识工作者
**我想要** 在设置页面中修改 AI 配置、主题、同步、快捷键、语言等选项
**以便** 应用按我的偏好和需求运行

#### 验收标准 G9-AC1: AI 设置保存并生效

```dart
test('G9-AC1: AI settings save and take effect', () async {
  final container = createContainer();
  final aiSettings = container.read(aiSettingsProvider.notifier);
  
  await aiSettings.updateConfig(
    provider: 'ollama',
    model: 'qwen2.5:7b',
    baseUrl: 'http://localhost:11434',
  );
  
  final aiService = container.read(aiServiceProvider);
  expect(aiService.currentProvider, 'ollama');
  expect(aiService.currentModel, 'qwen2.5:7b');
});
```

#### 验收标准 G9-AC2: API Key 安全存储

```dart
test('G9-AC2: API keys stored in secure storage, not state (S-2)', () async {
  final container = createContainer();
  final aiSettings = container.read(aiSettingsProvider.notifier);
  
  await aiSettings.updateApiKey('openai', 'sk-1234567890');
  
  // State 对象中不应包含明文 Key
  final state = container.read(aiSettingsProvider);
  expect(state.apiKeys.containsKey('openai'), isFalse);
  
  // Key 应从 secure storage 读取
  final storedKey = await secureStorage.read(key: 'api_key_openai');
  expect(storedKey, 'sk-1234567890');
});
```

#### 失效文件列表
- `lib/ui/pages/settings_page.dart` — 重写
- `lib/ui/pages/settings/ai_settings_section.dart` — 重写
- `lib/ui/pages/settings/theme_settings_section.dart` — 重写
- `lib/ui/pages/settings/sync_settings_section.dart` — 重写
- `lib/ui/pages/settings/shortcut_settings_section.dart` — 重写
- `lib/ui/pages/settings/language_settings_section.dart` — 重写
- `lib/ui/pages/settings/editor_settings_section.dart` — 重写
- `lib/ui/pages/settings/component_settings_section.dart` — 重写
- `lib/ui/pages/settings/quick_moves_settings_section.dart` — 重写
- `lib/ui/pages/settings/about_section.dart` — 重写

---

## Phase 2：「短板补齐 + 质量加固」

---

### Epic G10: EmbeddingService 实现

> **目标**: 实现文本向量化服务，对接 Ollama/OpenAI Embedding API
> **依赖**: G9 (Settings — 需要 AI 配置)
> **验收标准文件**: `test/services/embedding_service_test.dart`

#### 验收标准 G10-AC1: Ollama Embedding 调用成功

```dart
test('G10-AC1: Ollama embedding returns vectors', () async {
  final service = EmbeddingService(provider: 'ollama', model: 'nomic-embed-text');
  
  final vectors = await service.embed(['Hello world', 'Another text']);
  
  expect(vectors.length, 2);
  expect(vectors[0].length, 768); // nomic-embed-text dimension
});
```

#### 验收标准 G10-AC2: 余弦相似度计算正确

```dart
test('G10-AC2: cosine similarity computed correctly', () {
  final service = EmbeddingService();
  
  final sim = service.cosineSimilarity([1.0, 0.0], [1.0, 0.0]);
  expect(sim, closeTo(1.0, 0.0001));
  
  final opposite = service.cosineSimilarity([1.0, 0.0], [-1.0, 0.0]);
  expect(opposite, closeTo(-1.0, 0.0001));
  
  final orthogonal = service.cosineSimilarity([1.0, 0.0], [0.0, 1.0]);
  expect(orthogonal, closeTo(0.0, 0.0001));
});
```

#### 失效文件列表
- `lib/services/embedding_service.dart` — 重写

---

### Epic G11: ShortcutService 实现

> **目标**: 实现全局快捷键注册/冲突检测，满足 UX-7 规则
> **依赖**: 无
> **验收标准文件**: `test/services/shortcut_service_test.dart`

#### 验收标准 G11-AC1: Top 5 操作有快捷键 (UX-7)

```dart
test('G11-AC1: top 5 actions have keyboard shortcuts (UX-7)', () {
  final service = ShortcutService();
  service.registerDefaults();
  
  final bindings = service.getAllBindings();
  
  expect(bindings.containsKey('search'), isTrue);          // Ctrl+K
  expect(bindings.containsKey('new_note'), isTrue);        // Ctrl+N
  expect(bindings.containsKey('save'), isTrue);            // Ctrl+S
  expect(bindings.containsKey('switch_view'), isTrue);     // Ctrl+1/2/3
  expect(bindings.containsKey('daily_note'), isTrue);      // Ctrl+D
});
```

#### 验收标准 G11-AC2: 冲突检测

```dart
test('G11-AC2: duplicate shortcut detected as conflict', () {
  final service = ShortcutService();
  service.register('action_a', LogicalKeySet(LogicalKeyboardKey.keyA, LogicalKeyboardKey.control), () {});
  service.register('action_b', LogicalKeySet(LogicalKeyboardKey.keyA, LogicalKeyboardKey.control), () {});
  
  final conflicts = service.detectConflicts();
  expect(conflicts.length, 1);
});
```

#### 失效文件列表
- `lib/services/shortcut_service.dart` — 重写

---

### Epic G12: 性能与安全加固

> **目标**: 在关键路径埋点性能监控，审计 WebView 安全
> **依赖**: G4 (BrowserPage), G6 (CanvasPage)
> **验收标准文件**: `test/performance/profiling_test.dart`, `test/security/webview_security_test.dart`

#### 验收标准 G12-AC1: 帧级性能监控不造成 jank

```dart
test('G12-AC1: performance monitor overhead < 1ms per frame', () async {
  final monitor = FramePerformanceMonitor();
  
  final stopwatch = Stopwatch()..start();
  for (int i = 0; i < 100; i++) {
    monitor.recordFrame(Duration(milliseconds: 16));
  }
  stopwatch.stop();
  
  // 100 帧的监控开销 < 100ms
  expect(stopwatch.elapsedMilliseconds, lessThan(100));
});
```

#### 验收标准 G12-AC2: WebView 安全审计通过

```dart
test('G12-AC2: all WebView URL entry points filtered (S-1)', () {
  final audit = WebViewSecurityAudit();
  final results = audit.scan('lib/platform/webview/');
  
  // 所有 URL 加载点都必须经过 shouldOverrideUrlLoading 或等价过滤
  expect(results.violations, isEmpty);
});
```

---

## Phase 3：「高级特性」

---

### Epic G13: 高级特性实施

> **目标**: AI 流式优化、图谱布局升级、向量搜索质量基准
> **依赖**: G5, G10
> **这批在 Phase 3 开始前，需根据 Phase 1+2 的实际进度细化**

| 子任务 | 描述 | 工时 |
|--------|------|------|
| G13-A | AI 流式 token buffer 优化 → 减少 UI 线程争用 (INN-AI-004) | 3d |
| G13-B | 图谱布局从力导向升级到 stress majorization (INN-GRAPH-005) | 3d |
| G13-C | HNSW recall@k + MRR 基准测试，目标 recall@10 > 0.9 (INN-DATA-002) | 2d |
| G13-D | 集成测试：搜索→笔记→图谱→画布→AI 五步链路 | 2d |

---

### Epic G14: 插件与同步加固

> **依赖**: G10, G11
> **这批在 Phase 3 开始前细化**

| 子任务 | 描述 | 工时 |
|--------|------|------|
| G14-A | 插件沙箱加固：资源限制 + 超时 + 能力安全 (INN-PLUG-001) | 4d |
| G14-B | Git 三方合并冲突解决 (INN-SYNC-003) | 4d |
| G14-C | QuickMove 快捷操作真实功能 | 2d |
| G14-D | Agent Monitor 代理监控实时状态 | 2d |

---

## Phase 4：「生产就绪」

---

### Epic G15: 生产就绪

> **依赖**: 全部
> **这批在 Phase 4 开始前细化**

| 子任务 | 描述 | 工时 |
|--------|------|------|
| G15-A | CI/CD Harness 集成到 GitHub Actions (INN-CI-001) | 3d |
| G15-B | E2E 覆盖 5 条关键用户旅程 (INN-TEST-003) | 5d |
| G15-C | 跨组件数据流验证 → 满足 A-1 全局 | 2d |
| G15-D | 用户文档自动生成 (INN-DOC-002) | 2d |
| G15-E | Windows/macOS/Linux 三平台打包 | 3d |

---

## 文件变更总览

### Phase 1 需重写的文件

| # | 文件 | Epic | 类型 |
|---|------|------|------|
| 1 | `lib/ui/widgets/command_bar.dart` | G1 | Widget |
| 2 | `lib/ui/pages/ai_chat_panel.dart` | G2 | Page |
| 3 | `lib/ui/pages/editor_page.dart` | G3 | Page |
| 4 | `lib/ui/pages/browser_page.dart` | G4 | Page |
| 5 | `lib/ui/pages/graph_page.dart` | G5 | Page |
| 6 | `lib/ui/widgets/filter_panel.dart` | G5 | Widget |
| 7 | `lib/ui/widgets/node_detail_panel.dart` | G5 | Widget |
| 8 | `lib/ui/pages/canvas_page.dart` | G6 | Page |
| 9 | `lib/ui/widgets/canvas_painter.dart` | G6 | Widget |
| 10 | `lib/ui/scenes/capture/capture_scene.dart` | G7 | Scene |
| 11 | `lib/ui/scenes/think/think_scene.dart` | G7 | Scene |
| 12 | `lib/ui/scenes/connect/connect_scene.dart` | G7 | Scene |
| 13 | `lib/ui/widgets/clip_toolbar.dart` | G7 | Widget |
| 14 | `lib/ui/widgets/inline_ai_editor.dart` | G7 | Widget |
| 15 | `lib/ui/widgets/note_sidebar.dart` | G8 | Widget |
| 16 | `lib/ui/widgets/backlinks_panel.dart` | G8 | Widget |
| 17 | `lib/ui/widgets/status_bar.dart` | G8 | Widget |
| 18 | `lib/ui/widgets/empty_vault_guide.dart` | G8 | Widget |
| 19 | `lib/ui/pages/settings_page.dart` | G9 | Page |
| 20 | `lib/ui/pages/settings/ai_settings_section.dart` | G9 | Section |
| 21 | `lib/ui/pages/settings/theme_settings_section.dart` | G9 | Section |
| 22 | `lib/ui/pages/settings/sync_settings_section.dart` | G9 | Section |
| 23 | `lib/ui/pages/settings/shortcut_settings_section.dart` | G9 | Section |
| 24 | `lib/ui/pages/settings/language_settings_section.dart` | G9 | Section |
| 25 | `lib/ui/pages/settings/editor_settings_section.dart` | G9 | Section |
| 26 | `lib/ui/pages/settings/component_settings_section.dart` | G9 | Section |
| 27 | `lib/ui/pages/settings/quick_moves_settings_section.dart` | G9 | Section |
| 28 | `lib/ui/pages/settings/about_section.dart` | G9 | Section |

### Phase 2 需重写的文件

| # | 文件 | Epic | 类型 |
|---|------|------|------|
| 29 | `lib/services/embedding_service.dart` | G10 | Service |
| 30 | `lib/services/shortcut_service.dart` | G11 | Service |

### 需新增的文件

| # | 文件 | Epic | 类型 |
|---|------|------|------|
| N1 | `test/ui/command_bar_test.dart` | G1 | Test |
| N2 | `test/ui/ai_chat_panel_test.dart` | G2 | Test |
| N3 | `test/ui/editor_page_test.dart` | G3 | Test |
| N4 | `test/ui/browser_page_test.dart` | G4 | Test |
| N5 | `test/ui/graph_page_test.dart` | G5 | Test |
| N6 | `test/ui/canvas_page_test.dart` | G6 | Test |
| N7 | `test/ui/scene_integration_test.dart` | G7 | Test |
| N8 | `test/ui/widgets_integration_test.dart` | G8 | Test |
| N9 | `test/ui/settings_page_test.dart` | G9 | Test |
| N10 | `test/services/embedding_service_test.dart` | G10 | Test |
| N11 | `test/services/shortcut_service_test.dart` | G11 | Test |
| N12 | `test/performance/profiling_test.dart` | G12 | Test |
| N13 | `test/security/webview_security_test.dart` | G12 | Test |

---

## 里程碑

```
M0 ✅ 当前状态: 31/10 验收标准满足, 0 约束违规, Status: solid
   │
M1 ── Week 1-2: Phase 1 P0 交付 (G1+G2+G3+G4)
   │  CommandBar + AIChat + EditorPage + BrowserPage 可交互
   │  验收: flutter analyze 0 issues, 测试全通过
   │
M2 ── Week 3-4: Phase 1 P1 交付 (G5+G6+G7+G8)
   │  GraphPage + CanvasPage + Scenes + Widgets 可交互
   │  验收: 所有页面无 Placeholder, 每个页面 ≥1 个数据流路径
   │
M3 ── Week 5: Phase 1 P2 交付 (G9)
   │  Settings 所有分区真实配置
   │  🎯 MILESTONE: 「血肉填充」完成
   │
M4 ── Week 6: Phase 2 P0 交付 (G10+G11)
   │  EmbeddingService + ShortcutService 完善
   │  验收: Domain "Solid" 阶段条件全部满足
   │
M5 ── Week 7: Phase 2 P1 交付 (G12)
   │  性能监控埋点 + 安全审计通过
   │  🎯 MILESTONE: Domain "Solid" → 可进入 "Advanced"
   │
M6 ── Week 8-10: Phase 3 交付 (G13+G14)
   │  流式优化 + 图谱升级 + 向量基准 + 沙箱/Git/QuickMove
   │  🎯 MILESTONE: Domain "Advanced" → 可进入 "Production"
   │
M7 ── Week 11-14: Phase 4 交付 (G15)
   │  CI/CD + E2E + 文档 + 三平台打包
   │  🎯 MILESTONE: 🚀 v1.0 Release
```

---

> **关联文档**:
> - 设计案: [next-phase-design-spec.md](./next-phase-design-spec.md)
> - 产品愿景: [01-product-vision.md](./01-product-vision.md)
> - UX 重构设计案: [ux-redesign-spec.md](./ux-redesign-spec.md)
> - Genome 约束: [genome.yaml](../../seeds/evolution/genome.yaml)
> - 领域进阶: [domain-advancements.yaml](../../seeds/evolution/domain-advancements.yaml)
