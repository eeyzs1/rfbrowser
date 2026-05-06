# Phase 4 功能详细计划（生态系统扩展 — 全部已完成）

> Phase 4 目标：插件生态 + 高级功能。
> **全部 7 项功能均已完成**，通过 194 个测试（零回归）。
> 本文件作为实现参考和设计记录保留。

**完成状态摘要**：

| 编号 | 功能 | 完成批次 | 状态 |
|------|------|----------|------|
| P4-1 | 插件系统完善（API Bridge 接入真实服务） | Batch 3 | ✅ |
| P4-2 | 未链接提及 UI | Batch 1 (审计确认) | ✅ |
| P4-3 | 语义搜索（本地嵌入升级 + HybridSearch RRF） | Batch 3 | ✅ |
| P4-4 | Dataview 查询（DQL Parser + 引擎 + 渲染器） | Batch 4 | ✅ |
| P4-5 | 性能优化（端到端基准测试） | Batch 3 | ✅ |
| P4-6 | 插件市场 | Batch 4 | ✅ |
| P4-7 | Skill 市场 | Batch 4 | ✅ |

---

## P4-1: 插件系统完善（API Bridge 接入真实服务）✅ Batch 3

**完成内容**：
- `plugin_host.dart` 全面重写：Isolate 沙箱含 `SendPort`/`ReceivePort` 双向通信
- API Bridge 主机侧：权限检查 + 服务转发（`_handleApiCall` 接入真实 `KnowledgeService` / `BrowserService`）
- API Bridge 插件侧：代理调用接口
- 崩溃检测 + 自动恢复（3 次重试 / 3 秒内）
- `PluginCommand` 注册机制
- 8 个测试通过

### User Stories（全部满足）

| ID | User Story | 优先级 |
|----|-----------|--------|
| US-P4-1-1 | 作为插件开发者，我希望插件的 `knowledge.getNote(id)` 能返回实际笔记内容 | P0 |
| US-P4-1-2 | 作为插件开发者，我希望插件的 `browser.extractText()` 能返回当前浏览器的页面文本 | P0 |
| US-P4-1-3 | 作为插件开发者，我希望插件调用未声明权限的 API 时收到 PermissionDeniedError | P0 |
| US-P4-1-4 | 作为用户，我希望插件崩溃后自动恢复 | P1 |
| US-P4-1-5 | 作为插件开发者，我希望插件可以注册命令并在命令栏中可见 | P1 |

### 验收标准（全部通过）

| ID | 验收标准 | 测试方式 |
|----|---------|----------|
| AC-P4-1-1 | 插件调用 `knowledge.getNote(id)` 返回 NoteRepository 中存储的实际内容 | 集成测试 |
| AC-P4-1-2 | 插件调用 `knowledge.search("量子")` 返回包含匹配笔记的搜索结果列表 | 集成测试 |
| AC-P4-1-3 | 插件调用 `browser.getCurrentUrl()` 返回当前活跃标签页的 URL | 集成测试 |
| AC-P4-1-4 | 插件无 `knowledge.read` 权限调用 knowledge API 时返回 PermissionDeniedError | 单元测试 |
| AC-P4-1-5 | 插件 Isolate 内抛出未捕获异常，主应用不崩溃，3 秒内自动重启 | 单元测试 |
| AC-P4-1-6 | 插件注册命令后，命令栏搜索能匹配到该命令 | 人工验证 |
| AC-P4-1-7 | API Bridge 调用超时（30s）时返回 timeout error | 单元测试 |

### 实现架构

- Isolate 通信序列化 → 限制传输对象为 `Map<String, dynamic>`
- 服务注入方式 → 通过回调函数传递 API Handler，不直接注入实例

---

## P4-2: 未链接提及 UI ✅ Batch 1（审计确认）

**完成内容**：
- `backlinks_panel.dart` 完整实现未链接提及区域
- 自动检测笔记中出现的其他笔记标题但未建立 `[[wikilink]]` 的情况
- 支持一键转换为双向链接

---

## P4-3: 语义搜索完善（本地嵌入升级）✅ Batch 3

**完成内容**：
- `embedding_service.dart` 全面重写：
  - Ollama 本地嵌入（`nomic-embed-text` 模型）
  - API 嵌入回退链：API → Ollama → 本地 hash
- `HybridSearch`：FTS5 关键词搜索分支 + Reciprocal Rank Fusion（RRF, K=60）结果融合
- 搜索结果 `source` 标签：`fts` / `semantic` / `both`
- 10 个测试通过

### User Stories（全部满足）

| ID | User Story | 优先级 |
|----|-----------|--------|
| US-P4-3-1 | 作为离线用户，我希望本地嵌入能产生有意义的语义编码 | P0 |
| US-P4-3-2 | 作为知识工作者，我希望搜索结果同时包含关键词和语义匹配，有 source 标签区分 | P0 |
| US-P4-3-3 | 作为知识工作者，我希望笔记保存时自动更新向量 | P1 |

### 验收标准（全部通过）

| ID | 验收标准 | 测试方式 |
|----|---------|----------|
| AC-P4-3-1 | 本地嵌入对语义相似文本（"机器学习"/"深度学习"）的余弦相似度 > 对无关文本 | 单元测试 |
| AC-P4-3-2 | HybridSearch.query 返回结果 source 字段正确标记为 fts/semantic/both | 单元测试 |
| AC-P4-3-3 | 笔记保存后向量已更新 | 集成测试 |
| AC-P4-3-4 | 100 篇笔记批量嵌入完成，vectorStore.count() == 100 | 集成测试 |
| AC-P4-3-5 | 语义搜索 TopK=20 查询 1000 篇笔记耗时 < 200ms | 基准测试 |

---

## P4-4: Dataview 查询 ✅ Batch 4

**完成内容**：
- DQL Parser（`dql_parser.dart`）：支持 `LIST` / `TABLE` / `TASK` + `WHERE` + `SORT`
- 查询引擎（`query_engine.dart`）：标签/日期/字段过滤、排序、100 结果上限
- 结果渲染器（`result_renderer.dart`）：`DataTable` / `List` / `TaskList` 三种 Widget
- 15 个测试通过

### 验收标准（全部通过）

| ID | 验收标准 | 测试方式 |
|----|---------|----------|
| AC-P4-4-1 | DQL 查询 `TABLE WHERE tag = #project SORT date DESC` 正确解析为 QueryType.table + filters + sorts | 单元测试 |
| AC-P4-4-2 | 查询引擎对标签过滤返回匹配笔记 | 单元测试 |
| AC-P4-4-3 | 查询引擎对日期过滤返回匹配笔记 | 单元测试 |
| AC-P4-4-4 | 结果渲染返回正确的 Widget 树 | Widget 测试 |
| AC-P4-4-5 | 查询结果超过 100 条时自动截断 | 单元测试 |

---

## P4-5: 性能优化（端到端基准测试）✅ Batch 3

**完成内容**：
- `VectorStore`：预计算向量范数 + min-heap topK 搜索（O(N log K) 替代 O(N log N)）
- `IndexStore`：`updateNote` 增量更新方法
- 3 个性能基准测试：
  1. VectorStore 1000 向量搜索 < 200ms
  2. 图谱 500 节点单次迭代 < 16ms
  3. 编辑器高亮 1000 行 < 50ms
- 基准测试文件：`test/performance_benchmark_test.dart`

### User Stories（全部满足）

| ID | User Story | 优先级 |
|----|-----------|--------|
| US-P4-5-1 | 作为拥有 1000+ 笔记的用户，我希望应用启动时间 < 3 秒 | P0 |
| US-P4-5-2 | 作为拥有 1000+ 笔记的用户，我希望全文搜索响应 < 200ms | P0 |
| US-P4-5-3 | 作为拥有 1000+ 笔记的用户，我希望内存占用 < 500MB | P1 |

---

## P4-6: 插件市场 ✅ Batch 4

**完成内容**：
- `PluginRegistryNotifier`（`plugin_registry_service.dart`）：
  - `fetchIndex(registryUrl?)` — 从 GitHub 仓库拉取 `index.json`
  - `search(query)` — 按名称/描述搜索
  - `getPermissions(pluginId)` — 查询插件权限声明
- `RegistryPluginInfo` 模型（id/name/version/description/author/permissions/downloadUrl）
- install / uninstall 生命周期
- 6 个测试通过

### 验收标准（全部通过）

| ID | 验收标准 | 测试方式 |
|----|---------|----------|
| AC-P4-6-1 | registryService.fetchIndex() 返回非空插件列表 | 单元测试 |
| AC-P4-6-2 | registryService.search("dataview") 返回匹配结果 | 单元测试 |
| AC-P4-6-3 | pluginHost.installFromRegistry(pluginId) 后插件目录存在 | 集成测试 |
| AC-P4-6-4 | pluginHost.uninstall(pluginId) 后插件目录不存在 | 集成测试 |
| AC-P4-6-5 | 插件市场 UI 展示插件列表和搜索框 | 人工验证 |

### 依赖链（已满足）

P4-1（API Bridge）→ P4-6（插件市场）

---

## P4-7: Skill 市场 ✅ Batch 4

**完成内容**：
- `RegistrySkillInfo` 模型（id/name/description/downloadUrl）
- `getSkill(skillId)` 查询方法
- install / uninstall 生命周期
- 3 个测试通过

### 验收标准（全部通过）

| ID | 验收标准 | 测试方式 |
|----|---------|----------|
| AC-P4-7-1 | skillService.installFromRegistry(skillId) 后 .rfbrowser/skills/{skillId}.yaml 存在 | 集成测试 |
| AC-P4-7-2 | 安装后 skillService.getSkill(skillId) 返回可用 Skill 对象 | 集成测试 |
| AC-P4-7-3 | skillService.uninstall(skillId) 后文件不存在 | 集成测试 |

### 依赖链（已满足）

P4-6（插件市场基础设施）→ P4-7（Skill 市场）
