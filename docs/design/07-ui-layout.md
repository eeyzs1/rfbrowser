# RFBrowser — UI 布局设计

---

## 主窗口布局（桌面端）

```
┌──────────────────────────────────────────────────────────────────┐
│  Menu Bar  │  Command Bar (Ctrl+K)                   │ AI Model │
├────────┬───────────────────────────────┬─────────────────────────┤
│        │                               │                         │
│  Tab   │     Main Content Area         │    Right Sidebar        │
│  Group │     (Split View)              │                         │
│  Bar   │  ┌─────────────┬────────────┐│  ┌─ AI Chat ──────────┐│
│        │  │             │            ││  │                     ││
│  ────  │  │  Browser    │  Editor    ││  │  Context: @note[x] ││
│  工作  │  │  View       │  View      ││  │  @web[current]     ││
│  ────  │  │             │            ││  │                     ││
│  学习  │  │             │            ││  │  [AI response...]   ││
│  ────  │  │             │            ││  │                     ││
│  研究  │  │             │            ││  ├─ Backlinks ────────┤│
│  ────  │  │             │            ││  │  ← [[相关笔记1]]    ││
│  阅读  │  │             │            ││  │  ← [[相关笔记2]]    ││
│        │  │             │            ││  ├─ Outline ──────────┤│
│  ────  │  │             │            ││  │  # 标题1            ││
│  收藏  │  │             │            ││  │  ## 标题2           ││
│        │  │             │            ││  └─────────────────────┘│
│        │  └─────────────┴────────────┘│                         │
├────────┴───────────────────────────────┴─────────────────────────┤
│  Status Bar  │  Agent Tasks: [2 running]  │  Sync: ✓ Git  │ LN │
└──────────────────────────────────────────────────────────────────┘
```

## 主窗口布局（Android 端）

```
┌──────────────────────┐
│  ≡  │ Title  │  AI   │  ← 顶部导航栏
├──────────────────────┤
│                      │
│  Current View        │  ← 单视图（浏览器/编辑器/图谱）
│  (Full Screen)       │
│                      │
│                      │
├──────────────────────┤
│ 🌐 │ 📝 │ 🕸️ │ 🤖 │  ← 底部导航栏
│浏览 │笔记 │图谱 │AI  │
└──────────────────────┘
```

---

## 视图模式

| 模式 | 说明 | 快捷键 |
|------|------|--------|
| **浏览器** | 全屏浏览器 | Ctrl+1 |
| **编辑器** | 全屏 Markdown 编辑器 | Ctrl+2 |
| **图谱** | 全屏知识图谱 | Ctrl+3 |
| **Canvas** | 无限画布 | Ctrl+4 |
| **双栏** | 浏览器 + 编辑器并排 | Ctrl+5 |
| **三栏** | 浏览器 + 编辑器 + AI Chat | Ctrl+6 |
| **专注** | 隐藏所有侧栏，仅编辑器 | Ctrl+Shift+F |

---

## Command Bar（命令栏）

类似 VS Code 的 Command Palette，是核心交互入口：

- `Ctrl+K` 打开
- 支持模糊搜索命令、笔记、标签、Skills
- 支持 AI 自然语言输入（"帮我总结当前网页"）
- 支持快捷操作（"创建笔记"、"切换模型"、"执行 Skill"）

---

## 国际化（i18n）设计

### 方案

- 使用 Flutter 内置的 `intl` 包
- 语言文件格式：ARB (Application Resource Bundle)
- 支持运行时切换语言，无需重启

### 文件结构

```
lib/
  l10n/
    app_en.arb      # 英文
    app_zh.arb      # 中文
    app_zh_CN.arb   # 简体中文
```

### 切换机制

```dart
MaterialApp(
  locale: userPreferredLocale,  // 从设置中读取
  localizationsDelegates: [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ],
  supportedLocales: [
    Locale('en'),
    Locale('zh'),
  ],
);
```
