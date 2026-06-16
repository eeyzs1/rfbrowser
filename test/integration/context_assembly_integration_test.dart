import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/data/models/note.dart';
import 'package:rfbrowser/data/models/context_assembly.dart';
import 'package:rfbrowser/core/context/assembler.dart';
import 'package:rfbrowser/core/context/reference_parser.dart';
import 'package:rfbrowser/core/context/priority_ranker.dart';
import 'package:rfbrowser/core/context/token_budget.dart';

void main() {
  group('Context Assembler Integration', () {
    test('assemble with current note includes note content', () async {
      final assembler = Assembler(maxTokens: 4096);
      final currentNote = Note(
        id: 'n1',
        title: 'Test Note',
        filePath: 'test.md',
        content: 'This is the current note content.',
        created: DateTime.now(),
        modified: DateTime.now(),
      );

      final assembly = await assembler.assemble(
        'What is this about?',
        currentNote: currentNote,
      );

      expect(assembly.items, isNotEmpty);
      expect(assembly.items.any((i) => i.type == ContextType.note), isTrue);
    });

    test(
      'assemble with current web content referenced via @web[current]',
      () async {
        final assembler = Assembler(maxTokens: 4096);

        final assembly = await assembler.assemble(
          'Summarize @web[current]',
          currentWebUrl: 'https://example.com',
          currentWebTitle: 'Example Page',
          currentWebContent: 'This is the web page content.',
        );

        expect(assembly.items, isNotEmpty);
        expect(
          assembly.items.any((i) => i.type == ContextType.webPage),
          isTrue,
        );
      },
    );

    test('assemble with clips referenced via @clip[name]', () async {
      final assembler = Assembler(maxTokens: 4096);

      final assembly = await assembler.assemble(
        'What does the clip say? @clip[clip1]',
        clips: {'clip1': 'This is clipped content.'},
      );

      expect(assembly.items, isNotEmpty);
      expect(
        assembly.items.any(
          (i) =>
              i.metadata.containsKey('source') &&
              i.metadata['source'] == 'clip',
        ),
        isTrue,
      );
    });

    test('assemble with agent results referenced via @agent[name]', () async {
      final assembler = Assembler(maxTokens: 4096);

      final assembly = await assembler.assemble(
        'What did the agent find? @agent[step1]',
        agentResults: {'step1': 'Agent found something.'},
      );

      expect(assembly.items, isNotEmpty);
      expect(
        assembly.items.any((i) => i.type == ContextType.agentResult),
        isTrue,
      );
    });

    test('assemble with note references finds matching notes', () async {
      final assembler = Assembler(maxTokens: 4096);
      final allNotes = [
        Note(
          id: 'n1',
          title: 'AI Research',
          filePath: 'ai.md',
          content: 'AI research notes.',
          created: DateTime.now(),
          modified: DateTime.now(),
        ),
        Note(
          id: 'n2',
          title: 'Meeting Notes',
          filePath: 'meeting.md',
          content: 'Meeting notes content.',
          created: DateTime.now(),
          modified: DateTime.now(),
        ),
      ];

      final assembly = await assembler.assemble(
        'Tell me about @note[AI Research]',
        allNotes: allNotes,
      );

      expect(assembly.items, isNotEmpty);
    });

    test('assemble with file references via @file[name]', () async {
      final assembler = Assembler(maxTokens: 4096);

      final assembly = await assembler.assemble(
        'What is in the file? @file[readme.md]',
        files: {'readme.md': '# Project Title\n\nDescription'},
      );

      expect(assembly.items, isNotEmpty);
      expect(assembly.items.any((i) => i.type == ContextType.file), isTrue);
    });
  });

  group('Reference Parser', () {
    test('parse extracts note references', () {
      final parser = ReferenceParser();
      final refs = parser.parse('See @note[TestNote] for details');

      expect(refs, isNotEmpty);
      expect(refs.any((r) => r.type == ContextRefType.note), isTrue);
      expect(refs.first.target, 'TestNote');
    });

    test('parse extracts web references', () {
      final parser = ReferenceParser();
      final refs = parser.parse('Based on @web[current] content');

      expect(refs, isNotEmpty);
      expect(refs.any((r) => r.type == ContextRefType.web), isTrue);
      expect(refs.first.target, 'current');
    });

    test('parse extracts file references', () {
      final parser = ReferenceParser();
      final refs = parser.parse('Read @file[readme.md]');

      expect(refs, isNotEmpty);
      expect(refs.any((r) => r.type == ContextRefType.file), isTrue);
      expect(refs.first.target, 'readme.md');
    });

    test('parse returns empty for no references', () {
      final parser = ReferenceParser();
      final refs = parser.parse('Just a plain text message');

      expect(refs, isEmpty);
    });
  });

  group('Token Budget', () {
    test('tokenBudget trims items exceeding maxTokens', () {
      final budget = TokenBudget(maxTokens: 200, charsPerToken: 4);
      final items = [
        ContextItem(
          type: ContextType.note,
          id: 'n1',
          content: 'A' * 200, // 50 tokens, leaves 150 remaining
        ),
        ContextItem(
          type: ContextType.note,
          id: 'n2',
          content: 'B' * 800, // 200 tokens, exceeds 150 remaining
        ),
      ];

      final result = budget.trim(items);
      expect(result.items.length, 2);
      expect(result.items.last.content.length, lessThan(800));
      expect(result.items.last.metadata['truncated'], isTrue);
      expect(result.truncated, isTrue);
    });

    test('tokenBudget does not trim when under budget', () {
      final budget = TokenBudget(maxTokens: 1000, charsPerToken: 4);
      final items = [
        ContextItem(type: ContextType.note, id: 'n1', content: 'Short content'),
      ];

      final result = budget.trim(items);
      expect(result.items.length, 1);
      expect(result.truncated, isFalse);
    });

    test('tokenBudget handles empty list', () {
      final budget = TokenBudget(maxTokens: 100);
      final result = budget.trim([]);
      expect(result.items, isEmpty);
      expect(result.truncated, isFalse);
    });

    test('estimateTokens calculates correctly', () {
      final budget = TokenBudget(charsPerToken: 4);
      expect(budget.estimateTokens('12345678'), 2);
      expect(budget.estimateTokens('1234'), 1);
      expect(budget.estimateTokens(''), 0);
    });
  });

  group('Priority Ranker', () {
    test('rank sorts items by type priority', () {
      final ranker = PriorityRanker();
      final items = [
        ContextItem(type: ContextType.file, id: 'f1', content: 'File content'),
        ContextItem(
          type: ContextType.selection,
          id: 's1',
          content: 'Selection',
        ),
      ];

      final ranked = ranker.rank(items);
      expect(ranked.first.type, ContextType.selection);
      expect(ranked.last.type, ContextType.file);
    });

    test('rank handles empty list', () {
      final ranker = PriorityRanker();
      final ranked = ranker.rank([]);
      expect(ranked, isEmpty);
    });
  });
}
