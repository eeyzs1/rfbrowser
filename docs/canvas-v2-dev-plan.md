# RFBrowser 画布 V2 — 开发计划

> 依赖设计案: [canvas-v2-design.md](./canvas-v2-design.md)
> 前置: [canvas-dev-plan.md](./canvas-dev-plan.md) (V1 已完成)

---

## Phase 1: 基础能力补全

### Task 1.1: 多选 — 数据模型改造

- **文件**: `lib/data/models/canvas_model.dart`
- **改动**:
  1. `CanvasData` 将 `selectedCardId: String?` 改为 `selectedCardIds: List<String>`
  2. `copyWith` 新增 `List<String>? selectedCardIds` + `bool clearSelectedCardIds`
  3. `toJsonString` 不序列化 `selectedCardIds`（UI 状态不持久化）
  4. `fromJsonString` 兼容旧格式：旧 JSON 中无 `selectedCardIds` 时默认 `[]`
- **验证**: `flutter analyze` + 现有模型测试通过

### Task 1.2: 多选 — CanvasNotifier 改造

- **文件**: `lib/services/canvas_service.dart`
- **改动**:
  1. `selectCard(String? cardId)` → `selectCard(String cardId, {bool additive = false})`
  2. 新增 `selectCards(List<String> cardIds)`
  3. 新增 `addToSelection(String cardId)`
  4. 新增 `removeFromSelection(String cardId)`
  5. 新增 `selectAll()`
  6. 新增 `clearSelection()`
  7. 新增 `batchMoveCards(Map<String, (double, double)> moves)` — 批量移动
  8. 新增 `batchDeleteCards(List<String> cardIds)` — 批量删除
  9. 新增 `batchUpdateCardColor(List<String> cardIds, int colorValue)` — 批量改色
- **验证**: 单元测试

### Task 1.3: 多选 — CanvasPainter 渲染

- **文件**: `lib/ui/widgets/canvas_painter.dart`
- **改动**:
  1. 构造器 `selectedCardId: String?` → `selectedCardIds: List<String>`
  2. `_drawCards` 中判断 `selectedCardIds.contains(card.id)` 代替 `card.id == selectedCardId`
  3. 选中卡片边框高亮逻辑不变
  4. 新增框选矩形渲染：`selectionRect: Rect?` 参数
  5. 框选矩形：蓝色半透明填充 + 蓝色边框
- **验证**: Widget 测试

### Task 1.4: 多选 — CanvasPage 交互逻辑

- **文件**: `lib/ui/pages/canvas_page.dart`
- **改动**:
  1. 状态字段 `selectedCardId` → `selectedCardIds: List<String>`
  2. 点击卡片：`selectCard(id)` 或 `addToSelection(id)`（Shift）
  3. 空白区域拖拽：记录起始点，计算世界坐标选择矩形，更新 `selectionRect`
  4. 释放鼠标：计算框内卡片，调用 `selectCards(matchedIds)`
  5. Ctrl+A：`selectAll()`
  6. Delete：`batchDeleteCards(selectedCardIds)`
  7. 拖拽选中卡片：计算偏移量，`batchMoveCards()`
  8. 右键菜单：多选时显示批量操作（改色、分组、删除）
- **验证**: 手动测试 + Widget 测试

### Task 1.5: 分组 — 数据模型

- **文件**: `lib/data/models/canvas_model.dart`
- **改动**:
  1. 新增 `CanvasGroup` 类（id, name, cardIds, colorValue）
  2. `CanvasData` 新增 `List<CanvasGroup> groups`
  3. `CanvasData.toJsonString` 序列化 groups
  4. `CanvasData.fromJsonString` 兼容旧格式（无 groups 时默认 []）
- **验证**: 序列化 round-trip 测试

### Task 1.6: 分组 — CanvasNotifier 方法

- **文件**: `lib/services/canvas_service.dart`
- **改动**:
  1. 新增 `groupCards(List<String> cardIds, {String? name})`
  2. 新增 `ungroupCards(String groupId)`
  3. 新增 `renameGroup(String groupId, String name)`
  4. 新增 `addToGroup(String groupId, String cardId)`
  5. 新增 `removeFromGroup(String groupId, String cardId)`
  6. 分组移动：拖拽分组中卡片时，同组卡片同步移动
- **验证**: 单元测试

### Task 1.7: 分组 — CanvasPainter 渲染

- **文件**: `lib/ui/widgets/canvas_painter.dart`
- **改动**:
  1. 新增 `groups: List<CanvasGroup>` 参数
  2. 在卡片下层绘制分组背景矩形
  3. 分组背景：组色半透明填充 + 虚线边框
  4. 分组名称：背景矩形顶部居中显示
- **验证**: Widget 测试

### Task 1.8: 分组 — CanvasPage 交互

- **文件**: `lib/ui/pages/canvas_page.dart`
- **改动**:
  1. Ctrl+G 快捷键分组
  2. Ctrl+Shift+G 快捷键取消分组
  3. 右键菜单新增"分组"/"取消分组"
  4. 点击分组中卡片 → 选中整个分组
  5. 双击分组名称 → 编辑
- **验证**: 手动测试

### Task 1.9: 智能对齐参考线

- **文件**: `lib/ui/widgets/canvas_painter.dart` (新增参考线渲染)
- **文件**: `lib/ui/pages/canvas_page.dart` (新增参考线计算)
- **改动**:
  1. 新增 `AlignmentGuide` 数据类：
     ```dart
     class AlignmentGuide {
       final Offset start;   // 世界坐标
       final Offset end;     // 世界坐标
       final GuideType type; // center, edge, spacing
     }
     ```
  2. CanvasPage 拖拽逻辑中计算参考线：
     - 遍历可视区域内其他卡片
     - 计算 6 种对齐条件（中心X/Y、4边）
     - 差值 < 5px 时生成参考线 + 吸附偏移
  3. CanvasPainter 新增 `guides: List<AlignmentGuide>` 参数
  4. 参考线渲染：蓝色虚线，贯穿可视区域
  5. Alt 键禁用参考线
- **验证**: 手动测试

### Task 1.10: 对齐与分布工具

- **文件**: `lib/services/canvas_service.dart` (新增对齐/分布方法)
- **文件**: `lib/ui/pages/canvas_page.dart` (新增对齐工具栏/菜单)
- **改动**:
  1. CanvasNotifier 新增方法：
     - `alignCards(List<String> cardIds, AlignmentType type)`
     - `distributeCards(List<String> cardIds, DistributeType type)`
  2. 对齐算法：
     - 左对齐：所有卡片 x = min(cards.map((c) => c.x))
     - 水平居中：所有卡片 x = avg(center.x) - width/2
     - 右对齐：所有卡片 x = max(cards.map((c) => c.x + c.width)) - width
     - 顶/垂直居中/底对齐：同理
  3. 分布算法：
     - 水平分布：按 x 排序，等分水平间距
     - 垂直分布：按 y 排序，等分垂直间距
  4. 工具栏新增对齐下拉按钮（PopupMenuButton）
  5. 右键菜单新增"对齐"子菜单
- **验证**: 单元测试 + 手动测试

### Task 1.11: Phase 1 测试

- **文件**: `test/core/model/canvas_model_test.dart` (扩展)
- **文件**: `test/services/canvas_service_test.dart` (扩展)
- **覆盖**:
  - CanvasGroup 序列化 round-trip
  - CanvasData 向后兼容（旧 JSON 无 groups/selectedCardIds）
  - 多选方法（addToSelection, selectAll, batchDeleteCards）
  - 分组方法（groupCards, ungroupCards）
  - 对齐/分布算法正确性
- **验证**: `flutter test` 全绿

---

## Phase 2: 样式与表达力增强

### Task 2.1: 卡片样式系统 — 数据模型

- **文件**: `lib/data/models/canvas_model.dart`
- **改动**:
  1. 新增 `BorderStyle` 枚举
  2. 新增 `GradientDirection` 枚举
  3. 新增 `CanvasCardStyle` 类
  4. `CanvasCard` 新增 `CanvasCardStyle? style` 字段
  5. 序列化/反序列化 + 向后兼容
- **验证**: 序列化 round-trip 测试

### Task 2.2: 卡片样式系统 — CanvasPainter 渲染

- **文件**: `lib/ui/widgets/canvas_painter.dart`
- **改动**:
  1. `_drawCards` 中读取 `card.style` 属性
  2. 支持渐变填充（LinearGradient）
  3. 支持自定义边框（色/粗细/虚线/圆角）
  4. 支持透明度
  5. 支持阴影开关
  6. `style == null` 时使用默认样式（向后兼容）
- **验证**: Widget 测试

### Task 2.3: 卡片样式系统 — 属性面板

- **文件**: `lib/ui/widgets/card_properties_panel.dart`
- **改动**:
  1. 新增样式编辑区：填充色、渐变色、边框色/粗细/样式、圆角、透明度、阴影
  2. 多选时显示"混合样式"提示
  3. 修改样式时调用 `updateCard(card.copyWith(style: ...))`
- **验证**: 手动测试

### Task 2.4: 样式刷

- **文件**: `lib/ui/pages/canvas_page.dart`
- **改动**:
  1. 新增 `_styleBrushMode` 状态 + `_copiedStyle: CanvasCardStyle?`
  2. 工具栏新增样式刷按钮
  3. 点击样式刷 → 拾取选中卡片样式
  4. 点击目标卡片 → 应用样式
  5. Esc 退出样式刷模式
  6. 右键菜单"复制样式"/"粘贴样式"
- **验证**: 手动测试

### Task 2.5: 连线样式 — 数据模型

- **文件**: `lib/data/models/canvas_model.dart`
- **改动**:
  1. 新增 `ConnectionPath` 枚举
  2. 新增 `ArrowStyle` 枚举
  3. 新增 `CanvasConnectionStyle` 类
  4. `CanvasConnection` 新增 `CanvasConnectionStyle? style` 字段
- **验证**: 序列化 round-trip 测试

### Task 2.6: 连线样式 — CanvasPainter 渲染

- **文件**: `lib/ui/widgets/canvas_painter.dart`
- **改动**:
  1. `_drawConnections` 中根据 `conn.style.pathType` 选择路径算法
  2. 新增直线渲染：直接 `lineTo`
  3. 新增正交折线渲染：计算拐点 + 小圆角
  4. 根据 `conn.style.arrowStyle` 渲染箭头
  5. 根据 `conn.style.strokeWidth` 和 `conn.style.colorValue` 设置画笔
- **验证**: Widget 测试

### Task 2.7: 容器(Container) — 数据模型

- **文件**: `lib/data/models/canvas_model.dart`
- **改动**:
  1. `CanvasCardType` 新增 `container` 值
  2. `CanvasCard` 新增 `childIds: List<String>` 和 `collapsed: bool` 字段
- **验证**: 序列化 round-trip 测试

### Task 2.8: 容器(Container) — 渲染与交互

- **文件**: `lib/ui/widgets/canvas_painter.dart`
- **文件**: `lib/ui/pages/canvas_page.dart`
- **改动**:
  1. 容器卡片自动扩展大小包含子卡片
  2. 折叠/展开按钮渲染
  3. 拖拽容器时子卡片跟随
  4. 拖拽卡片到容器上方时加入容器
- **验证**: 手动测试

### Task 2.9: Phase 2 测试

- **文件**: `test/core/model/canvas_model_test.dart` (扩展)
- **文件**: `test/services/canvas_service_test.dart` (扩展)
- **覆盖**:
  - CanvasCardStyle 序列化 round-trip
  - CanvasConnectionStyle 序列化 round-trip
  - 容器卡片 childIds 序列化
  - 向后兼容（旧 JSON 无 style/childIds/collapsed）
- **验证**: `flutter test` 全绿

---

## 完整文件变更清单

```
Phase 1 修改文件:
├── lib/data/models/canvas_model.dart         (selectedCardIds, CanvasGroup)
├── lib/services/canvas_service.dart          (多选/分组/对齐/分布方法)
├── lib/ui/widgets/canvas_painter.dart        (多选渲染/分组渲染/参考线渲染)
├── lib/ui/pages/canvas_page.dart             (多选交互/分组交互/参考线计算/对齐工具栏)
├── test/core/model/canvas_model_test.dart    (扩展)
└── test/services/canvas_service_test.dart    (扩展)

Phase 2 修改文件:
├── lib/data/models/canvas_model.dart         (CanvasCardStyle, CanvasConnectionStyle, container)
├── lib/services/canvas_service.dart          (样式相关方法)
├── lib/ui/widgets/canvas_painter.dart        (样式渲染/容器渲染/连线样式渲染)
├── lib/ui/pages/canvas_page.dart             (样式刷/容器交互)
├── lib/ui/widgets/card_properties_panel.dart (样式编辑面板)
├── test/core/model/canvas_model_test.dart    (扩展)
└── test/services/canvas_service_test.dart    (扩展)
```

---

## 里程碑定义

| 里程碑 | 定义 | 门禁条件 |
|--------|------|---------|
| M1: Multi-Select | 多选+框选+批量操作可用 | Task 1.1-1.4 完成 + 测试通过 |
| M2: Grouping | 分组功能可用 | Task 1.5-1.8 完成 + 测试通过 |
| M3: Alignment | 参考线+对齐+分布可用 | Task 1.9-1.10 完成 + 测试通过 |
| M4: Phase 1 Done | 基础能力补全完成 | Phase 1 全部测试通过 + `flutter analyze` 0 issues |
| M5: Card Styles | 卡片样式系统可用 | Task 2.1-2.3 完成 + 测试通过 |
| M6: Connection Styles | 连线样式增强可用 | Task 2.5-2.6 完成 + 测试通过 |
| M7: Containers | 容器功能可用 | Task 2.7-2.8 完成 + 测试通过 |
| M8: Phase 2 Done | 样式与表达力增强完成 | Phase 2 全部测试通过 + `flutter analyze` 0 issues |

---

*文档版本: 2.0 | 依赖: [canvas-v2-design.md](./canvas-v2-design.md)*
