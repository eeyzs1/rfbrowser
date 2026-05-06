# RFBrowser — 开发路线图与执行计划

> **状态标记**：✅ 已完成 | 🔶 部分完成 | ❌ 未开始

---

## Phase 1: 基础框架 (MVP) — ✅ 已完成

- [x] Flutter 项目初始化 + 三平台构建配置
- [x] 主窗口布局（双栏 + 侧边栏）
- [x] Markdown 编辑器（基础编辑 + 预览切换）
- [x] 文件系统 Vault 管理
- [x] 基础浏览器（flutter_inappwebview 集成）
- [x] 标签管理（手动分组）
- [x] AI Chat（云端 API，单模型）
- [x] 中英双语切换
- [x] SQLite 索引 + 全文搜索

## Phase 2: 知识核心 — ✅ 已完成

- [x] `[[wikilink]]` 双向链接 + 反向链接面板
- [x] 网页剪藏（保存为 Markdown 笔记）
- [x] 模板系统
- [x] Daily Notes
- [x] Git 同步
- [x] 知识图谱视图（力导向布局 + 局部图谱 + 过滤引擎）
- [x] @引用 系统（reference_parser, content_extractor, priority_ranker, token_budget, assembler）
- [x] AI 自动标签分组（TabGroupProposal, AutoGroupEngine）

## Phase 3: AI 增强 — ✅ 已完成

- [x] 多模型切换（OpenAI/Claude/DeepSeek）
- [x] Skills 系统（用户自定义宏）
- [x] AI 深度研究任务
- [x] 本地模型支持（Ollama）
- [x] Agent 浏览器自动化（HeadlessManager, 状态机, step执行引擎, 暂停/取消）
- [x] 上下文组装器（5 模块管线）
- [x] WebDAV 同步（ETag增量, 冲突检测/解决, 自动定时）

## Phase 4: 生态扩展 — ✅ 已完成

> 详见 feature-plans/phase4.md（Batch 3-5 全部完成）

- [x] Canvas 无限画布
- [x] 主题系统
- [x] 未链接提及 UI（backlinks_panel 完整实现）
- [x] Dataview 查询（DQL parser + 查询引擎 + 结果渲染器）
- [x] 插件系统（Isolate沙箱 + API Bridge 接入真实服务 + 崩溃恢复）
- [x] 语义搜索（Ollama embedding + HybridSearch RRF + TF-IDF 本地兜底）
- [x] 性能优化（VectorStore heap topK + IndexStore增量 + 端到端基准测试）
- [x] 插件市场（PluginRegistryNotifier + fetchIndex/search + install/uninstall）
- [x] Skill 市场（RegistrySkillInfo + install/uninstall 生命周期）

## Phase 5: 打磨与发布 — ✅ 已完成

> 详见 feature-plans/phase5.md（Batch 3-6 全部完成）

- [x] 快捷键系统（ShortcutService 含冲突检测、持久化、Settings UI）
- [x] 拖拽互操作（DragData + DropHandler + editor DragTarget集成）
- [x] 编辑器增强（HighlightedTextEditingController + 语法高亮 + 同步滚动）
- [x] 离线模式（ConnectivityNotifier 含 monitoring + SyncExecutor + flushSyncQueue + 去重）
- [x] Linux 内嵌浏览器（占位符增强，支持URL输入/外链/剪辑）
- [x] 无障碍访问（高对比度主题 + AppSettings.highContrastMode）
- [x] 自动更新（UpdateCheckNotifier + GitHub Releases API + 版本比较）
- [x] 安装包优化（Android minify + shrinkResources + proguard）
- [x] 三平台测试与适配（Platform.isLinux/isWindows 适配）
- [x] 用户文档（CONTRIBUTING.md 含 dev setup/code style/PR/测试/架构）
- [x] 社区建设（.github/ISSUE_TEMPLATE 含 bug_report + feature_request）

---

## 开发优先级与依赖关系

```
✅ 第一批（Phase 2收尾）：
  P2-2 (@引用完善) ──→ P3-2 (上下文组装器)
  P2-1 (图谱增强)
  P2-3 (AI 自动分组)

✅ 第二批（Phase 3收尾）：
  P3-1 (Agent 自动化)
  P3-3 (WebDAV 完善)

✅ 第三批（Phase 4 生态扩展核心）：
  P4-1 (插件 API Bridge 接真实服务)
  P4-3 (语义搜索本地嵌入升级)
  P4-5 (端到端性能基准)
  P5-3 (编辑器增强)
  P5-5 (离线模式完善)

✅ 第四批（Phase 4 生态扩展 + Phase 5 打磨）：
  P4-4 (Dataview)
  P4-6 (插件市场) ──→ P4-7 (Skill 市场)
  P5-4 (Linux 内嵌浏览器)
  P5-3 测试 + P5-5 测试

✅ 第五批（Phase 5 发布准备）：
  P5-6 ~ P5-11 (无障碍、自动更新、安装包、文档、社区建设)
```

### 关键依赖链（全部已满足）

```
P4-1 (API Bridge) ──→ P4-6 (插件市场) ──→ P4-7 (Skill 市场)  ✅
P4-3 (语义搜索本地嵌入) ──→ P5-5 (离线模式复用降级策略)  ✅
```

### 可并行开发（已全部完成）

- P4-1 与 P4-3 与 P4-5 无依赖，已并行  ✅
- P5-4 (Linux 浏览器) 独立于其他 Phase 5 项  ✅

---

## 关键风险与缓解

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| Flutter 内嵌浏览器性能 | 中 | 使用 flutter_inappwebview，避免自建 CEF 集成 |
| Linux WebKitGTK 兼容性 | 低 | 提供 CEF 可选后端，WPE WebKit 优化渲染 |
| 插件沙箱安全 | 高 | Isolate 隔离 + 权限声明 + 资源配额 |
| Agent 操作失控 | 高 | 操作白名单 + 确认门槛 + 步数限制 + 可撤销 |
| 大规模 Vault 性能 | 中 | SQLite 索引 + 增量解析 + LOD 渲染 |
| AI API 成本 | 中 | 本地模型备选 + 缓存 + 模型路由优化 |
| 跨平台 UI 一致性 | 低 | Flutter 自绘引擎天然一致，响应式布局 |
