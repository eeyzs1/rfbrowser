# Project Rules — RFBrowser

## 重构工作流规则（强制）

### 规则 1：重构后必须运行完整测试

**触发条件**：每完成一轮重构（一个 P 级任务或一个独立重构单元）后。

**必须执行的验证步骤**（按顺序，全部通过才能继续下一步重构）：

1. **静态分析**（AI 在 Trae 终端执行）
   ```powershell
   flutter analyze
   ```
   - 必须输出 `No issues found!`

2. **单元测试 + test/integration 集成测试**（AI 在 Trae 终端执行）
   ```powershell
   flutter test
   ```
   - 运行 `test/` 目录下所有测试（含 `test/integration/` 子目录）
   - 必须全部通过（skipped 允许，failed 不允许）

3. **端到端集成测试**（AI 在 Trae 终端执行）
   ```powershell
   pwsh scripts\run-integration-tests.ps1
   ```
   - 逐个运行 `integration_test/` 目录下所有测试文件
   - **已知问题**：`flutter test integration_test\` 批量运行时，每个测试文件的 rebuild 不会把插件 DLL（sqlite3.dll、url_launcher_windows_plugin.dll 等）复制到 `runner\Debug\` 目录，导致 exe 启动崩溃（STATUS_DLL_NOT_FOUND）。`run-integration-tests.ps1` 脚本通过先 `flutter build windows --debug` 生成所有 DLL，再在每次测试前复制 DLL 来解决此问题
   - 必须全部通过（skipped 允许，failed 不允许）
   - 可用 `-TestFile integration_test/xxx_test.dart` 参数单独运行某个测试文件

**AI 与用户的分工**：
- 步骤 1、2、3 均由 AI 在 Trae 终端中自动执行
- 步骤 3 需要使用 `scripts\run-integration-tests.ps1` 脚本（不能直接用 `flutter test integration_test\`，因为批量运行时 DLL 不会被复制）
- 如果步骤 3 因环境问题失败，AI 应先排查 DLL 是否缺失，再考虑提醒用户在真实桌面重试

**禁止行为**：
- 在上述 3 步未全部通过前，不得开始下一轮重构
- 不得跳过任何一步
- 不得在测试失败时继续新重构（应先修复失败的测试）

### 规则 2：测试失败处理

- 如果测试失败，**必须先修复测试**，不得绕过
- 修复后重新执行完整的 3 步验证
- 如果失败是由于外部依赖（如网络服务不可用）导致的预期降级警告（如 DioException），需在回复中明确说明，不算测试失败
- 如果步骤 3 因 DLL 缺失失败（exit code -1073741515 / 0xC0000135），需确保使用 `run-integration-tests.ps1` 脚本而非直接 `flutter test integration_test\`

### 规则 3：重构范围声明

- 每轮重构开始前，明确声明重构目标和涉及文件
- 每轮重构结束后，报告：修改的文件、行数变化、测试结果

### 规则 4：Windows 桌面端 UI 模式（强制）

**触发条件**：任何涉及 `ListView`、`Scrollable`、`TextField`、`TextEditingController`、手势处理的代码改动。

**禁止模式（已知会导致 Windows 崩溃/卡顿）**：

1. **嵌套 Scrollable** — 禁止在父 `ListView`/`SingleChildScrollView` 内嵌套 `ReorderableListView.builder` + `shrinkWrap: true` + `NeverScrollableScrollPhysics()`。这会触发 `accessibility_bridge.cc` AXTree 更新失败（`Failed to update ui::AXTree, error: NNN`），最终进程崩溃（`Lost connection to device`）。
   - **替代方案**：用 `Column` + 显式上下移动 `IconButton`（`canMoveUp`/`canMoveDown` 守卫，边界 `onPressed: null`）。

2. **大文件全文档渲染** — 禁止对 >20KB 内容使用 `TextField(maxLines: null, expands: true)`、全文档 `SelectableText`、或 `flutter_markdown` 直接渲染。会导致 UI 线程布局冻结。
   - **替代方案**：`ListView.builder` 视口懒渲染 + `SelectionArea`；Edit 模式对 >20KB 文件降级为 Source 视图 + 顶部提示条提供手动切换。

3. **同步 UI 线程正则扫描** — 禁止在 `TextEditingController.buildTextSpan` 或 `build` 方法内同步执行 O(n×content) 正则扫描（高亮、反向链接、提及检测）。
   - **替代方案**：`buildTextSpan` 立即返回纯文本，debounce 120ms 后异步计算；>2000 字用 `compute()` 隔离线程，短文本用 post-frame callback。

4. **水平 ListView 鼠标滚轮不响应** — Windows 上水平 `ListView` 不响应垂直鼠标滚轮。
   - **替代方案**：`Listener(onPointerSignal)` + `PointerScrollEvent`，把 `scrollDelta.dy`（滚轮）和 `scrollDelta.dx`（触控板）转换为水平 `jumpTo`。

**允许模式**：

- 左键拖拽滚动：`GestureDetector.onHorizontalDragUpdate` + `ListView` 设 `NeverScrollableScrollPhysics()`（gesture arena 通过 kTouchSlop 区分点击 vs 拖拽）
- 中键关闭标签：`GestureDetector.onTertiaryTapDown`（注意 `onSecondaryTapUp` 是右键，不是中键）
- 分屏保留标签：`handleSplit` 时原 leaf 保留 `tabs` + `activeTabIndex`，新 leaf 只含当前活动标签

### 规则 5：真机冒烟测试（强制）

**触发条件**：规则 1 的 3 步验证全部通过后，重构才算完成。

**AI 职责**：在 3 步验证通过后，**必须主动提醒用户**执行真机冒烟测试：
```
请运行 `flutter run -d windows` 并执行以下冒烟测试 checklist：
1. 滚动设置页每个 section 至底部（验证无 AXTree 崩溃）
2. 打开一个 >20KB 的 markdown 笔记（验证无卡顿，<2s 打开）
3. 切换 edit/source/rendered 视图模式（验证切换正常）
4. 分屏操作 + 标签栏滚轮/拖拽/中键关闭（验证手势正常）
```

**用户职责**：执行冒烟测试并反馈结果。

**禁止行为**：
- 真机测试未通过前，不得声明重构完成
- 真机测试失败 = 重构未通过，必须修复后重新执行完整 3 步验证 + 真机测试
- 不得以"3 步验证已通过"为由跳过真机测试

**例外**：纯文档改动、纯测试代码改动、或用户明确声明跳过真机测试时，可免除。

### 规则 6：异步 UI 计算模式（强制）

**触发条件**：任何可能阻塞 UI 线程的计算（正则扫描、文件夹树重建、反向链接扫描、语法高亮）。

**强制规则**：

1. **异步化** — 所有可能阻塞 UI 线程的计算必须异步执行：
   - 短任务（<16ms）：microtask 或 `scheduleMicrotask`
   - 中任务（16ms-100ms）：post-frame callback + debounce
   - 长任务（>100ms 或 >2000 字内容）：`compute()` 隔离线程

2. **防虚假 dirty** — 异步高亮/重建会触发虚假的 content-changed 通知。所有 content-changed 监听器必须用 `_lastSeenText` 跟踪，仅在文本真正变化时标记 dirty：
   ```dart
   if (newText == _lastSeenText) return; // 跳过虚假通知
   _lastSeenText = newText;
   // ... 标记 dirty
   ```

3. **防全量重建** — `NoteSidebar` 等树形控件不得在 `activeNoteId` 变化时重建整棵树。必须基于引用一致性（notes/links/noteFilter/searchQuery/diskFolders）实现 trie 缓存，仅在依赖真正变化时重建。

4. **防 UI 阻塞** — `BacklinksPanel` 等需要扫描全量笔记的面板，必须在 `ConsumerStatefulWidget` 中用 microtask 异步计算 unlinked mentions，不得在 `build` 中同步扫描。
