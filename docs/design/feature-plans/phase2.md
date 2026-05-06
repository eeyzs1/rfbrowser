# Phase 2 功能详细计划（参考文档 — 全部已完成）

> 以下为 Phase 2 各功能的 User Story、可自动化验收标准、实施步骤和风险。
> Phase 2 所有计划均已在 Batch 1 中完成，194 个测试通过，零回归。
> 本文件作为历史记录和实现参考保留。

---

## P2-1: 知识图谱视图增强 ✅ 已完成（Batch 1）

**目标**：图谱达到 Obsidian 基础水平，支持力导向布局 + 局部图谱 + 过滤

### User Stories

| ID | User Story | 优先级 |
|----|-----------|--------|
| US-P2-1-1 | 作为知识工作者，我希望图谱使用力导向布局自动排列节点，以便直观看到笔记间的聚类关系 | P0 |
| US-P2-1-2 | 作为知识工作者，我希望选中某笔记后只显示它的 2 度关系子图，以便聚焦当前上下文 | P0 |
| US-P2-1-3 | 作为知识工作者，我希望按标签或时间范围过滤图谱节点，以便只关注特定主题或时段的知识 | P1 |
| US-P2-1-4 | 作为知识工作者，我希望大规模图谱（500+ 笔记）依然流畅渲染，以便不因数据量增长而无法使用 | P1 |

### 可自动化验收标准

| ID | 验收标准 | 类型 | 自动化方式 |
|----|---------|------|-----------|
| AC-P2-1-1 | 给定 50 个节点和 80 条边，力导向布局在 200 次迭代后任意两节点最小距离 > 节点半径×2 | 🤖 | 单元测试：`LayoutEngine.compute()` → 断言 minDistance |
| AC-P2-1-2 | 力导向布局连续 3 次运行，相同输入产生相同输出（确定性） | 🤖 | 单元测试：固定 seed → 断言输出坐标一致 |
| AC-P2-1-3 | 给定笔记 A→B→C→D 的链接链，`getLocalGraph(A, depth=2)` 返回节点 {A,B,C} 和边 {A→B,B→C} | 🤖 | 集成测试：创建笔记链 → 断言节点集和边集 |
| AC-P2-1-4 | 给定笔记 A→B→C→D，`getLocalGraph(A, depth=1)` 仅返回 {A,B}，depth=2 返回 {A,B,C} | 🤖 | 集成测试：断言 depth 参数正确裁剪子图 |
| AC-P2-1-5 | 给定 10 个带 `#project` 标签的笔记和 5 个无标签笔记，`filterByTag("project")` 返回恰好 10 个节点 | 🤖 | 单元测试：构造图数据 → 过滤 → 断言结果数量 |
| AC-P2-1-6 | 给定 2024 年和 2025 年各 5 篇笔记，`filterByDateRange(2025)` 返回 5 个节点 | 🤖 | 单元测试：构造图数据 → 过滤 → 断言结果 |
| AC-P2-1-7 | 500 节点图谱力导向布局单次迭代耗时 < 16ms（60fps 帧预算） | 📊 | 基准测试：`benchmarkLayoutIteration(500)` → 断言 < 16ms |
| AC-P2-1-8 | 局部图谱切换后 UI 在 300ms 内完成重绘 | 👁️ | 人工验证 + 性能 overlay 确认 |

### 实施步骤

| 步骤 | 内容 | 产出 | 依赖 |
|------|------|------|------|
| 1 | 实现力导向布局算法（Fruchterman-Reingold） | `core/graph/layout_engine.dart` | 无 |
| 2 | 局部图谱查询（从 IndexStore 获取 2 度关系） | `KnowledgeService.getLocalGraph()` | IndexStore |
| 3 | 局部图谱 UI（切换按钮 + 子图渲染） | `graph_page.dart` 更新 | 步骤 1, 2 |
| 4 | 过滤引擎（标签/时间/类型） | `core/graph/filter_engine.dart` | IndexStore |
| 5 | 过滤 UI（底部过滤栏） | `graph_page.dart` 更新 | 步骤 4 |
| 6 | LOD 优化（远距离节点简化渲染） | `graph_page.dart` 更新 | 步骤 1 |
| 7 | 性能测试（500+ 节点基准） | 测试报告 | 步骤 6 |

### 风险

- 力导向算法在大图上可能卡顿 → 使用迭代式布局（每帧迭代 N 次，渐进收敛）
- CustomPainter 重绘开销 → 使用 `shouldRepaint` 精确比较 + RepaintWrap

---

## P2-2: @引用系统完善（上下文引用） ✅ 已完成（Batch 1）

**目标**：AI Chat 中完整支持 `@note[]`、`@web[]`、`@clip[]` 引用，自动注入上下文

### User Stories

| ID | User Story | 优先级 |
|----|-----------|--------|
| US-P2-2-1 | 作为知识工作者，我希望在 AI Chat 中输入 `@note[笔记标题]` 自动注入该笔记内容，以便 AI 能基于我的笔记回答问题 | P0 |
| US-P2-2-2 | 作为知识工作者，我希望在 AI Chat 中输入 `@web[current]` 自动注入当前浏览器页面内容，以便 AI 能分析我正在浏览的网页 | P0 |
| US-P2-2-3 | 作为知识工作者，我希望在发送前预览 @引用 注入的实际内容，以便确认上下文是否正确 | P1 |
| US-P2-2-4 | 作为知识工作者，我希望 @引用 内容超出 token 限制时自动截断并提示，以便不会因上下文过长导致 AI 请求失败 | P0 |
| US-P2-2-5 | 作为知识工作者，我希望输入 `@` 时弹出自动补全列表，以便快速选择要引用的笔记 | P1 |

### 可自动化验收标准

| ID | 验收标准 | 类型 | 自动化方式 |
|----|---------|------|-----------|
| AC-P2-2-1 | 给定笔记"量子计算"内容为"量子叠加是..."，`assembler.resolve("@note[量子计算]")` 返回包含该笔记内容的 ContextItem | 🤖 | 单元测试：创建笔记 → 调用 resolve → 断言 item.content 包含笔记文本 |
| AC-P2-2-2 | 给定不存在的笔记标题，`assembler.resolve("@note[不存在]")` 返回空 ContextItem + 错误标记 | 🤖 | 单元测试：断言 `item.content.isEmpty && item.metadata['error'] == 'not_found'` |
| AC-P2-2-3 | 给定浏览器标签页加载了 example.com，`assembler.resolve("@web[current]")` 返回包含页面文本的 ContextItem | 🤖 | 集成测试：mock BrowserService → 断言 item.type == ContextType.webPage |
| AC-P2-2-4 | 给定输入含 3 个 @引用（总计 8000 字符），token 预算 2000，`assembler.assemble()` 截断低优先级引用并设置 `truncated=true` 标记 | 🤖 | 单元测试：构造超限输入 → 断言 assembly.truncated && 总字符数 ≤ 预算×4 |
| AC-P2-2-5 | `assembler.resolve()` 对 `@note[A]` + `@note[B]` + `@web[current]` 返回 3 个 ContextItem，类型分别为 note, note, webPage | 🤖 | 单元测试：断言 items.length == 3 且类型匹配 |
| AC-P2-2-6 | `ContextAssembly.toPrompt()` 输出格式为 `[Context: note "标题"]\n内容\n[End Context]` 结构化格式 | 🤖 | 单元测试：断言输出匹配 RegExp |
| AC-P2-2-7 | @触发自动补全时，输入"量"后搜索返回标题包含"量"的笔记列表，结果 ≤ 10 条 | 🤖 | 单元测试：创建 20 个含"量"标题的笔记 → 断言 completer 结果 ≤ 10 |
| AC-P2-2-8 | 引用预览 chip 在 UI 中显示笔记标题和前 50 字符摘要 | 👁️ | 人工验证：确认 chip 展示正确 |

### 实施步骤

| 步骤 | 内容 | 产出 | 依赖 |
|------|------|------|------|
| 1 | ContextAssembler 服务：解析输入中的 @引用 | `core/context/assembler.dart` | LinkExtractor |
| 2 | @note 引用解析：标题→笔记内容查找 | assembler 内部 | KnowledgeService |
| 3 | @web 引用解析：标签页ID→页面内容提取 | assembler 内部 | BrowserService |
| 4 | @clip 引用解析：ID→剪藏内容查找 | assembler 内部 | KnowledgeService |
| 5 | Token 估算 + 截断策略 | assembler 内部 | ContextAssembly 模型 |
| 6 | AI Chat 输入框集成：@触发自动补全 | `ai_chat_panel.dart` 更新 | 步骤 1-5 |
| 7 | 引用预览 UI（chip 展示 + 展开查看） | `ui/widgets/context_reference_chip.dart` | 步骤 6 |

### 风险

- 大笔记注入可能超出上下文窗口 → 实现智能摘要（先 AI 摘要再注入）
- @引用自动补全性能 → 使用 IndexStore FTS5 模糊搜索，限制结果 10 条

---

## P2-3: AI 自动标签分组 ✅ 已完成（Batch 1）

**目标**：AI 根据标签页内容自动分组，用户可一键应用

### User Stories

| ID | User Story | 优先级 |
|----|-----------|--------|
| US-P2-3-1 | 作为多标签页用户，我希望 AI 根据标签页内容自动将它们分组，以便快速找到相关标签页 | P0 |
| US-P2-3-2 | 作为多标签页用户，我希望在应用分组前预览方案并调整，以便 AI 分组不符合预期时可以修正 | P0 |
| US-P2-3-3 | 作为多标签页用户，我希望标签页少于 3 个时自动分组按钮禁用，以便避免无意义的分组 | P2 |

### 可自动化验收标准

| ID | 验收标准 | 类型 | 自动化方式 |
|----|---------|------|-----------|
| AC-P2-3-1 | 给定 5 个标签页（2 个 GitHub + 3 个新闻），`generateGroupProposal(tabs)` 返回包含 2 个分组的 TabGroupProposal | 🤖 | 单元测试：构造标签数据 → 断言 groups.length == 2 |
| AC-P2-3-2 | TabGroupProposal 包含每个分组的 name、tabIds、color 字段，且所有 tabIds 的并集等于输入标签页 ID 集合 | 🤖 | 单元测试：断言 proposal.allTabIds.toSet() == inputTabIds.toSet() |
| AC-P2-3-3 | 给定 2 个标签页，`canAutoGroup(tabs)` 返回 false | 🤖 | 单元测试：断言 canAutoGroup([tab1, tab2]) == false |
| AC-P2-3-4 | 给定 5 个标签页，`canAutoGroup(tabs)` 返回 true | 🤖 | 单元测试：断言 canAutoGroup([tab1..tab5]) == true |
| AC-P2-3-5 | `applyGroupProposal(proposal)` 将所有 tabIds 移入对应分组，原有分组被替换 | 🤖 | 集成测试：应用方案 → 断言每个标签页的 groupId 已更新 |
| AC-P2-3-6 | 分组预览对话框展示分组名称和每组包含的标签页标题 | 👁️ | 人工验证：确认对话框内容正确 |

### 实施步骤

| 步骤 | 内容 | 产出 | 依赖 |
|------|------|------|------|
| 1 | 提取标签页内容摘要（标题 + URL + 可选页面文本） | BrowserService 扩展 | BrowserService |
| 2 | AI 分组提示词模板 | Skill 定义 | AIService |
| 3 | 分组方案数据模型 | `data/models/tab_group_proposal.dart` | 无 |
| 4 | 分组预览 UI（对话框，展示方案，可调整） | `ui/widgets/auto_group_dialog.dart` | 步骤 3 |
| 5 | 应用分组逻辑 | BrowserService 扩展 | 步骤 4 |
| 6 | 集成到标签页右键菜单 | `tab_group_sidebar.dart` 更新 | 步骤 5 |

### 风险

- AI 分组质量不稳定 → 提供预览+调整，不自动应用
- 标签页数量少时分组无意义 → 低于 3 个标签时禁用
