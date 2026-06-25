import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rfbrowser/data/models/chat_memory.dart';
import 'package:rfbrowser/services/hebbian_service.dart';
import 'package:rfbrowser/services/memory_service.dart';
import '../helpers/sqflite_test_setup.dart';

MemoryFragment _frag(String id) => MemoryFragment(
  id: id,
  sessionId: 's',
  content: 'content for $id',
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);

void main() {
  setUpAll(setupSqfliteForTests);

  group('HebbianService', () {
    late MemoryService memory;
    late HebbianService hebbian;
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('rfbrowser_hebbian_');
      memory = MemoryService(p.join(tempDir.path, 'memory.db'));
      hebbian = HebbianService(memory);
    });

    tearDown(() async {
      await memory.close();
      tempDir.deleteSync(recursive: true);
    });

    test('recordCoAccess creates edges between every pair', () async {
      await memory.upsertFragment(_frag('a'));
      await memory.upsertFragment(_frag('b'));
      await memory.upsertFragment(_frag('c'));
      await hebbian.recordCoAccess(['a', 'b', 'c']);
      final edgesForA = await memory.getHebbianEdgesFor('a');
      expect(edgesForA.length, 2); // a-b and a-c
      final bEdge = edgesForA.firstWhere((e) => e.otherEnd('a') == 'b');
      final cEdge = edgesForA.firstWhere((e) => e.otherEnd('a') == 'c');
      expect(bEdge.coAccessCount, 1);
      expect(cEdge.coAccessCount, 1);
    });

    test(
      'expandByHebbianLinks returns neighbors ranked by decayed strength',
      () async {
        // First create the fragments so hydration works.
        for (final id in ['center', 'a', 'b', 'c']) {
          await memory.upsertFragment(_frag(id));
        }
        // Build a star: 'center' is co-accessed with each of [a, b, c].
        await hebbian.recordCoAccess(['center', 'a']);
        await hebbian.recordCoAccess(['center', 'b']);
        await hebbian.recordCoAccess(['center', 'c']);
        // Reinforce 'center <-> b' multiple times so it ranks higher.
        for (var i = 0; i < 5; i++) {
          await hebbian.recordCoAccess(['center', 'b']);
        }
        final neighbors = await hebbian.expandByHebbianLinks(
          ['center'],
          limit: 5,
          minStrength: 0.0,
        );
        expect(neighbors.length, 3);
        // b should be ranked above a (more co-accesses).
        expect(neighbors.first.fragment.id, 'b');
        expect(
          neighbors.map((n) => n.fragment.id),
          containsAll(['a', 'b', 'c']),
        );
      },
    );

    test('expandByHebbianLinks excludes the seed set', () async {
      await memory.upsertFragment(_frag('a'));
      await memory.upsertFragment(_frag('b'));
      await hebbian.recordCoAccess(['a', 'b']);
      final neighbors = await hebbian.expandByHebbianLinks(['a', 'b']);
      expect(neighbors, isEmpty);
    });

    test('minStrength filter drops weak edges', () async {
      await memory.upsertFragment(_frag('a'));
      await memory.upsertFragment(_frag('b'));
      await hebbian.recordCoAccess(['a', 'b']);
      final all = await hebbian.expandByHebbianLinks(['a'], minStrength: 0.0);
      final filtered = await hebbian.expandByHebbianLinks([
        'a',
      ], minStrength: 10.0);
      expect(all, isNotEmpty);
      expect(filtered, isEmpty);
    });
  });
}
