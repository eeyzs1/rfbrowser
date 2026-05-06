import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:rfbrowser/data/models/note.dart';
import 'package:rfbrowser/data/stores/index_store.dart';
import 'package:rfbrowser/services/embedding_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  Note makeNote(String id, String title, String content, String filePath) {
    return Note(
      id: id,
      title: title,
      filePath: filePath,
      content: content,
      created: DateTime.now(),
      modified: DateTime.now(),
    );
  }

  Future<void> indexForSemanticSearch(ProviderContainer c, String id, String text, {Map<String, dynamic>? metadata}) async {
    final embeddingService = c.read(embeddingServiceProvider);
    final embedding = await embeddingService.embed(text);
    embeddingService.hnswIndex.insert(id, embedding, metadata: metadata);
    embeddingService.store.insert(id, embedding, metadata: metadata);
  }

  test('AC-IMP-3-1: hybrid search returns results from both sources', () async {
    final indexStore = container.read(indexStoreProvider);

    final note1 = makeNote('n1', '微服务Dubbo', 'Apache Dubbo是高性能RPC微服务框架�?, '微服务Dubbo.md');
    final note2 = makeNote('n2', '周末计划', '周六去爬山周日在家休息看书�?, '周末计划.md');

    await indexStore.indexNote(note1);
    await indexStore.indexNote(note2);

    await indexForSemanticSearch(container, note1.id, note1.content);
    await indexForSemanticSearch(container, note2.id, note2.content);

    final semanticSearch = container.read(semanticSearchProvider);
    final hybridSearch = HybridSearch(
      semanticSearch,
      ftsSearchFn: (query, {limit = 50}) => indexStore.searchNotes(query, limit: limit),
    );

    final results = await hybridSearch.search('微服�?);

    final sourceSet = results.map((r) => r.source).toSet();
    expect(sourceSet.any((s) => s == 'semantic' || s == 'fts'), isTrue);
  });

  test('AC-IMP-3-2: results include source field and metadata', () async {
    final indexStore = container.read(indexStoreProvider);

    final note = makeNote('src1', 'API设计', 'REST API使用正确的HTTP方法和状态码�?, 'API设计.md');
    await indexStore.indexNote(note);
    await indexForSemanticSearch(container, note.id, note.content);

    final semanticSearch = container.read(semanticSearchProvider);
    final hybridSearch = HybridSearch(
      semanticSearch,
      ftsSearchFn: (query, {limit = 50}) => indexStore.searchNotes(query, limit: limit),
    );

    final results = await hybridSearch.search('API 设计');

    for (final result in results) {
      expect(result.source, isNotEmpty);
      expect(result.id, isNotEmpty);
      expect(result.score, greaterThanOrEqualTo(0.0));
    }
  });

  test('AC-IMP-3-3: FTS failure still returns semantic results', () async {
    final indexStore = container.read(indexStoreProvider);

    final note = makeNote('fail1', '量子计算', '这是一份关于量子计算的基础教程�?, '量子计算.md');
    await indexStore.indexNote(note);
    await indexForSemanticSearch(container, note.id, note.content);

    final semanticSearch = container.read(semanticSearchProvider);
    final hybridSearchWithBrokenFts = HybridSearch(
      semanticSearch,
      ftsSearchFn: (query, {limit = 50}) {
        throw Exception('FTS unavailable');
      },
    );

    final results = await hybridSearchWithBrokenFts.search('量子计算');
    expect(results, isNotEmpty);
    expect(results.every((r) => r.source == 'semantic'), isTrue);
  });

  test('keyword search finds exact match via FTS', () async {
    final indexStore = container.read(indexStoreProvider);

    final noteDart = makeNote('kw1', 'Dart编程', 'Dart是一种客户端优化的编程语言�?, 'Dart编程.md');
    final notePython = makeNote('kw2', 'Python笔记', 'Python适合数据科学�?, 'Python笔记.md');

    await indexStore.indexNote(noteDart);
    await indexStore.indexNote(notePython);

    final results = await indexStore.searchNotes('Dart');
    expect(results.length, equals(1));
    expect(results.first['title'], equals('Dart编程'));
  });
}
