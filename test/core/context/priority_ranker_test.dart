import 'package:flutter_test/flutter_test.dart';

import 'package:rfbrowser/core/context/priority_ranker.dart';
import 'package:rfbrowser/data/models/context_assembly.dart';

void main() {
  group('PriorityRanker', () {
    late PriorityRanker ranker;

    setUp(() {
      ranker = PriorityRanker();
    });

    test('空列表返回空列表', () {
      final result = ranker.rank([]);
      expect(result, isEmpty);
    });

    test('单个项目返回自身', () {
      final items = [
        ContextItem(type: ContextType.note, id: 'a', content: 'content'),
      ];
      final result = ranker.rank(items);
      expect(result.length, 1);
      expect(result[0].id, 'a');
    });

    test('selection 优先级最高', () {
      final items = [
        ContextItem(type: ContextType.note, id: 'note1', content: 'c'),
        ContextItem(type: ContextType.selection, id: 'sel1', content: 'c'),
        ContextItem(type: ContextType.webPage, id: 'web1', content: 'c'),
      ];
      final result = ranker.rank(items);
      expect(result.first.type, ContextType.selection);
    });

    test('优先级顺序: selection > note > webPage > file > agentResult > screenshot', () {
      final items = [
        ContextItem(type: ContextType.screenshot, id: 'ss', content: 'c'),
        ContextItem(type: ContextType.agentResult, id: 'ar', content: 'c'),
        ContextItem(type: ContextType.file, id: 'fi', content: 'c'),
        ContextItem(type: ContextType.webPage, id: 'wp', content: 'c'),
        ContextItem(type: ContextType.note, id: 'no', content: 'c'),
        ContextItem(type: ContextType.selection, id: 'se', content: 'c'),
      ];
      final result = ranker.rank(items);
      expect(result[0].type, ContextType.selection);
      expect(result[1].type, ContextType.note);
      expect(result[2].type, ContextType.webPage);
      expect(result[3].type, ContextType.file);
      expect(result[4].type, ContextType.agentResult);
      expect(result[5].type, ContextType.screenshot);
    });

    test('同优先级按 id 字母排序', () {
      final items = [
        ContextItem(type: ContextType.note, id: 'c', content: 'c'),
        ContextItem(type: ContextType.note, id: 'a', content: 'c'),
        ContextItem(type: ContextType.note, id: 'b', content: 'c'),
      ];
      final result = ranker.rank(items);
      expect(result[0].id, 'a');
      expect(result[1].id, 'b');
      expect(result[2].id, 'c');
    });

    test('不修改原始列表', () {
      final items = [
        ContextItem(type: ContextType.webPage, id: 'web1', content: 'c'),
        ContextItem(type: ContextType.note, id: 'note1', content: 'c'),
      ];
      final originalOrder = items.map((i) => i.id).toList();
      ranker.rank(items);
      expect(items.map((i) => i.id).toList(), originalOrder);
    });

    test('混合类型正确排序', () {
      final items = [
        ContextItem(type: ContextType.file, id: 'file1', content: 'c'),
        ContextItem(type: ContextType.selection, id: 'sel1', content: 'c'),
        ContextItem(type: ContextType.note, id: 'note1', content: 'c'),
      ];
      final result = ranker.rank(items);
      expect(result[0].id, 'sel1');
      expect(result[1].id, 'note1');
      expect(result[2].id, 'file1');
    });
  });
}
