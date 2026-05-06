# RFBrowser 画布重设计 — 设计案

> 版本 1.0 | 2026-05-06 | 基于第一性原理分析

---

## 目录

1. [背景与目标](#1-背景与目标)
2. [第一性原理：画布是什么](#2-第一性原理画布是什么)
3. [User Stories](#3-user-stories)
4. [架构设计](#4-架构设计)
5. [自动化验收标准](#5-自动化验收标准)
6. [测试矩阵](#6-测试矩阵)
7. [留给后续阶段的能力](#7-留给后续阶段的能力)

---

## 1. 背景与目标

### 1.1 当前状态

画布功能已实现基础骨架，代码质量良好（debounced save、shouldRepaint 优化、坐标系转换），但存在三个根本性缺陷：

| 维度 | 当前实现 | 根因 |
|------|---------|------|
| **数据连接** | 0 条自动数据流 | 画布被设计为独立沙盒，与知识图谱/AI/浏览器完全隔离 |
| **连线方式** | 100% 手动创建 | 已有 LinkExtractor + outlinks 数据但未被画布利用 |
| **卡片数据** | 创建时静态快照 | `noteId` 字段存在但仅用于导航，不用于实时同步 |
| **持久化** | SharedPreferences 单键 JSON | 不可版本控制、不支持多画布、大 JSON 影响启动性能 |
| **导航** | 仅滚轮缩放+平移 | 无缩略图、无搜索、无语义缩放 |
| **可发现性** | 无快捷键 | 唯一没有键盘快捷键的面板（违背 UX-7） |

### 1.2 设计目标

将画布从 **独立自由白板** 提升为 **知识的空间化思考界面**，使其成为知识工作流的一等公民。本设计案覆盖三个梯队改进中的第一、二梯队。

### 1.3 范围界定

**本阶段实现（Phase 1-2）**：
- 卡片与知识笔记的实时同步
- 基于 wikilink / outlinks 的自动连线发现
- 键盘快捷键 `Ctrl+Shift+C` 切换画布面板
- 画布内搜索与卡片高亮定位
- 持久化迁移到文件系统（`.canvas.json`）

**不在本阶段（Phase 3+，见第 7 节）**：
- 语义缩放（Semantic Zoom）
- 画布-图谱双向联动
- AI 对话生成卡片
- 画布模板（SWOT、时间线等）

---

## 2. 第一性原理：画布是什么

### 2.1 根本目的

> **画布是知识的空间化思考界面。它将线性的、一维的笔记关系（wikilink / 标签 / 时间）投射到二维连续空间，利用人类视觉皮层的模式识别能力来发现非线性洞察。**

### 2.2 原子需求与当前满足度

| 原子操作 | 描述 | 当前满足度 | 目标 |
|---------|------|-----------|------|
| **捕获** (Capture) | 从知识库将笔记投射到空间 | 有（手动选择笔记→卡片） | 保持 |
| **连接** (Connect) | 发现并展示卡片间的关系 | 仅手动连线 | 70% 自动发现 + 30% 手动调整 |
| **空间化** (Spatialize) | 在空间中排列以辅助思维 | 有（自由拖拽） | 保持 + 新增搜索定位 |
| **导航** (Navigate) | 在大量卡片中快速定位 | 无 | 搜索 + 键盘导航 |
| **持久化** (Persist) | 保存思维状态，可审计可合并 | SharedPreferences | 文件系统 `.canvas.json` |
| **同步** (Sync) | 卡片数据与底层笔记保持一致 | 无 | 实时引用而非静态快照 |

### 2.3 核心设计原则

**P0：卡片是知识的视觉代理，不是数据的副本。** 卡片 UI 应始终展示其所代表笔记的**当前状态**。`card.content` 降级为 fallback（用于无 `noteId` 的纯文本卡片）。

**P1：连线应被发现(discovered)，而非被创建(created)。** 如果两张卡片背后的笔记存在 wikilink 关系，连线应自动呈现。用户只需确认、隐藏或微调。

**P2：布局是辅助认知的工具。** 自由拖拽是主要交互方式，但搜索和高亮定位是管理大量卡片的必要补充。

---

## 3. User Stories

### US-1: 卡片实时同步笔记内容

**作为** 知识工作者
**我想要** 当我在编辑器中修改一篇笔记后，画布上对应的卡片自动显示最新内容
**以便于** 画布始终反映知识库的真实状态，不需要手动更新每张卡片

**验收标准**:
- `AC-1-1`: 创建卡片时关联笔记（`noteId != null`），卡片内容区实时展示 `note.title` 和 `note.content`（而非 `card.content` 静态副本）
- `AC-1-2`: 在编辑器中修改关联笔记的标题后，切换到画布页面，对应卡片的标题已更新
- `AC-1-3`: 在编辑器中修改关联笔记的正文后，切换到画布页面，对应卡片的内容已更新
- `AC-1-4`: 无 `noteId` 的纯文本卡片行为不变（使用自身的 `card.title` 和 `card.content`）
- `AC-1-5`: 从知识笔记创建的卡片内容被截断显示（前 500 字符 + "...更多"），双击可打开完整笔记
- `AC-1-6`: 删除关联笔记后，画布卡片仍保留（降级显示静态内容），但显示"原始笔记已删除"提示

### US-2: 自动发现并展示笔记间的连线

**作为** 知识工作者
**我想要** 当我将两篇有关联的笔记（存在 wikilink）拖到画布上后，它们之间自动显示连线
**以便于** 我不需要手动为每对相关的卡片创建连线，连线成本从 O(n²) 降为 O(n)

**验收标准**:
- `AC-2-1`: 画布上有卡片 A（noteId=X）和卡片 B（noteId=Y），且笔记 X 包含指向 Y 的 `[[wikilink]]`，自动渲染一条从 A 到 B 的连线
- `AC-2-2`: 自动连线与手动连线在视觉上有区分：自动连线为虚线 + 半透明，手动连线为实线
- `AC-2-3`: 手动连线和自动连线共存时去重——同一对卡片只显示一条连线（手动连线优先级更高）
- `AC-2-4`: 移除卡片 A 后，从 A 出发的自动连线同步消失
- `AC-2-5`: 新卡片加入画布时，在 200ms 内完成自动连线计算
- `AC-2-6`: 自动连线功能可被用户通过工具栏按钮全局关闭/开启，设置持久化

### US-3: 键盘快捷键切换画布

**作为** 键盘流用户
**我想要** 按 `Ctrl+Shift+C` 即可打开/关闭画布面板
**以便于** 不需要鼠标点击就能在画布和其他视图之间快速切换

**验收标准**:
- `AC-3-1`: 在 ShortcutService 默认绑定中注册 `toggle_canvas` → `Ctrl+Shift+C`
- `AC-3-2`: 按下 `Ctrl+Shift+C` 时，若画布未打开则打开画布面板并聚焦，若已打开则关闭
- `AC-3-3`: `Ctrl+Shift+C` 不与现有快捷键冲突（现有绑定中无此组合）
- `AC-3-4`: 快捷键可在设置页面的快捷键管理区段被用户自定义修改
- `AC-3-5`: 重启应用后快捷键绑定保持不变

### US-4: 画布内搜索卡片

**作为** 重度用户
**我想要** 在画布工具栏的搜索框输入关键词后，匹配的卡片被高亮，且画面自动平移到第一张匹配卡片
**以便于** 在 30+ 张卡片的画布中快速定位目标

**验收标准**:
- `AC-4-1`: 工具栏新增搜索输入框，Placeholder 显示"搜索卡片..."
- `AC-4-2`: 输入关键词时实时过滤（200ms debounce），匹配标题或内容的卡片边框变为高亮色
- `AC-4-3`: 按下 Enter 键后，画面自动平移+缩放到第一张匹配卡片居中显示
- `AC-4-4`: 按下 `F3` 跳转到下一个匹配卡片，`Shift+F3` 跳转到上一个
- `AC-4-5`: 搜索结果计数显示在搜索框右侧（如"3/12 张卡片"）
- `AC-4-6`: 清空搜索框后所有卡片恢复常态，不保留高亮
- `AC-4-7`: 搜索空字符串或无匹配结果时显示"No matching cards"

### US-5: 画布持久化迁移到文件系统

**作为** 长期用户
**我想要** 画布数据保存为 vault 下的 `.rf/canvases/default.canvas.json` 文件
**以便于** 画布可以被 Git 追踪、可以被备份和还原、支持未来多画布切换

**验收标准**:
- `AC-5-1`: 首次加载画布时，若 vault 下无 `.rf/canvases/` 目录，自动创建
- `AC-5-2`: 画布数据保存到 `<vault_path>/.rf/canvases/default.canvas.json`
- `AC-5-3`: 加载画布时优先从文件系统读取，文件不存在时 fallback 到 SharedPreferences（迁移旧数据）
- `AC-5-4`: 旧数据成功迁移后删除 SharedPreferences 中的 `'canvas_data'` 键
- `AC-5-5`: 文件损坏（无效 JSON）时返回空画布，不崩溃，并提示用户
- `AC-5-6`: 保存失败（磁盘满/权限不足）时显示 SnackBar 错误提示
- `AC-5-7`: 多个面板操作（拖拽结束、添加卡片、删除连线）后的保存合并为一次 debounced write（500ms），不频繁写磁盘

### US-6: 连线视觉区分与交互增强

**作为** 用户
**我想要** 自动连线和手动连线在视觉上有明显区别，并且能方便地管理连线
**以便于** 我能一眼看出哪些关系是知识库中已有的，哪些是我额外标注的

**验收标准**:
- `AC-6-1`: 手动连线：实线，主色，宽度 2px，带箭头
- `AC-6-2`: 自动连线：虚线 (`strokeWidth: 1.5, dash pattern: [4, 4]`)，主色 50% 透明度，带箭头
- `AC-6-3`: 选中连线（点击线体或连接点）后显示删除按钮和 label 编辑框
- `AC-6-4`: 右键连线时弹出菜单：编辑标签、转为手动连线（对自动连线）、删除

---

## 4. 架构设计

### 4.1 改进后的组件关系图

```
┌─────────────────────────────────────────────────────────────────────┐
│                         UI Layer                                     │
│                                                                      │
│  CanvasView                                                          │
│  ├── Toolbar: [+添加] [连接模式] [自动连线: ON/OFF] [搜索框] [适应] [清空]│
│  ├── InteractiveViewer (minScale=0.1, maxScale=4.0)                 │
│  │    ├── _GridPainter (CustomPainter)                               │
│  │    ├── _ConnectionPainter (CustomPainter, 新增 虚线支持)           │
│  │    └── CardWidget (新增 实时绑定到 KnowledgeState)                 │
│  │         ├── noteId != null → 读取 knowledgeProvider 最新数据       │
│  │         ├── noteId == null → 使用 card.title / card.content       │
│  │         └── 被删除笔记 → 降级显示 + 警告标记                       │
│  └── _CardSearchOverlay (新增, 搜索高亮时叠加)                        │
│                                                                      │
├─────────────────────────────────────────────────────────────────────┤
│                       State Layer                                     │
│                                                                      │
│  CanvasNotifier (修改)                                               │
│  ├── loadCanvas() → 优先读文件系统，fallback SharedPreferences        │
│  ├── _save() / _debouncedSave() → 写入 .canvas.json                  │
│  ├── _deriveAutoConnections() → 新增: 基于 knowledgeProvider 推算     │
│  ├── autoConnectionsEnabled → 新增: 用户开关状态                      │
│  └── searchCards(query) → 新增: 卡片搜索方法                          │
│                                                                      │
│  CanvasSearchState (新增)                                            │
│  ├── query: String                                                   │
│  ├── matchedCardIds: List<String>                                    │
│  ├── activeIndex: int                                                │
│  └── isActive: bool                                                  │
│                                                                      │
├─────────────────────────────────────────────────────────────────────┤
│                      Data Layer                                       │
│                                                                      │
│  <vault>/.rf/canvases/default.canvas.json (新增, 持久化文件)          │
│  ├── cards[]                                                         │
│  ├── connections[] (含 isAuto: bool 字段)                             │
│  ├── settings: { autoConnectionsEnabled: true }                      │
│  └── metadata: { version: 2, lastModified: "..." }                   │
│                                                                      │
│  SharedPreferences 'canvas_data' (旧格式, 加载后迁移并删除)           │
│                                                                      │
├─────────────────────────────────────────────────────────────────────┤
│                   Integration (已有, 新增数据流方向)                   │
│                                                                      │
│  knowledgeProvider ←→ CanvasNotifier                                 │
│  ├── 读取: notes, activeNote, outlinks (用于实时同步 + 自动连线)       │
│  └── 调用: openNote(noteId) - 双击卡片打开笔记                        │
│                                                                      │
│  shortcutService (修改)                                              │
│  └── 新增: 'toggle_canvas' → 'Ctrl+Shift+C'                          │
│                                                                      │
│  browserProvider ← CanvasNotifier                                    │
│  └── 调用: createTab(url:) - 双击链接卡片打开浏览器                   │
└─────────────────────────────────────────────────────────────────────┘
```

### 4.2 数据模型变更

```dart
// canvas_model.dart — 新增字段

class CanvasConnection {
  // ...existing fields...
  final bool isAuto;  // 新增: 是否为自动发现的连线

  const CanvasConnection({
    // ...existing params...
    this.isAuto = false,
  });
}

class CanvasSettings {
  final bool autoConnectionsEnabled;
  final DateTime lastModified;

  const CanvasSettings({
    this.autoConnectionsEnabled = true,
    DateTime? lastModified,
  }) : lastModified = lastModified ?? DateTime.now();
}

// canvas_service.dart — 新增状态字段
class CanvasSearchState {
  final String query;
  final List<String> matchedCardIds;
  final int activeIndex;

  const CanvasSearchState({
    this.query = '',
    this.matchedCardIds = const [],
    this.activeIndex = 0,
  });

  bool get isActive => query.isNotEmpty;
}
```

### 4.3 卡片渲染逻辑变更

```
renderCard(card):
    note = null
    if card.noteId != null:
        note = knowledgeProvider.getById(card.noteId)
    
    if note != null:
        title = note.title                   // 实时标题
        content = truncated(note.content)    // 实时正文, 截断显示
        showWarning = false
    else if card.noteId != null:
        // 笔记已删除
        title = card.title + " [已删除]"     // 降级标题
        content = card.content
        showWarning = true                   // 显示警告标记
    else:
        // 无关联笔记的纯卡片
        title = card.title
        content = card.content
        showWarning = false
    
    render(title, content, showWarning)
```

### 4.4 自动连线推导流程

```
deriveAutoConnections(cards, enabled):
    if not enabled: return []

    autoConns = []
    for each pair (cardA, cardB) where cardA.noteId != null && cardB.noteId != null:
        noteA_outlinks = knowledgeProvider.getOutlinks(cardA.noteId)
        noteB_outlinks = knowledgeProvider.getOutlinks(cardB.noteId)
        
        // 双向检查
        if cardB.noteId in noteA_outlinks.targetIds:
            autoConns.add(connection(A→B, isAuto=true))
        if cardA.noteId in noteB_outlinks.targetIds:
            autoConns.add(connection(B→A, isAuto=true))

    // 去重: 如果已存在手动连线, 不添加同向自动连线
    manualPairs = {(c.fromCardId, c.toCardId) | c in connections and not c.isAuto}
    autoConns = autoConns.filterIf(pair not in manualPairs)

    return autoConns
```

### 4.5 文件持久化变更

```dart
// canvas_service.dart — 改写持久化

Future<String> _canvasFilePath() async {
  final vaultPath = ref.read(vaultProvider).currentVault?.path;
  if (vaultPath == null) throw StateError('No vault open');
  final dir = Directory(p.join(vaultPath, '.rf', 'canvases'));
  if (!await dir.exists()) await dir.create(recursive: true);
  return p.join(dir.path, 'default.canvas.json');
}

Future<void> _saveToFile() async {
  try {
    final path = await _canvasFilePath();
    await File(path).writeAsString(state.toJsonString());
  } on StateError {
    // 无 vault 时 fallback 到 SharedPreferences
    await _saveToSharedPrefs();
  } catch (e) {
    debugPrint('Canvas save failed: $e');
    // 吞掉异常，不影响 UI
  }
}

Future<void> _loadFromFile() async {
  try {
    final path = await _canvasFilePath();
    if (await File(path).exists()) {
      final json = await File(path).readAsString();
      state = CanvasData.fromJsonString(json);
      return;
    }
  } catch (_) {}
  // fallback
  await _loadFromSharedPrefs();
}

Future<void> _migrateFromSharedPrefs() async {
  final prefs = await SharedPreferences.getInstance();
  final json = prefs.getString('canvas_data');
  if (json != null) {
    state = CanvasData.fromJsonString(json);
    await prefs.remove('canvas_data');
  }
}
```

---

## 5. 自动化验收标准

以下验收标准可通过 `flutter test` 在 CI 中自动执行：

### 5.1 模型层（canvas_model_test.dart）

```dart
group('CanvasCard with noteId', () {
  test('AC-M-1: card with noteId serializes/deserializes correctly', () {
    final card = CanvasCard(
      id: 'c1', type: CanvasCardType.note,
      noteId: 'note-123', title: '', content: '',
    );
    final json = card.toJson();
    final restored = CanvasCard.fromJson(json);
    expect(restored.noteId, equals('note-123'));
    expect(restored.type, equals(CanvasCardType.note));
  });

  test('AC-M-2: card without noteId has null noteId', () {
    final card = CanvasCard(
      id: 'c2', type: CanvasCardType.text,
      title: 'Hello', content: 'World',
    );
    expect(card.noteId, isNull);
  });
});

group('CanvasConnection isAuto flag', () {
  test('AC-M-3: manual connection has isAuto=false by default', () {
    final conn = CanvasConnection(
      id: 'conn1', fromCardId: 'a', toCardId: 'b',
    );
    expect(conn.isAuto, isFalse);
  });

  test('AC-M-4: auto connection serializes isAuto in JSON', () {
    final conn = CanvasConnection(
      id: 'conn_auto1', fromCardId: 'a', toCardId: 'b',
      isAuto: true,
    );
    final json = conn.toJson();
    expect(json['isAuto'], isTrue);
  });

  test('AC-M-5: old JSON without isAuto → isAuto=false after deserialization', () {
    final json = {
      'id': 'old_conn', 'fromCardId': 'a', 'toCardId': 'b',
      'fromSide': 3, 'toSide': 2, 'label': '', 'isAuto': false,
    };
    final conn = CanvasConnection.fromJson(json);
    expect(conn.isAuto, isFalse);
  });
});

group('CanvasSettings', () {
  test('AC-M-6: default autoConnectionsEnabled is true', () {
    final settings = CanvasSettings();
    expect(settings.autoConnectionsEnabled, isTrue);
  });
});
```

### 5.2 服务层（canvas_service_test.dart）

```dart
group('CanvasNotifier auto connections', () {
  test('AC-S-1: deriveAutoConnections returns empty when disabled', () {
    // Given: cards for notes that have mutual outlinks
    // When: autoConnectionsEnabled = false
    // Then: returns empty list
  });

  test('AC-S-2: deriveAutoConnections finds wikilink relationships', () {
    // Given: card A (noteId=X) and card B (noteId=Y),
    //        X's outlinks include Y
    // Then: returns a CanvasConnection(isAuto: true) from A to B
  });

  test('AC-S-3: auto connections deduplicate with manual connections', () {
    // Given: manual connection from A to B already exists
    // And: auto connection would also go from A to B
    // Then: no duplicate auto connection generated
  });

  test('AC-S-4: cards without noteId not included in auto connections', () {
    // Given: card A has noteId, card C has no noteId
    // Then: no auto connection involving C is generated
  });
});

group('CanvasNotifier file persistence', () {
  test('AC-S-5: toJsonString includes CanvasSettings', () {
    // CanvasData.toJsonString() should include settings section
  });

  test('AC-S-6: fromJsonString handles missing settings gracefully', () {
    // Old format JSON without 'settings' key → defaults
    // autoConnectionsEnabled = true
  });

  test('AC-S-7: corrupt JSON returns empty CanvasData, no exception', () {
    final data = CanvasData.fromJsonString('{not valid json}}');
    expect(data.cards, isEmpty);
    expect(data.connections, isEmpty);
  });
});

group('CanvasNotifier search', () {
  test('AC-S-8: searchCards matches title (case-insensitive)', () {
    // Given: cards with titles "Research Notes", "Shopping List", "Research Methods"
    // When: query = "research"
    // Then: returns 2 cards ("Research Notes", "Research Methods")
  });

  test('AC-S-9: searchCards matches content', () {
    // Given: card with content "learn Flutter state management"
    // When: query = "flutter"
    // Then: card is returned
  });

  test('AC-S-10: searchCards empty query returns all', () {
    // When: query = ""
    // Then: returns all cards
  });

  test('AC-S-11: searchCards no match returns empty', () {
    // When: query = "xyzwqk"
    // Then: returns empty list
  });
});
```

### 5.3 快捷方式层（shortcut_service_test.dart）

```dart
group('Canvas shortcut', () {
  test('AC-K-1: toggle_canvas registered with Ctrl+Shift+C', () {
    final service = ShortcutService();
    expect(service.getShortcut('toggle_canvas'), equals('Ctrl+Shift+C'));
  });

  test('AC-K-2: Ctrl+Shift+C does not conflict with existing shortcuts', () {
    final service = ShortcutService();
    final bound = <String>{};
    for (final entry in service.defaults.entries) {
      if (entry.key == 'toggle_canvas') continue;
      expect(entry.value, isNot(equals('Ctrl+Shift+C')),
          reason: 'toggle_canvas conflicts with ${entry.key}');
    }
  });

  test('AC-K-3: toggle_canvas can be customized', () {
    final service = ShortcutService();
    service.register('toggle_canvas', 'Ctrl+Alt+C');
    expect(service.getShortcut('toggle_canvas'), equals('Ctrl+Alt+C'));
  });
});
```

### 5.4 集成验收决策树

```
1. Card Real-time Sync
   ├─ card.noteId != null → card UI reads from knowledgeProvider, not card.content
   ├─ modify note → canvas card updates without manual refresh
   └─ delete note → card shows warning, not crash

2. Auto Connections
   ├─ two cards with linked notes → auto connection line appears
   ├─ auto line style: dashed, semi-transparent
   ├─ manual line style: solid, full opacity
   ├─ toggle OFF → all auto lines disappear immediately
   ├─ toggle ON → auto lines reappear within 200ms
   └─ add/remove card → auto connections recalculated

3. Keyboard Shortcut
   ├─ Ctrl+Shift+C → toggle canvas panel
   ├─ canvas open → Ctrl+Shift+C closes canvas panel
   ├─ canvas closed → Ctrl+Shift+C opens and focuses canvas
   └─ shortcut persists after restart

4. Canvas Search
   ├─ type query → matched cards highlighted in realtime (200ms debounce)
   ├─ Enter → viewport pans to first match, card centered
   ├─ F3 → next match; Shift+F3 → previous match
   ├─ clear query → all highlights removed
   └─ no match → shows "No matching cards"

5. File Persistence
   ├─ vault open → saves to <vault>/.rf/canvases/default.canvas.json
   ├─ vault not open → fallback to SharedPreferences
   ├─ old SharedPreferences data → migrated to file, old key removed
   ├─ corrupt file → empty canvas, no crash, error logged
   └─ concurrent saves → debounced, only last write within 500ms goes to disk
```

---

## 6. 测试矩阵

### 6.1 单元测试

| 测试类 | 测试用例 | 验证目标 |
|--------|---------|---------|
| `CanvasCard.fromJson/toJson` | noteId 序列化 round-trip | 数据完整性 |
| `CanvasConnection.fromJson/toJson` | isAuto 序列化 round-trip + 向后兼容 | 模型扩展 |
| `CanvasData.fromJsonString` | 损坏 JSON → 空状态 | 容错 |
| `CanvasData.fromJsonString` | 旧格式 JSON（无 isAuto/settings）→ 默认值 | 向后兼容 |
| `CanvasData.toJsonString` | 包含 settings 区段 | 输出完整性 |
| `CanvasNotifier._deriveAutoConnections` | 空 cards → 空结果 | 边界 |
| `CanvasNotifier._deriveAutoConnections` | 有 wikilink 关系 → 自动连线 | 核心逻辑 |
| `CanvasNotifier._deriveAutoConnections` | 去重（手动连线已存在） | 去重 |
| `CanvasNotifier._deriveAutoConnections` | 无 noteId 的卡片不参与 | 过滤 |
| `CanvasNotifier.searchCards` | 空查询 → 全量返回 | 搜索 |
| `CanvasNotifier.searchCards` | 部分匹配 | 搜索 |
| `CanvasNotifier.searchCards` | 无匹配 → 空列表 | 边界 |
| `ShortcutService.register` | toggle_canvas 默认绑定 | 快捷键 |
| `ShortcutService.register` | 自定义绑定后覆盖 | 快捷键 |
| `ShortcutService` 冲突检查 | Ctrl+Shift+C 不冲突 | 快捷键 |

### 6.2 Widget 测试

| 测试文件 | 测试用例 | 验证目标 |
|----------|---------|---------|
| `canvas_page_test.dart` | 搜索框输入 → 卡片高亮 | 搜索 UI |
| `canvas_page_test.dart` | 搜索 Enter → 画面平移 | 搜索 UI |
| `canvas_page_test.dart` | 自动连线开关 → 连线显示/隐藏 | 自动连线 UI |
| `canvas_page_test.dart` | 自动连线样式（虚线）vs 手动连线（实线） | 视觉区分 |
| `canvas_page_test.dart` | `_ConnectionPainter` 虚线 dash pattern | CustomPainter |
| `canvas_page_test.dart` | 卡片有 noteId 且笔记存在 → 显示实时数据 | 实时同步 UI |
| `canvas_page_test.dart` | 卡片有 noteId 但笔记已删除 → 显示警告 | 实时同步 UI |

### 6.3 集成测试

| 测试文件 | 测试用例 | 验证目标 |
|----------|---------|---------|
| `canvas_integration_test.dart` | UI-1: 修改笔记标题 → 画布卡片标题更新 | 实时同步 |
| `canvas_integration_test.dart` | UI-2: 创建有 wikilink 关系的笔记 → 添加卡片 → 自动连线出现 | 自动连线 |
| `canvas_integration_test.dart` | UI-3: Ctrl+Shift+C → 画布面板开关 | 快捷键 |
| `canvas_integration_test.dart` | UI-4: 搜索"Research" → 2 张卡片高亮 → Enter → 画面居中 | 搜索 |
| `canvas_integration_test.dart` | UI-5: 添加 5 张卡片 → 重启应用 → 卡片仍存在 | 持久化 |

---

## 7. 留给后续阶段的能力

以下能力**故意不在本阶段实现**，避免范围膨胀：

| 能力 | 为什么不现在做 |
|------|---------------|
| 语义缩放（Semantic Zoom） | 需要重构卡片渲染为缩放感知的 CustomPainter，与当前 Stack+Positioned 架构冲突 |
| 画布-图谱双向联动 | 需要事件总线机制，且图谱 UI（GraphView）需先支持外部选择信号 |
| AI 对话生成卡片 | 依赖 AI Chat Panel 的消息类型扩展 + 画布坐标自动布局算法 |
| 画布模板（SWOT、时间线等） | 需要模板引擎 + 智能布局算法，可作为独立 feature |
| 多画布切换 | 依赖文件持久化先落地 + 画布列表 UI |
| 力导向自动布局 | 依赖 Web 端 2D 物理引擎或自研算法，复杂度高 |

---

*文档版本: 1.0 | 依赖: [quick-moves-design.md](./quick-moves-design.md) (参考格式)*
