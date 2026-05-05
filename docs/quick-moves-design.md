# RFBrowser 轻型扩展系统 — 设计案

> 版本 1.0 | 2026-05-05 | 双轨架构 · 轻型轨道 Phase 1

---

## 1. 背景与目标

### 1.1 当前状态
RFBrowser 已具备浏览器核心能力（WebView 渲染、多标签管理、Agent 自动浏览），插件系统已实现重型 Sandbox（Dart Isolate + 权限白名单）。但缺少普通用户可即时触达的**轻量扩展入口**。

### 1.2 产品目标
让用户在 URL 栏输入 `/` 即可调用自定义的 AI 能力，无需离开当前页面、无需写代码。实现 Tabbit 式"妙招"体验的同时，保持 RFBrowser 重安全 Sandbox 的底线。

### 1.3 范围界定
本阶段仅实现**轻型轨道**的核心能力：
- 用户自定义命令（Quick Move）
- `/` 触发 + CommandBar 集成
- AI Prompt 模板 + 上下文绑定
- 持久化存储 + 跨设备云同步接口预留
- **不涉及**页面脚本注入、数据捕手（留待 Phase 2）

---

## 2. User Stories

### US-1: 创建我的第一条快捷命令
**作为** 日常用户
**我想要** 用自然语言创建一个自定义命令，比如"翻译这段文字为英文"
**以便于** 之后在任何页面上选中文字，输入 `/翻译` 就能立即获得结果

**验收标准**:
- `AC-1-1`: 用户在 CommandBar 输入 `/翻译 你好世界`，AI 返回英文翻译 "Hello World"
- `AC-1-2`: 第一次输入 `/翻译` 时，系统提示"命令不存在，是否创建？"
- `AC-1-3`: 确认创建后，弹出配置对话框，可设置名称、Prompt 模板、图标
- `AC-1-4`: 创建成功后命令立即可用，不需重启应用
- `AC-1-5`: Prompt 模板支持 `{input}` 占位符，代表 `/命令名` 之后的参数

### US-2: 浏览和使用已有命令
**作为** 日常用户
**我想要** 在 CommandBar 中看到所有可用的命令
**以便于** 快速选择并执行，不需要记住具体的命令名

**验收标准**:
- `AC-2-1`: 打开 CommandBar（Ctrl+K），输入 `/` 前缀，列表只显示 Quick Moves 类型的命令
- `AC-2-2`: 输入 `/翻`，列表过滤为名称包含"翻"的命令（模糊匹配）
- `AC-2-3`: 选中命令后，后面自动补充一个空格，等待用户输入参数
- `AC-2-4`: 命令按照最近使用时间排序

### US-3: 管理我的命令列表
**作为** 重度用户
**我想要** 编辑、删除、重新排序我已经创建的命令
**以便于** 保持命令列表整洁，优化常用工作流

**验收标准**:
- `AC-3-1`: 设置页面新增 "Quick Moves" 管理区段
- `AC-3-2`: 列表显示所有命令，每项包含图标、名称、Prompt 预览
- `AC-3-3`: 点击编辑可修改名称、Prompt 模板、图标、颜色
- `AC-3-4`: 滑动删除（或长按菜单删除），需确认
- `AC-3-5`: 删除后 CommandBar 搜索 `/` 不再出现该命令
- `AC-3-6`: 支持拖拽排序

### US-4: 使用预设命令模板
**作为** 新用户
**我想要** 在首次使用时就有一些预设的常用命令
**以便于** 不需要从头创建，降低使用门槛

**验收标准**:
- `AC-4-1`: 首次启动后，CommandBar `/` 列表包含 ≥5 个预设命令
- `AC-4-2`: 预设命令可被用户编辑和删除
- `AC-4-3`: 预设命令包含：翻译、总结页面、解释概念、生成邮件、修正语法
- `AC-4-4`: 可通过"恢复默认"按钮一键还原被删除的预设命令

### US-5: 上下文感知的 AI 响应
**作为** 日常用户
**我想要** 命令执行时自动携带当前网页/笔记的上下文
**以便于** AI 能基于我当前正在看的内容给出更精准的回答

**验收标准**:
- `AC-5-1`: 在浏览器页面执行 `/总结` 命令时，AI 收到当前页面内容作为上下文
- `AC-5-2`: 在编辑器页面执行 `/翻译` 时，AI 收到选中的文本（如有）或整个笔记内容
- `AC-5-3`: Prompt 支持 `{pageContent}` 和 `{selectedText}` 上下文占位符
- `AC-5-4`: 无可用上下文时不报错，仅提示"无页面上下文"

### US-6: 命令结果展示与后续操作
**作为** 日常用户
**我想要** 看到命令执行结果后能将其保存或者继续对话
**以便于** 产出物不会丢失，还能继续优化

**验收标准**:
- `AC-6-1`: 命令结果在 AI Chat Panel 中展示（流式输出）
- `AC-6-2`: 结果末尾有"保存为笔记"按钮
- `AC-6-3`: 保存后笔记自动关联源页面（如有 sourceUrl）
- `AC-6-4`: 保存后笔记出现在知识图谱中，可通过 backlinks 追溯

### US-7: 命令数据持久化
**作为** 长期用户
**我想要** 关闭并重新打开应用后，我创建的命令仍然存在
**以便于** 不需要重复创建

**验收标准**:
- `AC-7-1`: 创建命令后重启应用，CommandBar `/` 列表仍包含该命令
- `AC-7-2`: 删除命令后重启应用，该命令不再出现
- `AC-7-3`: 编辑命令后重启应用，修改保留
- `AC-7-4`: 命令数据存储格式可被导出/导入（JSON 格式）

---

## 3. 架构设计

### 3.1 组件关系图

```
┌─────────────────────────────────────────────────────────────────┐
│                        UI Layer                                   │
│                                                                   │
│  ┌──────────────┐    ┌───────────────┐    ┌──────────────────┐  │
│  │ CommandBar   │    │ Settings >    │    │ AI Chat Panel    │  │
│  │ (extended)   │    │ Quick Moves   │    │ (result display) │  │
│  │ / 触发解析   │    │ Management UI │    │ save-to-note     │  │
│  └──────┬───────┘    └───────┬───────┘    └────────┬─────────┘  │
│         │                    │                      │             │
├─────────┼────────────────────┼──────────────────────┼─────────────┤
│         │           State Layer                      │             │
│         │                                           │             │
│  ┌──────▼───────────────────────────────────────────▼──────────┐ │
│  │                 QuickMoveNotifier (new)                      │ │
│  │                 state: QuickMoveState                        │ │
│  │   ┌─────────────────────────────────────────────────────┐   │ │
│  │   │  List<QuickMove> moves                                │   │ │
│  │   │  Map<String, QuickMove> byId                          │   │ │
│  │   │                                                       │   │ │
│  │   │  + createMove(name, prompt, icon, color)              │   │ │
│  │   │  + updateMove(id, ...)                                │   │ │
│  │   │  + deleteMove(id)                                     │   │ │
│  │   │  + reorderMove(id, newIndex)                          │   │ │
│  │   │  + findMatch(prefix) → List<QuickMove>                │   │ │
│  │   │  + resolvePrompt(move, context) → String              │   │ │
│  │   │  + importFromJson(json)                               │   │ │
│  │   │  + exportToJson() → String                            │   │ │
│  │   └─────────────────────────────────────────────────────┘   │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  ┌──────────────────────────┐  ┌──────────────────────────────┐  │
│  │ QuickMoveContext (new)   │  │ QuickMoveStore (new)          │  │
│  │                          │  │ (persistence via SharedPrefs) │  │
│  │ currentUrl               │  │                               │  │
│  │ pageTitle                │  │ + load()                      │  │
│  │ pageContent              │  │ + save(QuickMoveState)        │  │
│  │ selectedText             │  │                               │  │
│  │ activeNoteContent        │  │                               │  │
│  └──────────────────────────┘  └──────────────────────────────┘  │
├───────────────────────────────────────────────────────────────────┤
│                        Service Layer                               │
│                                                                   │
│  ┌──────────────────┐  ┌──────────────────────────────────────┐  │
│  │ AINotifier       │  │ KnowledgeService                     │  │
│  │ (existing)       │  │ (existing)                            │  │
│  │ sendMessage()    │  │ createNote() / saveNote()            │  │
│  └──────────────────┘  └──────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────────────┘
```

### 3.2 数据模型

```dart
// lib/data/models/quick_move.dart

enum QuickMoveType { user, preset }

class QuickMove {
  final String id;           // UUID v4
  final String name;         // 命令名，如 "翻译" (不含 / 前缀)
  final String promptTemplate; // Prompt 模板，支持占位符
  final IconData icon;       // Material icon codePoint
  final int colorValue;      // ARGB32 int
  final QuickMoveType type;  // user | preset
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastUsedAt;
  final int useCount;

  // 占位符:
  // {input}         → 用户输入的参数
  // {pageContent}   → 当前 WebView 页面文本 (截断至 8000 字)
  // {selectedText}  → 用户选中的文本
  // {pageUrl}       → 当前页面 URL
  // {noteContent}   → 当前编辑器笔记内容
}

class QuickMoveState {
  final List<QuickMove> moves;    // 按 displayOrder 排序
  final Map<String, QuickMove> byId;

  // 派生属性
  List<QuickMove> get byLastUsed =>
      [...moves]..sort((a, b) => (b.lastUsedAt ?? b.createdAt)
          .compareTo(a.lastUsedAt ?? a.createdAt));

  List<QuickMove> matching(String prefix) => moves
      .where((m) => m.name.toLowerCase().contains(prefix.toLowerCase()))
      .toList();
}

class QuickMoveContext {
  final String? currentUrl;
  final String? pageTitle;
  final String? pageContent;
  final String? selectedText;
  final String? noteContent;
}
```

### 3.3 占位符解析规则

| 占位符 | 来源 | 最大长度 | 缺值行为 |
|--------|------|----------|----------|
| `{input}` | CommandBar 输入 `/命令名` 之后的文本 | 无限制 | 传空字符串 |
| `{pageContent}` | `BrowserPage` 当前 WebView 页面文本 | 8000 字符 | 提示"无页面上下文" |
| `{selectedText}` | 当前聚焦区域的选中文本 | 4000 字符 | 提示"请先选中文本" |
| `{pageUrl}` | `BrowserState.activeTab.url` | 无限制 | 传空字符串 |
| `{noteContent}` | `EditorPage` 当前笔记内容 | 8000 字符 | 提示"无笔记上下文" |

### 3.4 预设命令清单

| name | promptTemplate | icon | color |
|------|---------------|------|-------|
| 翻译 | "Translate the following text to English. Only return the translation, no explanations:\n\n{input}" | translate | slate |
| 总结 | "Summarize the following content in 3 bullet points:\n\n{input}" | summarize | sky |
| 解释 | "Explain the following concept in simple terms:\n\n{input}" | psychology | violet |
| 邮件 | "Write a professional email based on the following context:\n\n{input}" | mail | emerald |
| 语法 | "Fix grammar and spelling errors in the following text. Only return the corrected version:\n\n{input}" | spellcheck | amber |

### 3.5 命令执行流程

```
用户输入 "/翻译 Hello World" + Enter
          │
          ▼
┌──────────────────────┐
│ CommandBar 解析输入   │
│ prefix = "/"          │
│ commandName = "翻译"  │
│ input = "Hello World" │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ QuickMoveNotifier    │
│ .findMatch("翻译")    │
│ → 返回 QuickMove     │  若未找到 → "命令不存在，是否创建？"
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ 记录 useCount++       │
│ lastUsedAt = now      │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────────────┐
│ buildContext()               │
│ 收集: currentUrl,             │
│       pageContent,            │
│       selectedText, etc.     │
└──────────┬───────────────────┘
           │
           ▼
┌──────────────────────┐
│ resolvePrompt()       │
│ 占位符替换:            │
│ {input} → Hello World │
│ {pageContent} → ...   │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ AINotifier            │
│ .sendStreamingMessage │
│ (resolvedPrompt)      │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ AI Chat Panel         │
│ (流式展示结果)         │
│ [+ 保存为笔记按钮]     │
└──────────────────────┘
```

---

## 4. 测试矩阵

### 4.1 单元测试

| 测试类 | 测试用例 | 验证目标 |
|--------|----------|----------|
| `QuickMove.resolvePrompt` | 全部占位符正常替换 | 模板解析正确性 |
| `QuickMove.resolvePrompt` | 占位符缺值时不抛异常 | 容错性 |
| `QuickMove.resolvePrompt` | 模板中不包含占位符 | 原文原样返回 |
| `QuickMoveState.matching` | 空字符串返回全部 | 过滤逻辑 |
| `QuickMoveState.matching` | 部分匹配 | 模糊搜索 |
| `QuickMoveState.matching` | 无匹配返回空列表 | 边界情况 |
| `QuickMove.fromJson / toJson` | 完整 round-trip | 序列化正确性 |
| `QuickMoveNotifier.createMove` | 正常创建 | 状态变更 |
| `QuickMoveNotifier.createMove` | 重名创建 | 拒绝或自动追加后缀 |
| `QuickMoveNotifier.deleteMove` | 删除 preset 命令 | 应成功（用户可删除预设） |
| `QuickMoveNotifier.restoreDefaults` | 恢复已删除的 preset | 重新生成 |
| `QuickMoveNotifier.restoreDefaults` | 已有同名 preset | 不重复创建 |
| `QuickMoveStore.save / load` | 持久化 round-trip | 数据一致性 |

### 4.2 Widget 测试

| 测试文件 | 测试用例 | 验证目标 |
|----------|----------|----------|
| `command_bar_quick_moves_test.dart` | 输入 `/` 显示 Quick Move 列表 | UI 渲染 |
| `command_bar_quick_moves_test.dart` | 输入 `/翻` 过滤列表 | 过滤 UI |
| `command_bar_quick_moves_test.dart` | 选中命令自动带空格 | 交互行为 |
| `command_bar_quick_moves_test.dart` | 不存在的命令 → 创建提示 | 新命令创建流程 |
| `quick_moves_settings_test.dart` | 管理列表渲染 | 设置 UI |
| `quick_moves_settings_test.dart` | 删除按钮 → 确认弹窗 | 删除安全 |
| `quick_moves_settings_test.dart` | 拖拽排序 | 排序持久化 |

### 4.3 集成测试

| 测试文件 | 测试用例 | 验证目标 |
|----------|----------|----------|
| `quick_moves_integration_test.dart` | UI-1: `/翻译 Hello` → AI Chat Panel 显示翻译 | 端到端链路 |
| `quick_moves_integration_test.dart` | UI-2: 创建命令 → 重启 → 命令仍存在 | 持久化 |
| `quick_moves_integration_test.dart` | UI-3: 结果 "保存为笔记" → 笔记列表出现 | 与 KnowledgeService 集成 |
| `quick_moves_integration_test.dart` | UI-4: 浏览器页面执行 `/总结` → 携带 pageContent | 上下文注入 |
| `quick_moves_integration_test.dart` | UI-5: 编辑器页面输入 `/语法` → 携带 selectedText | 上下文注入 |
| `quick_moves_integration_test.dart` | UI-6: 无上下文执行 `/总结` → 提示无上下文但不崩溃 | 容错 |

---

## 5. 验收决策树

以下验收标准可在 CI 中自动执行：

```
1. Preset Initialization
   └─ assert: QuickMoveState.initializeDefaults().moves.length >= 5
   └─ assert: default move IDs are unique
   └─ assert: all preset promptTemplates contain at least {input}

2. CRUD Operations
   └─ create: moves.length increases by 1, byId contains new id
   └─ update: byId[id].name == newName, updatedAt > createdAt
   └─ delete: byId does not contain id, moves.length decreased by 1

3. Search & Match
   └─ matching("") returns all moves
   └─ matching("trans") returns moves with "trans" in name (case-insensitive)
   └─ matching("nonexistent") returns empty list

4. Prompt Resolution
   └─ template "{input}" + args {"input": "hello"} → "hello"
   └─ template "No placeholders" + args {} → "No placeholders"
   └─ template "{input} {missing}" + args {"input": "hi"} → "hi "  (no crash)
   └─ template "{input}{input}" + args {"input": "x"} → "xx"

5. Persistence
   └─ save(state) → load() → deep equality with original
   └─ save(empty) → load() → moves is empty, not null
   └─ corrupt JSON → load() → returns default state, logs warning

6. Import / Export
   └─ exportToJson → valid JSON string
   └─ importFromJson(exportToJson(s)) → deep equality with original
   └─ importFromJson(invalid_json) → returns false, state unchanged
```

---

## 6. 留给 Phase 2 的能力

以下能力**故意不在本阶段实现**，避免范围膨胀：

| 能力 | 为什么不现在做 |
|------|---------------|
| 页面脚本注入（自然语言→JS） | 需要 WebView JS bridge + 安全审查 |
| 数据捕手（提取表格→结构化数据） | 依赖页面脚本注入能力 |
| 妙招市场 / 分享链接 | 需要后端服务 + 社区运营 |
| 跨设备云同步 | 依赖 WebDAV/云同步基础设施就绪 |
| 命令执行宏链（A→B→C） | 需要 DAG 编排引擎 |
