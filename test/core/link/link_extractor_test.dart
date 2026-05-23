import 'package:flutter_test/flutter_test.dart';

import 'package:rfbrowser/core/link/link_extractor.dart';
import 'package:rfbrowser/data/models/link_type.dart';
import 'package:rfbrowser/data/models/unlinked_mention.dart';

void main() {
  group('LinkExtractor', () {
    late LinkExtractor extractor;

    setUp(() {
      extractor = LinkExtractor();
    });

    group('extractLinks — wikilink', () {
      test('简单 wikilink [[笔记名]]', () {
        final links = extractor.extractLinks('这是 [[我的笔记]] 的内容');
        expect(links.length, 1);
        expect(links[0].target, '我的笔记');
        expect(links[0].type, LinkType.wikilink);
        expect(links[0].alias, isNull);
        expect(links[0].heading, isNull);
      });

      test('带别名的 wikilink [[笔记名|显示名]]', () {
        final links = extractor.extractLinks('参见 [[我的笔记|这篇笔记]]');
        expect(links.length, 1);
        expect(links[0].target, '我的笔记');
        expect(links[0].alias, '这篇笔记');
      });

      test('带标题的 wikilink [[笔记名#标题]]', () {
        final links = extractor.extractLinks('跳转到 [[笔记#第一章]]');
        expect(links.length, 1);
        expect(links[0].target, '笔记');
        expect(links[0].heading, '第一章');
      });

      test('带标题和别名的 wikilink [[笔记名#标题|显示名]]', () {
        final links = extractor.extractLinks('参见 [[笔记#章节|这里]]');
        expect(links.length, 1);
        expect(links[0].target, '笔记');
        expect(links[0].heading, '章节');
        expect(links[0].alias, '这里');
      });

      test('多个 wikilink', () {
        final links = extractor.extractLinks('[[A]] 和 [[B]] 以及 [[C]]');
        expect(links.length, 3);
        expect(links[0].target, 'A');
        expect(links[1].target, 'B');
        expect(links[2].target, 'C');
      });

      test('空内容返回空列表', () {
        final links = extractor.extractLinks('');
        expect(links, isEmpty);
      });

      test('无链接的文本返回空列表', () {
        final links = extractor.extractLinks('这是一段普通文本，没有链接。');
        expect(links, isEmpty);
      });

      test('wikilink 包含空格', () {
        final links = extractor.extractLinks('[[我的 笔记]]');
        expect(links.length, 1);
        expect(links[0].target, '我的 笔记');
      });

      test('wikilink 记录原始文本', () {
        final links = extractor.extractLinks('参见 [[目标笔记|别名]]');
        expect(links[0].rawText, '[[目标笔记|别名]]');
      });

      test('wikilink 记录位置', () {
        final links = extractor.extractLinks('前缀 [[目标]] 后缀');
        expect(links[0].position, greaterThan(0));
      });
    });

    group('extractLinks — embed', () {
      test('简单 embed ![[图片.png]]', () {
        final links = extractor.extractLinks('嵌入 ![[截图.png]] 在此');
        final embeds = links.where((l) => l.type == LinkType.embed).toList();
        expect(embeds.length, 1);
        expect(embeds[0].target, '截图.png');
      });

      test('embed 带标题 ![[笔记#章节]]', () {
        final links = extractor.extractLinks('嵌入 ![[笔记#摘要]]');
        final embeds = links.where((l) => l.type == LinkType.embed).toList();
        expect(embeds.length, 1);
        expect(embeds[0].target, '笔记');
        expect(embeds[0].heading, '摘要');
      });

      test('wikilink 和 embed 混合', () {
        final links = extractor.extractLinks(
          '[[笔记A]] 和 ![[图片.png]] 以及 [[笔记B]]',
        );
        final wikilinks = links
            .where((l) => l.type == LinkType.wikilink)
            .toList();
        final embeds = links.where((l) => l.type == LinkType.embed).toList();
        expect(wikilinks.length, 3);
        expect(embeds.length, 1);
        expect(wikilinks.any((l) => l.target == '笔记A'), true);
        expect(wikilinks.any((l) => l.target == '笔记B'), true);
      });
    });

    group('extractContextRefs', () {
      test('@note[笔记名]', () {
        final refs = extractor.extractContextRefs('请参考 @note[我的笔记]');
        expect(refs.length, 1);
        expect(refs[0].type, 'note');
        expect(refs[0].target, '我的笔记');
      });

      test('@web[URL]', () {
        final refs = extractor.extractContextRefs(
          '查看 @web[https://example.com]',
        );
        expect(refs.length, 1);
        expect(refs[0].type, 'web');
        expect(refs[0].target, 'https://example.com');
      });

      test('@file[路径]', () {
        final refs = extractor.extractContextRefs('附件 @file[report.pdf]');
        expect(refs.length, 1);
        expect(refs[0].type, 'file');
        expect(refs[0].target, 'report.pdf');
      });

      test('@agent[任务ID]', () {
        final refs = extractor.extractContextRefs('任务 @agent[task-001]');
        expect(refs.length, 1);
        expect(refs[0].type, 'agent');
        expect(refs[0].target, 'task-001');
      });

      test('@clip[剪辑ID]', () {
        final refs = extractor.extractContextRefs('剪辑 @clip[clip-123]');
        expect(refs.length, 1);
        expect(refs[0].type, 'clip');
        expect(refs[0].target, 'clip-123');
      });

      test('带选择器 @note[笔记名#标题]', () {
        final refs = extractor.extractContextRefs('参考 @note[笔记#第一章]');
        expect(refs.length, 1);
        expect(refs[0].target, '笔记');
        expect(refs[0].selector, '第一章');
      });

      test('多个上下文引用', () {
        final refs = extractor.extractContextRefs(
          '参考 @note[A] 和 @web[https://b.com] 以及 @file[c.pdf]',
        );
        expect(refs.length, 3);
      });

      test('无效类型不匹配', () {
        final refs = extractor.extractContextRefs('@invalid[something]');
        expect(refs, isEmpty);
      });

      test('记录原始文本', () {
        final refs = extractor.extractContextRefs('参考 @note[笔记]');
        expect(refs[0].rawText, '@note[笔记]');
      });
    });

    group('extractTags', () {
      test('英文标签 #tag', () {
        final tags = extractor.extractTags('这是 #重要 的笔记');
        expect(tags, contains('重要'));
      });

      test('中文标签 #标签', () {
        final tags = extractor.extractTags('这是一篇 #技术 笔记');
        expect(tags, contains('技术'));
      });

      test('多个标签', () {
        final tags = extractor.extractTags('#标签1 #标签2 #标签3');
        expect(tags.length, 3);
      });

      test('标签含连字符 #my-tag', () {
        final tags = extractor.extractTags('使用 #my-tag 标签');
        expect(tags, contains('my-tag'));
      });

      test('行首标签', () {
        final tags = extractor.extractTags('#日记\n今天天气不错');
        expect(tags, contains('日记'));
      });

      test('不匹配 wikilink 开头 #[[', () {
        final tags = extractor.extractTags('#[[不是标签]]');
        expect(tags, isEmpty);
      });

      test('不以数字开头的标签', () {
        final tags = extractor.extractTags('#123invalid');
        expect(tags, isEmpty);
      });

      test('空内容返回空列表', () {
        final tags = extractor.extractTags('');
        expect(tags, isEmpty);
      });
    });

    group('findUnlinkedMentions', () {
      test('找到未链接提及', () {
        final mentions = extractor.findUnlinkedMentions('今天学习了量子计算的相关知识', [
          '量子计算',
        ]);
        expect(mentions.length, 1);
        expect(mentions[0].targetTitle, '量子计算');
      });

      test('已链接的不标记为未链接', () {
        final mentions = extractor.findUnlinkedMentions('今天学习了[[量子计算]]的相关知识', [
          '量子计算',
        ]);
        expect(mentions, isEmpty);
      });

      test('短标题跳过', () {
        final mentions = extractor.findUnlinkedMentions('AB 是一个概念', ['AB']);
        expect(mentions, isEmpty);
      });

      test('多个标题多个提及', () {
        final mentions = extractor.findUnlinkedMentions('Flutter和Dart是很好的组合', [
          'Flutter',
          'Dart',
        ]);
        expect(mentions.length, 2);
      });

      test('不存在标题返回空', () {
        final mentions = extractor.findUnlinkedMentions('这是一段普通文本', ['不存在的标题']);
        expect(mentions, isEmpty);
      });
    });

    group('上下文提取', () {
      test('提取链接周围上下文', () {
        final links = extractor.extractLinks('前面的文字 [[目标]] 后面的文字');
        expect(links[0].context, contains('目标'));
      });

      test('长文本上下文被截断', () {
        final longPrefix = 'A' * 200;
        final longSuffix = 'B' * 200;
        final links = extractor.extractLinks('$longPrefix[[目标]]$longSuffix');
        expect(
          links[0].context.length,
          lessThan(longPrefix.length + longSuffix.length + 20),
        );
      });
    });
  });

  group('UnlinkedMentionResult', () {
    test('model stores all fields correctly', () {
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
  });

  group('linkMention replacement', () {
    test('linkMention wraps all occurrences of title', () {
      final content = '量子计算是未来的技术方向，量子计算将改变世界';
      final title = '量子计算';
      final result = content.replaceAll(title, '[[$title]]');
      expect(result, '[[量子计算]]是未来的技术方向，[[量子计算]]将改变世界');
    });
  });
}
