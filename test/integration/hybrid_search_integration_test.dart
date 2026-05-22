// ignore_for_file: avoid_print
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:rfbrowser/data/models/note.dart';
import 'package:rfbrowser/data/stores/index_store.dart';
import 'package:rfbrowser/services/embedding_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late IndexStore indexStore;
  late Directory tempDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('rfbrowser_fts_test_');
    final dbPath = p.join(tempDir.path, 'index.db');
    indexStore = IndexStore(dbPath);
  });

  tearDown(() async {
    try {
      await indexStore.close();
    } catch (_) {}
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
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

  test('keyword search finds exact match via FTS', () async {
    final noteDart = makeNote(
      'kw1',
      'Dart编程',
      'Dart是一种客户端优化的编程语言',
      'Dart编程.md',
    );

    await indexStore.indexNote(noteDart);

    final db = await indexStore.database;

    final ftsContent = await db.rawQuery("SELECT * FROM notes_fts_content");
    print('FTS content table: $ftsContent');

    final ftsIdxCols = await db.rawQuery("PRAGMA table_info(notes_fts_idx)");
    print('FTS idx columns: $ftsIdxCols');

    final ftsIdxAll = await db.rawQuery("SELECT * FROM notes_fts_idx LIMIT 10");
    print('FTS idx all: $ftsIdxAll');

    final matchTest = await db.rawQuery("SELECT * FROM notes_fts WHERE notes_fts MATCH 'kw1'");
    print('MATCH kw1: $matchTest');

    final matchDart = await db.rawQuery("SELECT * FROM notes_fts WHERE notes_fts MATCH '{title content}: dart'");
    print('MATCH explicit columns dart: $matchDart');

    final allResults = await indexStore.searchNotes('Dart');
    expect(allResults.length, equals(1));
  });

  test('keyword search finds Chinese match via FTS', () async {
    final note = makeNote(
      'c1',
      '量子计算',
      '这是一份关于量子计算的基础教程',
      '量子计算.md',
    );

    await indexStore.indexNote(note);

    final results = await indexStore.searchNotes('量子');
    expect(results.length, equals(1));
    expect(results.first['title'], equals('量子计算'));
  });

  test('hybrid search returns results from both sources', () async {
    final note1 = makeNote(
      'n1',
      '微服务Dubbo',
      'Apache Dubbo是高性能RPC微服务框架',
      '微服务Dubbo.md',
    );
    final note2 = makeNote('n2', '周末计划', '周六去爬山周日在家休息看书', '周末计划.md');

    await indexStore.indexNote(note1);
    await indexStore.indexNote(note2);

    final embeddingService = EmbeddingService();
    final emb1 = await embeddingService.embed(note1.content);
    final emb2 = await embeddingService.embed(note2.content);
    embeddingService.hnswIndex.insert(note1.id, emb1, metadata: {'title': note1.title});
    embeddingService.hnswIndex.insert(note2.id, emb2, metadata: {'title': note2.title});

    final semanticSearch = SemanticSearch(embeddingService);
    final hybridSearch = HybridSearch(
      semanticSearch,
      ftsSearchFn: (query, {limit = 50}) =>
          indexStore.searchNotes(query, limit: limit),
    );

    final results = await hybridSearch.search('微服务');
    expect(results, isNotEmpty);
  });

  test('FTS failure still returns semantic results', () async {
    final note = makeNote('fail1', '量子计算', '这是一份关于量子计算的基础教程', '量子计算.md');
    await indexStore.indexNote(note);

    final embeddingService = EmbeddingService();
    final emb = await embeddingService.embed(note.content);
    embeddingService.hnswIndex.insert(note.id, emb, metadata: {'title': note.title});

    final semanticSearch = SemanticSearch(embeddingService);
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

  test('results include source field and metadata', () async {
    final note = makeNote(
      'src1',
      'API设计',
      'REST API使用正确的HTTP方法和状态码',
      'API设计.md',
    );
    await indexStore.indexNote(note);

    final embeddingService = EmbeddingService();
    final emb = await embeddingService.embed(note.content);
    embeddingService.hnswIndex.insert(note.id, emb, metadata: {'title': note.title});

    final semanticSearch = SemanticSearch(embeddingService);
    final hybridSearch = HybridSearch(
      semanticSearch,
      ftsSearchFn: (query, {limit = 50}) =>
          indexStore.searchNotes(query, limit: limit),
    );

    final results = await hybridSearch.search('API 设计');

    for (final result in results) {
      expect(result.source, isNotEmpty);
      expect(result.id, isNotEmpty);
      expect(result.score, greaterThanOrEqualTo(0.0));
    }
  });
}
