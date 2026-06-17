import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/core/ai/embedding_document_builder.dart';
import 'package:rfbrowser/data/models/chat_memory.dart';
import 'package:rfbrowser/data/models/note.dart';

void main() {
  group('EmbeddingDocumentBuilder', () {
    const builder = EmbeddingDocumentBuilder();

    test('fragment document is deterministic and versioned', () {
      final frag = MemoryFragment(
        id: 'a',
        sessionId: 's',
        content: 'Hello world',
        tier: MemoryTier.short,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      final d1 = builder.buildForFragment(frag);
      final d2 = builder.buildForFragment(frag);
      expect(d1.contentHash, d2.contentHash);
      expect(d1.textVersion, memoryRecordEmbeddingTextVersion);
      expect(d1.content, contains('Text: Hello world'));
      expect(d1.content, contains('Tier: short'));
    });

    test('different content yields different hash', () {
      final f1 = MemoryFragment(
        id: 'a',
        sessionId: 's',
        content: 'foo',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      final f2 = MemoryFragment(
        id: 'a',
        sessionId: 's',
        content: 'bar',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      expect(
        builder.buildForFragment(f1).contentHash,
        isNot(equals(builder.buildForFragment(f2).contentHash)),
      );
    });

    test('pinned flag is reflected in document', () {
      final pinned = MemoryFragment(
        id: 'a',
        sessionId: 's',
        content: 'foo',
        isPinned: true,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      final doc = builder.buildForFragment(pinned);
      expect(doc.content, contains('Pinned: true'));
    });

    test('note document includes title, content, and tags', () {
      final note = Note(
        title: 'Daily Note',
        filePath: '/tmp/daily.md',
        content: 'Body text',
        tags: const ['daily', 'journal'],
        created: DateTime.utc(2026, 1, 1),
        modified: DateTime.utc(2026, 1, 2),
      );
      final doc = builder.buildForNote(note);
      expect(doc.textVersion, noteEmbeddingTextVersion);
      expect(doc.content, contains('Daily Note'));
      expect(doc.content, contains('Body text'));
      expect(doc.content, contains('Tags:'));
      expect(doc.content, contains('daily'));
    });

    test('long content is truncated at a sensible boundary', () {
      final note = Note(
        title: 'T',
        filePath: '/tmp/x.md',
        content: 'X' * 9000,
        created: DateTime.utc(2026, 1, 1),
        modified: DateTime.utc(2026, 1, 1),
      );
      final doc = builder.buildForNote(note);
      expect(doc.content.length, lessThanOrEqualTo(8000));
    });
  });
}
