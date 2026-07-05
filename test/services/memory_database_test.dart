// Coverage map (acceptance criteria):
// AC-DB-01: database getter is lazy and returns the same instance on repeat
//           calls; concurrent callers resolve to the same instance.
// AC-DB-02: close() releases the connection and resets internal state so the
//           database can be reopened.
// AC-DB-03: All v4 tables (chat_sessions, chat_messages, memory_fragments,
//           memory_fragments_fts, memory_summaries, memory_hebbian_links)
//           are created on a fresh database.
// AC-DB-04: v3 source-tracking columns (source_message_id, source,
//           extra_json) and the v4 parent_summary_id column exist.
// AC-DB-05: Expected indexes (including v3/v4 additions) are created.
// AC-DB-06: CRUD (insert/query/update/delete) works on memory_fragments.
// AC-DB-07: Transactions commit on success and roll back on failure.
// AC-DB-08: Consolidation lock is single-flight and survives foreign releases.
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rfbrowser/services/memory/memory_database.dart';
import '../helpers/sqflite_test_setup.dart';

/// Minimal row for memory_fragments satisfying all NOT NULL columns that
/// have no DEFAULT. Extra columns are included to mirror production writes.
Map<String, Object?> _fragmentRow(
  String id, {
  String content = 'c',
  String tier = 'short',
}) => {
  'id': id,
  'session_id': 's',
  'content': content,
  'tier': tier,
  'is_active': 1,
  'importance_score': 0.0,
  'access_count': 0,
  'is_pinned': 0,
  'summary_tier': 'none',
  'source': 'auto',
  'created_at': DateTime.now().toIso8601String(),
  'updated_at': DateTime.now().toIso8601String(),
};

void main() {
  setUpAll(setupSqfliteForTests);

  group('MemoryDatabase — initialization (AC-DB-01, AC-DB-02)', () {
    late Directory tempDir;
    late String dbPath;
    late MemoryDatabase db;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('rfbrowser_memdb_init_');
      dbPath = p.join(tempDir.path, 'memory.db');
      db = MemoryDatabase(dbPath);
    });

    tearDown(() async {
      await db.close();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('database getter is lazy and returns the same instance', () async {
      final first = await db.database;
      final second = await db.database;
      expect(identical(first, second), isTrue);
    });

    test(
      'concurrent database getter calls resolve to the same instance',
      () async {
        final results = await Future.wait([
          db.database,
          db.database,
          db.database,
        ]);
        expect(identical(results[0], results[1]), isTrue);
        expect(identical(results[1], results[2]), isTrue);
      },
    );

    test('path accessor returns the constructor-provided path', () {
      expect(db.path, dbPath);
    });

    test(
      'open creates the parent directory tree if it does not exist',
      () async {
        final nestedPath = p.join(tempDir.path, 'nested', 'deep', 'memory.db');
        final nested = MemoryDatabase(nestedPath);
        await nested.database;
        expect(File(nestedPath).existsSync(), isTrue);
        await nested.close();
      },
    );

    test(
      'close resets internal state so the database can be reopened',
      () async {
        final first = await db.database;
        expect(first.isOpen, isTrue);
        await db.close();
        final reopened = await db.database;
        expect(reopened.isOpen, isTrue);
        expect(
          identical(reopened, first),
          isFalse,
          reason: 'a fresh Database instance should be produced after close',
        );
      },
    );
  });

  group('MemoryDatabase — schema (AC-DB-03, AC-DB-04, AC-DB-05)', () {
    late Directory tempDir;
    late MemoryDatabase db;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('rfbrowser_memdb_schema_');
      db = MemoryDatabase(p.join(tempDir.path, 'memory.db'));
    });

    tearDown(() async {
      await db.close();
      tempDir.deleteSync(recursive: true);
    });

    Future<List<String>> tableNames() async {
      final database = await db.database;
      final rows = await database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
      );
      return rows.map((r) => r['name'] as String).toList();
    }

    Future<Set<String>> indexNames() async {
      final database = await db.database;
      final rows = await database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' ORDER BY name",
      );
      return rows.map((r) => r['name'] as String).toSet();
    }

    test('creates all expected tables on a fresh database', () async {
      await db.database; // force creation
      final names = await tableNames();
      expect(
        names,
        containsAll(<String>[
          'chat_sessions',
          'chat_messages',
          'memory_fragments',
          'memory_fragments_fts',
          'memory_summaries',
          'memory_hebbian_links',
        ]),
      );
    });

    test('memory_fragments has the v3 source-tracking columns', () async {
      final database = await db.database;
      final rows = await database.rawQuery(
        'PRAGMA table_info(memory_fragments)',
      );
      final cols = rows.map((r) => r['name'] as String).toSet();
      expect(
        cols,
        containsAll(<String>['source_message_id', 'source', 'extra_json']),
      );
    });

    test('memory_summaries has the v4 parent_summary_id column', () async {
      final database = await db.database;
      final rows = await database.rawQuery(
        'PRAGMA table_info(memory_summaries)',
      );
      final cols = rows.map((r) => r['name'] as String).toSet();
      expect(cols, contains('parent_summary_id'));
    });

    test('creates the expected indexes (including v3/v4 additions)', () async {
      await db.database;
      final indexes = await indexNames();
      expect(
        indexes,
        containsAll(<String>[
          'idx_messages_session',
          'idx_fragments_active',
          'idx_fragments_tier',
          'idx_fragments_pinned',
          'idx_summaries_tier',
          'idx_hebbian_a',
          'idx_hebbian_b',
          'idx_fragments_source_message_id',
          'idx_summaries_parent_summary_id',
        ]),
      );
    });

    test('memory_fragments_fts is an FTS5 virtual table', () async {
      final database = await db.database;
      final rows = await database.rawQuery(
        "SELECT sql FROM sqlite_master WHERE type='table' "
        "AND name='memory_fragments_fts'",
      );
      expect(rows, hasLength(1));
      final sql = (rows.first['sql'] as String).toLowerCase();
      expect(sql, contains('fts5'));
    });
  });

  group('MemoryDatabase — CRUD on memory_fragments (AC-DB-06)', () {
    late Directory tempDir;
    late MemoryDatabase db;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('rfbrowser_memdb_crud_');
      db = MemoryDatabase(p.join(tempDir.path, 'memory.db'));
    });

    tearDown(() async {
      await db.close();
      tempDir.deleteSync(recursive: true);
    });

    test('insert and query a fragment row', () async {
      final database = await db.database;
      await database.insert(
        'memory_fragments',
        _fragmentRow('a', content: 'hello'),
      );
      final rows = await database.query(
        'memory_fragments',
        where: 'id = ?',
        whereArgs: ['a'],
      );
      expect(rows, hasLength(1));
      expect(rows.first['content'], 'hello');
    });

    test('update changes the stored row', () async {
      final database = await db.database;
      await database.insert(
        'memory_fragments',
        _fragmentRow('a', content: 'old'),
      );
      await database.update(
        'memory_fragments',
        {'content': 'new', 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: ['a'],
      );
      final rows = await database.query(
        'memory_fragments',
        where: 'id = ?',
        whereArgs: ['a'],
      );
      expect(rows.first['content'], 'new');
    });

    test('delete removes the row and reports the affected count', () async {
      final database = await db.database;
      await database.insert('memory_fragments', _fragmentRow('a'));
      final deleted = await database.delete(
        'memory_fragments',
        where: 'id = ?',
        whereArgs: ['a'],
      );
      expect(deleted, 1);
      final rows = await database.query(
        'memory_fragments',
        where: 'id = ?',
        whereArgs: ['a'],
      );
      expect(rows, isEmpty);
    });

    test('query with WHERE filter returns only matching rows', () async {
      final database = await db.database;
      await database.insert(
        'memory_fragments',
        _fragmentRow('a', tier: 'short'),
      );
      await database.insert('memory_fragments', _fragmentRow('b', tier: 'mid'));
      final shorts = await database.query(
        'memory_fragments',
        where: 'tier = ?',
        whereArgs: ['short'],
      );
      expect(shorts.map((r) => r['id']).toList(), ['a']);
    });
  });

  group('MemoryDatabase — transactions (AC-DB-07)', () {
    late Directory tempDir;
    late MemoryDatabase db;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('rfbrowser_memdb_txn_');
      db = MemoryDatabase(p.join(tempDir.path, 'memory.db'));
    });

    tearDown(() async {
      await db.close();
      tempDir.deleteSync(recursive: true);
    });

    test('transaction commits all writes on success', () async {
      final database = await db.database;
      await database.transaction((txn) async {
        await txn.insert('memory_fragments', _fragmentRow('t1'));
        await txn.insert('memory_fragments', _fragmentRow('t2'));
      });
      final rows = await database.query('memory_fragments');
      expect(rows.map((r) => r['id']).toSet(), {'t1', 't2'});
    });

    test('transaction rolls back when an exception is thrown', () async {
      final database = await db.database;
      try {
        await database.transaction((txn) async {
          await txn.insert('memory_fragments', _fragmentRow('r1'));
          throw StateError('boom');
        });
      } on StateError {
        // expected — the transaction must be rolled back.
      }
      final rows = await database.query(
        'memory_fragments',
        where: 'id = ?',
        whereArgs: ['r1'],
      );
      expect(rows, isEmpty, reason: 'rolled-back row must not persist');
    });
  });

  group('MemoryDatabase — consolidation lock (AC-DB-08)', () {
    late Directory tempDir;
    late MemoryDatabase db;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('rfbrowser_memdb_lock_');
      db = MemoryDatabase(p.join(tempDir.path, 'memory.db'));
    });

    tearDown(() async {
      await db.close();
      tempDir.deleteSync(recursive: true);
    });

    test('first acquisition succeeds, second is denied', () async {
      final first = await db.tryAcquireConsolidationLock();
      expect(first, isNotNull);
      final second = await db.tryAcquireConsolidationLock();
      expect(second, isNull, reason: 'second acquisition must be denied');
      db.releaseConsolidationLock(first!);
    });

    test('lock can be re-acquired after release', () async {
      final first = await db.tryAcquireConsolidationLock();
      db.releaseConsolidationLock(first!);
      final second = await db.tryAcquireConsolidationLock();
      expect(second, isNotNull);
      db.releaseConsolidationLock(second!);
    });

    test('release with a foreign completer is a no-op', () async {
      final first = await db.tryAcquireConsolidationLock();
      final foreign = Completer<void>();
      db.releaseConsolidationLock(foreign);
      final second = await db.tryAcquireConsolidationLock();
      expect(second, isNull, reason: 'foreign release must not clear the lock');
      db.releaseConsolidationLock(first!);
    });
  });
}
