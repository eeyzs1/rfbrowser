import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/core/context/reference_parser.dart';
import 'package:rfbrowser/core/context/content_extractor.dart';
import 'package:rfbrowser/core/context/priority_ranker.dart';
import 'package:rfbrowser/core/context/token_budget.dart';
import 'package:rfbrowser/core/context/assembler.dart';
import 'package:rfbrowser/data/models/context_assembly.dart';
import 'package:rfbrowser/data/models/note.dart';

void main() {
  group('ReferenceParser', () {
    late ReferenceParser parser;

    setUp(() {
      parser = ReferenceParser();
    });

    test('AC-P2-2-1: parses @note and @web references', () {
      final refs = parser.parse('帮我分析 @note[A] 和 @web[current]');
      expect(refs.length, 2);
      expect(refs[0].type, ContextRefType.note);
      expect(refs[0].target, 'A');
      expect(refs[1].type, ContextRefType.web);
      expect(refs[1].target, 'current');
    });

    test('parses @clip reference', () {
      final refs = parser.parse('查看 @clip[clip-123]');
      expect(refs.length, 1);
      expect(refs[0].type, ContextRefType.clip);
      expect(refs[0].target, 'clip-123');
    });

    test('parses @agent reference', () {
      final refs = parser.parse('参考 @agent[task-456]');
      expect(refs.length, 1);
      expect(refs[0].type, ContextRefType.agent);
      expect(refs[0].target, 'task-456');
    });

    test('parses @file reference', () {
      final refs = parser.parse('读取 @file[README.md]');
      expect(refs.length, 1);
      expect(refs[0].type, ContextRefType.file);
      expect(refs[0].target, 'README.md');
    });

    test('parses reference with selector', () {
      final refs = parser.parse('查看 @note[A#section1]');
      expect(refs.length, 1);
      expect(refs[0].target, 'A');
      expect(refs[0].selector, 'section1');
    });

    test('returns empty list for no references', () {
      final refs = parser.parse('普通消息没有引用');
      expect(refs, isEmpty);
    });
  });

  group('NoteContentSource', () {
    test('AC-P2-2-1: resolves existing note by title', () async {
      final notes = [
        Note(
          id: '1',
          title: '量子计算',
          filePath: 'quantum.md',
          content: '量子叠加是...',
          tags: [],
          aliases: [],
          created: DateTime.now(),
          modified: DateTime.now(),
        ),
      ];
      final source = NoteContentSource(notes);
      final ref = ParsedReference(
        type: ContextRefType.note,
        target: '量子计算',
        position: 0,
        rawText: '@note[量子计算]',
      );

      final item = await source.resolve(ref);
      expect(item, isNotNull);
      expect(item!.type, ContextType.note);
      expect(item.content, contains('量子叠加'));
    });

    test('AC-P2-2-2: returns error for non-existent note', () async {
      final source = NoteContentSource([]);
      final ref = ParsedReference(
        type: ContextRefType.note,
        target: '不存在',
        position: 0,
        rawText: '@note[不存在]',
      );

      final item = await source.resolve(ref);
      expect(item, isNotNull);
      expect(item!.content, isEmpty);
      expect(item.metadata['error'], 'not_found');
    });

    test('resolves note by alias', () async {
      final notes = [
        Note(
          id: '1',
          title: '量子计算',
          filePath: 'quantum.md',
          content: '量子叠加是...',
          tags: [],
          aliases: ['QC'],
          created: DateTime.now(),
          modified: DateTime.now(),
        ),
      ];
      final source = NoteContentSource(notes);
      final ref = ParsedReference(
        type: ContextRefType.note,
        target: 'QC',
        position: 0,
        rawText: '@note[QC]',
      );

      final item = await source.resolve(ref);
      expect(item, isNotNull);
      expect(item!.content, contains('量子叠加'));
    });
  });

  group('WebContentSource', () {
    test('AC-P2-2-3: resolves @web[current]', () async {
      final source = WebContentSource(
        currentUrl: 'https://example.com',
        currentTitle: 'Example',
        currentContent: 'Example page content',
      );
      final ref = ParsedReference(
        type: ContextRefType.web,
        target: 'current',
        position: 0,
        rawText: '@web[current]',
      );

      final item = await source.resolve(ref);
      expect(item, isNotNull);
      expect(item!.type, ContextType.webPage);
      expect(item.content, 'Example page content');
    });

    test('returns error when no active page', () async {
      final source = WebContentSource();
      final ref = ParsedReference(
        type: ContextRefType.web,
        target: 'current',
        position: 0,
        rawText: '@web[current]',
      );

      final item = await source.resolve(ref);
      expect(item, isNotNull);
      expect(item!.metadata['error'], 'no_active_page');
    });
  });

  group('PriorityRanker', () {
    test('AC-P2-2-3: ranks items by priority', () {
      final ranker = PriorityRanker();
      final items = [
        ContextItem(
          type: ContextType.agentResult,
          id: 'agent1',
          content: 'agent result',
        ),
        ContextItem(
          type: ContextType.note,
          id: 'note1',
          content: 'note content',
        ),
        ContextItem(
          type: ContextType.webPage,
          id: 'web1',
          content: 'web content',
        ),
        ContextItem(
          type: ContextType.selection,
          id: 'sel1',
          content: 'selection',
        ),
      ];

      final ranked = ranker.rank(items);
      expect(ranked[0].type, ContextType.selection);
      expect(ranked[1].type, ContextType.note);
      expect(ranked[2].type, ContextType.webPage);
      expect(ranked[3].type, ContextType.agentResult);
    });
  });

  group('TokenBudget', () {
    test('AC-P2-2-4: truncates low-priority items when over budget', () {
      final budget = TokenBudget(maxTokens: 1000);
      final items = [
        ContextItem(
          type: ContextType.note,
          id: 'note1',
          content: 'A' * 4000,
        ),
        ContextItem(
          type: ContextType.webPage,
          id: 'web1',
          content: 'B' * 4000,
        ),
      ];

      final result = budget.trim(items);
      expect(result.truncated, true);
      expect(result.items.length, lessThan(2));
    });

    test('preserves high-priority items first', () {
      final budget = TokenBudget(maxTokens: 2000);
      final items = [
        ContextItem(
          type: ContextType.webPage,
          id: 'web1',
          content: 'B' * 4000,
        ),
        ContextItem(
          type: ContextType.note,
          id: 'note1',
          content: 'A' * 200,
        ),
      ];

      final ranked = PriorityRanker().rank(items);
      final result = budget.trim(ranked);
      expect(result.items.any((i) => i.type == ContextType.note), true);
    });

    test('no truncation when within budget', () {
      final budget = TokenBudget(maxTokens: 10000);
      final items = [
        ContextItem(
          type: ContextType.note,
          id: 'note1',
          content: 'short content',
        ),
      ];

      final result = budget.trim(items);
      expect(result.truncated, false);
      expect(result.items.length, 1);
    });
  });

  group('Assembler', () {
    test('AC-P2-2-5: resolves multiple references of different types', () async {
      final assembler = Assembler(maxTokens: 100000);
      final notes = [
        Note(
          id: '1',
          title: 'A',
          filePath: 'a.md',
          content: 'Note A content',
          tags: [],
          aliases: [],
          created: DateTime.now(),
          modified: DateTime.now(),
        ),
        Note(
          id: '2',
          title: 'B',
          filePath: 'b.md',
          content: 'Note B content',
          tags: [],
          aliases: [],
          created: DateTime.now(),
          modified: DateTime.now(),
        ),
      ];

      final assembly = await assembler.assemble(
        '分析 @note[A] 和 @note[B] 和 @web[current]',
        allNotes: notes,
        currentWebUrl: 'https://example.com',
        currentWebTitle: 'Example',
        currentWebContent: 'Example page',
      );

      expect(assembly.items.length, 3);
      final types = assembly.items.map((i) => i.type).toSet();
      expect(types, containsAll([ContextType.note, ContextType.webPage]));
    });

    test('AC-P2-2-6: toPrompt outputs structured format', () async {
      final assembler = Assembler();
      final assembly = await assembler.assemble(
        '分析 @note[测试]',
        allNotes: [
          Note(
            id: '1',
            title: '测试',
            filePath: 'test.md',
            content: '测试内容',
            tags: [],
            aliases: [],
            created: DateTime.now(),
            modified: DateTime.now(),
          ),
        ],
      );

      final prompt = assembly.toPrompt();
      expect(prompt, contains('[Context:'));
      expect(prompt, contains('[End Context]'));
    });

    test('auto-injects current note context', () async {
      final assembler = Assembler();
      final currentNote = Note(
        id: '1',
        title: '当前笔记',
        filePath: 'current.md',
        content: '当前笔记内容',
        tags: [],
        aliases: [],
        created: DateTime.now(),
        modified: DateTime.now(),
      );

      final assembly = await assembler.assemble(
        '总结一下',
        currentNote: currentNote,
      );

      expect(
        assembly.items.any((i) => i.type == ContextType.note),
        true,
      );
    });

    test('does not duplicate current note when @note[title] matches', () async {
      final assembler = Assembler();
      final currentNote = Note(
        id: '1',
        title: '当前笔记',
        filePath: 'current.md',
        content: '当前笔记内容',
        tags: [],
        aliases: [],
        created: DateTime.now(),
        modified: DateTime.now(),
      );

      final assembly = await assembler.assemble(
        '分析 @note[当前笔记]',
        currentNote: currentNote,
        allNotes: [currentNote],
      );

      final noteItems = assembly.items.where(
        (i) => i.type == ContextType.note && i.id == '1',
      );
      expect(noteItems.length, 1);
    });
  });
}
