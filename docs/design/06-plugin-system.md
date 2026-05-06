# RFBrowser — 插件系统设计

---

## 插件架构

```
┌─────────────────────────────────────┐
│           Plugin Host               │
│  ┌─────────────────────────────┐    │
│  │      Plugin Sandbox         │    │
│  │  ┌───────┐  ┌───────┐      │    │
│  │  │Plugin │  │Plugin │      │    │
│  │  │  A    │  │  B    │      │    │
│  │  └───┬───┘  └───┬───┘      │    │
│  │      │          │          │    │
│  │      ▼          ▼          │    │
│  │  ┌─────────────────────┐   │    │
│  │  │   Plugin API Bridge │   │    │
│  │  └─────────┬───────────┘   │    │
│  └────────────┼───────────────┘    │
│               │                    │
│               ▼                    │
│  ┌─────────────────────────────┐   │
│  │      Core API Surface       │   │
│  │  Knowledge | Browser | AI   │   │
│  │  Agent | UI | FileSystem    │   │
│  └─────────────────────────────┘   │
└─────────────────────────────────────┘
```

---

## 插件清单（manifest.yaml）

```yaml
id: com.rfbrowser.dataview
name: Dataview
version: 1.0.0
author: RFBrowser Community
description: SQL-like queries on your notes
minAppVersion: 0.1.0

permissions:
  - knowledge.read
  - knowledge.query
  - ui.panel
  - ui.command

skills:
  - id: dataview-query
    name: Query Notes
    description: Run a Dataview query
    params:
      - name: query
        type: string
        description: Dataview DQL query
        required: true

commands:
  - id: dataview-refresh
    name: Refresh Queries
    shortcut: "Ctrl+Shift+R"

settings:
  - id: enable-javascript-queries
    name: Enable JavaScript Queries
    type: boolean
    default: false

hooks:
  - event: note.opened
    handler: onNoteOpened
  - event: note.saved
    handler: onNoteSaved
```

---

## 插件 API Surface

```dart
abstract class RFBrowserPluginAPI {
  // 知识 API
  KnowledgeAPI get knowledge;
  // 浏览器 API
  BrowserAPI get browser;
  // AI API
  AIAPI get ai;
  // Agent API
  AgentAPI get agent;
  // UI API
  UIAPI get ui;
  // 文件系统 API
  FileSystemAPI get fs;
  // 设置 API
  SettingsAPI get settings;
}

// 示例：Knowledge API
abstract class KnowledgeAPI {
  Future<Note> getNote(String id);
  Future<List<Note>> queryNotes(QuerySpec spec);
  Future<List<Note>> searchNotes(String query);
  Future<Note> createNote(CreateNoteSpec spec);
  Future<void> updateNote(String id, String content);
  Stream<NoteEvent> onNoteChange();
}
```

---

## 插件沙箱

- **语言**：插件使用 Dart AOT 编译为独立 isolate，或使用 JavaScript（QuickJS 引擎）
- **权限**：基于 manifest.yaml 声明的权限，运行时检查
- **隔离**：每个插件运行在独立 isolate 中，通过 API Bridge 通信
- **资源限制**：CPU 时间和内存配额，防止恶意插件

---

## Skill 系统

Skill 是用户可自定义的"一键命令"，可以：
- 由用户手动创建（录制操作序列或编写提示词模板）
- 由插件提供（插件 manifest 中声明 skills）
- 由 AI 建议（基于用户行为模式自动推荐）

```yaml
# 内置 Skill 示例
id: summarize-page
name: 总结网页
description: 总结当前打开的网页内容
prompt: |
  请总结以下网页内容，提取关键要点：
  @web[current]
params: []
trigger: command    # command | shortcut | auto
shortcut: "Ctrl+Shift+S"
```
