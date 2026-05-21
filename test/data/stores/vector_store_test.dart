import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:rfbrowser/data/stores/vector_store.dart';

void main() {
  group('VectorStore', () {
    late VectorStore store;

    setUp(() {
      store = VectorStore();
    });

    group('insert / exists / remove', () {
      test('插入后存在', () {
        store.insert('v1', [1.0, 0.0, 0.0]);
        expect(store.exists('v1'), true);
        expect(store.count, 1);
      });

      test('插入多条记录', () {
        store.insert('v1', [1.0, 0.0]);
        store.insert('v2', [0.0, 1.0]);
        store.insert('v3', [0.0, 0.0]);
        expect(store.count, 3);
      });

      test('删除后不存在', () {
        store.insert('v1', [1.0, 0.0]);
        store.remove('v1');
        expect(store.exists('v1'), false);
        expect(store.count, 0);
      });

      test('删除不存在的 ID 不报错', () {
        store.remove('nonexistent');
        expect(store.count, 0);
      });

      test('插入相同 ID 覆盖', () {
        store.insert('v1', [1.0, 0.0]);
        store.insert('v1', [0.0, 1.0]);
        expect(store.count, 1);
      });

      test('clear 清空所有', () {
        store.insert('v1', [1.0]);
        store.insert('v2', [0.0]);
        store.clear();
        expect(store.count, 0);
        expect(store.exists('v1'), false);
      });

      test('带 metadata 插入', () {
        store.insert('v1', [1.0, 0.0], metadata: {'title': 'Test'});
        expect(store.exists('v1'), true);
      });
    });

    group('search', () {
      test('空存储返回空列表', () {
        final results = store.search([1.0, 0.0]);
        expect(results, isEmpty);
      });

      test('零向量查询返回空列表', () {
        store.insert('v1', [1.0, 0.0]);
        final results = store.search([0.0, 0.0]);
        expect(results, isEmpty);
      });

      test('零向量记录被跳过', () {
        store.insert('v1', [0.0, 0.0]);
        store.insert('v2', [1.0, 0.0]);
        final results = store.search([1.0, 0.0]);
        expect(results.length, 1);
        expect(results[0].id, 'v2');
      });

      test('不同维度向量被跳过', () {
        store.insert('v1', [1.0, 0.0]);
        store.insert('v2', [1.0, 0.0, 0.0]);
        final results = store.search([1.0, 0.0]);
        expect(results.length, 1);
        expect(results[0].id, 'v1');
      });

      test('余弦相似度排序 — 完全匹配排第一', () {
        store.insert('v1', [1.0, 0.0, 0.0]);
        store.insert('v2', [0.0, 1.0, 0.0]);
        store.insert('v3', [0.5, 0.5, 0.0]);

        final results = store.search([1.0, 0.0, 0.0]);
        expect(results.first.id, 'v1');
        expect(results.first.score, closeTo(1.0, 0.001));
      });

      test('余弦相似度排序 — 正交向量相似度为 0', () {
        store.insert('v1', [1.0, 0.0]);
        store.insert('v2', [0.0, 1.0]);

        final results = store.search([1.0, 0.0]);
        expect(results.length, 2);
        final v2Result = results.firstWhere((r) => r.id == 'v2');
        expect(v2Result.score, closeTo(0.0, 0.001));
      });

      test('topK 限制返回数量', () {
        for (var i = 0; i < 10; i++) {
          store.insert('v$i', [i.toDouble(), (10 - i).toDouble()]);
        }

        final results = store.search([1.0, 0.0], topK: 3);
        expect(results.length, 3);
      });

      test('topK 大于记录数返回全部', () {
        store.insert('v1', [1.0, 0.0]);
        store.insert('v2', [0.0, 1.0]);

        final results = store.search([1.0, 0.0], topK: 100);
        expect(results.length, 2);
      });

      test('结果按分数降序排列', () {
        store.insert('v1', [0.9, 0.1]);
        store.insert('v2', [0.5, 0.5]);
        store.insert('v3', [0.1, 0.9]);

        final results = store.search([1.0, 0.0]);
        for (var i = 0; i < results.length - 1; i++) {
          expect(results[i].score, greaterThanOrEqualTo(results[i + 1].score));
        }
      });

      test('相似向量高分', () {
        store.insert('similar', [0.99, 0.01, 0.0]);
        store.insert('different', [0.0, 0.0, 1.0]);

        final results = store.search([1.0, 0.0, 0.0]);
        expect(results.first.id, 'similar');
        expect(results.first.score, greaterThan(0.9));
      });

      test('metadata 保留在搜索结果中', () {
        store.insert('v1', [1.0, 0.0], metadata: {'title': 'Test Note'});
        final results = store.search([1.0, 0.0]);
        expect(results.first.metadata['title'], 'Test Note');
      });

      test('大量记录搜索性能', () {
        final random = Random(42);
        for (var i = 0; i < 1000; i++) {
          final embedding = List.generate(64, (_) => random.nextDouble());
          store.insert('v$i', embedding);
        }

        final query = List.generate(64, (_) => random.nextDouble());
        final stopwatch = Stopwatch()..start();
        final results = store.search(query, topK: 20);
        stopwatch.stop();

        expect(results.length, 20);
        expect(stopwatch.elapsedMilliseconds, lessThan(1000));
      });
    });
  });
}
