# RFBrowser Quick Moves — 开发计划

> 依赖设计案: [quick-moves-design.md](./quick-moves-design.md)

---

## Phase 0: 数据层 (Day 1-2)

### Task 0.1: 创建数据模型
- **文件**: `lib/data/models/quick_move.dart` (新建)
- **内容**: `QuickMove`, `QuickMoveState`, `QuickMoveType`, `QuickMoveContext`
- **验证**: `dart analyze` 通过，模型类所有字段有 fromJson/toJson/copyWith

### Task 0.2: 创建持久化存储
- **文件**: `lib/data/stores/quick_move_store.dart` (新建)
- **内容**: `QuickMoveStore` 类，内部用 SharedPreferences 存 JSON
- **接口**:
  ```dart
  Future<QuickMoveState> load();
  Future<void> save(QuickMoveState state);
  Future<String> exportToJson();
  Future<bool> importFromJson(String json);
  ```
- **验证**: save → load round-trip 测试通过

### Task 0.3: 预设命令工厂
- **文件**: `lib/data/models/quick_move.dart` (追加)
- **内容**: QuickMove 静态方法 `QuickMove.defaultPresets()` 返回 5 个预设命令
- **验证**: 返回的 list 长度为 5，每个 promptTemplate 含 `{input}`

### Task 0.4: 单元测试
- **文件**: `test/data/models/quick_move_test.dart` (新建)
- **覆盖**: 模型序列化、resolvePrompt、matching、presets 工厂
- **验证**: `flutter test test/data/models/quick_move_test.dart` 全绿

---

## Phase 1: 状态管理层 (Day 2-3)

### Task 1.1: 创建 QuickMoveNotifier
- **文件**: `lib/services/quick_move_service.dart` (新建)
- **内容**: Riverpod `QuickMoveNotifier extends Notifier<QuickMoveState>`
- **方法**:
  ```dart
  QuickMoveState build()         // 从 store 加载，首次运行时注入 presets
  Future<QuickMove> createMove(name, promptTemplate, {icon, color})
  Future<void> updateMove(id, ...)
  Future<void> deleteMove(id)
  void reorderMove(id, newIndex)
  Future<void> restoreDefaults()
  String resolvePrompt(QuickMove move, Map<String, String> args)
  ```
- **验证**: `dart analyze` 通过

### Task 1.2: 创建 Context Provider
- **文件**: `lib/services/quick_move_service.dart` (追加)
- **内容**: `quickMoveContextProvider` — 一个被 UI 层 set 的 StateProvider
  ```dart
  final quickMoveContextProvider = StateProvider<QuickMoveContext>((ref) =>
      QuickMoveContext());
  ```
- **目的**: BrowserPage / EditorPage 在焦点变化时更新此 provider

### Task 1.3: 单元测试
- **文件**: `test/services/quick_move_service_test.dart` (新建)
- **覆盖**: CRUD 操作、状态变更、restoreDefaults、reorder
- **验证**: `flutter test test/services/quick_move_service_test.dart` 全绿

---

## Phase 2: UI — CommandBar 集成 (Day 3-5)

### Task 2.1: CommandBar 支持 / 前缀
- **文件**: `lib/ui/widgets/command_bar.dart` (修改)
- **改动点**:
  1. 监听输入以 `/` 开头时，将搜索源从 HybridSearch 改为 `quickMoveProvider`
  2. `/` 后面文本作为过滤关键字传给 `matching()`
  3. 选中 Quick Move 后，在输入框补充一个空格等待参数
  4. Quick Move 列表项显示: icon + name + "Quick Move" badge

### Task 2.2: CommandBar 提交逻辑扩展
- **文件**: `lib/ui/widgets/command_bar.dart` (修改，`_handleSubmit`)
- **逻辑**:
  ```dart
  if (text.startsWith('/')) {
    final parts = text.substring(1).split(' ');
    final cmdName = parts[0];
    final input = parts.skip(1).join(' ');
    final match = quickMoves.matching(cmdName).firstOrNull;
    if (match != null) {
      // 执行 Quick Move
      executeQuickMove(match, input);
    } else {
      // "命令不存在，是否创建？" 弹窗
      showCreateQuickMoveDialog(cmdName, input);
    }
  }
  ```

### Task 2.3: Quick Move 创建对话框
- **文件**: `lib/ui/widgets/create_quick_move_dialog.dart` (新建)
- **内容**: 一个 AlertDialog 表单:
  - 命令名称（必填，预填用户输入的命令名）
  - Prompt 模板（必填，TextArea，下方有占位符提示）
  - 图标选择器（IconPicker grid）
  - 颜色选择器（9 色圆点）
- **验证**: `dart analyze` 通过

### Task 2.4: Widget 测试
- **文件**: `test/ui/widgets/command_bar_quick_moves_test.dart` (新建)
- **覆盖**: `/` 触发 Quick Move 列表、创建按钮、过滤、选择行为
- **验证**: `flutter test test/ui/widgets/command_bar_quick_moves_test.dart` 全绿

---

## Phase 3: UI — 设置页面 (Day 5-6)

### Task 3.1: Quick Moves 管理区段
- **文件**: `lib/ui/pages/settings/quick_moves_settings_section.dart` (新建)
- **内容**:
  - 命令列表（ListView），每项左滑删除
  - 点击进入编辑对话框
  - 拖拽排序（ReorderableListView）
  - "恢复默认" 按钮
  - "导出/导入" 按钮（使用 file_picker 选择文件）
- **集成**: 在 `settings_page.dart` 中添加新 section

### Task 3.2: Widget 测试
- **文件**: `test/ui/pages/settings/quick_moves_settings_test.dart` (新建)
- **覆盖**: 列表渲染、删除确认、拖拽排序、恢复默认、导入/导出按钮存在
- **验证**: 全绿

---

## Phase 4: 集成 — AI 响应 + 保存笔记 (Day 6-7)

### Task 4.1: Quick Move 执行 → AI Chat Panel
- **文件**: `lib/ui/layout/main_layout.dart` (修改)
- **改动**:
  1. 新增 `_executeQuickMove(QuickMove move, String input)` 方法
  2. 从 `quickMoveContextProvider` 获取上下文
  3. 调用 `resolvePrompt(move, context + input)`
  4. 切换到 AI Chat Panel，发送 resolved prompt
  5. 若 AI Chat Panel 未打开，自动打开

### Task 4.2: 上下文感知 — BrowserPage
- **文件**: `lib/ui/pages/browser_page.dart` (修改)
- **改动**: 当 WebView 页面加载完成 / 用户切换 tab 时，更新 `quickMoveContextProvider`

### Task 4.3: 上下文感知 — EditorPage
- **文件**: `lib/ui/pages/editor_page.dart` (修改)
- **改动**: 当用户切换笔记 / 选中文本变化时，更新 `quickMoveContextProvider`

### Task 4.4: "保存为笔记" 功能
- **文件**: `lib/ui/pages/ai_chat_panel.dart` (修改)
- **改动**: 检测消息来自 Quick Move 命令执行时，在消息末尾显示"保存为笔记"按钮

### Task 4.5: 集成测试
- **文件**: `test/integration/quick_moves_integration_test.dart` (新建)
- **覆盖**: 端到端链路 ×6（详见设计案 4.3）
- **验证**: `flutter test test/integration/quick_moves_integration_test.dart` 全绿

---

## Phase 5: 收尾 (Day 7-8)

### Task 5.1: main_layout 键盘快捷键
- **文件**: `lib/ui/layout/main_layout.dart` (修改)
- **改动**: 打开 CommandBar 后输入 `/` 可直接筛选 Quick Moves（优先排序）

### Task 5.2: 全局 Lint 检查 + Regression 测试
- **命令**: `dart analyze lib/` → 0 issues
- **命令**: `flutter test` → 全绿（排除 Ollama 环境依赖的测试）

---

## 完整文件变更清单

```
新建文件 (10):
├── lib/data/models/quick_move.dart
├── lib/data/stores/quick_move_store.dart
├── lib/services/quick_move_service.dart
├── lib/ui/widgets/create_quick_move_dialog.dart
├── lib/ui/pages/settings/quick_moves_settings_section.dart
├── test/data/models/quick_move_test.dart
├── test/services/quick_move_service_test.dart
├── test/ui/widgets/command_bar_quick_moves_test.dart
├── test/ui/pages/settings/quick_moves_settings_test.dart
└── test/integration/quick_moves_integration_test.dart

修改文件 (5):
├── lib/ui/widgets/command_bar.dart         (支持 / 前缀 + Quick Move 执行)
├── lib/ui/layout/main_layout.dart           (_executeQuickMove + 快捷键)
├── lib/ui/pages/browser_page.dart           (更新 quickMoveContextProvider)
├── lib/ui/pages/editor_page.dart            (更新 quickMoveContextProvider)
├── lib/ui/pages/ai_chat_panel.dart          ("保存为笔记" 按钮)
└── lib/ui/pages/settings_page.dart          (集成 Quick Moves 区段)
```

---

## CI 验收流水线

```yaml
# 伪 CI 配置 — 可自动执行
quick-moves-acceptance:
  - dart analyze lib/
  - flutter test test/data/models/quick_move_test.dart
  - flutter test test/services/quick_move_service_test.dart
  - flutter test test/ui/widgets/command_bar_quick_moves_test.dart
  - flutter test test/ui/pages/settings/quick_moves_settings_test.dart
  - flutter test test/integration/quick_moves_integration_test.dart
```
