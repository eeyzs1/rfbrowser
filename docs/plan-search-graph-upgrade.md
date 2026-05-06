# 方案C：搜索与图谱升级 — 设计案与开发计划

> 状态: Draft | 作者: AI | 日期: 2026-05-05

---

## 目录

1. [概述](#1-概述)
2. [Phase 1: HNSW 语义搜索](#2-phase-1-hnsw-语义搜索)
3. [Phase 2: GraphFilter 图算法增强](#3-phase-2-graphfilter-图算法增强)
4. [Phase 3: Tantivy FFI 全文搜索](#4-phase-3-tantivy-ffi-全文搜索)
5. [User Stories 汇总](#5-user-stories-汇总)
6. [自动化验收标准](#6-自动化验收标准)
7. [开发计划与里程碑](#7-开发计划与里程碑)
8. [风险与缓解](#8-风险与缓解)

---

## 1. 概述

### 1.1 当前状态

| 系统 | 当前实现 | 瓶颈 |
|------|---------|------|
| 语义搜索 | `VectorStore` — HashMap + 全量 Cosine 暴力扫描 | O(n×d)，2000条笔记 ~10ms/次，万级笔记不可接受 |
| 图谱跳跃 | `GraphFilter.getLocalGraph()` — 邻接表 + BFS | 仅有2跳子图，无最短路径/中心性/社区发现 |
| 全文搜索 | SQLite FTS5 + unicode61 tokenizer | 中文逐字分词，搜"代理模式"命中率不可预测 |

### 1.2 目标架构

| 系统 | 目标实现 | 关键技术 |
|------|---------|---------|
| 语义搜索 | `HnswIndex` — 纯 Dart HNSW 图 | M=16, efConstruction=200, ef=100 |
| 图谱跳跃 | `GraphFilter` 扩展 — Dijkstra/PageRank/递归CTE | 纯 Dart 图算法 + SQLite WITH RECURSIVE |
| 全文搜索 | `TantivyBridge` — Tantivy + jieba 分词 | Rust FFI |

### 1.3 资源预算

| 指标 | 当前 | 目标 | Chrome对比 |
|------|------|------|-----------|
| 二进制大小 | ~50MB | ~60MB (+10MB) | ~200MB |
| 空闲内存 | ~80MB | ~130MB (+50MB) | ~400MB |
| 索引内存(2000笔记) | ~20MB | ~50MB (+30MB) | — |
| 语义搜索耗时 | ~10ms | ~0.5ms (20x) | — |
| 图谱2跳查询 | ~2ms | ~2ms (持平) | — |
| FTS搜索结果数 | 不完整 | 完整 | — |

---

## 2. Phase 1: HNSW 语义搜索

### 2.1 技术方案

**HNSW (Hierarchical Navigable Small World)** 是一种近似最近邻搜索算法，通过构建多层图结构实现对数级查找。

```
层级结构示意 (M=4, 指数衰减分配层级):

Layer 3:  [入口节点] ── 稀疏连接，快速定位区域
              │
Layer 2:  [A]──[B]──[C] ── 中等密度
              │    │
Layer 1:  [D]──[E]──[F]──[G] ── 较密
              │╲  ╱│
Layer 0:  ★──[H]──[I]──[J]──[K] ── 全量节点，最密连接
              │
          (每层最多 M 个邻居)
```

**核心参数**:

| 参数 | 值 | 含义 |
|------|-----|------|
| M | 16 | 每层每个节点最大连接数 |
| M_max0 | 32 | 第0层最大连接数 (2×M) |
| efConstruction | 200 | 构建时的候选队列大小 |
| ef | 100 | 搜索时的候选队列大小 |
| mL | 1/ln(M) ≈ 0.36 | 层级分配概率因子 |

**搜索流程**:
```
1. 从顶层入口点开始
2. for layer in top..0:
     a. 在当前层用 Beam Search (ef 个候选) 找最近的入口
     b. 下降到下一层，以上一层的最近邻为入口
3. 在 Layer 0 用 Beam Search 返回 Top-K
```

**内存估算 (2000条笔记, 768维)**:
```
向量:  2000 × 768 × 8bytes = 12.3 MB
图结构: 2000 × 32(平均连接) × 8bytes × 3(层) ≈ 1.5 MB
总计:  ~15 MB
```

### 2.2 文件变更清单

| 文件 | 操作 | 说明 |
|------|------|------|
| `lib/data/stores/hnsw_index.dart` | **新增** | HNSW 索引核心实现 |
| `lib/data/stores/hnsw_index_test.dart` | **新增** | 单元测试(≥80%覆盖率) |
| `lib/data/stores/vector_store.dart` | 保留 | 作为 HNSW 的 fallback |
| `lib/services/embedding_service.dart` | **修改** | `SemanticSearch` 改用 HnswIndex |
| `lib/services/embedding_service_test.dart` | **新增** | 集成测试 |

### 2.3 HNSW 核心接口设计

```dart
class HnswIndex {
  final int M;
  final int efConstruction;
  final int maxLayer0Connections;

  HnswIndex({this.M = 16, this.efConstruction = 200});

  int get size;
  bool get isEmpty;

  void insert(String id, List<double> vector, {Map<String, dynamic>? metadata});
  void remove(String id);
  List<SearchResult> search(List<double> query, {int k = 20, int ef = 100});
  void clear();
  Map<String, dynamic> stats(); // {layers, nodes, connections}
}
```

### 2.4 User Stories — Phase 1

#### US-1.1: 语义搜索速度提升

> **作为** 一个有 1000+ 条笔记的知识工作者
> **我想要** 在搜索栏输入中文关键词后不到 0.5 秒就能看到结果
> **以便** 我可以流畅地在大量笔记中快速定位信息

**验收标准 (AC)**:
- AC-1.1.1: 2000 条笔记环境下，`SemanticSearch.search()` 单次耗时 ≤ 5ms
- AC-1.1.2: 5000 条笔记环境下，单次耗时 ≤ 15ms
- AC-1.1.3: 搜索结果与暴力扫描的 Top-10 至少有 8 条重叠 (召回率 ≥80%)

#### US-1.2: 笔记保存后自动索引

> **作为** 用户
> **我想要** 保存/创建笔记后它自动进入语义搜索索引
> **以便** 我刚写的笔记就能被搜到

**验收标准 (AC)**:
- AC-1.2.1: `onNoteSaved()` 调用后，同一条笔记在 100ms 内可被 `search()` 命中
- AC-1.2.2: 索引中有 2000 条笔记时，新增一条的 `insert()` 耗时 ≤ 50ms

#### US-1.3: 删除笔记后索引同步清理

> **作为** 用户
> **我想要** 删除的笔记不再出现在搜索结果中
> **以便** 我的搜索结果始终反映最新状态

**验收标准 (AC)**:
- AC-1.3.1: `remove(noteId)` 后该笔记不可被 `search()` 查到
- AC-1.3.2: `remove()` 不存在的 id 时静默成功，不抛异常

#### US-1.4: 语义搜索作为用户切换后的降级方案

> **作为** 用户
> **我想要** 即使未配置 Ollama 或远程 Embedding API，语义搜索仍能工作
> **以便** 打开软件就能用

**验收标准 (AC)**:
- AC-1.4.1: 使用本地 n-gram embedding 时，HNSW 正常返回结果
- AC-1.4.2: 本地 n-gram 结果与 Ollama 结果的重叠率 ≥ 50%

---

## 3. Phase 2: GraphFilter 图算法增强

### 3.1 技术方案

在当前 `GraphFilter` 基础上，新增 4 个图算法能力：

```
GraphFilter
├── getLocalGraph(id, depth)     ← 现有，保留
├── shortestPath(fromId, toId)    ← 新增：双向 BFS
├── pageRank(opts)                ← 新增：幂迭代
├── connectedComponents()         ← 新增：并查集
├── getBridgeNodes()              ← 新增：关键节点
└── getGraphStats()               ← 新增：图统计
```

**GraphPageData** 模型新增字段：

```dart
class GraphPageData {
  // ...existing fields...
  final List<BridgeNode> bridgeNodes;
  final Map<String, double> pageRanks;
  final GraphStats stats;
}
```

### 3.2 算法选择与复杂度

| 算法 | 实现方式 | 复杂度 | 适用规模 |
|------|---------|--------|---------|
| shortestPath | 双向 BFS (无向图) | O(V+E) | 全量 |
| pageRank | 幂迭代 (50轮, damping=0.85) | O(iter × E) | ≤5000节点 |
| connectedComponents | 并查集 (Union-Find with 路径压缩) | O(E × α(V)) | 全量 |
| bridgeNodes | Tarjan 桥算法 (DFS) | O(V+E) | 全量 |
| graphStats | 一次遍历 | O(V+E) | 全量 |

### 3.3 文件变更清单

| 文件 | 操作 | 说明 |
|------|------|------|
| `lib/core/graph/filter_engine.dart` | **修改** | 新增方案 |
| `lib/core/graph/graph_algorithm.dart` | **新增** | 图算法实现 |
| `lib/data/models/graph_stat.dart` | **新增** | BridgeNode, GraphStats |
| `lib/ui/pages/graph_page.dart` | **修改** | 新增 bridgeNode marker |
| `lib/ui/widgets/graph_stats_card.dart` | **新增** | 图统计卡片 |
| `test/core/graph/graph_algorithm_test.dart` | **新增** | 单元测试 |

### 3.4 User Stories — Phase 2

#### US-2.1: 发现两篇笔记之间的连接路径

> **作为** 用户
> **我想要** 在图谱视图中选择两个节点后看到它们之间的最短路径
> **以便** 我能理解两个看似无关的概念是如何通过其他笔记关联起来的

**验收标准 (AC)**:
- AC-2.1.1: `shortestPath(A, B)` 返回从 A 到 B 的最短节点序列（含首尾）
- AC-2.1.2: 两节点不连通时返回空列表（不抛异常）
- AC-2.1.3: 2000 节点 3000 边的图，最短路径计算 ≤ 30ms

#### US-2.2: 识别知识库中的关键枢纽笔记

> **作为** 用户
> **我想要** 看到哪些笔记是图谱中的"桥梁"节点（删除后会断开图的笔记）
> **以便** 我知道哪些笔记在知识体系中最为关键

**验收标准 (AC)**:
- AC-2.2.1: `getBridgeNodes()` 返回所有桥节点列表
- AC-2.2.2: 桥节点在图谱页面用红色星标标记
- AC-2.2.3: 至少提供一个单元测试验证已知的桥（如链状图的中部节点）

#### US-2.3: 查看知识图谱整体统计

> **作为** 用户
> **我想要** 看到图谱的基本统计信息（节点数、边数、平均连接度、最大连通分量大小）
> **以便** 我了解知识库的整体连接状况

**验收标准 (AC)**:
- AC-2.3.1: `getGraphStats()` 返回: totalNodes, totalEdges, avgDegree, componentCount, maxComponentSize
- AC-2.3.2: 统计值在 `GraphStatsCard` UI 组件中展示
- AC-2.3.3: 1000 条笔记 + 2000 条链接，统计计算 ≤ 5ms

#### US-2.4: PageRank 中心性排序

> **作为** 用户
> **我想要** 按 PageRank 值查看笔记的重要性排序
> **以便** 我能快速定位知识库中最核心的笔记

**验收标准 (AC)**:
- AC-2.4.1: `pageRank()` 返回 Map<String, double>，值在 0-1 之间，和为 1
- AC-2.4.2: 链状图 A→B→C 中，pageRank(B) > pageRank(A) 且 pageRank(B) > pageRank(C)
- AC-2.4.3: 1000 节点图，50 轮迭代 ≤ 100ms

---

## 4. Phase 3: Tantivy FFI 全文搜索

### 4.1 技术方案

通过 Rust C ABI 将 Tantivy 嵌入 Flutter，配置 jieba-rs 或 lindera 做 CJK 分词。

```
Flutter (Dart)                    Rust (C ABI)
┌──────────────────┐           ┌─────────────────────┐
│  TantivyBridge   │──dart:ffi──→ tantivy_search()    │
│  .search()       │           │ tantivy_index()      │
│  .index()        │           │ tantivy_delete()     │
│  .delete()       │           │ tantivy_stats()      │
│  .rebuild()      │           │                      │
└──────────────────┘           │ Tantivy Index        │
                               │ ├── schema:          │
                               │ │   id, title,       │
                               │ │   content, tags,   │
                               │ │   file_path        │
                               │ ├── tokenizer:       │
                               │ │   jieba (中文)     │
                               │ └── scorer: BM25     │
                               └─────────────────────┘
```

### 4.2 Rust 依赖

```toml
# Cargo.toml
[dependencies]
tantivy = "0.22"
jieba-rs = "0.7"       # 中文分词
serde = "1.0"          # JSON 序列化
serde_json = "1.0"
```

### 4.3 Dart 桥接层设计

```dart
class TantivyBridge {
  static bool get isAvailable;

  Future<void> initialize(String indexPath);
  Future<void> indexNote(Note note);
  Future<void> removeNote(String noteId);
  Future<void> rebuildIndex(List<Note> notes);

  Future<TantivySearchResults> search(String query, {
    int topK = 20,
    List<String>? filterTags,
  });

  Future<void> close();
}

class TantivySearchResults {
  final List<TantivyHit> hits;
  final int totalCount;
  final int elapsedMs;
}

class TantivyHit {
  final String noteId;
  final String title;
  final String snippet;     // 带高亮标记的片段
  final double score;
  final String filePath;
}
```

### 4.4 Tantivy 索引 schema

```
id:         STRING (stored, indexed)
title:      TEXT   (stored, indexed, tokenized with jieba)
content:    TEXT   (stored, indexed, tokenized with jieba)
tags:       TEXT   (stored, indexed, tokenized with raw)
file_path:  STRING (stored)
```

### 4.5 文件变更清单

| 路径 | 操作 | 说明 |
|------|------|------|
| `native/tantivy_bridge/Cargo.toml` | **新增** | Rust 项目配置 |
| `native/tantivy_bridge/src/lib.rs` | **新增** | Tantivy 核心逻辑 + C ABI |
| `native/tantivy_bridge/src/tokenizer.rs` | **新增** | jieba 分词配置 |
| `lib/services/tantivy_bridge.dart` | **新增** | Dart FFI 桥接层 |
| `lib/services/tantivy_bridge_stub.dart` | **新增** | 非支持平台的 stub |
| `lib/services/hybrid_search.dart` | **修改** | 使用 Tantivy 替代 FTS |
| `test/services/tantivy_bridge_test.dart` | **新增** | 集成测试 |
| `build.rs` / Makefile | **新增** | 三平台编译脚本 |

### 4.6 User Stories — Phase 3

#### US-3.1: 中文全文搜索可靠命中

> **作为** 中文用户
> **我想要** 搜索"量子纠缠"时能够找到所有包含这个短语或相关分词的笔记
> **以便** 中文搜索不再是碰运气

**验收标准 (AC)**:
- AC-3.1.1: 给定 5 篇中文笔记，其中 3 篇包含"代理模式"相关概念，搜索"代理"返回全部 3 篇
- AC-3.1.2: 搜索"模式"至少返回 2 篇（"代理模式"和"设计模式总结"）
- AC-3.1.3: 搜索无意义词"xyzwqk"返回 0 结果（不崩溃、不假阳性）

#### US-3.2: 搜索结果带关键词高亮

> **作为** 用户
> **我想要** 搜索结果中匹配的关键词被标记出来
> **以便** 我能快速判断每个结果的相关性

**验收标准 (AC)**:
- AC-3.2.1: 搜索"代理"，返回结果的 snippet 中包含 `**代理**` 包裹的片段
- AC-3.2.2: snippet 长度 ≤ 200 字符，截断处填充 `...`

#### US-3.3: 搜索结果按相关性排序

> **作为** 用户
> **我想要** 最匹配的笔记排在搜索结果最前面
> **以便** 我不需要翻页就能找到最相关的信息

**验收标准 (AC)**:
- AC-3.3.1: 搜索"量子"，标题为"量子力学入门"的笔记排名高于正文中仅提到一次"量子"的笔记
- AC-3.3.2: 完全匹配标题的得分 > 部分匹配标题 > 仅正文匹配

#### US-3.4: 搜索性能满足流畅体验

> **作为** 用户
> **我想要** 搜索结果在输入后立即显示
> **以便** 我感到搜索是即时的

**验收标准 (AC)**:
- AC-3.4.1: 5000 条笔记，`TantivyBridge.search()` ≤ 50ms
- AC-3.4.2: 单条 `indexNote()` ≤ 20ms

#### US-3.5: 平台降级兼容

> **作为** 用户
> **我想要** 在不支持 Tantivy 的平台（如 Web）上搜索仍然能工作
> **以便** 不会因为功能缺失而无法使用

**验收标准 (AC)**:
- AC-3.5.1: 非支持平台自动 fallback 到 SQLite FTS5
- AC-3.5.2: fallback 时有明确的警告但不阻断用户操作

---

## 5. User Stories 汇总

| ID | Phase | 标题 | 优先级 |
|----|-------|------|--------|
| US-1.1 | P1 | 语义搜索速度提升 | P0 |
| US-1.2 | P1 | 笔记保存后自动索引 | P0 |
| US-1.3 | P1 | 删除笔记后索引同步清理 | P1 |
| US-1.4 | P1 | 本地 n-gram 降级方案 | P1 |
| US-2.1 | P2 | 发现两篇笔记之间的最短路径 | P1 |
| US-2.2 | P2 | 识别知识库中关键枢纽笔记 | P2 |
| US-2.3 | P2 | 查看知识图谱整体统计 | P2 |
| US-2.4 | P2 | PageRank 中心性排序 | P2 |
| US-3.1 | P3 | 中文全文搜索可靠命中 | P0 |
| US-3.2 | P3 | 搜索结果带关键词高亮 | P1 |
| US-3.3 | P3 | 搜索结果按相关性排序 | P1 |
| US-3.4 | P3 | 搜索性能满足流畅体验 | P1 |
| US-3.5 | P3 | 平台降级兼容 | P1 |

---

## 6. 自动化验收标准

以下所有测试必须在 CI 中通过，使用 `flutter test` 命令。

### 6.1 Phase 1 自动化测试

```dart
// === hnsw_index_test.dart ===

group('HnswIndex basic operations', () {
  test('AC-1.1 empty index returns empty results', () {
    final index = HnswIndex();
    final results = index.search([1.0, 0.0], k: 10);
    expect(results, isEmpty);
  });

  test('AC-1.2 insert and search returns the inserted node', () {
    final index = HnswIndex();
    index.insert('n1', [1.0, 0.0, 0.0]);
    final results = index.search([1.0, 0.0, 0.0], k: 1);
    expect(results.length, 1);
    expect(results.first.id, 'n1');
    expect(results.first.score, closeTo(1.0, 0.01));
  });

  test('AC-1.3 remove eliminates node from search', () {
    final index = HnswIndex();
    index.insert('n1', [1.0, 0.0]);
    index.remove('n1');
    expect(index.search([1.0, 0.0], k: 10), isEmpty);
  });

  test('AC-1.4 clear empties index', () {
    final index = HnswIndex();
    index.insert('n1', [1.0, 0.0]);
    index.clear();
    expect(index.size, 0);
    expect(index.search([1.0, 0.0], k: 10), isEmpty);
  });

  test('AC-1.5 many inserts do not crash', () {
    final index = HnswIndex(M: 8, efConstruction: 50);
    final rng = Random(42);
    for (var i = 0; i < 500; i++) {
      final vec = List.generate(128, (_) => rng.nextDouble());
      index.insert('n$i', vec);
    }
    expect(index.size, 500);
    final results = index.search(List.generate(128, (_) => rng.nextDouble()), k: 5);
    expect(results.length, 5);
  });
});

group('HnswIndex performance', () {
  test('AC-1.6 search ≤ 5ms for 2000 notes x 768d', () {
    final index = HnswIndex(M: 16, efConstruction: 200);
    final rng = Random(42);
    for (var i = 0; i < 2000; i++) {
      index.insert('n$i', List.generate(768, (_) => rng.nextDouble()));
    }
    final query = List.generate(768, (_) => rng.nextDouble());
    final sw = Stopwatch()..start();
    final results = index.search(query, k: 10, ef: 100);
    sw.stop();
    expect(results.length, 10);
    expect(sw.elapsedMicroseconds, lessThan(5000)); // ≤5ms
  });

  test('AC-1.7 insert ≤ 50ms for 2000 existing notes', () {
    final index = HnswIndex(M: 16, efConstruction: 200);
    final rng = Random(42);
    for (var i = 0; i < 2000; i++) {
      index.insert('n$i', List.generate(768, (_) => rng.nextDouble()));
    }
    final sw = Stopwatch()..start();
    index.insert('new', List.generate(768, (_) => rng.nextDouble()));
    sw.stop();
    expect(sw.elapsedMicroseconds, lessThan(50000)); // ≤50ms
  });

  test('AC-1.8 recall ≥ 80% against brute-force baseline', () {
    final index = HnswIndex(M: 16, efConstruction: 200);
    final rng = Random(42);
    final vectors = <String, List<double>>{};
    for (var i = 0; i < 500; i++) {
      final vec = List.generate(128, (_) => rng.nextDouble());
      vectors['n$i'] = vec;
      index.insert('n$i', vec);
    }

    for (var t = 0; t < 20; t++) {
      final query = List.generate(128, (_) => rng.nextDouble());

      // brute force
      final bruteTop10 = _bruteForceTopK(vectors, query, 10);
      final bruteIds = bruteTop10.map((e) => e.id).toSet();

      // HNSW
      final hnswTop10 = index.search(query, k: 10, ef: 100);
      final hnswIds = hnswTop10.map((e) => e.id).toSet();

      final overlap = bruteIds.intersection(hnswIds).length;
      expect(overlap, greaterThanOrEqualTo(8)); // ≥80% recall@10
    }
  });
});
```

### 6.2 Phase 2 自动化测试

```dart
// === graph_algorithm_test.dart ===

group('shortestPath', () {
  test('AC-2.1 finds path in simple chain A-B-C', () {
    final alg = GraphAlgorithm(allLinks: [
      Link(sourceId: 'A', targetId: 'B', type: LinkType.wikilink),
      Link(sourceId: 'B', targetId: 'C', type: LinkType.wikilink),
    ]);
    final path = alg.shortestPath('A', 'C');
    expect(path, ['A', 'B', 'C']);
  });

  test('AC-2.2 returns empty list when disconnected', () {
    final alg = GraphAlgorithm(allLinks: [
      Link(sourceId: 'A', targetId: 'B', type: LinkType.wikilink),
    ]);
    final path = alg.shortestPath('A', 'Z');
    expect(path, isEmpty);
  });

  test('AC-2.3 same node returns single-element path', () {
    final alg = GraphAlgorithm(allLinks: [
      Link(sourceId: 'A', targetId: 'B', type: LinkType.wikilink),
    ]);
    final path = alg.shortestPath('A', 'A');
    expect(path, ['A']);
  });
});

group('pageRank', () {
  test('AC-2.4 chain A->B->C: B has highest rank', () {
    final alg = GraphAlgorithm(allLinks: [
      Link(sourceId: 'A', targetId: 'B', type: LinkType.wikilink),
      Link(sourceId: 'B', targetId: 'C', type: LinkType.wikilink),
    ]);
    final ranks = alg.pageRank(iterations: 100, damping: 0.85);
    expect(ranks['B']!, greaterThan(ranks['A']!));
    expect(ranks['B']!, greaterThan(ranks['C']!));
  });

  test('AC-2.5 values sum to 1.0', () {
    final alg = GraphAlgorithm(allLinks: [
      Link(sourceId: 'A', targetId: 'B', type: LinkType.wikilink),
      Link(sourceId: 'B', targetId: 'A', type: LinkType.wikilink),
    ]);
    final ranks = alg.pageRank();
    final sum = ranks.values.fold(0.0, (a, b) => a + b);
    expect(sum, closeTo(1.0, 0.01));
  });
});

group('graphStats', () {
  test('AC-2.6 stats for 3 nodes, 2 edges', () {
    final alg = GraphAlgorithm(allNotes: _notes(3), allLinks: [
      Link(sourceId: 'A', targetId: 'B', type: LinkType.wikilink),
      Link(sourceId: 'B', targetId: 'C', type: LinkType.wikilink),
    ]);
    final stats = alg.getGraphStats();
    expect(stats.totalNodes, 3);
    expect(stats.totalEdges, 2);
    expect(stats.avgDegree, closeTo(4.0 / 3, 0.1));
  });
});
```

### 6.3 Phase 3 自动化测试

```dart
// === tantivy_bridge_test.dart ===

group('Tantivy Chinese FTS', () {
  late TantivyBridge bridge;

  setUp(() {
    bridge = TantivyBridge.forTesting();
    bridge.initialize(':memory:');
  });

  tearDown(() => bridge.close());

  test('AC-3.1 search "代理" finds all 3 related notes', () {
    bridge.indexNote(_note('n1', '代理模式', '这是代理模式的介绍'));
    bridge.indexNote(_note('n2', '反向代理', '配置Nginx反向代理'));
    bridge.indexNote(_note('n3', '设计模式总结', '包含代理、观察者等模式'));
    bridge.indexNote(_note('n4', 'Python基础', 'Python语法入门'));

    final results = bridge.search('代理', topK: 10);
    final ids = results.hits.map((h) => h.noteId).toSet();
    expect(ids, containsAll(['n1', 'n2', 'n3']));
    expect(ids, isNot(contains('n4')));
  });

  test('AC-3.2 snippet contains highlighted keywords', () {
    bridge.indexNote(_note('n1', '代理', '代理是一种结构型设计模式'));
    final results = bridge.search('代理');
    expect(results.hits.first.snippet, contains('**代理**'));
  });

  test('AC-3.3 exact title match ranks above body-only match', () {
    bridge.indexNote(_note('n_title', '量子力学入门', '从基础讲起'));
    bridge.indexNote(_note('n_body', '物理学笔记', '量子力学是近代物理的基础...'));

    final results = bridge.search('量子力学');
    final ranks = results.hits.map((h) => h.noteId).toList();
    expect(ranks.first, 'n_title');
  });

  test('AC-3.4 search performance ≤ 50ms for 5000 notes', () {
    for (var i = 0; i < 5000; i++) {
      bridge.indexNote(_note('n$i', '标题$i', '正文内容$i 量子'));
    }
    final sw = Stopwatch()..start();
    bridge.search('量子', topK: 10);
    sw.stop();
    expect(sw.elapsedMilliseconds, lessThan(50));
  });
});
```

---

## 7. 开发计划与里程碑

```
Week 1                 Week 2                 Week 3-4

Phase 1: HNSW          Phase 2: Graph         Phase 3: Tantivy
┌─────────────────┐   ┌─────────────────┐   ┌─────────────────────┐
│ Day 1-2:         │   │ Day 1:           │   │ Day 1-3:             │
│ 实现 HnswIndex   │   │ shortestPath +  │   │ Rust 项目搭建        │
│ 核心算法         │   │ 双向BFS         │   │ 编译脚本 (win/mac)   │
│                  │   │                  │   │                      │
│ Day 3:           │   │ Day 2:           │   │ Day 4-7:             │
│ 单元测试 +       │   │ pageRank +       │   │ jieba分词 +          │
│ 性能基准         │   │ 图统计           │   │ Tantivy schema       │
│                  │   │                  │   │ 核心index/search     │
│ Day 4:           │   │ Day 3:           │   │                      │
│ 接入             │   │ bridgeNode +     │   │ Day 8-10:            │
│ SemanticSearch   │   │ 并查集组件       │   │ Dart FFI 桥接        │
│                  │   │                  │   │ 集成测试             │
│ Day 5:           │   │ Day 4-5:         │   │                      │
│ 集成测试 +       │   │ UI 组件 +        │   │ Day 11-12:           │
│ 代码Review       │   │ 测试 + Review    │   │ 接入 HybridSearch    │
│                  │   │                  │   │                      │
│ Milestone 1 ✓    │   │ Milestone 2 ✓    │   │ Day 13-14:           │
│ flutter test 100%│   │ flutter test 100%│   │ 兼容性测试 + Review  │
└─────────────────┘   └─────────────────┘   │                      │
                                             │ Milestone 3 ✓        │
                                             │ 三平台编译通过       │
                                             └─────────────────────┘
```

### 里程碑定义

| 里程碑 | 定义 | 门禁条件 |
|--------|------|---------|
| M1: HNSW Ready | HNSW 替换 VectorStore 上线 | 全部 Phase 1 测试通过 + 回归测试全部通过 |
| M2: Graph Enhanced | 图算法全部就绪 | 全部 Phase 2 测试通过 + 回归测试全部通过 |
| M3: Tantivy Ready | Tantivy 替换 FTS5，三平台就绪 | 全部 Phase 3 测试通过 + 回归测试全部通过 |

---

## 8. 风险与缓解

| 风险 | 影响 | 概率 | 缓解措施 |
|------|------|------|---------|
| HNSW 召回率不足 | 搜索结果遗漏 | 低 | 设置 ef=100 确保 ≥80% recall；保留暴力扫描对比 |
| Tantivy 编译失败(macOS/Linux) | Phase 3 延期 | 中 | CI 三平台同时验证；预留 Week 4 缓冲 |
| Tantivy + jieba 内存超预算 | 低配设备卡顿 | 低 | 设置 index 内存上限；可选轻量分词 |
| FFI 桥接 JSON 序列化瓶颈 | 搜索变慢 | 低 | 使用 FlatBuffers 或直接内存布局替代 JSON |

---

*文档版本: 1.0 | 下次评审: M1 完成后*
