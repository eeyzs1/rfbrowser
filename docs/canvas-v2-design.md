# RFBrowser 画布 V2 — Draw.io 启发的增强设计案

> 版本 2.0 | 2026-05-10 | 基于 Draw.io 功能对标分析
> 前置依赖: [canvas-redesign.md](./canvas-redesign.md) (V1 已实现)

---

## 目录

1. [背景与目标](#1-背景与目标)
2. [Draw.io 功能对标分析](#2-drawio-功能对标分析)
3. [设计原则](#3-设计原则)
4. [Phase 1: 基础能力补全](#4-phase-1-基础能力补全)
5. [Phase 2: 样式与表达力增强](#5-phase-2-样式与表达力增强)
6. [Phase 3: 高级功能](#6-phase-3-高级功能)
7. [RFBrowser 独有优势强化](#7-rfbrowser-独有优势强化)
8. [数据模型变更汇总](#8-数据模型变更汇总)
9. [验收标准](#9-验收标准)

---

## 1. 背景与目标

### 1.1 V1 已实现

V1 阶段已将画布从独立白板提升为知识空间化界面，实现了：
- 卡片与知识笔记实时同步（noteId 关联）
- 基于 wikilink 的自动连线发现
- 画布内搜索与卡片高亮定位
- 文件系统持久化（`.canvas.json`）
- 多画布管理
- 撤销/重做（50步）
- 小地图 + 缩放导航

### 1.2 V2 目标

对标 VS Code Draw.io Integration 插件的核心能力，将画布从"能用"提升为"好用"，重点补齐以下能力缺口：

| 维度 | V1 状态 | V2 目标 |
|------|---------|---------|
| **选择** | 仅单选 | 多选 + 框选 + 批量操作 |
| **组织** | 无 | 分组(Group) + 容器(Container) |
| **对齐** | 仅网格吸附 | 智能参考线 + 对齐/分布工具 |
| **样式** | 仅背景色 | 完整样式系统(边框/阴影/圆角/渐变) |
| **连线** | 固定贝塞尔曲线 | 多种路径类型 + 箭头样式 + 路径控制点 |
| **图层** | 无 | 多图层 + 可见性 + 锁定 |

### 1.3 范围界定

**本设计案覆盖 Phase 1-2**，Phase 3 为远期规划。

---

## 2. Draw.io 功能对标分析

### 2.1 Draw.io 核心功能清单

| 类别 | 功能 | Draw.io | RFBrowser V1 | V2 规划 |
|------|------|---------|-------------|---------|
| **选择** | 单选 | ✅ | ✅ | ✅ |
| | 多选(Shift+点击) | ✅ | ❌ | ✅ Phase1 |
| | 框选 | ✅ | ❌ | ✅ Phase1 |
| | 批量操作 | ✅ | ❌ | ✅ Phase1 |
| **组织** | 分组(Group) | ✅ | ❌ | ✅ Phase1 |
| | 容器(Container) | ✅ | ❌ | ✅ Phase2 |
| | 泳道(Swimlane) | ✅ | ❌ | Phase3 |
| | 折叠/展开 | ✅ | ❌ | ✅ Phase2 |
| **对齐** | 网格吸附 | ✅ | ✅ | ✅ |
| | 智能参考线 | ✅ | ❌ | ✅ Phase1 |
| | 对齐工具 | ✅ | ❌ | ✅ Phase1 |
| | 均匀分布 | ✅ | ❌ | ✅ Phase1 |
| | 自动布局 | ✅ | ❌ | Phase3 |
| **样式** | 填充色 | ✅ | ✅(仅1色) | ✅ Phase2 |
| | 渐变 | ✅ | ❌ | ✅ Phase2 |
| | 边框色/粗细/虚线 | ✅ | ❌ | ✅ Phase2 |
| | 阴影 | ✅ | ❌(固定) | ✅ Phase2 |
| | 圆角 | ✅ | ❌(固定8) | ✅ Phase2 |
| | 透明度 | ✅ | ❌ | ✅ Phase2 |
| | 样式刷 | ✅ | ❌ | ✅ Phase2 |
| | 默认样式 | ✅ | ❌ | Phase3 |
| **连线** | 曲线 | ✅ | ✅ | ✅ |
| | 直线 | ✅ | ❌ | ✅ Phase2 |
| | 正交折线 | ✅ | ❌ | ✅ Phase2 |
| | 箭头样式 | ✅ | ❌(固定) | ✅ Phase2 |
| | 路径控制点 | ✅ | ❌ | Phase3 |
| | 流动动画 | ✅ | ❌ | Phase3 |
| **图层** | 多图层 | ✅ | ❌ | Phase3 |
| | 可见性/锁定 | ✅ | ❌ | Phase3 |
| **文本** | 富文本 | ✅ | ❌ | Phase3 |
| | 竖排文本 | ✅ | ❌ | Phase3 |
| **导出** | PNG/SVG/PDF | ✅ | ❌ | Phase3 |
| **独有** | noteId 关联 | ❌ | ✅ | 强化 |
| **独有** | wikilink 自动连线 | ❌ | ✅ | 强化 |
| **独有** | 知识图谱联动 | ❌ | ✅(基础) | 强化 |

---

## 3. 设计原则

### P0: 知识代理，不是绘图工具

卡片的核心价值是关联笔记，不是画漂亮的图。样式增强是为了更好地区分和组织知识，不是为了艺术创作。每个样式属性必须有知识工作的语义含义。

### P1: 轻量优先

Draw.io 是重量级应用（基于 mxGraph 库，数万行代码），RFBrowser 的画布应保持轻量、快速响应。不实现 Draw.io 的所有功能，精选最有助于知识工作的特性。

### P2: 向后兼容

所有数据模型变更必须支持旧格式 JSON 的无损失加载。新字段缺失时使用合理默认值。

### P3: 性能不变

多选、参考线等新功能不能拖慢渲染性能。框选和参考线计算仅在交互时触发，不影响静态渲染帧率。

---

## 4. Phase 1: 基础能力补全

### 4.1 多选与批量操作

#### 4.1.1 数据模型变更

`CanvasData.selectedCardId: String?` → `CanvasData.selectedCardIds: List<String>`

```dart
class CanvasData {
  final List<CanvasCard> cards;
  final List<CanvasConnection> connections;
  final CanvasSettings settings;
  final List<String> selectedCardIds;        // 替代 selectedCardId
  final String? inlineEditingCardId;
  // ...
}
```

#### 4.1.2 交互设计

| 操作 | 行为 |
|------|------|
| 点击卡片 | 单选该卡片（清除其他选中） |
| Shift+点击卡片 | 增减选中项 |
| 空白区域拖拽 | 框选，选中框内所有卡片 |
| Ctrl+A | 全选 |
| Delete | 删除所有选中卡片 |
| 拖拽选中卡片 | 整体移动所有选中卡片 |
| 右键选中卡片 | 批量操作菜单（改色、分组、删除） |

#### 4.1.3 框选渲染

- 拖拽时绘制蓝色半透明选择矩形（`rgba(59, 130, 246, 0.1)` 填充 + `rgba(59, 130, 246, 0.5)` 边框）
- 选择矩形使用世界坐标系，与画布缩放/平移同步
- 释放鼠标时计算框内卡片

#### 4.1.4 批量移动

- 拖拽任一选中卡片时，所有选中卡片保持相对位置同步移动
- 使用 `updateCardInMemory()` 更新每张卡片位置
- 拖拽结束时调用 `persist()` 一次性保存

### 4.2 分组(Group)

#### 4.2.1 数据模型

```dart
class CanvasGroup {
  final String id;
  final String name;
  final List<String> cardIds;
  final int colorValue;

  const CanvasGroup({
    required this.id,
    required this.name,
    this.cardIds = const [],
    this.colorValue = 0xFFFFFFFF,
  });

  CanvasGroup copyWith({
    String? name,
    List<String>? cardIds,
    int? colorValue,
  }) => CanvasGroup(
    id: id,
    name: name ?? this.name,
    cardIds: cardIds ?? this.cardIds,
    colorValue: colorValue ?? this.colorValue,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'cardIds': cardIds,
    'colorValue': colorValue,
  };

  factory CanvasGroup.fromJson(Map<String, dynamic> json) => CanvasGroup(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    cardIds: (json['cardIds'] as List?)?.cast<String>() ?? [],
    colorValue: json['colorValue'] as int? ?? 0xFFFFFFFF,
  );
}
```

`CanvasData` 新增 `List<CanvasGroup> groups` 字段。

#### 4.2.2 交互设计

| 操作 | 行为 |
|------|------|
| 选中多张卡片 → 右键"分组" | 创建 CanvasGroup，cardIds 包含选中卡片 |
| Ctrl+G | 快捷键分组 |
| 点击分组中任一卡片 | 选中整个分组（高亮组内所有卡片） |
| 拖拽分组中任一卡片 | 整体移动组内所有卡片 |
| 右键分组 → "取消分组" | 解散分组，卡片独立 |
| Ctrl+Shift+G | 快捷键取消分组 |
| 双击分组标题 | 编辑分组名称 |

#### 4.2.3 分组渲染

- 分组内卡片共享一个半透明背景矩形（组色 + 低透明度）
- 背景矩形自动计算为包含所有组内卡片的最小矩形 + padding
- 分组名称显示在背景矩形顶部

### 4.3 智能对齐参考线

#### 4.3.1 参考线类型

| 参考线 | 触发条件 | 颜色 |
|--------|---------|------|
| 垂直居中对齐 | 两卡片中心X差值 < 5px | 蓝色虚线 |
| 水平居中对齐 | 两卡片中心Y差值 < 5px | 蓝色虚线 |
| 左边缘对齐 | 两卡片 left 差值 < 5px | 蓝色虚线 |
| 右边缘对齐 | 两卡片 right 差值 < 5px | 蓝色虚线 |
| 顶边缘对齐 | 两卡片 top 差值 < 5px | 蓝色虚线 |
| 底边缘对齐 | 两卡片 bottom 差值 < 5px | 蓝色虚线 |
| 等间距 | 三张以上卡片间距差 < 5px | 绿色虚线 |

#### 4.3.2 交互设计

- 拖拽卡片时实时计算参考线
- 差值 < 吸附阈值(5px) 时自动吸附
- Alt 键临时禁用参考线和吸附
- 参考线贯穿整个可视区域
- 释放鼠标后参考线消失

#### 4.3.3 性能考量

- 仅在拖拽过程中计算，不影响静态渲染
- 仅与可视区域内的卡片比较（剔除视口外卡片）
- 参考线数据作为 CanvasPainter 的临时参数传入，不持久化

### 4.4 对齐与分布工具

#### 4.4.1 对齐操作

| 操作 | 图标 | 行为 |
|------|------|------|
| 左对齐 | `Icons.align_horizontal_left` | 所有选中卡片的 left 对齐到最左卡片 |
| 水平居中 | `Icons.align_horizontal_center` | 所有选中卡片的中心X对齐到平均中心X |
| 右对齐 | `Icons.align_horizontal_right` | 所有选中卡片的 right 对齐到最右卡片 |
| 顶对齐 | `Icons.align_vertical_top` | 所有选中卡片的 top 对齐到最上卡片 |
| 垂直居中 | `Icons.align_vertical_center` | 所有选中卡片的中心Y对齐到平均中心Y |
| 底对齐 | `Icons.align_vertical_bottom` | 所有选中卡片的 bottom 对齐到最下卡片 |

#### 4.4.2 分布操作

| 操作 | 图标 | 行为 |
|------|------|------|
| 水平均匀分布 | `Icons.space_bar` | 选中卡片（≥3）水平间距相等 |
| 垂直均匀分布 | `Icons.view_headline` | 选中卡片（≥3）垂直间距相等 |

#### 4.4.3 UI 位置

- 工具栏新增"对齐"下拉按钮（仅选中 ≥2 张卡片时可用）
- 右键菜单新增"对齐"子菜单

---

## 5. Phase 2: 样式与表达力增强

### 5.1 增强卡片样式系统

#### 5.1.1 数据模型

```dart
enum BorderStyle { solid, dashed, dotted, none }

class CanvasCardStyle {
  final int fillColor;
  final int? gradientColor;
  final GradientDirection gradientDirection;
  final int borderColor;
  final double borderWidth;
  final BorderStyle borderStyle;
  final double borderRadius;
  final double opacity;
  final bool shadow;

  const CanvasCardStyle({
    this.fillColor = 0xFFFFFFFF,
    this.gradientColor,
    this.gradientDirection = GradientDirection.topToBottom,
    this.borderColor = 0xFFE0E0E0,
    this.borderWidth = 1.0,
    this.borderStyle = BorderStyle.solid,
    this.borderRadius = 8.0,
    this.opacity = 1.0,
    this.shadow = true,
  });

  Map<String, dynamic> toJson() => { ... };
  factory CanvasCardStyle.fromJson(Map<String, dynamic> json) => ...;
  factory CanvasCardStyle.defaults() => const CanvasCardStyle();
}

enum GradientDirection {
  topToBottom, bottomToTop, leftToRight, rightToLeft,
  topLeftToBottomRight, topRightToBottomLeft;
}
```

`CanvasCard` 新增 `CanvasCardStyle? style` 字段。`null` 表示使用默认样式（向后兼容）。

#### 5.1.2 样式刷

| 操作 | 行为 |
|------|------|
| 选中卡片 → 工具栏"样式刷"按钮 | 进入样式拾取模式 |
| 点击目标卡片 | 将源卡片样式应用到目标 |
| Esc | 退出样式刷模式 |
| 右键"复制样式" | 复制选中卡片样式到剪贴板 |
| 右键"粘贴样式" | 将剪贴板样式应用到选中卡片 |

### 5.2 连线样式增强

#### 5.2.1 数据模型

```dart
enum ConnectionPath { curved, straight, orthogonal }

enum ArrowStyle { none, triangle, filledTriangle, diamond, circle }

class CanvasConnectionStyle {
  final ConnectionPath pathType;
  final ArrowStyle arrowStyle;
  final double strokeWidth;
  final int colorValue;
  final List<Offset> waypoints;

  const CanvasConnectionStyle({
    this.pathType = ConnectionPath.curved,
    this.arrowStyle = ArrowStyle.filledTriangle,
    this.strokeWidth = 2.0,
    this.colorValue = 0xFF000000,
    this.waypoints = const [],
  });
}
```

`CanvasConnection` 新增 `CanvasConnectionStyle? style` 字段。

#### 5.2.2 正交折线算法

正交折线（orthogonal）的路径计算：
1. 从 fromSide 出发，沿方向延伸一段距离
2. 计算到 toSide 入口的最短正交路径（最多2个拐点）
3. 拐点处使用小圆角过渡

### 5.3 容器(Container)

#### 5.3.1 数据模型

新增 `CanvasCardType.container` 类型。

`CanvasCard` 新增字段：
```dart
final List<String> childIds;   // 仅 container 类型使用
final bool collapsed;          // 折叠状态
```

#### 5.3.2 交互设计

| 操作 | 行为 |
|------|------|
| 拖拽卡片到容器上方 | 卡片加入容器（childIds） |
| 拖拽容器 | 所有子卡片保持相对位置同步移动 |
| 点击容器折叠按钮 | 折叠/展开容器 |
| 折叠状态 | 仅显示标题栏，隐藏子卡片和内部连线 |
| 右键容器 → "从容器移除" | 将子卡片移出容器 |

#### 5.3.3 容器渲染

- 容器卡片自动扩展大小以包含所有子卡片 + padding
- 容器背景色为半透明填充
- 折叠时仅显示标题栏 + 子卡片数量标记
- 展开时显示完整内容

---

## 6. Phase 3: 高级功能（远期规划）

### 6.1 图层系统

- `CanvasLayer` 模型：id, name, visible, locked, order
- `CanvasCard` 新增 `layerId` 字段
- 图层面板 UI（底部或左侧）
- 跨层连接支持

### 6.2 自动布局

- 力导向布局（基于连线关系）
- 层次布局（按连线方向分层）
- 网格布局（均匀排列）

### 6.3 导出功能

- PNG 导出（RenderRepaintBoundary）
- SVG 导出（遍历生成 SVG XML）
- Markdown mermaid 导出

### 6.4 便签板(Scratchpad)

- 个人形状/卡片模板暂存区
- 跨画布复用
- 存储在 `<vault>/.rf/scratchpad.json`

---

## 7. RFBrowser 独有优势强化

### 7.1 笔记内容变更提示

当关联笔记内容变更时，卡片边框短暂闪烁提示用户。

### 7.2 自动连线标签

自动连线的标签自动填充 wikilink 的显示文本，而非空字符串。

### 7.3 画布-图谱双向联动

- 图谱中选中节点 → 画布高亮对应卡片
- 画布中选中卡片 → 图谱高亮对应节点
- 共享选择状态通过 Riverpod provider

### 7.4 AI 智能布局

- AI 根据笔记内容自动建议画布布局
- AI 生成卡片和连线（基于笔记关系分析）

---

## 8. 数据模型变更汇总

### 8.1 Phase 1 变更

```dart
// CanvasData — 修改
class CanvasData {
  final List<CanvasCard> cards;
  final List<CanvasConnection> connections;
  final List<CanvasGroup> groups;           // 新增
  final CanvasSettings settings;
  final List<String> selectedCardIds;       // 替代 selectedCardId
  final String? inlineEditingCardId;
}

// CanvasGroup — 新增
class CanvasGroup {
  final String id;
  final String name;
  final List<String> cardIds;
  final int colorValue;
}
```

### 8.2 Phase 2 变更

```dart
// CanvasCard — 扩展
class CanvasCard {
  // ...existing fields...
  final CanvasCardStyle? style;     // 新增
  final List<String> childIds;      // 新增 (container)
  final bool collapsed;             // 新增 (container)
}

// CanvasCardStyle — 新增
class CanvasCardStyle {
  final int fillColor;
  final int? gradientColor;
  final GradientDirection gradientDirection;
  final int borderColor;
  final double borderWidth;
  final BorderStyle borderStyle;
  final double borderRadius;
  final double opacity;
  final bool shadow;
}

// CanvasConnection — 扩展
class CanvasConnection {
  // ...existing fields...
  final CanvasConnectionStyle? style;  // 新增
}

// CanvasConnectionStyle — 新增
class CanvasConnectionStyle {
  final ConnectionPath pathType;
  final ArrowStyle arrowStyle;
  final double strokeWidth;
  final int colorValue;
  final List<Offset> waypoints;
}

// CanvasCardType — 扩展
enum CanvasCardType {
  note, image, link, text, container;  // 新增 container
}
```

---

## 9. 验收标准

### Phase 1 验收标准

| ID | 标准 | 自动化 |
|----|------|--------|
| AC-P1-1 | 点击卡片仅选中该卡片，清除其他选中 | ✅ |
| AC-P1-2 | Shift+点击增减选中项 | ✅ |
| AC-P1-3 | 空白区域拖拽框选，选中框内所有卡片 | ✅ |
| AC-P1-4 | Ctrl+A 全选 | ✅ |
| AC-P1-5 | Delete 删除所有选中卡片及其连线 | ✅ |
| AC-P1-6 | 拖拽任一选中卡片，所有选中卡片同步移动 | ✅ |
| AC-P1-7 | 右键选中卡片弹出批量操作菜单 | ✅ |
| AC-P1-8 | Ctrl+G 将选中卡片分组 | ✅ |
| AC-P1-9 | Ctrl+Shift+G 取消分组 | ✅ |
| AC-P1-10 | 拖拽分组中卡片，组内卡片同步移动 | ✅ |
| AC-P1-11 | 分组数据持久化到 JSON，重启后恢复 | ✅ |
| AC-P1-12 | 拖拽卡片时显示智能对齐参考线 | ✅ |
| AC-P1-13 | 差值 < 5px 时自动吸附 | ✅ |
| AC-P1-14 | Alt 键临时禁用参考线和吸附 | ✅ |
| AC-P1-15 | 选中 ≥2 张卡片时对齐工具可用 | ✅ |
| AC-P1-16 | 对齐操作正确调整卡片位置 | ✅ |
| AC-P1-17 | 均匀分布操作正确调整卡片间距 | ✅ |
| AC-P1-18 | 旧格式 JSON（无 groups/selectedCardIds）无损失加载 | ✅ |

### Phase 2 验收标准

| ID | 标准 | 自动化 |
|----|------|--------|
| AC-P2-1 | 卡片样式属性（边框/阴影/圆角/渐变/透明度）可编辑 | ✅ |
| AC-P2-2 | 样式刷可将源卡片样式复制到目标卡片 | ✅ |
| AC-P2-3 | 连线路径类型（曲线/直线/正交折线）可切换 | ✅ |
| AC-P2-4 | 连线箭头样式可切换 | ✅ |
| AC-P2-5 | 容器可包含子卡片，拖拽容器时子卡片跟随 | ✅ |
| AC-P2-6 | 容器可折叠/展开 | ✅ |
| AC-P2-7 | 新增样式字段缺失时使用合理默认值（向后兼容） | ✅ |

---

*文档版本: 2.0 | 前置: [canvas-redesign.md](./canvas-redesign.md) | 开发计划: [canvas-v2-dev-plan.md](./canvas-v2-dev-plan.md)*
