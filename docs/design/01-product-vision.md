# RFBrowser — 产品愿景与关键决策

> **RFBrowser**: 融合浏览（Browse）与知识流（Flow），让信息在获取与组织之间自由流动

---

## 一、产品愿景

### 核心命题

> 人在信息时代如何高效地**获取、组织、关联和自动化处理**知识？

### 三源融合

| 来源 | 解决的问题 | 我们吸收的核心 |
|------|-----------|---------------|
| **Tabbit** | 获取 + 自动化 | AI Agent、上下文引用、Skills、智能标签分组 |
| **Foam** | 组织 + 开放性 | 纯 Markdown、Git 集成、零锁定、开发者友好 |
| **Obsidian** | 关联 + 扩展性 | 双向链接、图谱视图、Canvas、插件生态、Dataview |

### 终极形态

**一个本地优先的 AI 增强知识工作台**——既能像浏览器一样获取信息，又能像 Obsidian 一样组织和关联知识，还能像 Tabbit 一样用 AI 自动化工作流，同时保持 Foam 的开放标准。

### 核心差异化（别人做不到的）

1. **上下文桥（Context Bridge）** — 浏览器与知识库之间的无缝上下文共享。你可以在笔记中 @引用 一个网页，也可以在浏览时 @引用 一条笔记
2. **知识感知 Agent** — Agent 不只是浏览网页，它还能创建笔记、建立链接、自动组织信息
3. **实时图谱** — 图谱在你浏览和保存信息时实时更新
4. **Skill + Plugin 融合** — Skill 可以调用 Plugin，Plugin 可以定义新 Skill
5. **双栏工作流** — 浏览器和编辑器并排，支持拖拽互操作

---

## 二、关键决策记录 (ADR)

| 决策项 | 选择 | 理由 |
|--------|------|------|
| 产品定位 | 双核融合 | 浏览器与知识管理完全融合，不分主次 |
| 技术框架 | Flutter | 三平台（Win/Android/Linux）成熟度最高 |
| AI 策略 | 云端为主 + 本地可选 | 功能优先，Ollama/llama.cpp 作为离线备选 |
| 数据格式 | 纯 Markdown + YAML frontmatter | 零锁定，兼容 Obsidian/Foam 生态 |
| 浏览器引擎 | 内嵌 Chromium（桌面）+ System WebView（Android） | 见下方详细说明 |
| 扩展系统 | 开放插件 + Skills + 模板 | 三者兼备，最大化生态和灵活性 |
| 同步策略 | Git + WebDAV | 去中心化，无服务器成本 |
| UI 语言 | 可切换中英双语 | — |

### 浏览器引擎方案说明

| 平台 | 引擎 | 说明 |
|------|------|------|
| Windows | WebView2 (Chromium) | 系统自带，Chromium 内核 |
| Android | System WebView (Chromium) | 大多数设备基于 Chromium |
| Linux | WebKitGTK / WPE WebKit | 非 Chromium，但功能完整；可选 CEF 后端 |

**技术选型**：使用 `flutter_inappwebview` 作为统一浏览器组件层：
- 支持 Inline WebView、Headless WebView、InApp Browser 三种模式
- Headless 模式用于 Agent 自动化（后台执行网页操作）
- Linux 端使用 WPE WebKit 后端（支持 GPU 纹理直传，性能优于 WebKitGTK）

**Agent 模式**：HeadlessInAppWebView 支持 Android/Windows，Linux 端通过 WPE WebKit 的 headless 模式实现。
