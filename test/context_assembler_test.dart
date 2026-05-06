import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:rfbrowser/core/context/assembler.dart';
import 'package:rfbrowser/data/models/note.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Assembler assembler;

  setUp(() {
    assembler = Assembler(maxTokens: 4096);
  });

  Note makeNote(String id, String title, String content) {
    return Note(
      id: id,
      title: title,
      filePath: '$title.md',
      content: content,
      created: DateTime.now(),
      modified: DateTime.now(),
    );
  }

  test('AC-IMP-5-1: assembler includes currentNote content in assembly', () async {
    final currentNote = makeNote('n1', 'test_note', '量子叠加原理是量子力学的核心概念之一�?);

    final assembly = await assembler.assemble(
      '总结一�?,
      currentNote: currentNote,
    );

    expect(assembly.items.any((item) => item.id == 'n1'), isTrue);
    final noteItem = assembly.items.firstWhere((item) => item.id == 'n1');
    expect(noteItem.content, contains('量子叠加原理'));
    expect(noteItem.metadata['title'], equals('test_note'));
  });

  test('AC-IMP-5-2: @note reference triggers Context block in prompt', () async {
    final notes = [
      makeNote('learning', '学习笔记', '这是一份关于机器学习和深度学习的笔记�?),
    ];

    final assembly = await assembler.assemble(
      '帮我分析 @note[学习笔记]',
      allNotes: notes,
    );

    final prompt = assembly.toPrompt();
    expect(prompt, contains('[Context:'));
    expect(prompt, contains('学习笔记'));
    expect(prompt, contains('机器学习'));
  });

  test('AC-IMP-5-3: assembly truncated when exceeding token budget', () async {
    final tinyAssembler = Assembler(maxTokens: 10);

    final currentNote = makeNote('big', 'big_note',
      'A' * 5000,
    );

    final assembly = await tinyAssembler.assemble(
      'test',
      currentNote: currentNote,
    );

    expect(assembly.truncated, isTrue);
  });

  test('assembler.toPrompt generates valid context blocks', () async {
    final note = makeNote('ctx1', 'context_note', 'context content here');

    final assembly = await assembler.assemble(
      'help @note[context_note]',
      allNotes: [note],
    );

    final prompt = assembly.toPrompt();
    expect(prompt, contains('[Context: note "context_note"]'));
    expect(prompt, contains('[End Context]'));
  });
}
