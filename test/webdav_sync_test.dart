import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/data/stores/sync_store.dart';
import 'package:rfbrowser/data/models/sync_conflict.dart';

void main() {
  group('SyncStore', () {
    test('AC-P3-3-2: stores and retrieves ETag', () async {
      final store = SyncStore(inMemoryOnly: true);
      await store.load();
      await store.setMeta(SyncMeta(
        relativePath: 'notes/A.md',
        etag: 'etag-123',
        lastSynced: DateTime(2025, 1, 1),
      ));

      expect(store.getEtag('notes/A.md'), 'etag-123');
    });

    test('AC-P3-3-2: returns null ETag for unknown path', () async {
      final store = SyncStore(inMemoryOnly: true);
      await store.load();
      expect(store.getEtag('nonexistent.md'), isNull);
    });

    test('stores and retrieves lastSynced', () async {
      final store = SyncStore(inMemoryOnly: true);
      await store.load();
      final now = DateTime(2025, 5, 4);
      await store.setMeta(SyncMeta(
        relativePath: 'notes/B.md',
        lastSynced: now,
      ));

      expect(store.getLastSynced('notes/B.md'), now);
    });

    test('removes meta', () async {
      final store = SyncStore(inMemoryOnly: true);
      await store.load();
      await store.setMeta(SyncMeta(relativePath: 'notes/C.md', etag: 'e1'));
      expect(store.getEtag('notes/C.md'), 'e1');
      await store.removeMeta('notes/C.md');
      expect(store.getEtag('notes/C.md'), isNull);
    });
  });

  group('SyncConflict', () {
    test('AC-P3-3-4: conflict has required fields', () {
      final conflict = SyncConflict(
        relativePath: 'notes/A.md',
        localModified: DateTime(2025, 5, 1),
        remoteModified: DateTime(2025, 5, 2),
      );

      expect(conflict.relativePath, 'notes/A.md');
      expect(conflict.localModified, isNotNull);
      expect(conflict.remoteModified, isNotNull);
    });
  });

  group('ConflictResolution', () {
    test('has three resolution options', () {
      expect(ConflictResolution.values.length, 3);
      expect(ConflictResolution.values, contains(ConflictResolution.keepLocal));
      expect(ConflictResolution.values, contains(ConflictResolution.keepRemote));
      expect(ConflictResolution.values, contains(ConflictResolution.keepBoth));
    });
  });

  group('SyncProgress', () {
    test('AC-P3-3-7: progress fields update correctly', () {
      var progress = SyncProgress(
        filesProcessed: 3,
        totalFiles: 10,
        currentFile: 'A.md',
        isUploading: false,
      );

      expect(progress.filesProcessed, 3);
      expect(progress.totalFiles, 10);
      expect(progress.progress, closeTo(0.3, 0.01));

      progress = progress.copyWith(filesProcessed: 5);
      expect(progress.filesProcessed, 5);
      expect(progress.progress, closeTo(0.5, 0.01));
    });

    test('progress is 0 when totalFiles is 0', () {
      final progress = SyncProgress(filesProcessed: 0, totalFiles: 0);
      expect(progress.progress, 0.0);
    });

    test('progress is 1.0 when all files processed', () {
      final progress = SyncProgress(filesProcessed: 10, totalFiles: 10);
      expect(progress.progress, 1.0);
    });
  });

  group('SyncMeta', () {
    test('serializes and deserializes correctly', () {
      final meta = SyncMeta(
        relativePath: 'notes/test.md',
        etag: 'etag-abc',
        lastSynced: DateTime(2025, 5, 4, 12, 30),
        localModified: DateTime(2025, 5, 3, 10, 0),
      );

      final json = meta.toJson();
      final restored = SyncMeta.fromJson(json);

      expect(restored.relativePath, meta.relativePath);
      expect(restored.etag, meta.etag);
    });

    test('copyWith preserves unmodified fields', () {
      final meta = SyncMeta(
        relativePath: 'notes/test.md',
        etag: 'e1',
        lastSynced: DateTime(2025, 1, 1),
      );

      final updated = meta.copyWith(etag: 'e2');
      expect(updated.etag, 'e2');
      expect(updated.relativePath, meta.relativePath);
      expect(updated.lastSynced, meta.lastSynced);
    });
  });
}
