import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/note.dart';
import '../models/link.dart';
import '../models/link_type.dart';
import 'vault_store.dart';

class IndexStore {
  final String _dbPath;
  Database? _db;
  Completer<Database>? _initCompleter;

  static final _cjkPattern = RegExp(
    r'[\u4e00-\u9fff\u3400-\u4dbf\uf900-\ufaff]',
  );

  IndexStore(this._dbPath);

  static String tokenizeForFts(String text) {
    if (text.isEmpty) return text;
    final buffer = StringBuffer();
    var prevWasCjk = false;
    String? prevCjkChar;
    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);
      final isCjk = _cjkPattern.hasMatch(char);
      if (isCjk) {
        if (buffer.isNotEmpty && buffer.toString().runes.last != 0x20) {
          buffer.write(' ');
        }
        if (prevCjkChar != null) {
          buffer.write('$prevCjkChar$char ');
        }
        buffer.write(char);
        buffer.write(' ');
        prevCjkChar = char;
        prevWasCjk = true;
      } else {
        prevCjkChar = null;
        if (prevWasCjk && char != ' ') {
          buffer.write(' ');
        }
        buffer.write(char);
        prevWasCjk = false;
      }
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Future<Database> get database async {
    if (_db != null) return _db!;
    _initCompleter ??= Completer<Database>();
    if (!_initCompleter!.isCompleted) {
      _db = await _initDb();
      _initCompleter!.complete(_db!);
    }
    return _initCompleter!.future;
  }

  Future<Database> _initDb() async {
    final dir = Directory(p.dirname(_dbPath));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return openDatabase(
      _dbPath,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE notes (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            file_path TEXT NOT NULL,
            content TEXT,
            tags TEXT,
            source_url TEXT,
            created TEXT,
            modified TEXT
          )
        ''');
        await db.execute('''
          CREATE VIRTUAL TABLE notes_fts USING fts5(
            id UNINDEXED, title, content, tags,
            tokenize=porter
          )
        ''');
        await db.execute('''
          CREATE TABLE links (
            source_id TEXT NOT NULL,
            target_id TEXT NOT NULL,
            type TEXT NOT NULL,
            context TEXT,
            position INTEGER,
            PRIMARY KEY (source_id, target_id, type)
          )
        ''');
        await db.execute('CREATE INDEX idx_links_source ON links(source_id)');
        await db.execute('CREATE INDEX idx_links_target ON links(target_id)');
        await db.execute('''
          CREATE TABLE tags (
            name TEXT PRIMARY KEY,
            count INTEGER DEFAULT 1
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 3) {
          await db.execute('DROP TABLE IF EXISTS notes_fts');
          await db.execute('''
            CREATE VIRTUAL TABLE notes_fts USING fts5(
              id UNINDEXED, title, content, tags,
              tokenize=porter
            )
          ''');
        }
      },
    );
  }

  Future<void> indexNote(Note note) async {
    final db = await database;
    await db.insert('notes', {
      'id': note.id,
      'title': note.title,
      'file_path': note.filePath,
      'tags': note.tags.join(','),
      'source_url': note.sourceUrl,
      'created': note.created.toIso8601String(),
      'modified': note.modified.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('notes_fts', {
      'id': note.id,
      'title': tokenizeForFts(note.title),
      'content': tokenizeForFts(note.content),
      'tags': tokenizeForFts(note.tags.join(' ')),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    for (final tag in note.tags) {
      await db.rawInsert(
        'INSERT OR REPLACE INTO tags (name, count) VALUES (?, COALESCE((SELECT count FROM tags WHERE name = ?), 0) + 1)',
        [tag, tag],
      );
    }
  }

  Future<void> removeNote(String noteId) async {
    final db = await database;
    await db.delete('notes', where: 'id = ?', whereArgs: [noteId]);
    await db.delete('notes_fts', where: 'id = ?', whereArgs: [noteId]);
    await db.delete(
      'links',
      where: 'source_id = ? OR target_id = ?',
      whereArgs: [noteId, noteId],
    );
  }

  Future<void> updateNote(Note note) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('notes_fts', where: 'id = ?', whereArgs: [note.id]);
      await txn.insert('notes', {
        'id': note.id,
        'title': note.title,
        'file_path': note.filePath,
        'tags': note.tags.join(','),
        'source_url': note.sourceUrl,
        'created': note.created.toIso8601String(),
        'modified': note.modified.toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.insert('notes_fts', {
        'id': note.id,
        'title': tokenizeForFts(note.title),
        'content': tokenizeForFts(note.content),
        'tags': tokenizeForFts(note.tags.join(' ')),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<List<Map<String, dynamic>>> searchNotes(
    String query, {
    int limit = 50,
  }) async {
    final db = await database;
    final tokenized = tokenizeForFts(query);
    if (tokenized.isEmpty) return [];
    try {
      return await db.rawQuery(
        '''
        SELECT n.* FROM notes n
        INNER JOIN notes_fts f ON f.id = n.id
        WHERE notes_fts MATCH ?
        ORDER BY rank
        LIMIT ?
      ''',
        [tokenized, limit],
      );
    } catch (e) {
      debugPrint('FTS search error for "$tokenized": $e');
      return [];
    }
  }

  Future<void> indexLink(Link link) async {
    final db = await database;
    await db.insert('links', {
      'source_id': link.sourceId,
      'target_id': link.targetId,
      'type': link.type.name,
      'context': link.context,
      'position': link.position,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Link>> getBacklinks(String noteId, {int limit = 100}) async {
    final db = await database;
    final rows = await db.query(
      'links',
      where: 'target_id = ?',
      whereArgs: [noteId],
      limit: limit,
    );
    return rows.map((row) {
      final typeName = row['type'] as String;
      final linkType =
          LinkType.values.where((t) => t.name == typeName).firstOrNull ??
          LinkType.wikilink;
      return Link(
        sourceId: row['source_id'] as String,
        targetId: row['target_id'] as String,
        type: linkType,
        context: row['context'] as String?,
        position: row['position'] as int?,
      );
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getAllTags({int limit = 200}) async {
    final db = await database;
    return db.query('tags', orderBy: 'count DESC', limit: limit);
  }

  Future<void> rebuildIndex(List<Note> notes) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('notes');
      await txn.delete('notes_fts');
      await txn.delete('links');
      await txn.delete('tags');
      final batch = txn.batch();
      for (final note in notes) {
        batch.insert('notes', {
          'id': note.id,
          'title': note.title,
          'file_path': note.filePath,
          'tags': note.tags.join(','),
          'source_url': note.sourceUrl,
          'created': note.created.toIso8601String(),
          'modified': note.modified.toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        batch.insert('notes_fts', {
          'id': note.id,
          'title': tokenizeForFts(note.title),
          'content': tokenizeForFts(note.content),
          'tags': tokenizeForFts(note.tags.join(' ')),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        for (final tag in note.tags) {
          batch.rawInsert(
            'INSERT OR REPLACE INTO tags (name, count) VALUES (?, COALESCE((SELECT count FROM tags WHERE name = ?), 0) + 1)',
            [tag, tag],
          );
        }
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
    _initCompleter = null;
  }
}

final indexStoreProvider = Provider<IndexStore>((ref) {
  final vaultState = ref.watch(vaultProvider);
  IndexStore indexStore;
  if (vaultState.currentVault != null) {
    final dbPath = p.join(
      vaultState.currentVault!.path,
      '.rfbrowser',
      'index.db',
    );
    indexStore = IndexStore(dbPath);
  } else {
    indexStore = IndexStore(p.join('rfbrowser_default', 'index.db'));
  }
  ref.onDispose(() => indexStore.close());
  return indexStore;
});
