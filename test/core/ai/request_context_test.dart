import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rfbrowser/core/ai/request_context.dart';

void main() {
  group('RequestContext', () {
    test('empty context renders no block', () {
      const ctx = RequestContext.empty;
      expect(ctx.toSystemPromptBlock(), isEmpty);
    });

    test('context with vault renders a Vault line', () {
      const ctx = RequestContext(
        vault: VaultSnapshot(name: 'Personal', path: '/home/me/personal'),
      );
      final block = ctx.toSystemPromptBlock();
      expect(block, contains('Vault: Personal'));
      expect(block, contains('/home/me/personal'));
    });

    test('context with selection renders a verbatim block', () {
      const ctx = RequestContext(
        selection: SelectionSnapshot(text: 'highlighted text'),
      );
      final block = ctx.toSystemPromptBlock();
      expect(block, contains('Current selection'));
      expect(block, contains('highlighted text'));
    });

    test('context with all fields renders all sections', () {
      const ctx = RequestContext(
        vault: VaultSnapshot(name: 'V', path: '/p'),
        activeNote: ActiveNoteSnapshot(
          id: 'n1',
          title: 'Note',
          path: '/p/note.md',
          tags: ['daily'],
        ),
        selection: SelectionSnapshot(text: 'foo'),
        scene: AppScene.think,
      );
      final block = ctx.toSystemPromptBlock();
      expect(block, contains('Vault: V'));
      expect(block, contains('Active note: Note'));
      expect(block, contains('Current selection'));
      expect(block, contains('Current scene: think'));
    });
  });

  group('RequestContextNotifier', () {
    test('starts as empty and supports setters', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(requestContextProvider), RequestContext.empty);
      container.read(requestContextProvider.notifier).updateScene(AppScene.think);
      expect(
        container.read(requestContextProvider).scene,
        AppScene.think,
      );
      container
          .read(requestContextProvider.notifier)
          .updateActiveNote(const ActiveNoteSnapshot(id: '1', title: 'X'));
      expect(
        container.read(requestContextProvider).activeNote?.title,
        'X',
      );
      container
          .read(requestContextProvider.notifier)
          .updateActiveNote(null);
      expect(
        container.read(requestContextProvider).activeNote,
        isNull,
      );
    });
  });
}
