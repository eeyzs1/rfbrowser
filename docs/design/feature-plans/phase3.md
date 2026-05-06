# Phase 3 功能详细计划（参考文档 — 全部已完成）

> 以下为 Phase 3 各功能的 User Story、可自动化验收标准、实施步骤和风险。
> Phase 3 所有计划均已在 Batch 2 中完成，零回归，测试通过。
> 本文件作为历史记录和实现参考保留。

---

## P3-1: Agent 浏览器自动化 ✅ 已完成（Batch 2）

**目标**：Agent 可通过 Headless WebView 执行浏览器操作（导航、点击、提取）

### User Stories

| ID | User Story | 优先级 |
|----|-----------|--------|
| US-P3-1-1 | 作为研究者，我希望 Agent 自动打开指定 URL 并提取页面正文，以便无需手动复制粘贴 | P0 |
| US-P3-1-2 | 作为研究者，我希望 Agent 执行多步骤任务（导航→提取→创建笔记），以便一键完成复杂工作流 | P0 |
| US-P3-1-3 | 作为研究者，我希望在 Agent 任务执行过程中可以暂停或取消，以便在发现方向错误时及时止损 | P0 |
| US-P3-1-4 | 作为研究者，我希望在 UI 中看到 Agent 任务的实时进度和每步结果，以便了解任务执行状态 | P1 |
| US-P3-1-5 | 作为研究者，我希望 Agent 执行超过 50 步或 30 分钟时自动终止，以便防止失控 | P0 |

### 可自动化验收标准

| ID | 验收标准 | 类型 | 自动化方式 |
|----|---------|------|-----------|
| AC-P3-1-1 | `HeadlessManager.create()` 返回非空 WebView 实例，且实例计数 +1 | 🤖 | 单元测试：创建 → 断言实例非空 → 断言 manager.activeCount == 1 |
| AC-P3-1-2 | `agentWebView.navigateTo("https://example.com")` 完成后 pageReady resolve，且 currentUrl 包含 "example.com" | 🤖 | 集成测试：mock WebView → 断言 URL 和加载状态 |
| AC-P3-1-3 | `agentWebView.extractText()` 返回非空字符串，长度 > 0 | 🤖 | 集成测试：加载页面 → 提取文本 → 断言 text.isNotEmpty |
| AC-P3-1-4 | 给定 3 步任务 [navigate, extract, createNote]，执行后每步 status == completed 依次推进 | 🤖 | 单元测试：构造任务 → 执行 → 断言每步状态变迁 |
| AC-P3-1-5 | 任务执行中调用 `pauseTask(id)`，task.status 变为 paused，当前步骤停止 | 🤖 | 单元测试：启动任务 → 暂停 → 断言 status == paused |
| AC-P3-1-6 | 任务执行中调用 `cancelTask(id)`，task.status 变为 cancelled，Headless 实例被销毁 | 🤖 | 单元测试：取消 → 断言 status + manager.activeCount == 0 |
| AC-P3-1-7 | 任务步骤达到 50 步时，task.status 自动变为 failed，原因 "step_limit_exceeded" | 🤖 | 单元测试：构造 51 步任务 → 断言失败原因 |
| AC-P3-1-8 | 任务运行超过 30 分钟时自动终止 | 🤖 | 单元测试：mock 时钟 → 断言超时终止 |
| AC-P3-1-9 | Headless 实例空闲超过 5 分钟自动回收，manager.activeCount 减少 | 🤖 | 单元测试：创建实例 → 等待超时 → 断言实例已回收 |
| AC-P3-1-10 | Agent Monitor UI 展示任务列表和步骤进度条 | 👁️ | 人工验证：确认 UI 展示正确 |

### 实施步骤

| 步骤 | 内容 | 产出 | 依赖 |
|------|------|------|------|
| 1 | Headless WebView 管理器 | `platform/webview/headless_manager.dart` | flutter_inappwebview |
| 2 | 基础操作封装（navigate, waitForLoad, extractText） | `platform/webview/agent_webview.dart` | 步骤 1 |
| 3 | Agent 执行引擎（步骤调度 + 状态机） | `services/agent_service.dart` 重构 | 步骤 2 |
| 4 | 任务暂停/取消机制 | agent_service 扩展 | 步骤 3 |
| 5 | Agent Monitor UI（任务列表 + 步骤进度 + 日志） | `ui/widgets/agent_monitor.dart` | 步骤 3 |
| 6 | 安全约束（步数限制 50、时间限制 30min、操作白名单） | agent_service 内部 | 步骤 3 |

### 风险

- Headless WebView 平台兼容性（Linux 不支持）→ 降级为 AI 对话模式
- Agent 操作失控 → 操作白名单 + 危险操作确认 + 可撤销
- Headless 实例泄漏 → 引用计数 + 自动回收 + 超时销毁

---

## P3-2: 上下文组装器完善 ✅ 已完成（Batch 1，随 P2-2 一并完成）

**目标**：完整实现上下文组装管线（解析→提取→排序→裁剪→格式化）

### User Stories

| ID | User Story | 优先级 |
|----|-----------|--------|
| US-P3-2-1 | 作为 AI Chat 用户，我希望 AI 自动获取当前打开笔记的内容作为上下文，以便 AI 回答更精准 | P0 |
| US-P3-2-2 | 作为 AI Chat 用户，我希望多个上下文源按优先级排序，以便最重要的上下文不会被截断丢弃 | P0 |
| US-P3-2-3 | 作为 AI Chat 用户，我希望上下文超出 token 限制时按优先级裁剪而非报错，以便对话始终可以进行 | P0 |
| US-P3-2-4 | 作为高级用户，我希望在调试模式下查看 AI 实际接收了哪些上下文，以便理解 AI 回答的依据 | P2 |

### 可自动化验收标准

| ID | 验收标准 | 类型 | 自动化方式 |
|----|---------|------|-----------|
| AC-P3-2-1 | `ReferenceParser.parse("帮我分析 @note[A] 和 @web[current]")` 返回 2 个引用 | 🤖 | 单元测试：断言解析结果数量和类型 |
| AC-P3-2-2 | `ContentExtractor.extract(noteRef)` 对存在的笔记返回 ContextItem(type: note, content: 笔记内容) | 🤖 | 单元测试：创建笔记 → 提取 → 断言内容 |
| AC-P3-2-3 | `PriorityRanker.rank([userInput, noteRef, webRef, agentResult])` 返回正确的优先级顺序 | 🤖 | 单元测试：构造 4 种 ContextItem → 排序 → 断言顺序 |
| AC-P3-2-4 | 给定总内容 10000 字符、预算 2000 字符，`TokenBudget.trim(items, budget)` 保留高优先级项 | 🤖 | 单元测试：断言裁剪后总字符数 ≤ 预算×4 且高优先级完整 |
| AC-P3-2-5 | `Assembler.assemble(input, references)` 返回 ContextAssembly，toPrompt() 输出非空 | 🤖 | 端到端测试 |
| AC-P3-2-6 | 给定当前打开笔记，assembler.assemble("总结一下") 自动注入该笔记内容 | 🤖 | 集成测试：设置当前笔记 → 断言 items 包含 note |
| AC-P3-2-7 | `ContextAssembly.toPrompt()` 输出中每个上下文项有 `[Context: type "title"]` 标记 | 🤖 | 单元测试：断言输出包含上下文标记 |
| AC-P3-2-8 | 调试模式下 aiChatPanel 展示注入的上下文列表 | 👁️ | 人工验证 |

### 实施步骤

| 步骤 | 内容 | 产出 | 依赖 |
|------|------|------|------|
| 1 | 引用解析器（从用户输入提取 @引用） | `core/context/reference_parser.dart` | LinkExtractor |
| 2 | 内容提取器（按引用类型获取实际内容） | `core/context/content_extractor.dart` | 各 Service |
| 3 | 相关性排序器（按优先级排序上下文项） | `core/context/priority_ranker.dart` | 无 |
| 4 | Token 预算管理器（估算 + 裁剪） | `core/context/token_budget.dart` | 无 |
| 5 | 组装管线串联 | `core/context/assembler.dart` 重构 | 步骤 1-4 |
| 6 | 调试模式 UI | `ai_chat_panel.dart` 扩展 | 步骤 5 |
| 7 | 相关笔记发现（通过链接图发现） | assembler 扩展 | LinkResolver |

---

## P3-3: WebDAV 同步完善 ✅ 已完成（Batch 2）

**目标**：完整的 WebDAV 双向同步 + 冲突处理

### User Stories

| ID | User Story | 优先级 |
|----|-----------|--------|
| US-P3-3-1 | 作为多设备用户，我希望 WebDAV 同步能下载远端变更，以便在另一台设备上看到最新笔记 | P0 |
| US-P3-3-2 | 作为多设备用户，我希望同步只传输变更文件，以便节省带宽和时间 | P0 |
| US-P3-3-3 | 作为多设备用户，我希望同步冲突时可以选择保留哪个版本，以便不会丢失数据 | P0 |
| US-P3-3-4 | 作为多设备用户，我希望看到同步进度和文件列表，以便了解同步状态 | P1 |
| US-P3-3-5 | 作为多设备用户，我希望设置自动定时同步，以便无需手动触发 | P2 |

### 可自动化验收标准

| ID | 验收标准 | 类型 | 自动化方式 |
|----|---------|------|-----------|
| AC-P3-3-1 | downloadChanges() 对远端有而本地无的文件执行 GET 下载 | 🤖 | 集成测试：mock WebDAV → 断言本地文件存在 |
| AC-P3-3-2 | 首次同步后 syncStore.getEtag("A.md") == 远端 ETag | 🤖 | 单元测试：同步 → 断言 ETag 已存储 |
| AC-P3-3-3 | 本地 A.md mtime > lastSyncTime，uploadChanges() 仅上传 A.md | 🤖 | 单元测试：3 文件（1 变更）→ 断言仅上传 1 |
| AC-P3-3-4 | 本地和远端都修改了 A.md，detectConflicts() 返回包含 A.md 的冲突列表 | 🤖 | 单元测试：断言 conflicts.length == 1 |
| AC-P3-3-5 | resolveConflict("A.md", keepLocal) 后本地不变，远端被覆盖 | 🤖 | 单元测试：断言本地文件内容不变 |
| AC-P3-3-6 | resolveConflict("A.md", keepBoth) 后存在 A.md 和 A (conflict copy).md | 🤖 | 单元测试：断言两个文件都存在 |
| AC-P3-3-7 | 同步过程中 syncProgress.filesProcessed 和 totalFiles 实时更新 | 🤖 | 单元测试：断言进度字段非空 |
| AC-P3-3-8 | 设置自动同步间隔 5min 后 Timer 状态正确 | 🤖 | 单元测试：断言 syncTimer.isActive |
| AC-P3-3-9 | 冲突解决 UI 展示文件名和修改时间 | 👁️ | 人工验证 |

### 实施步骤

| 步骤 | 内容 | 产出 | 依赖 |
|------|------|------|------|
| 1 | 完善下载逻辑（PROPFIND → GET 变更文件） | webdav_sync_service 更新 | 无 |
| 2 | ETag 增量检测（SyncStore） | `data/stores/sync_store.dart` | 步骤 1 |
| 3 | 冲突检测 | sync_service 扩展 | 步骤 2 |
| 4 | 冲突数据模型 + 解决策略 | `data/models/sync_conflict.dart` | 无 |
| 5 | 冲突解决 UI | `ui/widgets/sync_conflict_dialog.dart` | 步骤 4 |
| 6 | 同步进度 UI | `ui/widgets/sync_progress.dart` | 步骤 1 |
| 7 | 自动定时同步 | sync_service 扩展 | 步骤 1-3 |
