# RFBrowser — UX 重构设计案

> **版本**: 1.0  
> **状态**: Draft  
> **设计哲学**: "Simplicity is the ultimate sophistication." — 从 8 面板工具集进化为 3 场景智能空间

---

## 目录

1. [现状诊断](#1-现状诊断)
2. [设计原则](#2-设计原则)
3. [用户画像](#3-用户画像)
4. [场景模型](#4-场景模型)
5. [信息架构重构](#5-信息架构重构)
6. [逐场景 UI 规格](#6-逐场景-ui-规格)
7. [AI 融入模型](#7-ai-融入模型)
8. [视觉语言系统](#8-视觉语言系统)
9. [交互动效规格](#9-交互动效规格)
10. [可验证标准](#10-可验证标准)

---

## 1. 现状诊断

### 1.1 当前信息架构问题

```
现状：用户打开 Vault → 看到顶部一排面板按钮 → 4个空面板同时出现
问题：没有焦点，没有引导，没有"英雄路径"
```

当前 `main_layout.dart` 中的 `_buildTree()` 方法将活跃面板线性排列为多栏 SplitPane。这导致：
- **认知过载**: 新用户面对 8 种面板类型的选择瘫痪
- **焦点缺失**: 没有"当前任务是什么"的上下文感知
- **AI 降级**: AI Chat 作为平等面板之一，而非无所不在的智能层

### 1.2 与产品愿景的偏差

`01-product-vision.md` 中定义的核心命题是"高效获取、组织、关联和自动化处理知识"。但当前 UI 将这几个步骤呈现为彼此隔离的面板，违背了"融合"的初衷。

### 1.3 现状中的闪光点（保留）

以下设计决策是正确且必须保留的：
- **CommandBar 混合搜索**: 300ms debounce + hybrid search + slash 命令
- **Markdown 渲染**: AI 响应和编辑器预览中的 selectable MarkdownBody
- **上下文引用系统**: @note, @web, @clip 引用语法
- **流式 AI 响应**: 实时 token 输出
- **纯 Markdown 存储**: 零锁定，Git 可追踪

---

## 2. 设计原则

| 编号 | 原则 | 含义 | 可验证标准 |
|------|------|------|-----------|
| **P1** | 一次只做一件事 | 任意时刻只有一个主导视图占据 >60% 屏幕 | 可通过 Widget 层级验证 |
| **P2** | AI 先于面板 | AI 助手在任何场景下均可见可达（无需切换面板） | 所有场景可触发 AI 交互 |
| **P3** | 5 分钟价值 | 新用户打开 Vault 后 5 分钟内完成第一个有意义的操作闭环 | 时间度量 + 日志验证 |
| **P4** | 渐进式复杂度 | 高级功能通过 discoverable 的渐进方式暴露，不堵塞基础路径 | 基础功能 <3 步可达 |
| **P5** | 情感化反馈 | 每个破坏性/创造性操作有即时动画反馈 | 动画时长 200-400ms |
| **P6** | 品牌一致 | 所有 UI 元素共享同一套设计 token（色板、圆角、间距、字体层级） | 设计 token 文件存在且被引用 |

---

## 3. 用户画像

### Persona A: 研究者（李教授）
- **场景**: 每天阅读 20+ 篇论文/文章，需要捕捉关键论点并建立联系
- **痛点**: 信息散落在浏览器标签页、本地 PDF、手写笔记中，无法串联
- **目标**: "我希望读完一篇文章后，它能自动融入我的知识网络，而不是成为又一个孤立的书签"
- **核心路径**: 浏览 → 捕捉 → 关联

### Persona B: 写作者（小王）
- **场景**: 正在撰写一篇深度长文/报告，需要引用多个来源
- **痛点**: 引用管理混乱，写作时找不到之前保存的材料
- **目标**: "我希望写文章时，相关的参考资料自动出现在我手边"
- **核心路径**: 写作 → AI 辅助 → 引用

### Persona C: 学习者（张同学）
- **场景**: 学习新领域知识，需要建立概念地图
- **痛点**: 做了很多笔记但不知道它们之间的关系
- **目标**: "我希望看到一个领域内所有知识如何彼此连接"
- **核心路径**: 笔记 → 图谱探索 → 发现新知

---

## 4. 场景模型

### 4.1 三场景架构（替代 8 面板）

```
┌──────────────────────────────────────────────────────────────────┐
│                      场景切换器 (Ctrl+1/2/3)                       │
│           📖 捕捉       ✍️ 思考       🗺️ 连接                     │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│                     主导视图 (Scene Content)                       │
│                                                                  │
│        ┌──────────────────────────────────────────────┐          │
│        │                                              │          │
│        │         场景特定的主要工作区域                  │          │
│        │                                              │          │
│        └──────────────────────────────────────────────┘          │
│                                                                  │
│   左侧面板                           右侧面板                     │
│   ┌──────────┐                    ┌──────────────┐              │
│   │ 笔记列表  │                    │ AI 浮动助手   │              │
│   │ (可折叠)  │                    │ (始终可见)    │              │
│   └──────────┘                    └──────────────┘              │
│                                                                  │
├──────────────────────────────────────────────────────────────────┤
│  📂 My Vault  │  ✅ 已同步  │  🔍 搜索...                         │
└──────────────────────────────────────────────────────────────────┘
```

### 4.2 场景定义

| 场景 | 名称 | 主导视图 | 左侧面板 | 右侧面板 | 快捷键 | 适用 Persona |
|------|------|---------|---------|---------|--------|-------------|
| S1 | 📖 捕捉 | BrowserView + ClipBar | 笔记列表 | AI 摘要浮动 | Ctrl+1 | 研究者 |
| S2 | ✍️ 思考 | EditorView (全宽) | 大纲/笔记列表 | AI 建议 + 反向链接 | Ctrl+2 | 写作者 |
| S3 | 🗺️ 连接 | GraphView / CanvasView | 筛选面板 | AI 解释浮动 | Ctrl+3 | 学习者 |

### 4.3 场景切换行为

- 场景切换保留当前上下文（活跃笔记、浏览器 URL 不丢失）
- 切换动画: 主导视图 300ms 淡入淡出 + 侧面板 200ms 滑入滑出
- 场景状态隔离: 各场景独立维护自己的滚动位置、缩放级别、选中等
- 快捷键切换: Ctrl+1/2/3 全局可触发

---

## 5. 信息架构重构

### 5.1 导航层级

```
Level 0: App Shell
  ├── Scene Switcher (顶层，始终可见)
  ├── Left Drawer (笔记列表，可折叠，所有场景共享)
  ├── Scene Content (根据当前场景切换)
  ├── AI Float (右下角浮动按钮 + 可展开面板)
  └── Global Status Bar (底部，极简)

Level 1: Scene Content
  ├── S1 捕捉: BrowserView + ClipToolbar + MiniGraph
  ├── S2 思考: EditorView + OutlinePanel + Backlinks
  └── S3 连接: GraphView/CanvasView + FilterPanel + NodeDetail

Level 2: Context Panels
  ├── AI Float → (expand) → AI Chat Panel
  ├── Left Drawer → (toggle) → Note Sidebar
  └── Settings → (navigate) → Settings Page
```

### 5.2 路由表

| 路由 | 目标 | 触发方式 |
|------|------|---------|
| `/capture` | 捕捉场景 | Ctrl+1, 场景切换器点击 |
| `/think` | 思考场景 | Ctrl+2, 场景切换器点击 |
| `/connect` | 连接场景 | Ctrl+3, 场景切换器点击 |
| `/settings` | 设置页 | 状态栏齿轮图标, Ctrl+, |
| `/welcome` | 欢迎页 | Vault 切换/关闭时自动跳转 |
| `/ai-chat` | AI 浮动面板展开 | 右下角 AI 按钮点击, Ctrl+J |

### 5.3 全局搜索升级

当前 CommandBar 仅通过 Ctrl+K 触发。升级为双层搜索：

| 层级 | 名称 | 外观 | 触发 | 功能 |
|------|------|------|------|------|
| L1 | Quick Search | 状态栏内联搜索框 | 点击状态栏搜索区域 / Ctrl+F | 只搜笔记标题 |
| L2 | Command Palette | 全屏模态覆盖层 | Ctrl+K / Quick Search 中按 Ctrl+K | 混合搜索 + 命令 + Quick Move |

状态栏搜索框始终可见（用户的第一本能入口），CommandBar 保持现有功能不变。

---

## 6. 逐场景 UI 规格

### 6.1 场景 S1: 📖 捕捉 (Capture)

#### 6.1.1 布局

```
┌──────────────────────────────────────────────────────────────┐
│ [◀ 笔记面板] │                  BrowserView                  │ [AI摘要 ▶] │
│              │  ┌────────────────────────────────────────┐   │            │
│              │  │  🔗 https://example.com/article       │   │  ┌───────┐ │
│              │  ├────────────────────────────────────────┤   │  │ AI    │ │
│              │  │                                        │   │  │ 摘要   │ │
│              │  │   网页内容渲染区                         │   │  │       │ │
│              │  │                                        │   │  │ 关键点 │ │
│              │  │                                        │   │  │ 1. ... │ │
│              │  │                                        │   │  │ 2. ... │ │
│              │  │                                        │   │  └───────┘ │
│              │  └────────────────────────────────────────┘   │            │
│              │  ┌────────────────────────────────────────┐   │            │
│              │  │ 📎 剪辑全文 │ ✂️ 剪辑选中 │ 🔖 书签     │   │            │
│              │  └────────────────────────────────────────┘   │            │
└──────────────────────────────────────────────────────────────┘
```

#### 6.1.2 组件规格

**ClipToolbar (剪辑工具栏)**
- 位置: BrowserView 底部，固定在视口内
- 高度: 40px
- 包含 3 个按钮:
  - `📎 剪辑全文`: `Icons.content_copy` → 调用 `ClipperService.clipFullPage()`
  - `✂️ 剪辑选中`: `Icons.text_select` → 调用 `ClipperService.clipSelection()`（需先有选中文本）
  - `🔖 书签`: `Icons.bookmark_outline` → 调用 `ClipperService.clipBookmark()`
- 剪辑按钮需检测 `browserProvider.selectedText` 是否非空，空时 "剪辑选中" 按钮置灰
- 剪辑完成后的反馈: 按钮短暂变绿 (200ms) + toast "已保存到知识库" + 笔记列表闪烁新高亮

**AI Summary Float (AI 摘要浮动面板)**
- 位置: BrowserView 右侧，可折叠
- 宽度: 280px (折叠时 0)
- 内容: AI 自动生成的当前页面摘要
  - 触发: 页面加载完成 2 秒后自动请求（仅当页面停留 >5 秒）
  - 显示: 3-5 条关键要点 + "相关笔记" 列表
- 折叠状态: 仅显示一个竖条标签 "AI 摘要" (24px 宽)

#### 6.1.3 交互行为

| 操作 | 触发 | 行为 | 反馈 |
|------|------|------|------|
| 剪辑全文 | 点击 📎 按钮 | 后端剪辑 → 创建笔记 → 知识库刷新 | 按钮变绿 200ms + toast |
| 剪辑选中 | 选中文字 → 点击 ✂️ 按钮 | 同剪辑全文，但内容为选中文本 | 同上 |
| 添加书签 | 点击 🔖 按钮 | 创建仅含 URL+标题的笔记 | 按钮变绿 200ms + toast |
| 打开 AI 摘要 | 点击右侧 "AI 摘要" 标签 | 展开 280px 面板 | 200ms 滑入动画 |
| 在笔记中打开 | 点击 AI 摘要中的相关笔记 | 切换到 S2 思考场景并打开该笔记 | 场景切换动画 |

---

### 6.2 场景 S2: ✍️ 思考 (Think)

#### 6.2.1 布局

```
┌──────────────────────────────────────────────────────────────┐
│ [◀ 大纲] │                   EditorView                     │ [反向链接 ▶]│
│          │  ┌──────────────────────────────────────────┐    │             │
│          │  │  # 笔记标题                  [预览|编辑]  │    │  相关笔记    │
│          │  ├──────────────────────────────────────────┤    │  ┌────────┐ │
│          │  │                                          │    │  │ Note A │ │
│          │  │  Markdown 编辑器 / 预览区                  │    │  │ Note B │ │
│          │  │                                          │    │  │ Note C │ │
│          │  │                                          │    │  └────────┘ │
│          │  │                                          │    │             │
│          │  │                                          │    │  AI 建议    │
│          │  │                                          │    │  ┌────────┐ │
│          │  │                                          │    │  │ 链接?  │ │
│          │  │                                          │    │  └────────┘ │
│          │  └──────────────────────────────────────────┘    │             │
│          │  ┌──────────────────────────────────────────┐    │             │
│          │  │  💡 AI: 你提到了 "认知负荷"，是否链接到  │    │             │
│          │  │  [[认知心理学导论]]？ [链接] [忽略]      │    │             │
│          │  └──────────────────────────────────────────┘    │             │
└──────────────────────────────────────────────────────────────┘
```

#### 6.2.2 组件规格

**AI Inline Suggestion (AI 内联建议栏)**
- 位置: EditorView 底部，编辑器与 AI Float 之间
- 高度: 动态（最多 80px），不阻塞编辑器
- 触发: 用户在编辑器中输入停顿时（1.5s debounce after last keystroke）
- 内容: 
  - 检测到 `[[未创建笔记名]]` 时 → 建议创建
  - 检测到已知概念时 → 建议链接到现有笔记
  - 检测到问句时 → 建议让 AI 回答
- 交互:
  - "链接" 按钮: 在当前光标位置插入 `[[笔记名]]`
  - "忽略" 按钮: 关闭此建议并记录（同会话内不再建议）
  - "展开" 按钮: 将建议发送到 AI Float 进行深度对话
- 视觉效果: 从底部滑入，300ms ease-out

**Right Panel: Backlinks + AI Suggestions**
- 宽度: 260px
- 上半部分: 反向链接列表（来源：`knowledgeState.backlinks`）
- 下半部分: AI 上下文建议（来源：AI 分析当前笔记内容 + 知识图谱）
- 反向链接每项: 笔记标题 + 引用上下文摘要（30 字截断）+ 点击跳转

#### 6.2.3 编辑器增强

保留现有功能：
- `HighlightedTextEditingController` 语法高亮
- `SyncScrollController` 同步滚动
- 预览/编辑/分屏切换
- 拖放交互

新增：
- Wikilink 自动补全: 输入 `[[` 时弹出笔记搜索（复用 CommandBar 的 hybrid search）
- 编辑器光标处的 AI 浮动菜单: 选中文本 → 出现浮动菜单 "AI 解释 / AI 扩展 / AI 翻译"

---

### 6.3 场景 S3: 🗺️ 连接 (Connect)

#### 6.3.1 布局

```
┌──────────────────────────────────────────────────────────────┐
│ [◀ 筛选] │           GraphView / CanvasView                 │ [节点详情 ▶]│
│          │  ┌──────────────────────────────────────────┐    │            │
│          │  │                                          │    │  选中节点   │
│          │  │                                          │    │  ┌───────┐ │
│          │  │    知识图谱 / 无限画布                     │    │  │ 标题   │ │
│          │  │                                          │    │  │ 标签   │ │
│          │  │    • —— • —— •                           │    │  │ 连接数 │ │
│          │  │    |    |    |                           │    │  └───────┘ │
│          │  │    • —— • —— •                           │    │            │
│          │  │                                          │    │  AI 解释   │
│          │  │                                          │    │  ┌───────┐ │
│          │  │                                          │    │  │ ...   │ │
│          │  │                                          │    │  └───────┘ │
│          │  └──────────────────────────────────────────┘    │            │
└──────────────────────────────────────────────────────────────┘
```

#### 6.3.2 组件规格

**GraphView / CanvasView 切换**
- 场景 S3 内部有两个子模式: Graph（图谱）和 Canvas（画布）
- 切换: 底部标签栏或 Ctrl+Shift+G / Ctrl+Shift+C
- Canvas 支持画布内嵌套图谱小视图（minimap）

**Left Filter Panel (筛选面板)**
- 宽度: 220px（可折叠）
- 包含:
  - 标签筛选（多选 chips）
  - 时间范围滑块
  - 连接深度调节（1-4）
  - "只看桥接节点" 开关
- 筛选改变即时反映在图谱上（无需 "应用" 按钮）

**Right Node Detail Panel**
- 宽度: 280px
- 选中图谱节点时显示:
  - 笔记标题（可点击打开编辑）
  - 标签列表
  - 入链/出链数量
  - AI 生成的关系解释: "此笔记通过 X 与 Y 关联，因为..."
- 未选中节点时: 显示图谱统计摘要

#### 6.3.3 图谱增强

保留现有功能：
- 力导向/圆形布局
- 全图/局部图模式
- 桥接节点检测
- 缩放/平移
- `GraphStatsCard`

新增：
- 节点脉动动画: 选中节点以 2s 周期呼吸式缩放（1.0 → 1.08 → 1.0）
- 自动连线 vs 手动连线视觉区分（已有设计案 canvas-redesign.md）
- 双击节点 → 跳转到 S2 思考场景并打开对应笔记
- 右键菜单: "打开笔记" / "设为中心" / "在图谱中隐藏"

---

## 7. AI 融入模型

### 7.1 AI 存在层级

```
Layer 3: AI Float (显式对话)
  └── 右下角浮动按钮 → 展开 → 完整 AI Chat Panel
      保留所有现有 AI Chat 功能 (流式、Markdown、上下文引用)

Layer 2: Contextual AI (上下文感知)
  ├── S1: 页面摘要自动生成
  ├── S2: 内联链接建议 + 选中文本 AI 菜单
  └── S3: 节点关系解释

Layer 1: Ambient AI (环境智能)
  ├── 全局: 笔记列表中的 "AI 推荐阅读" 标记
  ├── 全局: 每日摘要通知（今天浏览/创作的内容总结）
  └── 全局: 未读/未整理内容的提醒
```

### 7.2 AI Float 组件规格

```
折叠态:                    展开态:
┌──┐                      ┌─────────────────────┐
│🤖│                      │ AI Assistant    [−] │
│  │                      ├─────────────────────┤
│  │                      │                     │
│  │                      │  [对话历史...]       │
│  │  点击展开              │                     │
│  │                      │                     │
│  │                      ├─────────────────────┤
│  │                      │ [模型选择] [技能]   │
│  │                      ├─────────────────────┤
│  │                      │ [输入框...]   [发送] │
└──┘                      └─────────────────────┘
  右下角                     右下角展开, 360×480px
  48×48px                   带阴影的浮动卡片
```

AI Float 的内容即现有 `AIChatPanel`，但容器从面板变为浮动卡片。
所有现有 AI 功能（流式、Markdown、Skill、上下文引用）不变。

### 7.3 AI 上下文感知触发规则

| 场景 | 触发条件 | AI 行为 | 去抖时间 | 静默条件 |
|------|---------|---------|---------|---------|
| S1 | 页面加载完成 + 停留 >5s | 生成页面摘要到右侧面板 | 2s after load | 页面 <200 字 |
| S2 | 编辑器输入暂停 | 检测未链接概念 → 底部建议栏 | 1.5s after last keystroke | 用户正在快速输入 |
| S2 | 编辑器选中文本 | 浮动菜单出现 | 选中后 300ms | 已选 <5 字符 |
| S3 | 选中图谱节点 | 生成关系解释到右侧面板 | 选中后 500ms | 节点无出链/入链 |

---

## 8. 视觉语言系统

### 8.1 设计 Token

```yaml
# design_tokens.yaml (新建文件，将被 AppTheme 引用)
colors:
  brand:
    primary: '#6366F1'        # 靛蓝色 (Indigo) — 智慧与科技感
    primary_light: '#818CF8'
    primary_dark: '#4F46E5'
    secondary: '#10B981'      # 翠绿色 — 成长与连接
    secondary_light: '#34D399'
  
  scene:
    capture_bg: '#0F172A'     # 深蓝 — 浏览/探索
    think_bg: '#1A1A2E'       # 深紫蓝 — 专注/思考
    connect_bg: '#0D1117'     # 极深灰 — 沉浸/连接
  
  semantic:
    success: '#10B981'
    warning: '#F59E0B'
    error: '#EF4444'
    info: '#3B82F6'
    
  text:
    primary: '#E2E8F0'
    secondary: '#CBD5E1'
    muted: '#64748B'
    inverse: '#0F172A'

typography:
  display:
    family: 'Inter'
    size: 28
    weight: 700
    letter_spacing: -0.5
  heading:
    family: 'Inter'
    size: 20
    weight: 600
    letter_spacing: -0.3
  body:
    family: 'Inter'
    size: 14
    weight: 400
    line_height: 1.6
  code:
    family: 'JetBrains Mono'
    size: 13

spacing:
  xs: 4
  sm: 8
  md: 12
  lg: 16
  xl: 24
  xxl: 32

radius:
  sm: 6
  md: 8
  lg: 12
  xl: 16
  full: 999

shadow:
  float: '0 8px 32px rgba(0,0,0,0.3)'
  dialog: '0 16px 48px rgba(0,0,0,0.4)'
  card: '0 2px 8px rgba(0,0,0,0.15)'
```

### 8.2 场景差异化配色

每个场景的 AppBar/背景有微妙区分，让用户潜意识感知当前模式：

| 场景 | 主色调 | 背景色 | 强调色 | 氛围 |
|------|--------|--------|--------|------|
| S1 捕捉 | 暖蓝 | `#0F172A` | Primary | 探索的兴奋 |
| S2 思考 | 暖灰 | `#1A1A2E` | Secondary | 专注的宁静 |
| S3 连接 | 深黑 | `#0D1117` | Primary | 深空的神秘 |

### 8.3 图标系统

- 场景图标: 使用 `Icons` 中表达力强的图标
  - S1 捕捉: `Icons.explore` (探索)
  - S2 思考: `Icons.edit_note` (笔记编辑) 
  - S3 连接: `Icons.hub` (枢纽)
- AI Float: `Icons.psychology` (心理学/智能)
- 所有图标尺寸: 状态栏 14px, 工具栏 16px, 场景图标 20px

---

## 9. 交互动效规格

### 9.1 动效时间表

| 动效 | 时长 | 曲线 | 说明 |
|------|------|------|------|
| 场景切换 | 300ms | easeInOut | 旧的 fadeOut + 新的 fadeIn |
| 面板滑入/滑出 | 200ms | easeOut/easeIn | 侧边面板 |
| AI Float 展开 | 250ms | easeOutBack | 带轻微弹性 |
| 剪辑成功 | 200ms | easeOut | 按钮短暂变绿 |
| 节点脉动 | 2000ms | easeInOut 循环 | 图谱选中节点 |
| Toast 出现/消失 | 300ms/200ms | easeOut/easeIn | 底部通知 |
| AI 建议滑入 | 300ms | easeOut | 编辑器底部 |

### 9.2 关键动效实现要求

**场景切换动效 (SceneTransition)**:
- 使用 `AnimatedSwitcher` 或自定义 `PageTransitionSwitcher`
- 旧场景: opacity 1→0, translateY 0→-8 (300ms)
- 新场景: opacity 0→1, translateY 8→0 (300ms)
- 两者同时进行（cross-fade + vertical slide）

**AI Float 展开动效**:
- 使用 `AnimationController` + `ScaleTransition` + `FadeTransition`
- scale: 0.0→1.0 (锚定右下角)
- 弹性系数: `Curves.elasticOut` 或自定义 cubic-bezier(0.34, 1.56, 0.64, 1)
- 展开高度: 由 48px → 480px

**剪辑成功反馈**:
- 按钮背景: normal → 绿色 (Color(0xFF10B981)) → normal
- 使用 `AnimationController` 0→1 在 200ms 内
- 同时触发: 笔记列表中新笔记项的短期高亮（黄色闪烁 2 次）

---

## 10. 可验证标准

以下标准可直接转换为自动化测试或人工验收清单：

### AC-ARCH-1: 场景导航架构

```
Given: 用户在任意场景下
When:  按下 Ctrl+1
Then:  
  - 主导视图切换为 BrowserView
  - 左侧面板（如展开）保持展开状态
  - AI Float 位置不变
  - 场景切换器中的 "📖 捕捉" 标签高亮
  - 上一个场景的状态（滚动位置、选中笔记）被保留
  - 整个切换过程 ≤350ms
  - 无 jank（通过 Flutter performance overlay 验证）
```

```
Given: 用户在任意场景下
When:  按下 Ctrl+2
Then:
  - 主导视图切换为 EditorView
  - 若当前有活跃笔记，EditorView 显示其内容
  - 若当前无活跃笔记，EditorView 显示 "选择一条笔记" 的引导状态
  - 右侧面板显示反向链接和 AI 建议
```

```
Given: 用户在任意场景下
When:  按下 Ctrl+3
Then:
  - 主导视图切换为 GraphView（默认）或 CanvasView（若上次 S3 使用 Canvas）
  - 左侧面板切换为筛选面板
  - 右侧面板显示 "点击节点查看详情" 提示或上次选中的节点详情
```

### AC-SCENE-1: 捕捉场景 — 剪辑功能

```
Given: 用户在 S1 捕捉场景，BrowserView 加载了任意网页
When:  点击 ClipToolbar 中的 "📎 剪辑全文" 按钮
Then:
  - 按钮变为绿色 (#10B981) 并持续 200ms
  - 200ms 内出现底部 toast: "已保存到知识库 · [笔记标题]"
  - toast 在 3s 后自动消失
  - 笔记列表中出现新笔记（标题 = 网页标题，内容 = 网页正文 Markdown）
  - 新笔记在笔记列表中闪烁高亮（黄色背景，2 次闪烁，每次 400ms）
  - knowledgeState.notes.length 增加 1
  - 新笔记的 sourceUrl 字段等于当前浏览器 URL
  
Edge Cases:
  - 若剪辑失败: 按钮变为红色 (#EF4444) 200ms, toast "剪辑失败: [原因]"
  - 若当前无网络: 按钮可点击但 toast "离线模式，已保存本地草稿"
  - 若页面内容 >10MB: toast "内容过大，仅保存前 10MB"
```

```
Given: 用户在 S1 捕捉场景，已选中网页中的一段文字
When:  点击 ClipToolbar 中的 "✂️ 剪辑选中" 按钮
Then:
  - 创建的笔记内容 = 选中的原始文本
  - 笔记标题 = 网页标题 + " · 片段"
  - 其余行为同 "剪辑全文"

Given: 用户在 S1 捕捉场景，未选中任何文字
When:  查看 "✂️ 剪辑选中" 按钮
Then:
  - 按钮显示为置灰状态（opacity 0.4）
  - 按钮不可点击（onPressed: null）
```

```
Given: 用户在 S1 捕捉场景
When:  点击 ClipToolbar 中的 "🔖 书签" 按钮
Then:
  - 创建的笔记内容 = "# [网页标题]\n\n> Source: [网页标题](网页URL)\n"
  - 笔记标题 = 网页标题
  - 行为同剪辑全文的成功反馈
```

### AC-SCENE-2: 思考场景 — AI 内联建议

```
Given: 用户在 S2 思考场景，正在编辑笔记
When:  输入包含已知笔记标题的文本（如输入 "认知负荷" 且存在笔记 "认知心理学导论"）,
      然后停止输入 1.5s
Then:
  - 编辑器底部出现 AI 内联建议栏
  - 建议栏高度 ≤80px
  - 建议栏内容: "💡 AI: 你提到了'认知负荷'，是否链接到 [[认知心理学导论]]？"
  - 建议栏包含 2-3 个操作按钮: [链接] [展开] [忽略]
  - 建议栏从底部滑入，动画 300ms ease-out
  - 编辑器视口自动上移（不遮挡正在编辑的行）

Given: 用户看到 AI 内联建议
When:  点击 [链接] 按钮
Then:
  - 当前光标位置插入 "[[认知心理学导论]]"
  - 建议栏 200ms 滑出消失
  - 插入后光标移到 ]] 之后
  
Given: 用户看到 AI 内联建议
When:  点击 [忽略] 按钮
Then:
  - 建议栏 200ms 滑出消失
  - 同一编辑会话中不再对同一对 (输入词, 建议笔记) 提出建议
  - 忽略记录在内存中（不持久化）

Given: 用户看到 AI 内联建议
When:  点击 [展开] 按钮
Then:
  - AI Float 展开
  - AI Float 中预填充上下文消息: "关于'认知负荷'和[[认知心理学导论]]的关系..."
  - 建议栏 200ms 滑出消失
```

```
Given: 用户在 S2 思考场景，输入了 "[["
When:  输入 [[ 后的 100ms 内
Then:
  - 光标下方出现笔记搜索弹出框
  - 弹出框复用 CommandBar 的 hybrid search 逻辑
  - 弹出框宽度 = 300px
  - 弹出框最多显示 8 条结果
  - 输入更多字符时实时过滤
  
Given: wikilink 弹出框可见
When:  用户选中一条笔记
Then:
  - 插入完整的 [[笔记标题]]
  - 弹出框消失
  - 光标移到 ]] 之后
```

### AC-SCENE-3: 连接场景 — 图谱交互

```
Given: 用户在 S3 连接场景，图谱中有 ≥3 个节点
When:  单击一个节点
Then:
  - 该节点开始 2s 周期呼吸式缩放动画（1.0 → 1.08 → 1.0）
  - 连接到该节点的边高亮（颜色变亮 20%）
  - 右侧节点详情面板 200ms 滑入，显示节点信息
  - 面板内容: 笔记标题 + 标签列表 + 出链/入链数量
  - AI 在经过 500ms 后开始生成关系解释（若节点有 ≥1 条出/入链接）
  - AI 关系解释格式: "此笔记通过 [链接类型] 与以下笔记关联: ..."
  
Given: 用户在图谱中选中了节点 A
When:  再次单击同一节点 A
Then:
  - 节点取消选中
  - 脉动动画停止
  - 边高亮恢复
  - 右侧面板恢复为 "点击节点查看详情"

Given: 用户在图谱中选中了节点 A
When:  双击节点 A
Then:
  - 应用切换到 S2 思考场景
  - EditorView 打开节点 A 对应的笔记
  - 场景切换动画 300ms

Given: 用户在图谱中选中了节点 A
When:  右键点击节点 A → 选择 "设为中心"
Then:
  - 图谱切换到 local graph 模式
  - 中心节点 = A
  - 深度默认 = 2
  - 仅显示与 A 距离 ≤2 的节点和边
```

```
Given: 用户在 S3 连接场景，Canvas 子模式
When:  在画布上拖拽卡片
Then:
  - 遵守 P-1 约束: 在内存中更新位置，不写磁盘
  - 拖拽结束 (onScaleEnd) 后调用 canvasProvider.notifier.persist()
  - persist() 通过 debounced save (500ms) 写入 .json 文件
  - 自动连线 (isAuto: true) 与手动连线视觉区分:
    - 自动连线: 虚线, opacity 0.4, 颜色 muted
    - 手动连线: 实线, opacity 0.8, 颜色 primary
```

### AC-AI-1: AI Float 行为

```
Given: 用户在任意场景
When:  查看右下角
Then:
  - AI Float 按钮始终可见（48×48px，右下角距边缘 16px）
  - AI Float 按钮有 z-index 最高，不被任何内容遮挡
  - 按钮为圆形，包含 🤖 图标
  - 按钮有微弱阴影（0 4px 12px rgba(0,0,0,0.2)）

Given: 用户在任意场景，AI Float 处于折叠态
When:  点击 AI Float 按钮
Then:
  - AI Float 展开为 360×480px 的对话面板
  - 展开动画: 250ms, anchored at 右下角
  - 面板包含: 顶部标题栏 + 消息列表 + 底部输入栏
  - 面板复用现有 AIChatPanel 的所有功能
  - 面板顶部有关闭按钮 [−] 和展开为全屏按钮 [□]
  - 面板出现时, 若输入框 autoFocus → 自动聚焦
  
Given: 用户在任意场景，AI Float 处于展开态
When:  点击面板外的任意区域
Then:
  - AI Float 折叠为圆形按钮
  - 折叠动画: 200ms easeIn
  - AI 对话历史保留

Given: 用户在任意场景，AI Float 处于展开态
When:  按下 Escape 键
Then:
  - AI Float 折叠（同点击外部区域的行为）
```

### AC-AI-2: AI Float 上下文感知

```
Given: 用户在 S1 捕捉场景，AI Float 被打开
When:  AI Float 的输入框获得焦点
Then:
  - 输入框 placeholder: "基于当前页面 [页面标题] 提问..."
  - 若用户未输入任何内容直接发送，默认行为: AI 生成当前页面摘要
  - @ 自动补全 默认包含 @web[current]

Given: 用户在 S2 思考场景，正在编辑笔记 X，AI Float 被打开
When:  AI Float 的输入框获得焦点
Then:
  - 输入框 placeholder: "基于笔记 [X 标题] 提问..."
  - @ 自动补全 默认包含 @note[X 标题]
  
Given: 用户在 S3 连接场景，选中了节点 Y，AI Float 被打开
When:  AI Float 的输入框获得焦点
Then:
  - 输入框 placeholder: "关于 [Y 标题] 的问题..."
  - @ 自动补全 默认包含 @note[Y 标题]
```

### AC-SEARCH-1: 全局搜索双层设计

```
Given: 用户在任意场景
When:  查看底部状态栏
Then:
  - 状态栏右侧存在一个搜索输入区域
  - 显示 🔍 图标 + "搜索笔记..." 占位文字
  - 宽度: 200px
  - 点击后变为可输入状态

Given: 用户在 Quick Search 中输入 ≥2 个字符
When:  输入后 300ms
Then:
  - 搜索结果下拉列表出现
  - 最多显示 5 条结果
  - 结果仅匹配笔记标题（fuzzy match）
  - 每条结果: 标题 + 最近修改日期
  - 选中结果: 切换到 S2 场景并打开笔记

Given: 用户在 Quick Search 中
When:  按下 Ctrl+K
Then:
  - Quick Search 关闭
  - 全屏 CommandBar (Command Palette) 打开
  - CommandBar 预填充 Quick Search 的查询文本
  - CommandBar 保留所有现有功能（混合搜索、命令、Quick Move）
```

### AC-VISUAL-1: 视觉 Token 一致性

```
Given: 设计 token 文件 `lib/ui/theme/design_tokens.dart` 存在
When:  检查 AppTheme 中的所有颜色引用
Then:
  - 所有颜色值通过设计 token 常量引用（不允许硬编码颜色值）
  - primary, secondary 颜色来源为 design_tokens
  - 间距值 xs/sm/md/lg/xl/xxl 通过 token 常量引用
  - 圆角值 sm/md/lg/xl/full 通过 token 常量引用
  - 字体大小通过 token 常量引用
```

### AC-EMPTY-1: 空状态引导 (UX-2 合规)

```
Given: 用户刚创建/打开 Vault，知识库为空
When:  进入主界面
Then:
  - 不显示 4 个空面板
  - 显示全屏引导视图:
    - 顶部: "从你的第一条信息开始" (大字标题)
    - 中间: 一个简洁的输入框 + 两个选项:
      - [粘贴网页链接 →]
      - [写一条笔记 ✍️]
    - 底部: 使用提示 (3 条简短 tip 轮播)
  - 粘贴链接后: AI 自动剪辑, 创建笔记, 切换到 S2 思考场景展示结果
  - 写笔记后: 直接切换到 S2 思考场景

Given: 用户在 S1 捕捉场景，浏览器未加载任何页面
When:  查看主导视图
Then:
  - 显示: 搜索栏样式输入框 "输入网址或搜索..."
  - 下方: 快速链接网格（常用网站 4-6 个）
  - 不显示空的 ClipToolbar（或显示为置灰状态）

Given: 用户在 S2 思考场景，知识库有笔记但未选中任何笔记
When:  查看主导视图  
Then:
  - 显示引导: "选择一条笔记开始编辑" + 笔记列表预览（最近 5 条笔记卡片）
  - CTA: "新建笔记" 按钮
```

### AC-PERF-1: 性能约束 (P-1 合规)

```
Given: 用户在 S1 捕捉场景中剪辑网页
When:  剪辑操作执行中
Then:
  - UI 线程不被阻塞（保持 60fps）
  - 剪辑使用异步操作（Future/isolate 处理大页面）
  - 剪辑期间显示加载指示器（按钮内 spinner 或线性进度条）

Given: 用户在 S3 连接场景，Canvas 中拖拽卡片
When:  拖拽过程中
Then:
  - 位置更新仅在内存中（不调用 persist）
  - 拖拽结束 (onScaleEnd) 后才调用 canvasProvider.notifier.persist()
  - persist() 使用 debounced save (500ms)
  - shouldRepaint 比较实际数据变化
```

---

## 附录 A: 文件变更清单

| 操作 | 文件 | 说明 |
|------|------|------|
| ✅ 保留 | `lib/ui/pages/ai_chat_panel.dart` | AI Chat 功能完整保留，改变容器 |
| ✅ 保留 | `lib/ui/pages/editor_page.dart` | 编辑器完整保留 |
| ✅ 保留 | `lib/ui/pages/browser_page.dart` | 浏览器完整保留 |
| ✅ 保留 | `lib/ui/pages/graph_page.dart` | 图谱完整保留 |
| ✅ 保留 | `lib/ui/pages/canvas_page.dart` | 画布完整保留 |
| ✅ 保留 | `lib/ui/pages/welcome_page.dart` | 欢迎页基本保留 |
| ✅ 保留 | `lib/ui/widgets/command_bar.dart` | 命令条完整保留 |
| ✅ 保留 | `lib/ui/widgets/note_sidebar.dart` | 笔记侧边栏完整保留 |
| ✅ 保留 | `lib/ui/widgets/split_pane.dart` | SplitPane 可能简化但保留 |
| 🔧 重构 | `lib/ui/layout/main_layout.dart` | 核心重构: 场景模型替代面板模型 |
| 🆕 新建 | `lib/ui/layout/scene_scaffold.dart` | 场景外壳组件 |
| 🆕 新建 | `lib/ui/layout/scene_switcher.dart` | 场景切换器组件 |
| 🆕 新建 | `lib/ui/widgets/ai_float.dart` | AI 浮动助手组件 |
| 🆕 新建 | `lib/ui/widgets/clip_toolbar.dart` | 剪辑工具栏组件 |
| 🆕 新建 | `lib/ui/widgets/ai_inline_suggestion.dart` | AI 内联建议组件 |
| 🆕 新建 | `lib/ui/widgets/quick_search_bar.dart` | 状态栏全局搜索 |
| 🆕 新建 | `lib/ui/theme/design_tokens.dart` | 设计 token 定义 |
| 🔧 修改 | `lib/ui/theme/app_theme.dart` | 引用设计 token |
| 🆕 新建 | `lib/ui/pages/empty_vault_guide.dart` | Vault 空状态引导页 |
| 🆕 新建 | `test/ui/scene_navigation_test.dart` | 场景导航测试 |
| 🆕 新建 | `test/ui/ai_float_test.dart` | AI Float 行为测试 |
| 🆕 新建 | `test/ui/clip_toolbar_test.dart` | 剪辑工具栏测试 |

---

## 附录 B: 向后兼容保证

1. 所有现有快捷键不变
2. 所有现有数据格式不变（Note、Link、CanvasData）
3. 所有现有 Provider 接口不变
4. 所有现有服务方法签名不变
5. 现有设置保留（新增的设置项有合理默认值）
6. 现有主题系统可切换（新旧两种布局可选，通过设置开关）
