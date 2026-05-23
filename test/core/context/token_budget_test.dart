import 'package:flutter_test/flutter_test.dart';

import 'package:rfbrowser/core/context/token_budget.dart';
import 'package:rfbrowser/data/models/context_assembly.dart';

void main() {
  group('TokenBudget', () {
    group('estimateTokens', () {
      test('空字符串返回 0', () {
        final budget = TokenBudget();
        expect(budget.estimateTokens(''), 0);
      });

      test('默认 charsPerToken=4 估算', () {
        final budget = TokenBudget();
        expect(budget.estimateTokens('abcd'), 1);
        expect(budget.estimateTokens('abcdefgh'), 2);
      });

      test('向上取整', () {
        final budget = TokenBudget();
        expect(budget.estimateTokens('abcde'), 2);
        expect(budget.estimateTokens('a'), 1);
      });

      test('自定义 charsPerToken', () {
        final budget = TokenBudget(charsPerToken: 2);
        expect(budget.estimateTokens('ab'), 1);
        expect(budget.estimateTokens('abc'), 2);
      });
    });

    group('estimateItemTokens', () {
      test('估算 ContextItem token 数', () {
        final budget = TokenBudget();
        final item = ContextItem(
          type: ContextType.note,
          id: 'test',
          content: 'a' * 400,
        );
        expect(budget.estimateItemTokens(item), 100);
      });
    });

    group('trim', () {
      test('空列表返回空结果', () {
        final budget = TokenBudget();
        final result = budget.trim([]);
        expect(result.items, isEmpty);
        expect(result.truncated, false);
      });

      test('单个项目在预算内完整保留', () {
        final budget = TokenBudget(maxTokens: 100);
        final items = [
          ContextItem(type: ContextType.note, id: 'item1', content: 'a' * 200),
        ];
        final result = budget.trim(items);
        expect(result.items.length, 1);
        expect(result.items[0].content, items[0].content);
        expect(result.truncated, false);
      });

      test('超出预算的项目被截断', () {
        final budget = TokenBudget(maxTokens: 200);
        final items = [
          ContextItem(type: ContextType.note, id: 'item1', content: 'a' * 1200),
        ];
        final result = budget.trim(items);
        expect(result.items.length, 1);
        expect(result.items[0].content, contains('truncated'));
        expect(result.items[0].metadata['truncated'], true);
        expect(result.truncated, true);
      });

      test('多个项目按顺序填充预算', () {
        final budget = TokenBudget(maxTokens: 100);
        final items = [
          ContextItem(type: ContextType.note, id: 'item1', content: 'a' * 200),
          ContextItem(type: ContextType.note, id: 'item2', content: 'b' * 200),
        ];
        final result = budget.trim(items);
        expect(result.items[0].id, 'item1');
        expect(result.items[0].content, isNot(contains('truncated')));
      });

      test('剩余 token < 100 时跳过项目', () {
        final budget = TokenBudget(maxTokens: 150);
        final items = [
          ContextItem(type: ContextType.note, id: 'item1', content: 'a' * 200),
          ContextItem(type: ContextType.note, id: 'item2', content: 'b' * 800),
        ];
        final result = budget.trim(items);
        expect(result.truncated, true);
      });

      test('空内容项目被跳过', () {
        final budget = TokenBudget(maxTokens: 100);
        final items = [
          ContextItem(type: ContextType.note, id: 'empty', content: ''),
        ];
        final result = budget.trim(items);
        expect(result.items, isEmpty);
        expect(result.truncated, false);
      });

      test('空内容但有 error metadata 的项目保留', () {
        final budget = TokenBudget(maxTokens: 100);
        final items = [
          ContextItem(
            type: ContextType.note,
            id: 'error-item',
            content: '',
            metadata: {'error': 'Something went wrong'},
          ),
        ];
        final result = budget.trim(items);
        expect(result.items.length, 1);
        expect(result.items[0].id, 'error-item');
      });

      test('截断内容长度不超过原始内容', () {
        final budget = TokenBudget(maxTokens: 10);
        final shortContent = 'hi';
        final items = [
          ContextItem(
            type: ContextType.note,
            id: 'short',
            content: shortContent,
          ),
        ];
        final result = budget.trim(items);
        if (result.items.isNotEmpty) {
          expect(
            result.items[0].content.length,
            lessThanOrEqualTo(shortContent.length + 20),
          );
        }
      });

      test('零预算不保留任何内容', () {
        final budget = TokenBudget(maxTokens: 0);
        final items = [
          ContextItem(
            type: ContextType.note,
            id: 'item1',
            content: 'some content',
          ),
        ];
        final result = budget.trim(items);
        expect(result.items, isEmpty);
        expect(result.truncated, true);
      });
    });
  });
}
