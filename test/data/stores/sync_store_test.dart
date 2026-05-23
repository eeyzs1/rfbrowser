import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/data/stores/sync_store.dart';

void main() {
  group('SyncMeta', () {
    test('toJson includes all fields', () {
      final now = DateTime(2025, 5, 22, 10, 30);
      final meta = SyncMeta(
        relativePath: 'notes/test.md',
        etag: '"abc123"',
        lastSynced: now,
        localModified: now,
      );
      final json = meta.toJson();

      expect(json['relativePath'], 'notes/test.md');
      expect(json['etag'], '"abc123"');
      expect(json['lastSynced'], now.toIso8601String());
      expect(json['localModified'], now.toIso8601String());
    });

    test('fromJson parses all fields correctly', () {
      final now = DateTime(2025, 5, 22, 10, 30);
      final json = {
        'relativePath': 'notes/test.md',
        'etag': '"abc123"',
        'lastSynced': now.toIso8601String(),
        'localModified': now.toIso8601String(),
      };
      final meta = SyncMeta.fromJson(json);

      expect(meta.relativePath, 'notes/test.md');
      expect(meta.etag, '"abc123"');
      expect(meta.lastSynced, now);
      expect(meta.localModified, now);
    });

    test('fromJson handles null optional fields', () {
      final json = {
        'relativePath': 'notes/test.md',
        'etag': null,
        'lastSynced': null,
        'localModified': null,
      };
      final meta = SyncMeta.fromJson(json);

      expect(meta.relativePath, 'notes/test.md');
      expect(meta.etag, isNull);
      expect(meta.lastSynced, isNull);
      expect(meta.localModified, isNull);
    });

    test('copyWith preserves unchanged fields', () {
      final now = DateTime(2025, 5, 22, 10, 30);
      final meta = SyncMeta(
        relativePath: 'notes/test.md',
        etag: '"abc123"',
        lastSynced: now,
        localModified: now,
      );
      final copied = meta.copyWith();

      expect(copied.relativePath, 'notes/test.md');
      expect(copied.etag, '"abc123"');
      expect(copied.lastSynced, now);
      expect(copied.localModified, now);
    });

    test('copyWith updates specified fields', () {
      final now = DateTime(2025, 5, 22, 10, 30);
      final later = DateTime(2025, 5, 23, 12, 0);
      final meta = SyncMeta(
        relativePath: 'notes/test.md',
        etag: '"abc123"',
        lastSynced: now,
        localModified: now,
      );
      final copied = meta.copyWith(etag: '"def456"', lastSynced: later);

      expect(copied.relativePath, 'notes/test.md');
      expect(copied.etag, '"def456"');
      expect(copied.lastSynced, later);
      expect(copied.localModified, now);
    });
  });

  group('SyncStore', () {
    late SyncStore store;

    setUp(() {
      store = SyncStore(inMemoryOnly: true);
    });

    test('getMeta returns null for unknown path', () {
      expect(store.getMeta('unknown.md'), isNull);
    });

    test('setMeta stores and retrieves meta', () async {
      final meta = SyncMeta(relativePath: 'notes/test.md', etag: '"abc123"');
      await store.setMeta(meta);

      expect(store.getMeta('notes/test.md'), meta);
    });

    test('setMeta overwrites existing meta', () async {
      final meta1 = SyncMeta(relativePath: 'notes/test.md', etag: '"v1"');
      final meta2 = SyncMeta(relativePath: 'notes/test.md', etag: '"v2"');
      await store.setMeta(meta1);
      await store.setMeta(meta2);

      expect(store.getMeta('notes/test.md')?.etag, '"v2"');
    });

    test('removeMeta deletes stored meta', () async {
      final meta = SyncMeta(relativePath: 'notes/test.md', etag: '"abc123"');
      await store.setMeta(meta);
      await store.removeMeta('notes/test.md');

      expect(store.getMeta('notes/test.md'), isNull);
    });

    test('getEtag returns etag for stored path', () async {
      final meta = SyncMeta(relativePath: 'notes/test.md', etag: '"abc123"');
      await store.setMeta(meta);

      expect(store.getEtag('notes/test.md'), '"abc123"');
    });

    test('getLastSynced returns lastSynced for stored path', () async {
      final now = DateTime(2025, 5, 22, 10, 30);
      final meta = SyncMeta(relativePath: 'notes/test.md', lastSynced: now);
      await store.setMeta(meta);

      expect(store.getLastSynced('notes/test.md'), now);
    });

    test('getLocalModified returns localModified for stored path', () async {
      final now = DateTime(2025, 5, 22, 10, 30);
      final meta = SyncMeta(relativePath: 'notes/test.md', localModified: now);
      await store.setMeta(meta);

      expect(store.getLocalModified('notes/test.md'), now);
    });

    test('inMemoryOnly store throws on prefs access', () {
      expect(() => store.prefs, throwsUnsupportedError);
    });
  });
}
