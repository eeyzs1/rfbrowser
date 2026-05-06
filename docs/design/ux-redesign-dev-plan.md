# RFBrowser UX 重构 — 详细开发计划

> **依赖设计案**: [ux-redesign-spec.md](./ux-redesign-spec.md)  
> **预估总工时**: 10-12 天（按单人全职计）  
> **策略**: 增量重构，每个 Epic 独立可交付，不阻塞现有功能  

---

## Epic 总览

| Epic | 名称 | 优先级 | 依赖 | 预估工时 | 关键交付 |
|------|------|--------|------|---------|---------|
| E0 | 设计 Token 基础设施 | P0 | 无 | 0.5 天 | `design_tokens.dart`, 颜色常量 |
| E1 | 场景导航架构 | P0 | E0 | 2 天 | SceneScaffold, SceneSwitcher, 三场景切换 |
| E2 | AI Float 浮动助手 | P0 | E1 | 2 天 | AI Float 组件, 折叠/展开, 上下文感知 |
| E3 | 捕捉场景重构 | P1 | E1, E2 | 2 天 | ClipToolbar, AI 摘要面板 |
| E4 | 思考场景重构 | P1 | E1, E2 | 1.5 天 | AI 内联建议, Wikilink 自动补全 |
| E5 | 连接场景重构 | P1 | E1, E2 | 1.5 天 | 筛选面板, 节点详情面板, 脉动动画 |
| E6 | 空状态引导 + 全局搜索 | P1 | E1 | 1 天 | EmptyVaultGuide, QuickSearchBar |
| E7 | 集成测试 + 回归 | P2 | E1-E6 | 1 天 | UI 测试, 性能验证 |

---

## Epic E0: 设计 Token 基础设施

> **目标**: 建立统一的设计 token 系统，所有新代码引用 token 常量而非硬编码值。不影响现有功能。  
> **依赖**: 无  
> **验收标准文件**: `test/ui/design_tokens_test.dart`

### User Story E0-US1: 开发者可使用统一的设计 token

**作为** UI 开发者  
**我想要** 一套统一的设计 token（颜色、间距、圆角、字体）  
**以便** 所有新增 UI 代码保持视觉一致性，且一次修改全局生效  

#### 验收标准 E0-AC1: Token 文件存在且完整

```dart
// 验证代码 — test/ui/design_tokens_test.dart
test('E0-AC1: design_tokens.dart defines all required token categories', () {
  // 颜色 token
  expect(DesignColors.brandPrimary, isA<Color>());
  expect(DesignColors.brandSecondary, isA<Color>());
  expect(DesignColors.semanticSuccess, isA<Color>());
  expect(DesignColors.semanticError, isA<Color>());
  expect(DesignColors.semanticWarning, isA<Color>());
  expect(DesignColors.semanticInfo, isA<Color>());
  
  // 场景颜色
  expect(DesignColors.sceneCaptureBg, isA<Color>());
  expect(DesignColors.sceneThinkBg, isA<Color>());
  expect(DesignColors.sceneConnectBg, isA<Color>());
  
  // 文字颜色
  expect(DesignColors.textPrimary, isA<Color>());
  expect(DesignColors.textSecondary, isA<Color>());
  expect(DesignColors.textMuted, isA<Color>());
  expect(DesignColors.textInverse, isA<Color>());
});

test('E0-AC1b: spacing tokens are defined as const doubles', () {
  expect(DesignSpacing.xs, 4.0);
  expect(DesignSpacing.sm, 8.0);
  expect(DesignSpacing.md, 12.0);
  expect(DesignSpacing.lg, 16.0);
  expect(DesignSpacing.xl, 24.0);
  expect(DesignSpacing.xxl, 32.0);
});

test('E0-AC1c: radius tokens are defined as const doubles', () {
  expect(DesignRadius.sm, 6.0);
  expect(DesignRadius.md, 8.0);
  expect(DesignRadius.lg, 12.0);
  expect(DesignRadius.xl, 16.0);
  expect(DesignRadius.full, 999.0);
});

test('E0-AC1d: typography tokens are defined', () {
  expect(DesignTypography.displaySize, 28.0);
  expect(DesignTypography.headingSize, 20.0);
  expect(DesignTypography.bodySize, 14.0);
  expect(DesignTypography.codeSize, 13.0);
  expect(DesignTypography.bodyLineHeight, 1.6);
});

test('E0-AC1e: animation duration tokens are defined', () {
  expect(DesignDuration.sceneTransition, const Duration(milliseconds: 300));
  expect(DesignDuration.panelSlide, const Duration(milliseconds: 200));
  expect(DesignDuration.aiFloatExpand, const Duration(milliseconds: 250));
  expect(DesignDuration.clipSuccess, const Duration(milliseconds: 200));
  expect(DesignDuration.toastShow, const Duration(milliseconds: 300));
  expect(DesignDuration.toastHide, const Duration(milliseconds: 200));
});
```

#### 验收标准 E0-AC2: 颜色值与设计案一致

```dart
test('E0-AC2: brand colors match design spec', () {
  expect(DesignColors.brandPrimary, const Color(0xFF6366F1));
  expect(DesignColors.brandPrimaryLight, const Color(0xFF818CF8));
  expect(DesignColors.brandPrimaryDark, const Color(0xFF4F46E5));
  expect(DesignColors.brandSecondary, const Color(0xFF10B981));
  expect(DesignColors.brandSecondaryLight, const Color(0xFF34D399));
});

test('E0-AC2b: semantic colors match design spec', () {
  expect(DesignColors.semanticSuccess, const Color(0xFF10B981));
  expect(DesignColors.semanticWarning, const Color(0xFFF59E0B));
  expect(DesignColors.semanticError, const Color(0xFFEF4444));
  expect(DesignColors.semanticInfo, const Color(0xFF3B82F6));
});
```

#### Task E0-T1: 创建 design_tokens.dart

- **文件**: `lib/ui/theme/design_tokens.dart` (新建)
- **内容**: 定义 `DesignColors`、`DesignSpacing`、`DesignRadius`、`DesignTypography`、`DesignDuration`、`DesignShadow` 六个类，所有属性为 `static const`
- **验证**: `dart analyze` 通过

#### Task E0-T2: 将现有 app_theme.dart 中的硬编码色值引用为 token

- **文件**: `lib/ui/theme/app_theme.dart` (修改)
- **改动**: 仅将 `surface` 和 `surfaceContainer` 中已有的颜色提取为 token 引用（不改现有颜色值）
- **验证**: `dart analyze` 通过；视觉回归 — 应用外观与修改前完全一致

#### Task E0-T3: 编写 token 单元测试

- **文件**: `test/ui/design_tokens_test.dart` (新建)
- **覆盖**: E0-AC1(a-e), E0-AC2(a-b)
- **验证**: `flutter test test/ui/design_tokens_test.dart` 全绿

---

## Epic E1: 场景导航架构

> **目标**: 用三场景模型（捕捉/思考/连接）替代当前的 8 面板自由组合模型。保留所有现有页面组件，仅改变它们的容器和导航方式。  
> **依赖**: E0 完成  
> **关键约束**: 不破坏现有快捷键、Provider、数据流  

### User Story E1-US1: 用户能在三种场景间快速切换

**作为** 知识工作者  
**我想要** 在捕捉、思考、连接三种场景间一键切换  
**以便** 根据当前任务快速进入对应的工作模式，而无需手动组合面板  

#### 验收标准 E1-AC1: SceneSwitcher 组件正确渲染

```dart
// 验证代码 — test/ui/scene_navigation_test.dart
testWidgets('E1-AC1: SceneSwitcher renders three scene buttons', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: SceneSwitcher(
          currentScene: SceneType.capture,
          onSceneChanged: (_) {},
        ),
      ),
    ),
  );
  
  expect(find.text('捕捉'), findsOneWidget);
  expect(find.text('思考'), findsOneWidget);
  expect(find.text('连接'), findsOneWidget);
  
  // 当前场景高亮
  final captureButton = tester.widget<Material>(
    find.ancestor(of: find.text('捕捉'), matching: find.byType(Material)),
  );
  expect(captureButton.color, isNotNull); // 活跃状态有背景色
});
```

#### 验收标准 E1-AC2: 场景切换逻辑正确

```dart
testWidgets('E1-AC2: clicking scene button triggers scene change', (tester) async {
  SceneType? changedTo;
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: SceneSwitcher(
          currentScene: SceneType.capture,
          onSceneChanged: (scene) => changedTo = scene,
        ),
      ),
    ),
  );
  
  await tester.tap(find.text('思考'));
  expect(changedTo, SceneType.think);
  
  await tester.tap(find.text('连接'));
  expect(changedTo, SceneType.connect);
});
```

#### 验收标准 E1-AC3: 快捷键 Ctrl+1/2/3 触发场景切换

```dart
testWidgets('E1-AC3: Ctrl+1/2/3 shortcuts trigger scene changes', (tester) async {
  int sceneChangeCount = 0;
  
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: SceneScaffold(
          initialScene: SceneType.capture,
          onSceneChanged: (_) => sceneChangeCount++,
          captureView: (_) => const Text('Capture View'),
          thinkView: (_) => const Text('Think View'),
          connectView: (_) => const Text('Connect View'),
        ),
      ),
    ),
  );
  
  // Ctrl+2: 切换到思考场景
  await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
  await tester.sendKeyDownEvent(LogicalKeyboardKey.digit2);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.digit2);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
  await tester.pump();
  expect(sceneChangeCount, 1);
  
  // Ctrl+3: 切换到连接场景
  await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
  await tester.sendKeyDownEvent(LogicalKeyboardKey.digit3);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.digit3);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
  await tester.pump();
  expect(sceneChangeCount, 2);
});
```

#### 验收标准 E1-AC4: 场景切换保留上下文

```dart
testWidgets('E1-AC4: scene switch preserves browser URL and active note', (tester) async {
  // 此测试需要 Mock Provider 环境
  // 验证: 在 S1 加载页面 → 切换到 S2 → 回到 S1 → BrowserView 仍显示相同页面
  // 验证: 在 S2 打开笔记 A → 切换到 S1 → 回到 S2 → EditorView 仍显示笔记 A
  // 实现: SceneScaffold 使用 IndexedStack 或状态保持机制
});
```

#### 验收标准 E1-AC5: 场景切换动效

```dart
testWidgets('E1-AC5: scene change animation duration <= 350ms', (tester) async {
  final stopwatch = Stopwatch();
  
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: SceneScaffold(
          initialScene: SceneType.capture,
          captureView: (_) => const Text('Capture'),
          thinkView: (_) => const Text('Think'),
          connectView: (_) => const Text('Connect'),
        ),
      ),
    ),
  );
  
  // 通过 pump 测量动画帧
  stopwatch.start();
  // 触发切换...（通过 StateFinder 或 internal callback）
  // 动画过程中 pump 多帧
  await tester.pump(const Duration(milliseconds: 350));
  stopwatch.stop();
  
  // 350ms 后新旧视图应完成过渡
  expect(find.text('Think'), findsOneWidget);
  // capture view 可能仍在树中但不可见（取决于实现），或已移除
});
```

#### Task E1-T1: 创建 SceneType 枚举

- **文件**: `lib/ui/layout/scene_scaffold.dart` (新建)
- **内容**: 
  ```dart
  enum SceneType { capture, think, connect }
  ```
- **验证**: `dart analyze` 通过

#### Task E1-T2: 创建 SceneSwitcher 组件

- **文件**: `lib/ui/layout/scene_switcher.dart` (新建)
- **规格**:
  - 水平排列三个场景按钮
  - 每个按钮: 图标(24px) + 标签文字(12px) + 快捷键提示(10px, 灰色)
  - 活跃场景: 底部 2px primary 色指示条 + 背景色 primary.withAlpha(0.15)
  - 非活跃场景: 无指示条，透明背景，图标和文字 muted 色
  - 高度: 44px
  - 宽度: 三个按钮均分约 360px 总宽
  - 每个按钮宽度: ~110px
- **交互**:
  - 点击非活跃场景按钮 → 调用 `onSceneChanged`
  - 点击活跃场景按钮 → 无操作
  - Hover 态: 背景色 primary.withAlpha(0.05)
- **验证**: E1-AC1, E1-AC2 通过

#### Task E1-T3: 创建 SceneScaffold 组件

- **文件**: `lib/ui/layout/scene_scaffold.dart` (新建)
- **职责**: 管理三个场景的布局和切换
- **结构**:
  ```
  Column(
    children: [
      SceneSwitcher(...),            // 场景切换器
      Expanded(
        child: Stack(
          children: [
            // 三个场景视图，根据 currentScene 显示对应视图
            // 使用 AnimatedSwitcher 实现切换动画
          ],
        ),
      ),
      // AI Float (E2 时添加)
      // Status Bar
    ],
  )
  ```
- **关键实现**:
  - 使用 `IndexedStack` 或 `Visibility` 保持所有三个场景存活（避免销毁/重建）
  - 切换时使用 `AnimatedSwitcher` + fade + slide 动画
  - 接收三个 `WidgetBuilder` 参数: `captureView`, `thinkView`, `connectView`
- **验证**: E1-AC3, E1-AC4, E1-AC5 通过

#### Task E1-T4: 重构 main_layout.dart 集成 SceneScaffold

- **文件**: `lib/ui/layout/main_layout.dart` (修改)
- **改动**:
  1. `_activePanels` 集合 → `_currentScene` (SceneType)
  2. `_togglePanel()` → `_switchScene(SceneType)`
  3. `_buildTree()` → 移除（不再有 SplitPane 动态面板树）
  4. `_buildView()` → 保留（用于 SceneScaffold 的 viewBuilder 参数）
  5. 顶部菜单栏从面板按钮 → `SceneSwitcher` + 右侧操作按钮
  6. 主内容区从 `SplitPane` → `SceneScaffold`
- **保留**:
  - 状态栏逻辑
  - CommandBar 触发逻辑（Ctrl+K）
  - 快捷键绑定框架
  - 所有 Provider 监听
  - Vault 切换逻辑
- **回退安全**: 在 `SettingsProvider` 中新增 `useSceneLayout` 开关（默认 true），false 时回退到原面板布局
- **验证**: `dart analyze` 通过；手动测试 — 应用启动后场景切换正常

#### Task E1-T5: 编写场景导航测试

- **文件**: `test/ui/scene_navigation_test.dart` (新建)
- **覆盖**: E1-AC1 ~ E1-AC5
- **Mock**: 需要 Mock `vaultProvider`（设置 `currentVault != null`）
- **验证**: `flutter test test/ui/scene_navigation_test.dart` 全绿

---

## Epic E2: AI Float 浮动助手

> **目标**: 将 AI Chat 从固定面板提取为右下角浮动按钮+面板。保留 AIChatPanel 所有现有功能，仅改变容器。  
> **依赖**: E1 完成（SceneScaffold 提供 Stack 容器）  

### User Story E2-US1: 用户在任何场景下都能快速唤起 AI 助手

**作为** 知识工作者  
**我想要** 在任何场景右下角看到一个 AI 浮动按钮，点击即可展开对话  
**以便** 无需切换面板即可随时向 AI 提问  

#### 验收标准 E2-AC1: AI Float 按钮始终可见

```dart
// 验证代码 — test/ui/ai_float_test.dart
testWidgets('E2-AC1: AI Float collapsed button visible in all scenes', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: SceneScaffold(
          initialScene: SceneType.capture,
          captureView: (_) => const Text('Capture Content'),
          thinkView: (_) => const Text('Think Content'),
          connectView: (_) => const Text('Connect Content'),
          aiFloat: const AIFloat(), // 新增参数
        ),
      ),
    ),
  );
  
  // 验证 AI 按钮存在
  expect(find.byIcon(Icons.psychology), findsOneWidget);
  
  // 验证位置: 右下角 (通过检查 Align alignment)
  final align = tester.widget<Align>(
    find.ancestor(of: find.byIcon(Icons.psychology), matching: find.byType(Align)),
  );
  expect(align.alignment, Alignment.bottomRight);
});
```

#### 验收标准 E2-AC2: 点击展开面板

```dart
testWidgets('E2-AC2: tapping collapsed AI Float expands it', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: SceneScaffold(
          initialScene: SceneType.capture,
          captureView: (_) => const Text('Capture'),
          thinkView: (_) => const Text('Think'),
          connectView: (_) => const Text('Connect'),
          aiFloat: const AIFloat(),
        ),
      ),
    ),
  );
  
  // 初始: 折叠态
  expect(find.byType(AIChatPanel), findsNothing);
  
  // 点击 AI Float 按钮
  await tester.tap(find.byIcon(Icons.psychology));
  await tester.pump();
  
  // 展开动画播放
  await tester.pump(const Duration(milliseconds: 250));
  
  // 验证: AIChatPanel 出现（在浮动面板内）
  expect(find.byType(AIChatPanel), findsOneWidget);
});
```

#### 验收标准 E2-AC3: 点击外部区域折叠

```dart
testWidgets('E2-AC3: tapping outside expanded AI Float collapses it', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: SceneScaffold(
          initialScene: SceneType.capture,
          captureView: (_) => const Text('Capture Content Here'),
          thinkView: (_) => const Text('Think'),
          connectView: (_) => const Text('Connect'),
          aiFloat: const AIFloat(),
        ),
      ),
    ),
  );
  
  // 展开 AI Float
  await tester.tap(find.byIcon(Icons.psychology));
  await tester.pumpAndSettle(const Duration(milliseconds: 300));
  expect(find.byType(AIChatPanel), findsOneWidget);
  
  // 点击外部（主导视图区域）
  await tester.tap(find.text('Capture Content Here'));
  await tester.pumpAndSettle(const Duration(milliseconds: 300));
  
  // 验证: AI Float 折叠
  expect(find.byType(AIChatPanel), findsNothing);
  expect(find.byIcon(Icons.psychology), findsOneWidget); // 折叠按钮仍可见
});
```

#### 验收标准 E2-AC4: Escape 键折叠面板

```dart
testWidgets('E2-AC4: Escape key collapses expanded AI Float', (tester) async {
  // 展开 AI Float
  // 发送 Escape 键事件
  await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
  await tester.pumpAndSettle();
  
  // 验证: AI Float 折叠
  expect(find.byType(AIChatPanel), findsNothing);
});
```

#### 验收标准 E2-AC5: AI Float 上下文感知 placeholder

```dart
testWidgets('E2-AC5: AI Float placeholder adapts to current scene', (tester) async {
  // 场景 S1: placeholder 包含 "基于当前页面"
  // 场景 S2: placeholder 包含 "基于笔记"
  // 场景 S3: placeholder 包含 "关于 [节点]"
  // 
  // 实现: AIFloat 通过 SceneType 参数或 Provider 获取上下文
});
```

#### Task E2-T1: 创建 AIFloat 组件

- **文件**: `lib/ui/widgets/ai_float.dart` (新建)
- **结构**:
  ```
  Stack(
    children: [
      // 展开态: 浮动卡片
      if (_isExpanded)
        Positioned(
          right: 16, bottom: 72,
          child: AnimatedContainer(
            width: 360, height: 480,
            child: Card(AIChatPanel(...)),
          ),
        ),
      // 折叠态: 圆形按钮
      Positioned(
        right: 16, bottom: 16,
        child: FloatingActionButton.small(icon: Icons.psychology),
      ),
    ],
  )
  ```
- **状态管理**: 
  - `_isExpanded` 布尔值
  - 展开动画: `AnimationController` 250ms, `Curves.easeOutBack`
  - 折叠动画: 200ms `Curves.easeIn`
- **关键交互**:
  - 点击 FAB → toggle `_isExpanded`
  - 点击展开面板外部 → 通过 `GestureDetector` 透明遮罩层检测
  - 展开面板内保留 AIChatPanel 的完整功能（流式、Markdown、Skill、@引用）
- **上下文感知**:
  - 接收 `SceneType currentScene` 参数
  - 展开时根据场景自动设置输入框 placeholder
  - 用户未输入直接按发送 → 生成默认上下文发送给 AI
- **验证**: E2-AC1 ~ E2-AC5 通过

#### Task E2-T2: 集成 AIFloat 到 SceneScaffold

- **文件**: `lib/ui/layout/scene_scaffold.dart` (修改)
- **改动**:
  - 在 Stack children 最后添加 `AIFloat(currentScene: currentScene)`
  - AIFloat 的 z-order 最高（最后渲染）
- **验证**: `dart analyze` 通过；手动测试各场景 AI Float 交互

#### Task E2-T3: 编写 AI Float 测试

- **文件**: `test/ui/ai_float_test.dart` (新建)
- **覆盖**: E2-AC1 ~ E2-AC5
- **Mock**: Mock `aiProvider`（提供空消息列表避免 UI 报错）
- **验证**: `flutter test test/ui/ai_float_test.dart` 全绿

---

## Epic E3: 捕捉场景重构

> **目标**: 在 S1 捕捉场景中添加 ClipToolbar 和 AI 摘要面板。整合 ClipperService 已完整实现的功能，赋予它们一流的 UI 地位。  
> **依赖**: E1, E2 完成  

### User Story E3-US1: 用户在浏览网页时可以一键剪辑到知识库

**作为** 研究者  
**我想要** 在浏览器底部看到一个剪辑工具栏，点击即可将网页/选中文本/书签保存为笔记  
**以便** 快速捕捉有价值的信息而不中断浏览流  

#### 验收标准 E3-AC1: ClipToolbar 剪辑全文

```dart
// 验证代码 — test/ui/clip_toolbar_test.dart
testWidgets('E3-AC1: ClipToolbar full-page clip creates a note', (tester) async {
  // Mock: browserProvider 中有加载的页面
  // Mock: clipperService 返回成功
  // Mock: knowledgeProvider 初始 notes.length = 0
  
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        browserProvider.overrideWith(...), // url = 'https://example.com'
        clipperProvider.overrideWith(...), // clipFullPage returns Note(...)
      ],
      child: MaterialApp(
        home: Scaffold(body: ClipToolbar()),
      ),
    ),
  );
  
  // 点击剪辑全文按钮
  await tester.tap(find.text('剪辑全文'));
  await tester.pump();
  
  // 验证: knowledgeProvider.notes.length 增加 1
  // 验证: 新笔记 sourceUrl = 'https://example.com'
});
```

#### 验收标准 E3-AC2: 剪辑选中文本（有选中时可用，无选中时置灰）

```dart
testWidgets('E3-AC2: selection clip button disabled when no selection', (tester) async {
  // Mock: browserProvider.selectedText = ''
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        browserProvider.overrideWith((ref) => BrowserState(selectedText: '')),
      ],
      child: MaterialApp(home: Scaffold(body: ClipToolbar())),
    ),
  );
  
  final clipSelectionButton = find.widgetWithText(ElevatedButton, '剪辑选中');
  final button = tester.widget<ElevatedButton>(clipSelectionButton);
  expect(button.onPressed, isNull); // 按钮置灰
});

testWidgets('E3-AC2b: selection clip button enabled when text selected', (tester) async {
  // Mock: browserProvider.selectedText = 'some selected text'
  // ... 省略 setup
  
  final clipSelectionButton = find.widgetWithText(ElevatedButton, '剪辑选中');
  final button = tester.widget<ElevatedButton>(clipSelectionButton);
  expect(button.onPressed, isNotNull);
});
```

#### 验收标准 E3-AC3: 剪辑成功反馈动画

```dart
testWidgets('E3-AC3: clip success shows green flash on button', (tester) async {
  // 剪辑后验证: 按钮背景短暂变为绿色 (200ms)
  // 方法: Widget 中有 AnimationController, 检查 backgroundColor 变化
  
  // 点击剪辑按钮
  await tester.tap(find.text('剪辑全文'));
  await tester.pump(const Duration(milliseconds: 50));
  
  // 验证绿色闪烁（Material color 变化）
  // 此项测试取决于具体实现（AnimatedContainer 或 TweenAnimationBuilder）
});
```

#### 验收标准 E3-AC4: 剪辑后 toast 通知

```dart
testWidgets('E3-AC4: clip success shows toast notification', (tester) async {
  // 点击剪辑按钮后
  await tester.tap(find.text('剪辑全文'));
  await tester.pump(Duration.zero);
  
  // 验证 toast 出现
  expect(find.textContaining('已保存到知识库'), findsOneWidget);
  
  // 验证 toast 3s 后消失
  await tester.pump(const Duration(seconds: 3));
  await tester.pump(const Duration(milliseconds: 300)); // 消失动画
  expect(find.textContaining('已保存到知识库'), findsNothing);
});
```

#### 验收标准 E3-AC5: 剪辑错误处理

```dart
testWidgets('E3-AC5: clip failure shows error toast with red flash', (tester) async {
  // Mock: clipperService.clipFullPage throws Exception('Network error')
  
  await tester.tap(find.text('剪辑全文'));
  await tester.pump(Duration.zero);
  
  // 验证 toast 显示错误
  expect(find.textContaining('剪辑失败'), findsOneWidget);
  
  // 验证按钮短暂变红
  // (同 E3-AC3 但颜色为 error)
});
```

#### Task E3-T1: 创建 ClipToolbar 组件

- **文件**: `lib/ui/widgets/clip_toolbar.dart` (新建)
- **结构**:
  ```
  Container(
    height: 40,
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: theme.dividerColor)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ClipButton(icon: Icons.content_copy, label: '剪辑全文', onPressed: _clipFull),
        SizedBox(width: 8),
        _ClipButton(icon: Icons.text_select, label: '剪辑选中', onPressed: _clipSelection),
        SizedBox(width: 8),
        _ClipButton(icon: Icons.bookmark_outline, label: '书签', onPressed: _clipBookmark),
      ],
    ),
  )
  ```
- **依赖**: 
  - `clipperService` Provider（调用 `clipFullPage`, `clipSelection`, `clipBookmark`）
  - `browserProvider`（获取当前 URL、标题、HTML 内容、selectedText）
  - `knowledgeProvider`（剪辑成功后刷新笔记列表）
- **动画**:
  - `_ClipButton` 是 AnimatedContainer: backgroundColor 从 normal → green/red → normal
  - 使用 `AnimationController` + `ColorTween`
- **验证**: E3-AC1 ~ E3-AC5 通过

#### Task E3-T2: 创建 AISummaryPanel 组件（AI 自动摘要）

- **文件**: `lib/ui/widgets/ai_summary_panel.dart` (新建)
- **行为**:
  - 折叠态: 右侧 24px 竖条 "AI 摘要"
  - 展开态: 280px 宽面板
  - 自动触发: 页面加载完成 2s 后，若停留 >5s，发送摘要请求
  - 内容: AI 返回的 3-5 条要点 + 相关笔记列表
- **注意**: 此项功能需要 AI 服务支持，初期可用占位 UI + "即将上线"
- **验证**: E3-AC6 省略，作为下一迭代项

#### Task E3-T3: 构建 S1 场景完整布局

- **文件**: `lib/ui/layout/main_layout.dart` (修改)
- **改动**: `_buildCaptureScene()` 方法:
  ```dart
  Widget _buildCaptureScene() {
    return Row(
      children: [
        // 左侧笔记面板 (可折叠)
        if (_leftPanelExpanded) NoteSidebar(width: 240),
        // 浏览器 + 剪辑工具栏
        Expanded(
          child: Column(
            children: [
              Expanded(child: BrowserView()),
              ClipToolbar(), // 固定在底部
            ],
          ),
        ),
        // 右侧 AI 摘要面板 (可折叠)
        if (_rightPanelExpanded) AISummaryPanel(width: 280),
      ],
    );
  }
  ```
- **验证**: `dart analyze` 通过

#### Task E3-T4: 编写 ClipToolbar 测试

- **文件**: `test/ui/clip_toolbar_test.dart` (新建)
- **覆盖**: E3-AC1 ~ E3-AC5
- **验证**: `flutter test test/ui/clip_toolbar_test.dart` 全绿

---

## Epic E4: 思考场景重构

> **目标**: 在 S2 思考场景中添加 AI 内联建议栏和 Wikilink 自动补全。增强编辑器体验。  
> **依赖**: E1, E2 完成  

### User Story E4-US1: AI 在用户写作时主动建议笔记链接

**作为** 写作者  
**我想要** 当我输入已知概念时，AI 自动建议链接到已有笔记  
**以便** 快速建立知识连接而不需要手动搜索  

#### 验收标准 E4-AC1: AI 内联建议栏触发

```dart
// 测试文件: test/ui/ai_inline_suggestion_test.dart
testWidgets('E4-AC1: inline suggestion appears after 1.5s pause', (tester) async {
  // 需要完整的 EditorView 环境
  // Mock: knowledgeProvider.notes 包含 "认知心理学导论"
  // 
  // 在 TextField 中输入 "认知负荷"
  // 停止输入 1.5s
  // 验证: 建议栏出现 "是否链接到 [[认知心理学导论]]？"
});
```

#### 验收标准 E4-AC2: 点击"链接"插入 Wikilink

```dart
testWidgets('E4-AC2: clicking "链接" inserts wikilink at cursor', (tester) async {
  // 建议栏可见
  // 点击 "链接" 按钮
  // 验证: TextField 内容包含 "[[认知心理学导论]]"
  // 验证: 建议栏消失
});
```

#### 验收标准 E4-AC3: 点击"忽略"隐藏并记住

```dart
testWidgets('E4-AC3: clicking "忽略" hides suggestion for this session', (tester) async {
  // 建议栏可见
  // 点击 "忽略" 
  // 验证: 建议栏消失
  // 再次输入 "认知负荷" → 1.5s → 不应再出现同一建议
});
```

#### 验收标准 E4-AC4: Wikilink 自动补全弹出

```dart
testWidgets('E4-AC4: typing [[ triggers wikilink autocomplete popup', (tester) async {
  // 在编辑器中输入 "[["
  // 验证: 弹出搜索结果列表
  // 验证: 结果复用 hybrid search
  // 验证: 弹出框宽度 = 300px, 最多 8 条
});
```

#### Task E4-T1: 创建 AIInlineSuggestion 组件

- **文件**: `lib/ui/widgets/ai_inline_suggestion.dart` (新建)
- **结构**:
  ```
  AnimatedSlide(
    child: Container(
      height: min(contentHeight, 80),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withAlpha(0.08),
        border: Border(top: BorderSide(color: theme.colorScheme.primary.withAlpha(0.2))),
      ),
      child: Row(
        children: [
          Text('💡 AI: $suggestionText'),
          Spacer(),
          TextButton('链接', onPressed: _onLink),
          TextButton('展开', onPressed: _onExpand),
          TextButton('忽略', onPressed: _onIgnore),
        ],
      ),
    ),
  )
  ```
- **状态管理**:
  - `_visible`: bool
  - `_suggestionText`: String
  - `_targetNoteTitle`: String
  - `_ignoredPairs`: Set<String> (会话内)
- **触发逻辑**:
  - 监听 `TextEditingController` 的输入
  - 1.5s debounce after last change
  - 遍历 `knowledgeProvider.notes` 检查标题是否在当前编辑内容中出现
  - 出现且未链接（不在 `[[...]]` 中）→ 生成建议
- **验证**: E4-AC1 ~ E4-AC3 通过

#### Task E4-T2: 实现 Wikilink 自动补全

- **文件**: `lib/ui/pages/editor_page.dart` (修改)
- **改动**:
  - 监听 `_controller.text`，当检测到 `[[` 时：
    1. 计算弹出位置（光标位置转屏幕坐标）
    2. 显示 `OverlayEntry` 或内嵌弹窗
    3. 弹窗内容: 搜索框 + 结果列表
  - 复用: `hybridSearchProvider` 搜索笔记标题
  - 选中后: 插入 `[[笔记标题]]`，光标移到 `]]` 之后
- **验证**: E4-AC4 通过

#### Task E4-T3: 构建 S2 场景完整布局

- **文件**: `lib/ui/layout/main_layout.dart` (修改)
- **改动**: `_buildThinkScene()` 方法:
  ```dart
  Widget _buildThinkScene() {
    return Stack(
      children: [
        Row(
          children: [
            // 左侧大纲/笔记面板
            if (_leftPanelExpanded) _buildOutlinePanel(),
            // 编辑器
            Expanded(child: EditorView()),
            // 右侧反向链接 + AI 建议
            if (_rightPanelExpanded) _buildThinkRightPanel(),
          ],
        ),
        // AI 内联建议 (覆盖在编辑器底部)
        if (_suggestionVisible)
          Positioned(
            left: leftPanelWidth,
            right: rightPanelWidth,
            bottom: 0,
            child: AIInlineSuggestion(...),
          ),
      ],
    );
  }
  ```
- **验证**: `dart analyze` 通过

#### Task E4-T4: 编写 AI 内联建议测试

- **文件**: `test/ui/ai_inline_suggestion_test.dart` (新建)
- **覆盖**: E4-AC1 ~ E4-AC4
- **验证**: `flutter test test/ui/ai_inline_suggestion_test.dart` 全绿

---

## Epic E5: 连接场景重构

> **目标**: 在 S3 连接场景中添加筛选面板、节点详情面板和脉动动画。  
> **依赖**: E1, E2 完成  

### User Story E5-US1: 用户可以在图谱中筛选节点并查看详情

**作为** 学习者  
**我想要** 在图谱中使用筛选器缩小关注范围，并单击节点查看详情和 AI 解释  
**以便** 高效地探索知识网络中的特定领域  

#### 验收标准 E5-AC1: 节点单击选中 + 脉动动画

```dart
// 测试: 图谱交互已有 graph_layout_test.dart 可扩展
test('E5-AC1: graph node selection triggers pulse animation', () {
  // 单元测试: NodePulseController 
  // start(nodeId) → _selectedNodeId == nodeId
  // _animationController.isAnimating == true
  
  // 动画值范围: 1.0 → 1.08 → 1.0 循环
});
```

#### 验收标准 E5-AC2: 双击节点跳转编辑

```dart
// 验证: 双击图谱节点 → SceneType 变为 think
// 验证: knowledgeProvider.activeNote 为对应笔记
```

#### 验收标准 E5-AC3: 筛选面板即时生效

```dart
test('E5-AC3: tag filter changes graph display immediately', () {
  // FilterPanel: toggle tag "机器学习"
  // 验证: GraphView.displayNotes 仅包含 "机器学习" 标签的笔记
  // 验证: 不需要点击 "应用" 按钮
});
```

#### Task E5-T1: 实现图谱节点脉动动画

- **文件**: `lib/ui/pages/graph_page.dart` (修改)
- **改动**:
  - 选中节点时, `_selectedNode` setter 中启动 `AnimationController(repeat: true)`
  - 动画值驱动节点缩放: `1.0 + 0.08 * sin(animation.value * 2 * pi)`
  - 取消选中时停止动画并重置
- **验证**: `dart analyze` 通过

#### Task E5-T2: 创建 FilterPanel 筛选面板

- **文件**: `lib/ui/widgets/filter_panel.dart` (新建)
- **内容**:
  - 标签选择: `Wrap` + `FilterChip` 多选
  - 时间范围: `RangeSlider` (基于笔记的 created/modified 时间)
  - 连接深度: `Slider` 1-4
  - "只看桥接节点": `Switch`
- **数据源**: `knowledgeProvider.notes[].tags`, `graphAlgorithm.bridgeNodes`
- **验证**: E5-AC3 通过

#### Task E5-T3: 创建 NodeDetailPanel 节点详情面板

- **文件**: `lib/ui/widgets/node_detail_panel.dart` (新建)
- **内容**:
  - 选中态: 笔记标题（可点击 → `Navigator` 或 `SceneType.think`）+ 标签 chips + 出链/入链数量 + AI 关系解释
  - 未选中态: 图谱统计摘要（复用 `GraphStatsCard`）
  - AI 关系解释: 选中节点 500ms debounce → 调用 AI 生成简短的连接说明
- **验证**: `dart analyze` 通过

#### Task E5-T4: 构建 S3 场景完整布局

- **文件**: `lib/ui/layout/main_layout.dart` (修改)
- **改动**: `_buildConnectScene()` 方法:
  ```dart
  Widget _buildConnectScene() {
    return Row(
      children: [
        if (_leftPanelExpanded) SizedBox(width: 220, child: FilterPanel()),
        Expanded(
          child: _connectSubMode == ConnectSubMode.graph
              ? GraphView()
              : CanvasView(),
        ),
        if (_rightPanelExpanded) SizedBox(width: 280, child: NodeDetailPanel()),
      ],
    );
  }
  ```
- 子模式切换: Graph ↔ Canvas（Ctrl+Shift+G / Ctrl+Shift+C）
- **验证**: `dart analyze` 通过

---

## Epic E6: 空状态引导 + 全局搜索

> **目标**: 实现满足 UX-2 规则的空状态引导页，以及在状态栏添加始终可见的全局搜索。  
> **依赖**: E1 完成  
> **关键约束**: 完全满足 UX-2 "empty states must guide the user"  

### User Story E6-US1: 新用户打开空 Vault 时看到明确的引导

**作为** 新用户  
**我想要** 打开空知识库时看到清晰的引导提示  
**以便** 知道第一步应该做什么，而不面对 4 个空面板  

#### 验收标准 E6-AC1: 空 Vault 引导视图

```dart
testWidgets('E6-AC1: empty vault shows guided onboarding view', (tester) async {
  // Mock: vaultProvider.currentVault != null
  // Mock: knowledgeProvider.notes = []
  
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        knowledgeProvider.overrideWith((ref) => KnowledgeState(notes: [])),
        vaultProvider.overrideWith((ref) => VaultState(
          currentVault: VaultConfig(name: 'Test', path: '/test'),
        )),
      ],
      child: MaterialApp(home: SceneScaffold(...)),
    ),
  );
  
  // 不应该看到场景布局
  // 应看到 EmptyVaultGuide
  expect(find.byType(EmptyVaultGuide), findsOneWidget);
  expect(find.text('从你的第一条信息开始'), findsOneWidget);
  
  // 两个 CTA
  expect(find.text('粘贴网页链接'), findsOneWidget);
  expect(find.text('写一条笔记'), findsOneWidget);
});
```

#### 验收标准 E6-AC2: 粘贴链接流程

```dart
testWidgets('E6-AC2: pasting a URL in empty guide clips and opens note', (tester) async {
  // Mock: clipperService.clipFullPage returns Note(...)
  // 
  // 在输入框粘贴 URL
  // 按 Enter
  // 验证: knowledgeProvider.notes.length == 1
  // 验证: 当前场景切换到 S2 思考
});
```

#### 验收标准 E6-AC3: 各场景内的空状态

```dart
testWidgets('E6-AC3: S1 empty state shows URL input', (tester) async {
  // 有笔记但浏览器无页面 → 显示 "输入网址或搜索..."
});

testWidgets('E6-AC3b: S2 empty state shows recent notes grid', (tester) async {
  // knowledgeProvider.notes.length > 0 但 activeNote == null
  // 显示 "选择一条笔记开始编辑" + 最近 5 条笔记
});
```

#### 验收标准 E6-AC4: QuickSearchBar 在状态栏

```dart
testWidgets('E6-AC4: QuickSearchBar visible in status bar', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(home: SceneScaffold(...)),
    ),
  );
  
  // 验证状态栏中有搜索区域
  expect(find.byType(QuickSearchBar), findsOneWidget);
  
  // 验证 placeholder
  expect(find.text('搜索笔记...'), findsOneWidget);
});

testWidgets('E6-AC4b: QuickSearchBar shows results after 300ms debounce', (tester) async {
  // 输入 "认"
  // await pump(Duration(milliseconds: 300))
  // 验证: 结果列表出现（最多 5 条）
  // 结果格式: 标题 + 最近修改日期
});

testWidgets('E6-AC4c: Ctrl+K in QuickSearch opens CommandBar with query', (tester) async {
  // 在 QuickSearch 中输入 "认知"
  // 按 Ctrl+K
  // 验证: CommandBar 打开，预填充 "认知"
  // 验证: QuickSearch 关闭
});
```

#### Task E6-T1: 创建 EmptyVaultGuide 组件

- **文件**: `lib/ui/pages/empty_vault_guide.dart` (新建)
- **UI**:
  ```
  Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo + 标题
        Icon(Icons.explore, 64, primary),
        Text('从你的第一条信息开始', style: display),
        
        // 输入区域
        Container(width: 480, child: TextField(
          decoration: '粘贴网页链接或输入搜索词...',
          onSubmitted: _handleSubmit,
        )),
        
        // 或
        Text('— 或者 —'),
        OutlinedButton.icon('写一条笔记 ✍️', onPressed: _createEmptyNote),
        
        // 底部提示轮播
        _TipCarousel(tips: ['提示 1: ...', '提示 2: ...', '提示 3: ...']),
      ],
    ),
  )
  ```
- **_handleSubmit logic**:
  - 检测输入是否为 URL (startsWith 'http' 或包含 '.com' 等)
    → 调用 clipperService → 创建笔记 → 切换到 S2
  - 否则 → 按搜索词创建笔记标题 → 切换到 S2
- **验证**: E6-AC1, E6-AC2 通过

#### Task E6-T2: 在各场景中添加空状态

- **文件**: `lib/ui/layout/main_layout.dart` (修改)
- **改动**:
  - S1: browserProvider 无活跃页面时 → 显示 URL 输入 + 快捷链接网格
  - S2: knowledgeState.activeNote == null → 显示 "选择笔记" + 最近笔记列表
  - S3: notes.isEmpty → 显示引导（已有的逻辑保留）
- **验证**: E6-AC3 通过

#### Task E6-T3: 创建 QuickSearchBar 组件

- **文件**: `lib/ui/widgets/quick_search_bar.dart` (新建)
- **规格**:
  - 内联在状态栏右侧
  - 默认显示 🔍 + "搜索笔记..."(灰色文字)
  - 点击变为可输入，宽度 200px
  - 输入 ≥2 字符 → 300ms debounce → fuzzy match 笔记标题 → 最多 5 条下拉结果
  - Ctrl+K 升级到 CommandBar
- **验证**: E6-AC4 通过

#### Task E6-T4: 编写空状态测试

- **文件**: `test/ui/empty_state_test.dart` (新建)
- **覆盖**: E6-AC1 ~ E6-AC4
- **验证**: `flutter test test/ui/empty_state_test.dart` 全绿

---

## Epic E7: 集成测试 + 回归

> **目标**: 确保所有重构不引入回归，性能满足约束。  
> **依赖**: E1-E6 全部完成  

### User Story E7-US1: 现有功能在新布局下正常运行

**作为** 产品负责人  
**我想要** 确认所有现有功能在新 UI 下正常工作  
**以便** 放心发布新版本  

#### 验收标准 E7-AC1: flutter analyze 0 issues

```bash
$ flutter analyze
No issues found! (ran in Xms)
```

#### 验收标准 E7-AC2: 现有测试不减损

```bash
$ flutter test
# 所有已有 test/ 下的测试文件全部通过
# 不包括新增测试文件（E0-E6 测试文件内测试）
```

#### 验收标准 E7-AC3: 性能约束面板

| 操作 | 期望 | 验证方式 |
|------|------|---------|
| 场景切换 | ≤350ms | Performance overlay |
| AI Float 展开 | ≤250ms | AnimationController duration |
| 剪辑按钮反馈 | ≤200ms | 肉眼 + 代码验证 |
| 图谱缩放 | 60fps | Performance overlay |
| 编辑器输入 | 60fps | 无 jank |

#### 验收标准 E7-AC4: 基因组约束合规

```bash
$ python seeds/orchestrator.py --check-constraints
# C010 (P-1 debounced save): 验证通过
# C031 (UX-1 trigger): 验证通过 (ClipToolbar = ClipperService trigger)
# C032 (UX-2 empty states): 验证通过 (EmptyVaultGuide)
# C034 (UX-4 streaming): 验证通过 (AI Float 内 AIChatPanel 保留流式)
```

#### Task E7-T1: 运行全量测试套件

- **命令**: `flutter test`
- **检查**: 新增测试文件全部通过，已有测试文件不降级
- **修复**: 若有失败，逐文件对照修改

#### Task E7-T2: 手动验收清单

执行以下手动测试（桌面 Windows 平台）：

| # | 测试场景 | 操作步骤 | 期望结果 |
|---|---------|---------|---------|
| 1 | 启动应用 | 打开 RFBrowser | 显示 WelcomePage |
| 2 | 创建新 Vault | WelcomePage → 创建 Vault → 选空目录 | 显示 EmptyVaultGuide |
| 3 | 创建第一条笔记 | EmptyVaultGuide → "写一条笔记" → 输入标题 | 切换到 S2 思考，编辑器显示新笔记 |
| 4 | 场景切换 | Ctrl+1 → Ctrl+2 → Ctrl+3 | 三个场景依次切换，动画流畅 |
| 5 | AI Float 交互 | 右下角 AI 按钮 → 展开 → 输入消息 → 发送 | AI 流式回复，Markdown 渲染 |
| 6 | AI Float 折叠 | AI Float 展开态 → Esc | 面板折叠，对话历史保留 |
| 7 | S1 剪辑 | S1 捕捉 → 输入 URL → 加载 → 点 📎 | 按钮变绿，toast 出现，笔记列表新笔记闪烁 |
| 8 | S2 Wikilink 补全 | S2 思考 → 输入 `[[` | 弹出搜索列表，选中后插入完整 wikilink |
| 9 | S3 图谱交互 | S3 连接 → 单击节点 | 节点脉动动画，右侧详情面板显示 |
| 10 | S3 双击跳转 | S3 连接 → 双击节点 | 切换到 S2 思考，打开对应笔记 |
| 11 | 全局搜索 | 状态栏搜索 → 输入 2+ 字符 | 下拉列表出现，选中打开笔记 |
| 12 | Ctrl+K 命令栏 | 任意场景 → Ctrl+K | 全屏 CommandBar，功能完整 |

#### Task E7-T3: 更新 genome.yaml 约束状态

- **文件**: `seeds/evolution/genome.yaml` (修改)
- **更新**: C010, C011, C012, C013 → trigger_count, last_triggered, evidence
- **验证**: `python seeds/orchestrator.py --check-constraints` 违规数减少

#### Task E7-T4: 更新 session-state.yaml

- **文件**: `seeds/memory/session-state.yaml` (修改)
- **内容**:
  ```yaml
  completed_criteria:
    - "UX redesign: 3-scene navigation model implemented"
    - "UX redesign: AI Float component created"
    - "UX redesign: ClipToolbar added to capture scene"
    - "UX redesign: AI inline suggestions in think scene"
    - "UX redesign: Filter + detail panels in connect scene"
    - "UX redesign: EmptyVaultGuide implemented (UX-2 compliant)"
    - "UX redesign: QuickSearchBar added to status bar"
  status: solid
  ```

---

## 附录 A: 风险与缓解

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|---------|
| AIChatPanel 作为浮动面板时布局异常 | 中 | 中 | 在 Widget 测试中覆盖 360×480px 容器尺寸 |
| 场景切换保留上下文的实现复杂度高 | 中 | 中 | 使用 `IndexedStack`（3 个子 widget 始终存活）而非重建 |
| ClipToolbar 依赖 ClipperService 异步操作 | 低 | 中 | ClipperService 已经实现且测试过；仅需 UI 集成 |
| 与现有快捷键系统的冲突 | 低 | 高 | 保留所有现有快捷键，Ctrl+1/2/3 之前已分配给视图模式 |
| 性能退化（IndexedStack 保持 3 场景常驻） | 低 | 中 | Flutter IndexedStack 不渲染不可见子节点；监控内存/帧率 |

---

## 附录 B: 快捷键映射

| 快捷键 | 旧行为 | 新行为 | 状态 |
|--------|-------|--------|------|
| Ctrl+1 | 全屏浏览器 | S1 捕捉场景（浏览器主导） | 兼容升级 |
| Ctrl+2 | 全屏编辑器 | S2 思考场景（编辑器主导） | 兼容升级 |
| Ctrl+3 | 全屏图谱 | S3 连接场景（图谱/画布） | 兼容升级 |
| Ctrl+K | 打开命令栏 | 打开命令栏 | **不变** |
| Ctrl+N | 新建笔记 | 新建笔记 | **不变** |
| Ctrl+S | 保存笔记 | 保存笔记 | **不变** |
| Ctrl+F | -- | 聚焦 Quick Search | 新增 |
| Ctrl+J | -- | 展开 AI Float | 新增 |
| Ctrl+Shift+G | -- | S3 切换为 Graph 子模式 | 新增 |
| Ctrl+Shift+C | -- | S3 切换为 Canvas 子模式 | 新增 |
| Esc | -- | 折叠 AI Float / 关闭 CommandBar | 增强 |

---

## 附录 C: 开发顺序建议

```
Day 1:    E0 (Token 基础设施) + E1-T1/T2 (SceneType, SceneSwitcher)
Day 2-3:  E1-T3/T4/T5 (SceneScaffold, main_layout 重构, 测试)
Day 4-5:  E2 (AI Float 组件, 集成, 测试)
          ─── MVP 可演示点: 三场景切换 + AI Float ───
Day 6-7:  E3 (ClipToolbar, S1 布局, 测试)
Day 8:    E4 (AI 内联建议, Wikilink 补全, S2 布局, 测试)
Day 9:    E5 (FilterPanel, NodeDetailPanel, 脉动动画, S3 布局)
Day 10:   E6 (EmptyVaultGuide, QuickSearchBar, 各场景空状态, 测试)
Day 11:   E7 (全量测试, 手动验收, 基因组更新)
Day 12:   Buffer (修复发现的 bug, 打磨动画细节)
```

**每个 Day 结束时运行**:
1. `flutter analyze` — 必须 0 issues
2. `flutter test` — 所有测试通过
3. `python seeds/orchestrator.py --check-constraints` — 新增违规数 ≤ 0
