# RFBrowser 画布重设计 — 开发计划

> 依赖设计案: [canvas-redesign.md](./canvas-redesign.md)
> 预估总工时: ~5 天

---

## Phase 0: 模型层扩展 (Day 1 上午)

本阶段仅扩展数据模型，不改变任何运行时行为，向后兼容。

### Task 0.1: CanvasConnection 新增 isAuto 字段
- **文件**: `lib/core/model/canvas_model.dart` (修改)
- **改动**:
  1. `CanvasConnection` 构造器新增 `this.isAuto = false`
  2. `copyWith` 新增 `bool? isAuto` 参数
  3. `toJson` 新增 `'isAuto': isAuto` 
  4. `fromJson` 兼容旧格式：`isAuto: json['isAuto'] as bool? ?? false`
- **验证**: `dart analyze` 通过，现有测试不减损

### Task 0.2: CanvasData 新增 settings 区段
- **文件**: `lib/core/model/canvas_model.dart` (修改)
- **改动**:
  1. `CanvasData` 新增 `final CanvasSettings? settings` 字段（可选，向前兼容）
  2. `copyWith` 新增 `CanvasSettings? settings`
  3. `toJsonString` 输出新增 `'settings': settings?.toJson() ?? {'autoConnectionsEnabled': true}`
  4. `fromJsonString` 解析 `settings` 字段，缺失时默认 `CanvasSettings()`
- **验证**: 序列化 round-trip 测试通过

### Task 0.3: 新增 CanvasSettings 和 CanvasSearchState
- **文件**: `lib/core/model/canvas_model.dart` (追加)
- **内容**: 
  ```dart
  class CanvasSettings {
    final bool autoConnectionsEnabled;
    final DateTime lastModified;
    // toJson / fromJson
  }
  
  class CanvasSearchState {
    final String query;
    final List<String> matchedCardIds;
    final int activeIndex;
    // isActive getter, copyWith
  }
  ```
- **验证**: `dart analyze` 通过

### Task 0.4: 单元测试（模型层）
- **文件**: `test/core/model/canvas_model_test.dart` (新建，扩展已有)
- **覆盖**: AC-M-1 到 AC-M-6（详见设计案 5.1）
- **验证**: `flutter test test/core/model/canvas_model_test.dart` 全绿

---

## Phase 1: 服务层 — 自动连线 + 搜索 + 文件持久化 (Day 1 下午 - Day 2)

### Task 1.1: CanvasNotifier 新增 autoConnections 状态管理
- **文件**: `lib/services/canvas_service.dart` (修改)
- **改动**:
  1. `build()` 中初始化 `autoConnectionsEnabled = true`
  2. 新增方法:
     ```dart
     void toggleAutoConnections() { /* 切换 + _save() */ }
     bool get autoConnectionsEnabled => /* from state.settings */;
     ```
- **验证**: `dart analyze` 通过

### Task 1.2: 实现 _deriveAutoConnections()
- **文件**: `lib/services/canvas_service.dart` (修改)
- **逻辑**:
  1. 监听 `ref.watch(knowledgeProvider).outlinks`
  2. 遍历画布中所有有 `noteId` 的卡片对
  3. 若 noteId_A 的 outlinks 包含 noteId_B，生成 `CanvasConnection(isAuto: true)`
  4. 去重：已存在同方向手动连线则跳过
  5. 自动连线不存储在 `state.connections` 中，而是作为 computed property `derivedConnections`
- **关键**: 自动连线是派生状态，不持久化到文件。持久化的仅手动连线 + settings。
- **验证**: 单元测试 AC-S-1 ~ AC-S-4

### Task 1.3: 实现 searchCards()
- **文件**: `lib/services/canvas_service.dart` (修改)
- **方法签名**: `List<CanvasCard> searchCards(String query)`
- **逻辑**: `state.cards.where((c) => c.title.toLowerCase().contains(query.toLowerCase()) || c.content.toLowerCase().contains(query.toLowerCase())).toList()`
- **验证**: 单元测试 AC-S-8 ~ AC-S-11

### Task 1.4: 文件持久化迁移
- **文件**: `lib/services/canvas_service.dart` (修改)
- **改动**:
  1. 导入 `dart:io`, `package:path/path.dart as p`
  2. 新增 `_canvasFilePath()` 方法
  3. 改写 `_save()` → `_saveToFile()` + `_saveToSharedPrefs()` fallback
  4. 改写 `loadCanvas()` → `_loadFromFile()` + `_migrateFromSharedPrefs()`
  5. 迁移逻辑：若文件不存在但 SharedPreferences 有 `'canvas_data'` → 读入 → 写入文件 → 删除旧 key
  6. `_saveToFile()` 吞异常，不阻塞 UI
- **验证**: 单元测试 AC-S-5 ~ AC-S-7

### Task 1.5: 单元测试（服务层）
- **文件**: `test/services/canvas_service_test.dart` (新建，扩展已有)
- **覆盖**: AC-S-1 到 AC-S-11
- **验证**: `flutter test test/services/canvas_service_test.dart` 全绿

---

## Phase 2: UI — 自动连线渲染 + 视觉区分 (Day 2 下午 - Day 3)

### Task 2.1: _ConnectionPainter 支持虚线
- **文件**: `lib/ui/pages/canvas_page.dart` (修改 `_ConnectionPainter`)
- **改动**:
  1. 构造器新增 `List<CanvasConnection> autoConnections` 参数
  2. `paint()` 方法中区分渲染：
     - 手动连线：`Paint()` solid, strokeWidth=2, 主色
     - 自动连线：`Paint()` dashed (`[4, 4]`), strokeWidth=1.5, 主色 with alpha=0.5
  3. Flutter 中虚线用 `PathMetrics` + dash interval 绘制
  4. `shouldRepaint` 新增 `autoConnections` 比较
- **参考 AGENTS.md P-2**: shouldRepaint 必须比较实际数据
- **验证**: Widget 测试验证虚线样式

### Task 2.2: CanvasView 集成自动连线
- **文件**: `lib/ui/pages/canvas_page.dart` (修改 `build()`)
- **改动**:
  1. 从 `canvasProvider` 获取 `autoConnectionsEnabled`
  2. 计算派生自动连线列表 → 传给 `_ConnectionPainter`
  3. 工具栏新增自动连线开关按钮:
     ```dart
     _toolbarButton(theme, 
       autoEnabled ? Icons.auto_fix_high : Icons.auto_fix_off,
       autoEnabled ? 'Auto-connect: ON' : 'Auto-connect: OFF',
       () => ref.read(canvasProvider.notifier).toggleAutoConnections(),
     )
     ```
- **验证**: Widget 测试验证开关行为

### Task 2.3: 连线右键菜单
- **文件**: `lib/ui/pages/canvas_page.dart` (修改 `_ConnectionPainter` + 新增 `_connectionContextMenu`)
- **改动**:
  1. 连线可点击（在 `paint()` 中记录每条连线的 `Path` 边界用作命中检测）
  2. 右键弹出菜单项：编辑标签 / 转为手动(仅自动连线) / 删除
- **简化取舍**: 点选连线的精确 HitTest 较复杂，本阶段可用"点击连线两端任意一端卡片"来选中连线
- **验证**: Widget 测试

### Task 2.4: Widget 测试
- **文件**: `test/ui/pages/canvas_page_test.dart` (新建)
- **覆盖**: 详见设计案 6.2
- **验证**: `flutter test test/ui/pages/canvas_page_test.dart` 全绿

---

## Phase 3: UI — 卡片实时同步 + 搜索 (Day 3 下午 - Day 4 上午)

### Task 3.1: 卡片渲染逻辑改为实时引用
- **文件**: `lib/ui/pages/canvas_page.dart` (修改 `_buildCard` + `_buildCardContent`)
- **改动**:
  1. `_buildCard()` 中：若 `card.noteId != null`，从 `ref.watch(knowledgeProvider).notes` 查找对应 note
  2. 渲染时使用 `note.title` 和 `note.content`（截断前 500 字符）替代 `card.title` / `card.content`
  3. 笔记不存在时降级显示：`title = "${card.title} [已删除]"，content = card.content`，标题旁显示警告图标
  4. 纯文本卡片（无 noteId）行为不变
- **参考 AGENTS.md F-7**: 不在 build() 中无条件赋值 TextEditingController
- **验证**: Widget 测试验证实时同步

### Task 3.2: 搜索框 UI
- **文件**: `lib/ui/pages/canvas_page.dart` (修改 `_buildToolbar` + 新增状态字段)
- **改动**:
  1. 状态新增: `String _searchQuery = ''`, `List<String> _searchMatchedIds = []`, `int _searchActiveIndex = 0`
  2. 工具栏新增搜索框:
     ```dart
     SizedBox(
       width: 180,
       child: TextField(
         decoration: InputDecoration(
           hintText: '搜索卡片...',
           isDense: true,
           contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
         ),
         style: TextStyle(fontSize: 12),
         onChanged: _onSearchChanged,
         onSubmitted: _onSearchSubmit,
       ),
     )
     ```
  3. `_onSearchChanged()`: 200ms debounce + `ref.read(canvasProvider.notifier).searchCards(query)` → 更新匹配列表
  4. 匹配的卡片边框高亮（如 `Colors.orange`），右侧显示计数 "3/12"
  5. `_onSearchSubmit()`: 画面平移+缩放到第一个匹配卡片居中

### Task 3.3: F3 / Shift+F3 搜索导航
- **文件**: `lib/ui/pages/canvas_page.dart` (修改)
- **改动**:
  1. 在 `build()` 中包裹 `CallbackShortcuts`:
     ```dart
     CallbackShortcuts(
       bindings: {
         const SingleActivator(LogicalKeyboardKey.f3): _searchNext,
         const SingleActivator(LogicalKeyboardKey.f3, shift: true): _searchPrev,
       },
       child: /* existing content */,
     )
     ```
  2. `_searchNext()`: `_searchActiveIndex = (_searchActiveIndex + 1) % _searchMatchedIds.length`，平移画面
  3. `_searchPrev()`: 逆向循环
- **验证**: Widget 测试

### Task 3.4: 清空搜索恢复
- **文件**: `lib/ui/pages/canvas_page.dart` (修改)
- **改动**: 
  1. 搜索框清空时重置所有状态
  2. 所有卡片恢复默认边框
  3. 搜索计数隐藏
- **验证**: Widget 测试

### Task 3.5: Widget 测试（搜索 + 实时同步）
- **文件**: `test/ui/pages/canvas_page_test.dart` (追加)
- **覆盖**: 搜索 UI、实时同步 UI（详见设计案 6.2）
- **验证**: `flutter test test/ui/pages/canvas_page_test.dart` 全绿

---

## Phase 4: 键盘快捷键 (Day 4 下午)

### Task 4.1: ShortcutService 注册 toggle_canvas
- **文件**: `lib/services/shortcut_service.dart` (修改)
- **改动**:
  1. `_defaults` 新增: `'toggle_canvas': 'Ctrl+Shift+C'`
  2. 确认不与现有快捷键冲突（`Ctrl+Shift+G` 是 `toggle_graph`，`C` 和 `G` 不冲突）
- **验证**: AC-K-1, AC-K-2, AC-K-3

### Task 4.2: main_layout 快捷键处理
- **文件**: `lib/ui/layout/main_layout.dart` (修改)
- **改动**:
  1. `_handlerForAction()` 新增 case:
     ```dart
     case 'toggle_canvas':
       return () => _togglePanel(ViewType.canvas);
     ```
  2. 无需其他改动——`_buildShortcutBindings` 已遍历所有 bindings
- **验证**: `dart analyze` 通过

### Task 4.3: 快捷键单元测试
- **文件**: `test/services/shortcut_service_test.dart` (修改/追加)
- **覆盖**: AC-K-1 ~ AC-K-3
- **验证**: `flutter test test/services/shortcut_service_test.dart` 全绿

---

## Phase 5: 集成测试 + 收尾 (Day 5)

### Task 5.1: 集成测试
- **文件**: `test/integration/canvas_integration_test.dart` (新建)
- **覆盖**: 端到端链路 ×5（详见设计案 6.3）
- **验证**: `flutter test test/integration/canvas_integration_test.dart` 全绿

### Task 5.2: 全局回归测试
- **命令**: `flutter test` → 全绿（排除 Ollama 环境依赖的测试）
- **命令**: `dart analyze lib/` → 0 issues
- **检查**: 所有已有测试不减损
- **检查**: AGENTS.md 规则无新违反

### Task 5.3: 更新 AGENTS.md
- **文件**: `AGENTS.md` (追加)
- **内容**: 新增本阶段学到的经验：
  ```
  - A-5: Canvas cards with noteId should render live note data, not static snapshots.
  - A-6: Auto-discovered connections (wikilink) must be visually distinct from manual ones.
  - A-7: Canvas persistence should use file system (.json in vault/.rf/) for Git traceability.
  ```

---

## 完整文件变更清单

```
新建文件 (3):
├── test/core/model/canvas_model_test.dart      (模型层测试, 扩展已有)
├── test/ui/pages/canvas_page_test.dart           (Widget 测试)
└── test/integration/canvas_integration_test.dart  (集成测试)

修改文件 (4):
├── lib/core/model/canvas_model.dart              (CanvasConnection.isAuto, CanvasSettings, CanvasSearchState)
├── lib/services/canvas_service.dart              (autoConnections, searchCards, 文件持久化)
├── lib/ui/pages/canvas_page.dart                 (实时同步渲染, 搜索框, _ConnectionPainter 虚线, 连线右键菜单)
├── lib/services/shortcut_service.dart            (toggle_canvas 默认绑定)
├── lib/ui/layout/main_layout.dart               (_handlerForAction 新增 toggle_canvas)
├── AGENTS.md                                     (新增 A-5, A-6, A-7)
└── test/services/canvas_service_test.dart        (服务层测试, 追加)
    test/services/shortcut_service_test.dart       (快捷键测试, 追加)
```

---

## CI 验收流水线

```yaml
# 伪 CI 配置 — 可自动执行
canvas-redesign-acceptance:
  - dart analyze lib/
  - flutter test test/core/model/canvas_model_test.dart
  - flutter test test/services/canvas_service_test.dart
  - flutter test test/services/shortcut_service_test.dart
  - flutter test test/ui/pages/canvas_page_test.dart
  - flutter test test/integration/canvas_integration_test.dart
  - flutter test  # 全量回归
```

---

## 里程碑定义

| 里程碑 | 定义 | 门禁条件 |
|--------|------|---------|
| M0: Model Ready | 模型层扩展完成，向后兼容 | Phase 0 全部测试通过 |
| M1: Service Ready | 自动连线 + 搜索 + 文件持久化就绪 | Phase 1 全部测试通过 + 回归不降 |
| M2: UI Ready | 视觉区分 + 实时同步 + 搜索 UI 就绪 | Phase 2-3 全部测试通过 |
| M3: Keyboard Ready | 快捷键可用 | Phase 4 全部测试通过 |
| M4: Ship Ready | 集成测试 + 全量回归通过 | Phase 5 全部测试通过 + `dart analyze` 零告警 |

---

*文档版本: 1.0 | 依赖: [canvas-redesign.md](./canvas-redesign.md)*
