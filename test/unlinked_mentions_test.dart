import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/core/link/link_extractor.dart';
import 'package:rfbrowser/data/models/unlinked_mention.dart';

void main() {
  group('UnlinkedMentions', () {
    test('AC-P4-2-1: finds unlinked mention of note title', () {
      final extractor = LinkExtractor();
      final content = '量子计算是未来的技术方向';
      final titles = ['量子计算'];

      final mentions = extractor.findUnlinkedMentions(content, titles);
      expect(mentions.length, 1);
      expect(mentions.first.targetTitle, '量子计算');
    });

    test('AC-P4-2-3: linkMention wraps all occurrences', () {
      final content = '量子计算是未来的技术方向，量子计算将改变世界';
      final title = '量子计算';
      final result = content.replaceAll(title, '[[$title]]');
      expect(result, '[[量子计算]]是未来的技术方向，[[量子计算]]将改变世界');
    });

    test('AC-P4-2-4: short titles (< 3 chars) excluded', () {
      final extractor = LinkExtractor();
      final content = '这是一个A的测试';
      final titles = ['A'];

      final mentions = extractor.findUnlinkedMentions(content, titles);
      expect(mentions.length, 0);
    });

    test('2-char Chinese titles are excluded (length < 3)', () {
      final extractor = LinkExtractor();
      final content = '这是一个测试';
      final titles = ['测试'];

      final mentions = extractor.findUnlinkedMentions(content, titles);
      expect(mentions.length, 0);
    });

    test('3+ char titles are included', () {
      final extractor = LinkExtractor();
      final content = '量子计算是未来的技术方向';
      final titles = ['量子计算'];

      final mentions = extractor.findUnlinkedMentions(content, titles);
      expect(mentions.length, 1);
    });

    test('titles shorter than 3 chars are skipped by findUnlinkedMentions', () {
      final extractor = LinkExtractor();
      final content = '这是一个A的测试';
      final titles = ['A'];

      final mentions = extractor.findUnlinkedMentions(content, titles);
      expect(mentions.length, 0);
    });

    test('already linked titles are not reported', () {
      final extractor = LinkExtractor();
      final content = '[[量子计算]]是未来的技术方向';
      final titles = ['量子计算'];

      final mentions = extractor.findUnlinkedMentions(content, titles);
      expect(mentions.length, 0);
    });

    test('UnlinkedMentionResult model', () {
      final result = UnlinkedMentionResult(
        sourceNoteId: 'note-1',
        targetTitle: '量子计算',
        context: '...量子计算是...',
        position: 3,
      );

      expect(result.sourceNoteId, 'note-1');
      expect(result.targetTitle, '量子计算');
      expect(result.context, '...量子计算是...');
      expect(result.position, 3);
    });

    test('multiple unlinked mentions in same content', () {
      final extractor = LinkExtractor();
      final content = '深度学习和机器学习都是AI的分支';
      final titles = ['深度学习', '机器学习'];

      final mentions = extractor.findUnlinkedMentions(content, titles);
      expect(mentions.length, 2);
      final foundTitles = mentions.map((m) => m.targetTitle).toSet();
      expect(foundTitles, containsAll(['深度学习', '机器学习']));
    });
  });
}
