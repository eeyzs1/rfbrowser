import 'dart:async';

import 'package:sqflite/sqflite.dart';

import 'memory_database.dart';

/// Bulk JSON export / import for the memory DB. Used by the "Backup to
/// JSON" button in Memory Settings. Schema-versioned so future imports
/// can refuse incompatible payloads.
class MemoryBackupService {
  final MemoryDatabase _db;
  MemoryBackupService(this._db);

  Future<Database> get _database => _db.database;

  /// Snapshot the entire memory DB (fragments, summaries, Hebbian
  /// edges, FTS rows) as a JSON map.
  Future<Map<String, Object?>> exportToJson({
    DateTime? now,
    int schemaVersion = 4,
  }) async {
    final db = await _database;
    final fragments = await db.query('memory_fragments');
    final summaries = await db.query('memory_summaries');
    final edges = await db.query('memory_hebbian_links');
    final fts = await db.query('memory_fragments_fts');
    return {
      'schema_version': schemaVersion,
      'exported_at': (now ?? DateTime.now()).toIso8601String(),
      'fragments': fragments,
      'summaries': summaries,
      'hebbian_edges': edges,
      'fts_rows': fts,
      'counts': {
        'fragments': fragments.length,
        'summaries': summaries.length,
        'hebbian_edges': edges.length,
        'fts_rows': fts.length,
      },
    };
  }

  /// Restore from a JSON map produced by [exportToJson]. Existing
  /// rows are kept; new rows are inserted. Use
  /// [replaceExisting]=true to wipe + insert (destructive).
  Future<({int fragments, int summaries, int hebbianEdges})> importFromJson(
    Map<String, Object?> json, {
    bool replaceExisting = false,
  }) async {
    final version = json['schema_version'] as int? ?? 0;
    if (version < 2) {
      throw const FormatException(
        'Backup schema < 2 is not supported by this build',
      );
    }
    final db = await _database;
    if (replaceExisting) {
      await db.transaction((txn) async {
        await txn.delete('memory_hebbian_links');
        await txn.delete('memory_fragments_fts');
        await txn.delete('memory_summaries');
        await txn.delete('memory_fragments');
      });
    }
    var fragments = 0;
    var summaries = 0;
    var edges = 0;
    await db.transaction((txn) async {
      for (final row in (json['fragments'] as List? ?? const [])) {
        if (row is! Map) continue;
        await txn.insert(
          'memory_fragments',
          Map<String, Object?>.from(row),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        fragments++;
      }
      for (final row in (json['summaries'] as List? ?? const [])) {
        if (row is! Map) continue;
        await txn.insert(
          'memory_summaries',
          Map<String, Object?>.from(row),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        summaries++;
      }
      for (final row in (json['hebbian_edges'] as List? ?? const [])) {
        if (row is! Map) continue;
        await txn.insert(
          'memory_hebbian_links',
          Map<String, Object?>.from(row),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        edges++;
      }
      for (final row in (json['fts_rows'] as List? ?? const [])) {
        if (row is! Map) continue;
        await txn.insert(
          'memory_fragments_fts',
          Map<String, Object?>.from(row),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
    return (fragments: fragments, summaries: summaries, hebbianEdges: edges);
  }
}
