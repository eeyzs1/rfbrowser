import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/data/models/sync_conflict.dart';

void main() {
  group('ConflictResolution', () {
    test('has all three values', () {
      expect(ConflictResolution.values, hasLength(3));
      expect(ConflictResolution.values, contains(ConflictResolution.keepLocal));
      expect(
        ConflictResolution.values,
        contains(ConflictResolution.keepRemote),
      );
      expect(ConflictResolution.values, contains(ConflictResolution.keepBoth));
    });
  });

  group('SyncConflict', () {
    test('stores all fields', () {
      final localTime = DateTime.parse('2025-03-10T08:00:00.000');
      final remoteTime = DateTime.parse('2025-03-10T09:00:00.000');

      final conflict = SyncConflict(
        relativePath: 'notes/daily/2025-03-10.md',
        localModified: localTime,
        remoteModified: remoteTime,
        localContent: 'local text',
        remoteContent: 'remote text',
      );

      expect(conflict.relativePath, 'notes/daily/2025-03-10.md');
      expect(conflict.localModified, localTime);
      expect(conflict.remoteModified, remoteTime);
      expect(conflict.localContent, 'local text');
      expect(conflict.remoteContent, 'remote text');
    });

    test('allows nullable fields to be null', () {
      final conflict = SyncConflict(relativePath: 'test.md');

      expect(conflict.relativePath, 'test.md');
      expect(conflict.localModified, isNull);
      expect(conflict.remoteModified, isNull);
      expect(conflict.localContent, isNull);
      expect(conflict.remoteContent, isNull);
    });
  });

  group('SyncProgress', () {
    test('defaults are correct', () {
      final progress = SyncProgress();

      expect(progress.filesProcessed, 0);
      expect(progress.totalFiles, 0);
      expect(progress.currentFile, '');
      expect(progress.isUploading, false);
    });

    test('copyWith preserves unchanged fields', () {
      final original = SyncProgress(
        filesProcessed: 5,
        totalFiles: 10,
        currentFile: 'note.md',
        isUploading: true,
      );

      final updated = original.copyWith(filesProcessed: 7);

      expect(updated.filesProcessed, 7);
      expect(updated.totalFiles, 10);
      expect(updated.currentFile, 'note.md');
      expect(updated.isUploading, true);
    });

    test('copyWith updates multiple fields', () {
      final original = SyncProgress(
        filesProcessed: 3,
        totalFiles: 10,
        currentFile: 'a.md',
        isUploading: false,
      );

      final updated = original.copyWith(
        filesProcessed: 4,
        currentFile: 'b.md',
        isUploading: true,
      );

      expect(updated.filesProcessed, 4);
      expect(updated.totalFiles, 10);
      expect(updated.currentFile, 'b.md');
      expect(updated.isUploading, true);
    });

    test('progress calculates correctly', () {
      final progress = SyncProgress(filesProcessed: 3, totalFiles: 10);

      expect(progress.progress, closeTo(0.3, 0.001));
    });

    test('progress is 0 when totalFiles is 0', () {
      final progress = SyncProgress(filesProcessed: 0, totalFiles: 0);

      expect(progress.progress, 0.0);
    });

    test('progress is 1.0 when fully complete', () {
      final progress = SyncProgress(filesProcessed: 10, totalFiles: 10);

      expect(progress.progress, 1.0);
    });
  });
}
