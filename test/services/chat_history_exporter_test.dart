import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rfbrowser/data/models/chat_memory.dart';
import 'package:rfbrowser/services/chat_history_exporter.dart';
import 'package:rfbrowser/services/memory_service.dart';
import '../helpers/sqflite_test_setup.dart';

void main() {
  setUpAll(setupSqfliteForTests);

  late MemoryService memory;
  late ChatHistoryExporter exporter;
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('rfbrowser_chat_test_');
    memory = MemoryService(p.join(tempDir.path, 'memory.db'));
    exporter = ChatHistoryExporter(memory);
  });

  tearDown(() async {
    await memory.close();
    // Give Windows time to release file handles before deletion
    await Future.delayed(const Duration(milliseconds: 50));
    tempDir.deleteSync(recursive: true);
  });

  group('ChatHistoryExporter.formatMarkdown', () {
    test('produces a YAML frontmatter and human-readable body', () {
      final md = exporter.formatMarkdown(
        sessionId: 'sess-1',
        title: 'My First Chat',
        createdAt: DateTime.utc(2026, 1, 1, 10),
        updatedAt: DateTime.utc(2026, 1, 1, 11),
        messages: [
          ChatRecord(
            id: 'm1',
            sessionId: 'sess-1',
            role: 'user',
            content: 'hello',
            timestamp: DateTime.utc(2026, 1, 1, 10),
          ),
          ChatRecord(
            id: 'm2',
            sessionId: 'sess-1',
            role: 'assistant',
            content: 'world',
            timestamp: DateTime.utc(2026, 1, 1, 10, 5),
          ),
        ],
      );
      expect(md, startsWith('---\n'));
      expect(md, contains('id: sess-1'));
      expect(md, contains('title: My First Chat'));
      expect(md, contains('message_count: 2'));
      expect(md, contains('# My First Chat'));
      expect(md, contains('### User'));
      expect(md, contains('hello'));
      expect(md, contains('### openloomi'));
      expect(md, contains('world'));
      expect(md, contains('**Total**: 2 Messages'));
    });

    test('truncates long content per the format limit', () {
      final md = exporter.formatMarkdown(
        sessionId: 'sess-1',
        title: 'Long',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
        messages: [
          ChatRecord(
            id: 'm1',
            sessionId: 'sess-1',
            role: 'user',
            content: 'X' * 1000,
            timestamp: DateTime.utc(2026, 1, 1),
          ),
        ],
      );
      // The body must contain the 180-char truncated form ending in "..."
      expect(md, contains('...'));
      // And the raw 1000-char string should NOT be present.
      expect(md.contains('X' * 1000), isFalse);
    });

    test('escapes YAML-unsafe characters in title', () {
      final md = exporter.formatMarkdown(
        sessionId: 'sess-1',
        title: 'Title: with colon and # hash',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
        messages: const [],
      );
      expect(md, contains('title: "Title: with colon and # hash"'));
    });

    test('handles empty messages gracefully', () {
      final md = exporter.formatMarkdown(
        sessionId: 'sess-1',
        title: 'Empty',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
        messages: const [],
      );
      expect(md, contains('*No Chat Messages*'));
    });
  });

  group('ChatHistoryExporter.exportSession', () {
    test('writes a real file to disk when given a target directory', () async {
      await memory.saveMessage(role: 'user', content: 'hi');
      await memory.saveMessage(role: 'assistant', content: 'hello back');

      final path = await exporter.exportSession(
        targetDir: p.join(tempDir.path, 'chats'),
      );
      expect(path, isNotNull);
      final file = File(path!);
      expect(file.existsSync(), isTrue);
      final body = file.readAsStringSync();
      expect(body, contains('message_count: 2'));
      expect(body, contains('### User'));
      expect(body, contains('### openloomi'));
    });

    test('returns null when there are no messages to export', () async {
      final path = await exporter.exportSession(
        targetDir: p.join(tempDir.path, 'chats'),
      );
      expect(path, isNull);
    });

    test('keeps only the N most recent exports per session', () async {
      final limited = ChatHistoryExporter(
        memory,
        format: const ChatHistoryFormat(keepLastNPerSession: 2),
      );
      await memory.saveMessage(role: 'user', content: 'hi');
      final targetDir = p.join(tempDir.path, 'chats_rotated');
      // Write 5 exports of the same session.
      for (var i = 0; i < 5; i++) {
        await limited.exportSession(targetDir: targetDir);
        // Stagger the modification times so rotation has a stable order.
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }
      final dir = Directory(targetDir);
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.md'))
          .toList();
      expect(
        files.length,
        2,
        reason: 'rotation should leave only the latest 2',
      );
    });

    test('keeps all files when keepLastNPerSession = 0', () async {
      final unlimited = ChatHistoryExporter(
        memory,
        format: const ChatHistoryFormat(keepLastNPerSession: 0),
      );
      await memory.saveMessage(role: 'user', content: 'hi');
      final targetDir = p.join(tempDir.path, 'chats_unlimited');
      for (var i = 0; i < 4; i++) {
        await unlimited.exportSession(targetDir: targetDir);
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      final count = Directory(targetDir)
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.md'))
          .length;
      expect(count, 4);
    });
  });
}
