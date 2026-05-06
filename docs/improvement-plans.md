# RFBrowser 改进计划 — User Stories 与可自动化验收标准

> 基于 2026-05-04 全面代码审计发现的 13 个改进项。
> 遵循证据驱动原则，每项均含 User Story 和可自动化验收标准（AC）。
>
> **验收标准格式**：
> - 🤖 = 可自动化测试（单元/集成测试可断言）
> - 👁️ = 需人工验证（UI 视觉/交互体验）
> - 📊 = 可自动化基准测试（性能指标可量化）

---

## 改进 1: 插件 API Bridge 接入真实服务

**关联代码**：[plugin_host.dart](file:///e:/AI_Generated_Projects/rfbrowser/lib/plugins/host/plugin_host.dart#L479-L495)

**问题**：Isolate 沙箱本身完整（SendPort/ReceivePort 双向通信、崩溃恢复、权限检查），但 `_handleApiCall` 返回硬编码空数据——插件调用任何 API 都拿到假结果。

| ID | User Story | 优先级 |
|----|-----------|--------|
| US-IMP-1-1 | 作为插件开发者，我希望 `knowledge.getNote(id)` 返回 NoteRepository 中存储的实际笔记内容，而非硬编码的空对象 | P0 |
| US-IMP-1-2 | 作为插件开发者，我希望 `knowledge.search(query)` 返回 IndexStore 的真实搜索结果 | P0 |
| US-IMP-1-3 | 作为插件开发者，我希望 `browser.getCurrentUrl()` 返回 BrowserService 当前活跃标签页的 URL | P0 |
| US-IMP-1-4 | 作为插件开发者，我希望 `browser.extractText()` 返回 WebView 提取的实际文本 | P0 |
| US-IMP-1-5 | 作为用户，我希望未声明权限的 API 调用被正确拒绝 | P0 |

### 可自动化验收标准

| ID | 验收标准 | 类型 | 自动化方式 |
|----|---------|------|-----------|
| AC-IMP-1-1 | 创建笔记 "测试"（content="Hello World"），插件通过 API Bridge 调用 `knowledge.getNote(id)`，返回的 content == "Hello World" | 🤖 | 集成测试：NoteRepository.create → PluginHost.callApi → 断言 content |
| AC-IMP-1-2 | 创建 3 篇含"量子"关键词的笔记，插件调用 `knowledge.search("量子")`，返回结果 ≥ 3 | 🤖 | 集成测试：创建笔记 → API 调用 → 断言 results.length ≥ 3 |
| AC-IMP-1-3 | 浏览器打开 "https://example.com"，插件调用 `browser.getCurrentUrl()`，返回 "https://example.com" | 🤖 | 集成测试：创建标签页 → API 调用 → 断言 URL |
| AC-IMP-1-4 | 插件调用 `browser.extractText()`，返回的 text 非空且长度 > 0 | 🤖 | 集成测试：加载页面 → API 调用 → 断言 text.isNotEmpty |
| AC-IMP-1-5 | 插件无 `knowledge.read` 权限调用 `knowledge.getNote(id)`，抛出 `PermissionDeniedError("lacks permission: knowledgeRead")` | 🤖 | 单元测试：构造无权限 manifest → callApi → 断言异常 |
| AC-IMP-1-6 | API 调用超过 30 秒未响应时返回 timeout 错误，不阻塞插件 Isolate | 🤖 | 单元测试：mock 延迟 → 断言 timeout |

### 实施步骤

| 步骤 | 内容 | 文件 |
|------|------|------|
| 1 | 将 PluginHostNotifier._handleApiCall 从硬编码改为引入 ref 读服务 | plugin_host.dart |
| 2 | knowledge.getNote → 接入 ref.read(noteRepositoryProvider).getById(args['id']) | plugin_host.dart |
| 3 | knowledge.search → 接入 ref.read(indexStoreProvider).search(args['query']) | plugin_host.dart |
| 4 | browser.getCurrentUrl → 接入 ref.read(browserProvider).activeTab?.url | plugin_host.dart |
| 5 | browser.extractText → 接入 BrowserService.extractContent | plugin_host.dart |

---

## 改进 2: Agent "Create note" 步骤接入真实 NoteRepository

**关联代码**：[agent_service.dart](file:///e:/AI_Generated_Projects/rfbrowser/lib/services/agent_service.dart#L133-L137)

**问题**：Agent 执行引擎的状态机和 Web 操作（navigate、extractText）是真实的，但 `Create note` 步骤仅返回字符串描述，未实际创建笔记。

| ID | User Story | 优先级 |
|----|-----------|--------|
| US-IMP-2-1 | 作为研究者，我希望 Agent 执行 "Create note" 步骤时真正在 Vault 中创建一个 Markdown 文件 | P0 |
| US-IMP-2-2 | 作为研究者，我希望 Agent 创建的笔记自动出现在笔记列表中 | P0 |

### 可自动化验收标准

| ID | 验收标准 | 类型 | 自动化方式 |
|----|---------|------|-----------|
| AC-IMP-2-1 | 创建任务步骤为 `AgentStep(description: "Create note: 量子研究笔记")`，执行后 NoteRepository 中存在 title="量子研究笔记" 的笔记 | 🤖 | 集成测试：创建步骤 → 执行 → 断言 noteRepository.getByTitle 非空 |
| AC-IMP-2-2 | 执行 "Create note: 从步骤上下文创建" 时，笔记 content 包含前面步骤的 stepResults | 🤖 | 集成测试：构造多步任务 → 执行 → 断言 created note.content 包含前置步骤内容 |
| AC-IMP-2-3 | 笔记创建成功后，knowledgeProvider 状态中 notes 列表增加 1 | 🤖 | 集成测试：执行前记数 → 执行后断言 notes.length == before + 1 |

### 实施步骤

| 步骤 | 内容 | 文件 |
|------|------|------|
| 1 | 在 AgentNotifier 中接收 NoteRepository 依赖 | agent_service.dart |
| 2 | "Create note:" 步骤解析标题和内容，调用 noteRepository.create | agent_service.dart |
| 3 | 创建成功后 invalidate knowledgeProvider 以刷新 UI | agent_service.dart |

---

## 改进 3: 命令栏集成 HybridSearch

**关联代码**：[command_bar.dart](file:///e:/AI_Generated_Projects/rfbrowser/lib/ui/widgets/command_bar.dart)

**问题**：命令栏（Ctrl+K，核心导航入口）搜索仅走 `knowledgeProvider.search()`（FTS 关键词搜索），未使用已实现的 HybridSearch（语义+关键词混合搜索，RRF 合并）。

| ID | User Story | 优先级 |
|----|-----------|--------|
| US-IMP-3-1 | 作为知识工作者，我希望命令栏搜索同时匹配关键词和语义相关内容，以便搜索"团队管理"也能找到"如何带人"相关的笔记 | P1 |
| US-IMP-3-2 | 作为知识工作者，我希望命令栏搜索结果能区分来源（关键词匹配 vs 语义匹配） | P2 |

### 可自动化验收标准

| ID | 验收标准 | 类型 | 自动化方式 |
|----|---------|------|-----------|
| AC-IMP-3-1 | 命令栏搜索 "团队管理" 后，调用链路经过 HybridSearch（而非仅知识库搜索），_results 中包含语义来源的结果 | 🤖 | 集成测试：创建语义相关但关键词不匹配的笔记 → 搜索 → 断言结果包含该笔记 |
| AC-IMP-3-2 | 搜索结果 HybridSearchResult.source 字段正确传递到 _SearchResult（用于 UI 标签） | 🤖 | 单元测试：断言 _SearchResult 含 source 字段 |
| AC-IMP-3-3 | 关键词搜索失败（FTS 异常）时语义搜索结果仍可正常返回 | 🤖 | 单元测试：mock FTS 异常 → 断言仍有结果 |

### 实施步骤

| 步骤 | 内容 | 文件 |
|------|------|------|
| 1 | CommandBar 注入 hybridSearchProvider | command_bar.dart |
| 2 | _performSearch 改为调用 hybridSearch.search() | command_bar.dart |
| 3 | _SearchResult 增加 source 字段 | command_bar.dart |
| 4 | UI 中区分显示语义/关键词标签 | command_bar.dart |

---

## 改进 4: 本地嵌入升级（替代玩具哈希）

**关联代码**：[embedding_service.dart](file:///e:/AI_Generated_Projects/rfbrowser/lib/services/embedding_service.dart#L79-L97)

**问题**：当无 API 密钥且未安装 Ollama 时，`_embedLocally` 使用字符码取模生成向量，导致"机器学习"和"今天天气"可能产生相似向量。

| ID | User Story | 优先级 |
|----|-----------|--------|
| US-IMP-4-1 | 作为离线用户，我希望本地语义搜索能产生有意义的排序结果，而非随机排列 | P1 |
| US-IMP-4-2 | 作为离线用户，我希望语义相关的笔记（"深度"/"机器学习"）比无关笔记（"机器学习"/"周末计划"）排序更靠前 | P1 |

### 可自动化验收标准

| ID | 验收标准 | 类型 | 自动化方式 |
|----|---------|------|-----------|
| AC-IMP-4-1 | 嵌入 "机器学习" 和 "深度学习"，余弦相似度 > 0.5 | 🤖 | 单元测试：embed → cosineSimilarity → 断言 > 0.5 |
| AC-IMP-4-2 | 嵌入 "机器学习" 和 "量子计算"，余弦相似度 < "机器学习" 和 "深度学习" 的相似度 | 🤖 | 单元测试：sim(ML,DL) > sim(ML,QC) |
| AC-IMP-4-3 | 嵌入 "机器学习" 和 "周末计划"，余弦相似度 < 0.3 | 🤖 | 单元测试：embed → 断言 sim < 0.3 |
| AC-IMP-4-4 | 同一文本两次嵌入，余弦相似度 == 1.0（确定性） | 🤖 | 单元测试：embed → embed → 断言 sim == 1.0 |

### 实施步骤

| 步骤 | 内容 | 文件 |
|------|------|------|
| 1 | 实现 TF-IDF 向量化（基于现有笔记语料构建 IDF 字典） | embedding_service.dart |
| 2 | 若有 OnnxRuntime Dart 支持，加载微型 sentence-transformers 模型 | embedding_service.dart |
| 3 | 嵌入质量基准测试（相似/不相似文本对共 20 组） | test/semantic_search_test.dart |

---

## 改进 5: 上下文组装器 AI Chat 调用链验证

**关联代码**：[assembler.dart](file:///e:/AI_Generated_Projects/rfbrowser/lib/core/context/assembler.dart) + [ai_chat_panel.dart](file:///e:/AI_Generated_Projects/rfbrowser/lib/ui/pages/ai_chat_panel.dart)

**问题**：ContextAssembler 有完整的 `toPrompt()` 实现，但需验证 AI Chat Panel 在所有消息发送路径上正确调用组装器。

| ID | User Story | 优先级 |
|----|-----------|--------|
| US-IMP-5-1 | 作为 AI Chat 用户，我希望每次发送消息时自动组装上下文（含当前笔记和 @引用），以便 AI 始终基于完整上下文回答 | P0 |

### 可自动化验收标准

| ID | 验收标准 | 类型 | 自动化方式 |
|----|---------|------|-----------|
| AC-IMP-5-1 | 用户在编辑器中打开笔记 A（content="量子叠加原理..."），在 AI Chat 中发送 "总结一下"，AI 接收到的 prompt 中包含笔记 A 的内容 | 🤖 | 集成测试：设置 activeNote → 发送消息 → 断言 aiService 收到的 prompt 含笔记内容 |
| AC-IMP-5-2 | 用户输入 "帮我分析 @note[学习笔记] 和@web[current]"，AI 接收的 prompt 包含 2 个 `[Context: ...]` 标记块 | 🤖 | 集成测试：包含 @引用 的消息 → 断言 prompt 含 Context 块 |
| AC-IMP-5-3 | 上下文超出 token 预算时 assembly.truncated == true，AI Chat 显示截断提示 | 🤖 | Widget 测试：构造超限输入 → 断言 truncated 提示可见 |

---

## 改进 6: Meta-Harness 管道端到端验证

**关联代码**：[generation-log.md](file:///e:/AI_Generated_Projects/rfbrowser/memory/generation-log.md) + `scripts/generate.py`

**问题**：Meta-Harness 生成管道（解释器→Harness生成器→Agent工厂→编排器）从未被真正执行过。生成日志明确写着 "(No generations yet)"。

| ID | User Story | 优先级 |
|----|-----------|--------|
| US-IMP-6-1 | 作为 Meta-Harness 维护者，我希望运行一次完整的生成管道来验证模板和种子的可用性，以便确保管道确实能产出可运行的项目 | P1 |

### 可自动化验收标准

| ID | 验收标准 | 类型 | 自动化方式 |
|----|---------|------|-----------|
| AC-IMP-6-1 | `python scripts/generate.py --task <测试任务>` 执行成功，输出到 generated/，verify-generation.py 报告 7+2 层完整 | 🤖 | CI 测试：执行生成 → 验证 → 断言 exitCode == 0 |
| AC-IMP-6-2 | 生成的项目中包含 AGENTS.md、orchestrator.py、7+2 层各至少一个可执行产物 | 🤖 | 脚本测试：断言文件存在 |
| AC-IMP-6-3 | generation-log.md 和 generation-log.yaml 各增加 1 条记录 | 🤖 | 脚本测试：断言记录数 +1 |

---

## 改进 7: Batch 1-6 经验回填 meta-mistakes.md

**关联代码**：[meta-mistakes.md](file:///e:/AI_Generated_Projects/rfbrowser/memory/meta-mistakes.md)

**问题**：meta-mistakes.md 在 4月14日（项目初始化）之后再无更新。但 Batch 1-6 经历了 194 个测试 + 多轮 bug fix（webdav 缺少 import、nullable spread、duplicate dispose 等），这些经验未回馈进化系统。

| ID | User Story | 优先级 |
|----|-----------|--------|
| US-IMP-7-1 | 作为 Meta-Harness 进化引擎，我希望每次开发阶段产生的 bug 和修复被记录为 meta-mistake，以便改进未来生成管道的质量 | P2 |

### 可自动化验收标准

| ID | 验收标准 | 类型 | 自动化方式 |
|----|---------|------|-----------|
| AC-IMP-7-1 | meta-mistakes.md 中存在 2026-05-04 或之后日期的至少 3 条新记录 | 👁️ | 人工验证：检查文件内容 |
| AC-IMP-7-2 | 每条新 meta-mistake 遵循模板格式（Date/Trigger/What went wrong/Root cause/Fix/Status） | 🤖 | 脚本验证：解析 Markdown → 断言所有必填字段存在 |

### 建议记录的已知问题

- webdav_sync_service: 缺少 dart:convert import → `import check template` 缺失
- main_layout: agentServiceProvider→agentProvider → 命名规范模板缺失
- ai_chat_panel: duplicate dispose → 生命周期清理模板缺失
- browser_page: updateUrl/updateTabUrl 方法签名不匹配 → API 命名一致性检查缺失

---

## 改进 8: Canvas 图片卡片真实渲染

**关联代码**：[canvas_page.dart](file:///e:/AI_Generated_Projects/rfbrowser/lib/ui/pages/canvas_page.dart#L364-L379)

**问题**：Canvas 支持 Image 类型卡片，但仅显示图标，不渲染实际图片。

| ID | User Story | 优先级 |
|----|-----------|--------|
| US-IMP-8-1 | 作为 Canvas 用户，我希望 Image 卡片显示真实图片缩略图，以便视觉化组织素材 | P3 |

### 可自动化验收标准

| ID | 验收标准 | 类型 | 自动化方式 |
|----|---------|------|-----------|
| AC-IMP-8-1 | 创建 Image 类型卡片且 content 为有效路径 `attachments/test.png`，卡片 Widget 树中包含 Image Widget | 🤖 | Widget 测试：pump → 断言 find.byType(Image) 存在 |
| AC-IMP-8-2 | 创建 Image 类型卡片 content 为空，显示默认占位图标 | 🤖 | Widget 测试：断言 find.byIcon(Icons.image) 存在 |

---

## 改进 9: Link Extractor / Link Resolver 调用链验证

**背景**：AGENTS.md 记录的教训 **UX-6**：如果 LinkExtractor/LinkResolver 存在但没被调用，图谱和反向链接就是空壳。

| ID | User Story | 优先级 |
|----|-----------|--------|
| US-IMP-9-1 | 作为知识工作者，我希望创建含 `[[wikilink]]` 的笔记后：(1) 目标笔记的 backlinks 中新增该链接，(2) 图谱中新增该边 | P1 |

### 可自动化验收标准

| ID | 验收标准 | 类型 | 自动化方式 |
|----|---------|------|-----------|
| AC-IMP-9-1 | 创建笔记 A(`content="链接到[[B]]"`)，保存后 `getBacklinks(B)` 返回包含 A 的链接 | 🤖 | 端到端集成测试：创建 A+B → 保存A → 调用getBacklinks(B) → 断言包含 {source:A, target:B} |
| AC-IMP-9-2 | knowledgeState.outlinks 包含 A→B，knowledgeState.backlinks 包含 B→A | 🤖 | 集成测试：断言双向链接 |
| AC-IMP-9-3 | graph_page 显示 A 和 B 节点及 A↔B 连线 | 👁️ | 人工验证：打开图谱 → 确认连线 |

---

## 改进 10: HybridSearch FTS 注入验证

**关联代码**：[embedding_service.dart](file:///e:/AI_Generated_Projects/rfbrowser/lib/services/embedding_service.dart#L143-L199)

**问题**：HybridSearch 接受 `FtsSearchFn?` 但 Provider 定义（line 224-226）未注入实际的 FTS 搜索函数。

| ID | User Story | 优先级 |
|----|-----------|--------|
| US-IMP-10-1 | 作为知识工作者，我希望混合搜索同时包含关键词匹配结果和语义匹配结果 | P1 |

### 可自动化验收标准

| ID | 验收标准 | 类型 | 自动化方式 |
|----|---------|------|-----------|
| AC-IMP-10-1 | HybridSearch.search("量子") 返回的结果中包含 source="fts" 或 source="both" 的结果（证明 FTS 被调用） | 🤖 | 集成测试：创建含关键词的笔记 → 搜索 → 断言存在 fts/both 来源 |
| AC-IMP-10-2 | hybridSearchProvider 创建时注入了实际的 ftsSearchFn | 🤖 | 单元测试：断言 hybridSearch._ftsSearchFn != null |

---

## 改进 11: Evolution 框架激活

**关联代码**：`evolution/framework.md` + `scripts/evolve.py` + `seeds/evolution/innovation-engine.py`

**问题**：README 描述的"四阶段进阶模型"（Basic→Solid→Advanced→Excellent）和"创新引擎"能力存在代码，但从未被激活。

| ID | User Story | 优先级 |
|----|-----------|--------|
| US-IMP-11-1 | 作为 RFBrowser 产品负责人，我希望创新引擎分析当前产品状态并提出进阶建议 | P2 |

### 可自动化验收标准

| ID | 验收标准 | 类型 | 自动化方式 |
|----|---------|------|-----------|
| AC-IMP-11-1 | `python seeds/evolution/innovation-engine.py --project-root .` 输出包含至少 3 条建议且每条的 workload 和 security 级别已评估 | 🤖 | 脚本测试：运行 → 断言 stdout 含 ≥3 条 + 每条有 workload/security |
| AC-IMP-11-2 | innovation-engine.py 不抛出异常，exit code == 0 | 🤖 | CI 测试：断言 exit code == 0 |

---

## 改进 12: 测试覆盖缺口

**背景**：194 个测试全部通过，但通过代码审查发现以下模块缺少对应的测试文件。

| 模块 | 缺失 | 优先级 |
|------|------|--------|
| Plugin API Bridge 端到端 | 无集成测试覆盖 `_handleApiCall` 真实调用 | P1 |
| Agent "Create note" 真实创建 | 无集成测试覆盖笔记实际创建 | P1 |
| CommandBar HybridSearch 集成 | 无 Widget 测试覆盖混合搜索调用 | P2 |

### 可自动化验收标准

| ID | 验收标准 | 类型 | 自动化方式 |
|----|---------|------|-----------|
| AC-IMP-12-1 | PluginHost 集成测试：插件通过 API Bridge 获取真实笔记，断言内容一致 | 🤖 | 集成测试 |
| AC-IMP-12-2 | Agent 集成测试：多步任务含 Create note 步骤，执行后断言 Vault 中存在新笔记 | 🤖 | 集成测试 |

---

## 改进 13: Docs 目录结构规范化

新增 `docs/` 目录包含 `docs/design/`（设计文档）和本文档 `docs/improvement-plans.md`（改进计划）。

| ID | User Story | 优先级 |
|----|-----------|--------|
| US-IMP-13-1 | 作为开发者，我希望设计文档按功能模块组织结构清晰，以便快速定位信息 | P2 |

### 可自动化验收标准

| ID | 验收标准 | 类型 | 自动化方式 |
|----|---------|------|-----------|
| AC-IMP-13-1 | docs/design/ 下至少包含 10 个子文档，每个文档不超过 300 行 | 🤖 | 脚本检查：遍历文件 → 断言 count ≥ 10 && max(lines) ≤ 300 |
| AC-IMP-13-2 | 根目录 DESIGN.md 作为索引，包含所有子文档的链接 | 👁️ | 人工验证 |

---

## 执行优先级总结

| 优先级 | 编号 | 改进项 | 预估工时 |
|--------|------|--------|----------|
| **P0** | 1 | 插件 API Bridge 接入真实服务 | 4h |
| **P0** | 2 | Agent "Create note" 接入 NoteRepository | 2h |
| **P1** | 3 | 命令栏集成 HybridSearch | 2h |
| **P1** | 4 | 本地嵌入升级（TF-IDF） | 4h |
| **P1** | 5 | 上下文组装器调用链验证 | 1h |
| **P1** | 9 | Link 系统端到端验证 | 2h |
| **P1** | 10 | HybridSearch FTS 注入 | 1h |
| **P2** | 6 | Meta-Harness 管道验证 | 3h |
| **P2** | 7 | meta-mistakes 经验回填 | 2h |
| **P2** | 11 | Evolution 框架激活 | 2h |
| **P2** | 12 | 测试覆盖补全 | 3h |
| **P3** | 8 | Canvas 图片卡片渲染 | 3h |
| **P2** | 13 | ✅ 已完成（本文档即产出） | — |
