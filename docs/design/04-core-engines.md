# RFBrowser — 核心引擎设计

---

## 5.1 Markdown 引擎

**职责**：解析、渲染、序列化 Markdown 文件

```
Markdown 文件
    │
    ├──→ [Parser] ──→ AST (抽象语法树)
    │                     │
    │                     ├──→ [Renderer] ──→ Flutter Widget Tree（预览）
    │                     ├──→ [LinkExtractor] ──→ Link[]（链接提取）
    │                     ├──→ [FrontMatterParser] ──→ YAML Map（元数据）
    │                     └──→ [SearchIndexer] ──→ 倒排索引（搜索）
    │
    └──→ [Serializer] ←── AST（保存回文件）
```

**关键特性**：
- 支持 `[[wikilink]]`、`#heading`、`^block-id` 三级链接
- 支持 `![[note]]` 嵌入引用
- 支持 YAML frontmatter
- 支持自定义语法扩展（通过插件）
- 增量解析：文件修改时只重新解析变更部分

**技术选型**：
- 使用 `flutter_markdown` + 自定义语法扩展
- 或使用 `markdown` Dart 包自行构建渲染管线

---

## 5.2 Link Resolver（链接解析器）

**职责**：解析所有类型的链接，构建双向链接图

```
输入：[[量子计算入门#核心概念]]
    │
    ├──→ [路径解析] ──→ vault/量子计算入门.md
    ├──→ [标题定位] ──→ ## 核心概念
    └──→ [反向链接更新] ──→ 在目标笔记的 backlinks 中添加记录
```

**链接类型**：

| 语法 | 类型 | 说明 |
|------|------|------|
| `[[note]]` | wikilink | 链接到笔记 |
| `[[note#heading]]` | heading link | 链接到笔记中的标题 |
| `[[note#^block-id]]` | block link | 链接到笔记中的块 |
| `![[note]]` | embed | 嵌入引用笔记内容 |
| `[[note\|alias]]` | alias link | 使用别名显示 |
| `@note[title]` | context ref | 上下文引用（AI 用） |
| `@web[tab#sel]` | web ref | 网页内容引用（AI 用） |

**反向链接**：
- 实时维护反向链接索引（SQLite）
- 支持未链接提及（Unlinked Mentions）— 发现隐式关联

---

## 5.3 Graph Engine（图谱引擎）

**职责**：构建和可视化知识图谱

```
Notes + Links
    │
    ├──→ [Graph Builder] ──→ 节点 + 边
    │                         │
    │                         ├──→ [Layout Engine] ──→ 力导向布局
    │                         ├──→ [Filter Engine] ──→ 按标签/类型/时间过滤
    │                         └──→ [Cluster Engine] ──→ 自动聚类
    │
    └──→ [Graph Renderer] ──→ Flutter Canvas / CustomPainter
```

**两种视图**：
1. **全局图谱** — 展示整个 Vault 的知识网络
2. **局部图谱** — 展示当前笔记的关联网络（2度关系）

**技术选型**：
- GPU 加速渲染（Canvas + CustomPainter）
- 大规模图谱（1000+ 节点）使用 LOD（Level of Detail）优化

---

## 5.4 Context Assembler（上下文组装器）

**职责**：将来自不同源的上下文统一组装，传递给 AI

```
用户输入 + @引用
    │
    ├──→ [引用解析] ──→ ContextItem[]
    │                     │
    │                     ├──→ [内容提取] ──→ 从各源获取实际内容
    │                     ├──→ [相关性排序] ──→ 按相关性排序上下文
    │                     ├──→ [长度裁剪] ──→ 适配模型上下文窗口
    │                     └──→ [格式化] ──→ 组装为统一格式
    │
    └──→ [Prompt Builder] ──→ 最终提示词
```

**上下文源优先级**：
1. 用户当前输入（最高优先级）
2. @引用 的内容
3. 当前打开的笔记/网页
4. 最近的 Agent 任务结果
5. 相关的笔记（通过链接图发现）

---

## 5.5 Search Engine（搜索引擎）

**职责**：全文搜索 + 语义搜索

```
查询输入
    │
    ├──→ [文本搜索] ──→ SQLite FTS5 倒排索引
    ├──→ [语义搜索] ──→ 向量嵌入 + 余弦相似度
    └──→ [结果合并] ──→ 按相关性排序的结果列表
```

**技术选型**：
- SQLite FTS5 用于全文搜索
- 语义搜索：使用云端 Embedding API（如 OpenAI text-embedding-3）或本地模型
- 向量存储：SQLite + vec 扩展，或独立的向量索引

---

## 5.6 Model Router（模型路由器）

**职责**：管理多个 AI 模型，智能路由请求

```
AI 请求
    │
    ├──→ [任务分类] ──→ chat | agent | embed | summarize
    │
    ├──→ [模型选择] ──→ 根据任务类型和用户偏好选择模型
    │                     │
    │                     ├──→ 云端：OpenAI / Claude / Gemini / DeepSeek
    │                     └──→ 本地：Ollama / llama.cpp
    │
    └──→ [请求执行] ──→ 统一 API 适配层
```

**模型配置**：

```yaml
models:
  cloud:
    - provider: openai
      models: [gpt-4o, gpt-4o-mini]
      api_key: ${OPENAI_API_KEY}
    - provider: anthropic
      models: [claude-sonnet-4-20250514]
      api_key: ${ANTHROPIC_API_KEY}
    - provider: deepseek
      models: [deepseek-chat, deepseek-reasoner]
      api_key: ${DEEPSEEK_API_KEY}
  local:
    - provider: ollama
      endpoint: http://localhost:11434
      models: [llama3, qwen2.5]
    - provider: llamacpp
      endpoint: http://localhost:8080
      models: [custom-model]

routing:
  chat: cloud:openai:gpt-4o
  agent: cloud:anthropic:claude-sonnet-4-20250514
  embed: cloud:openai:text-embedding-3-small
  summarize: local:ollama:llama3
  fallback: local:ollama:llama3
```
