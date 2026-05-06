# RFBrowser — 核心数据模型

---

## 4.1 文件结构（Vault）

```
vault/
├── .rfbrowser/                 # 应用配置（类似 .obsidian）
│   ├── config.yaml             # 全局配置
│   ├── plugins/                # 已安装插件
│   ├── skills/                 # 用户定义的 Skills
│   ├── templates/              # 笔记模板
│   ├── themes/                 # 自定义主题
│   ├── cache/                  # 索引缓存（SQLite）
│   │   └── index.db            # 搜索索引 + 图谱数据
│   └── sync/                   # 同步状态
│       ├── git-state.yaml
│       └── webdav-state.yaml
├── daily-notes/                # 日记
│   └── 2026-05-01.md
├── clippings/                  # 网页剪藏
│   └── article-title-20260501.md
├── attachments/                # 附件（图片、PDF等）
│   └── image-20260501.png
└── (用户自定义目录结构)
    └── ...
```

## 4.2 Markdown 文件格式

```markdown
---
title: 量子计算入门
created: 2026-05-01T10:30:00Z
modified: 2026-05-01T11:00:00Z
tags: [量子计算, 物理, 前沿技术]
aliases: [Quantum Computing 101]
source: https://example.com/quantum-computing
source-title: 量子计算完全指南
source-captured: 2026-05-01T10:25:00Z
agent-task: research-quantum
---

# 量子计算入门

## 核心概念

量子计算利用[[量子叠加]]和[[量子纠缠]]进行计算...

## 相关资源

- 来自网页的摘录：@web[quantum-guide#section-2]
- 相关笔记：[[量子算法概述]]
```

## 4.3 核心实体模型

```dart
class Note {
  String id;                    // UUID
  String title;
  String filePath;              // 相对于 vault 的路径
  String content;               // Markdown 原文
  FrontMatter frontMatter;      // YAML 元数据
  List<String> tags;
  List<String> aliases;
  DateTime created;
  DateTime modified;
  String? sourceUrl;            // 来源网页 URL（剪藏）
  String? sourceTitle;          // 来源网页标题
  String? agentTaskId;          // 创建此笔记的 Agent 任务
}

class WebClip {
  String id;
  String url;
  String title;
  String content;               // 提取的正文（Markdown）
  String rawHtml;               // 原始 HTML（可选保存）
  List<String> selectedText;    // 用户划选的文本
  String? screenshot;           // 截图路径
  DateTime captured;
  String noteId;                // 关联的笔记 ID
}

class Link {
  String sourceId;              // 源笔记/网页 ID
  String targetId;              // 目标笔记/网页 ID
  LinkType type;                // wikilink | reference | embed | web-link
  String? context;              // 链接出现的上下文文本
  int? position;                // 链接在文档中的位置
}

class AgentTask {
  String id;
  String name;
  String description;
  TaskStatus status;            // pending | running | paused | completed | failed
  List<AgentStep> steps;        // 执行步骤
  Map<String, dynamic> context; // 任务上下文
  DateTime created;
  DateTime? completed;
  String? result;               // 任务结果
}

class Skill {
  String id;
  String name;
  String description;
  String prompt;                // Skill 的提示词模板
  Map<String, SkillParam> params; // 可配置参数
  String? pluginId;             // 来源插件（如果有）
  bool isBuiltin;               // 是否内置
}

class Plugin {
  String id;
  String name;
  String version;
  String author;
  String description;
  PluginManifest manifest;      // 插件清单
  bool isEnabled;
  List<Skill> providedSkills;   // 插件提供的 Skills
}
```

## 4.4 Context Assembly（上下文组装）

这是 RFBrowser 最核心的创新——将来自不同源的上下文统一组装后传递给 AI：

```dart
class ContextAssembly {
  List<ContextItem> items;

  String toPrompt() {
    // 将所有上下文项组装为 AI 可理解的提示
  }
}

class ContextItem {
  ContextType type;             // note | web-page | selection | screenshot | file | agent-result
  String id;
  String content;               // 文本内容
  String? summary;              // AI 生成的摘要
  Map<String, dynamic> metadata;
}
```

### @引用语法

- `@note[笔记标题]` — 引用一条笔记
- `@web[标签页ID#选择区域]` — 引用浏览器中的内容
- `@file[文件路径]` — 引用本地文件
- `@agent[任务ID]` — 引用 Agent 任务结果
- `@clip[剪藏ID]` — 引用网页剪藏
