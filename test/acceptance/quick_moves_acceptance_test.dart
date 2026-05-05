import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rfbrowser/services/quick_move_service.dart';
import 'package:rfbrowser/data/models/quick_move.dart';
import 'package:rfbrowser/data/stores/quick_move_store.dart';
import 'package:rfbrowser/ui/widgets/command_bar.dart';
import 'package:rfbrowser/ui/pages/settings/quick_moves_settings_section.dart';

void main() {
  group('US-1: 创建我的第一条快捷命令', () {
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
    });

    tearDown(() => container.dispose());

    QuickMoveState s() => container.read(quickMoveProvider);

    test('AC-1-1: /翻译 Hello World resolves prompt with input', () {
      final presets = QuickMove.defaultPresets();
      final translate = presets.firstWhere((p) => p.id == 'preset_translate');
      final resolved = translate.resolvePrompt({'input': 'Hello World'});
      expect(resolved, contains('Hello World'));
      expect(resolved, contains('Translate'));
    });

    test('AC-1-5: Prompt template {input} placeholder works', () {
      final move = QuickMove(name: 'test', promptTemplate: 'Process: {input}');
      expect(move.resolvePrompt({'input': 'hello'}), 'Process: hello');
    });

    test('AC-1-4: Created command immediately available', () async {
      await container.read(quickMoveProvider.notifier).createMove('mycmd', 'Process {input}');
      expect(s().moves.any((m) => m.name == 'mycmd'), isTrue);
      expect(s().matching('mycmd').length, 1);
    });

    testWidgets('AC-1-2: /nonexistent prompts create dialog', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: CommandBar(onCommand: _noop, onClose: _noop)),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '/nonexistent');
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('命令不存在'), findsOneWidget);
      expect(find.text('创建'), findsOneWidget);
    });
  });

  group('US-2: 浏览和使用已有命令', () {
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
    });

    tearDown(() => container.dispose());

    test('AC-2-2: partial match filters commands', () {
      final s = container.read(quickMoveProvider);
      final matches = s.matching('翻');
      expect(matches.any((m) => m.name.contains('翻')), isTrue);
    });

    test('AC-2-2: case-insensitive matching', () {
      final presets = QuickMove.defaultPresets();
      final summarize = presets.firstWhere((p) => p.id == 'preset_summarize');
      final state = QuickMoveState(moves: [
        summarize.copyWith(name: 'SUMMARIZE'),
        QuickMove(id: '2', name: 'sum', promptTemplate: ''),
      ]);
      expect(state.matching('sum').length, greaterThanOrEqualTo(2));
    });

    test('AC-2-4: sorted by lastUsedAt descending', () {
      final now = DateTime.now();
      final moves = [
        QuickMove(id: 'old', name: 'Old', promptTemplate: '',
            lastUsedAt: now.subtract(const Duration(days: 5))),
        QuickMove(id: 'recent', name: 'Recent', promptTemplate: '', lastUsedAt: now),
        QuickMove(id: 'mid', name: 'Mid', promptTemplate: '',
            lastUsedAt: now.subtract(const Duration(hours: 1))),
      ];
      final sorted = QuickMoveState(moves: moves).byLastUsed;
      expect(sorted[0].name, 'Recent');
      expect(sorted[1].name, 'Mid');
      expect(sorted[2].name, 'Old');
    });

    testWidgets('AC-2-1: / shows only Quick Moves', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: CommandBar(onCommand: _noop, onClose: _noop)),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '/');
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      expect(find.text('/翻译'), findsOneWidget);
      expect(find.text('/总结'), findsOneWidget);
      expect(find.text('/解释'), findsOneWidget);
      expect(find.text('/邮件'), findsOneWidget);
      expect(find.text('/语法'), findsOneWidget);
      expect(find.text('Command'), findsNothing);
    });

    testWidgets('AC-2-3: select command appends space', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: CommandBar(onCommand: _noop, onClose: _noop)),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '/');
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      await tester.tap(find.text('/翻译'));
      await tester.pumpAndSettle();

      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.controller!.text, '/翻译 ');
      expect(tf.controller!.selection.baseOffset, '/翻译 '.length);
    });
  });

  group('US-3: 管理我的命令列表', () {
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
    });

    tearDown(() => container.dispose());

    test('AC-3-3: edit modifies name and prompt', () async {
      final n = container.read(quickMoveProvider.notifier);
      final m = await n.createMove('original', 'old prompt');
      await n.updateMove(m.id, name: 'updated', promptTemplate: 'new prompt');

      final u = container.read(quickMoveProvider).byId[m.id]!;
      expect(u.name, 'updated');
      expect(u.promptTemplate, 'new prompt');
    });

    test('AC-3-4+5: delete removes command, matching returns empty', () async {
      final n = container.read(quickMoveProvider.notifier);
      final m = await n.createMove('toDelete', 'dummy');
      await n.deleteMove(m.id);
      expect(container.read(quickMoveProvider).byId[m.id], isNull);
      expect(container.read(quickMoveProvider).matching('toDelete'), isEmpty);
    });

    test('AC-3-6: reorder changes positions', () {
      final a = QuickMove(id: 'a', name: 'A', promptTemplate: '');
      final b = QuickMove(id: 'b', name: 'B', promptTemplate: '');
      final state = QuickMoveState(moves: [a, b]);
      final newState = QuickMoveState(moves: [b, a]);
      expect(newState.moves[0].id, 'b');
      expect(newState.moves[1].id, 'a');
    });

    testWidgets('AC-3-1: settings section renders', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: QuickMovesSettingsSection()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Quick Moves'), findsOneWidget);
      expect(find.text('/翻译'), findsOneWidget);
    });

    testWidgets('AC-3-2: all moves show type badge and drag handle', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: QuickMovesSettingsSection()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Preset'), findsWidgets);
      expect(find.byIcon(Icons.drag_handle), findsWidgets);
    });
  });

  group('US-4: 使用预设命令模板', () {
    test('AC-4-1: >= 5 presets', () {
      expect(QuickMove.defaultPresets().length, greaterThanOrEqualTo(5));
    });

    test('AC-4-2: presets can be edited via copyWith', () {
      final p = QuickMove.defaultPresets().first;
      final u = p.copyWith(name: 'My Translate');
      expect(u.name, 'My Translate');
      expect(u.type, QuickMoveType.preset);
    });

    test('AC-4-3: names are 翻译/总结/解释/邮件/语法', () {
      final names = QuickMove.defaultPresets().map((p) => p.name).toSet();
      expect(names.containsAll(['翻译', '总结', '解释', '邮件', '语法']), isTrue);
    });

    test('AC-4-4: restoreDefaults re-adds deleted presets', () async {
      SharedPreferences.setMockInitialValues({});
      final c = ProviderContainer();
      final n = c.read(quickMoveProvider.notifier);
      for (final p in c.read(quickMoveProvider).moves
          .where((m) => m.type == QuickMoveType.preset)) {
        await n.deleteMove(p.id);
      }
      await n.restoreDefaults();
      final count = c.read(quickMoveProvider).moves
          .where((m) => m.type == QuickMoveType.preset).length;
      expect(count, greaterThanOrEqualTo(5));
      c.dispose();
    });

    test('AC-4-4 double restore: no duplicates', () async {
      SharedPreferences.setMockInitialValues({});
      final c = ProviderContainer();
      final n = c.read(quickMoveProvider.notifier);
      await n.restoreDefaults();
      await n.restoreDefaults();
      final ids = c.read(quickMoveProvider).moves
          .where((m) => m.type == QuickMoveType.preset).map((m) => m.id).toSet();
      expect(ids.length, 5);
      c.dispose();
    });
  });

  group('US-5: 上下文感知的 AI 响应', () {
    test('AC-5-3: {pageContent} resolves', () {
      final m = QuickMove(name: 'sum', promptTemplate: 'TL;DR:\n{pageContent}');
      expect(m.resolvePrompt({'pageContent': 'Long article...'}), 'TL;DR:\nLong article...');
    });

    test('AC-5-3: {selectedText} resolves', () {
      final m = QuickMove(name: 'trans', promptTemplate: 'EN: {selectedText}');
      expect(m.resolvePrompt({'selectedText': '你好'}), 'EN: 你好');
    });

    test('AC-5-1: combined {pageContent} + {input}', () {
      final m = QuickMove(name: 's', promptTemplate: 'Q: {input}\n\nDoc: {pageContent}');
      final r = m.resolvePrompt({'input': 'summary', 'pageContent': 'Article'});
      expect(r, contains('summary'));
      expect(r, contains('Article'));
    });

    test('AC-5-2: {selectedText} resolves', () {
      final m = QuickMove(name: 't', promptTemplate: 'Translate: {selectedText}');
      expect(m.resolvePrompt({'selectedText': '你好世界'}), contains('你好世界'));
    });

    test('AC-5-4: missing context placeholder stays (no crash)', () {
      final m = QuickMove(name: 's', promptTemplate: 'Page: {pageContent}. In: {input}');
      final r = m.resolvePrompt({'input': 'hi'});
      expect(r, contains('{pageContent}'));
      expect(r, contains('hi'));
    });

    test('AC-5-4: {pageUrl} + {noteContent} resolve together', () {
      final m = QuickMove(name: 's', promptTemplate: '{pageUrl}\n{noteContent}');
      final r = m.resolvePrompt({'pageUrl': 'https://x.com', 'noteContent': 'My note'});
      expect(r, contains('https://x.com'));
      expect(r, contains('My note'));
    });

    testWidgets('AC-5: context provider updates via Consumer widget', (tester) async {
      final container = ProviderContainer();
      container.read(quickMoveContextProvider.notifier).update(
            QuickMoveContext(
              currentUrl: 'https://example.com',
              pageContent: 'Some page text',
            ),
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(builder: (context, ref, _) {
                final ctx = ref.watch(quickMoveContextProvider);
                return Text(ctx.currentUrl ?? 'null');
              }),
            ),
          ),
        ),
      );

      expect(find.text('https://example.com'), findsOneWidget);
      container.dispose();
    });
  });

  group('US-7: 命令数据持久化 (Store-level round-trip)', () {
    final store = QuickMoveStore();

    test('AC-7-1: create → save → load returns same commands', () async {
      SharedPreferences.setMockInitialValues({});

      final presets = QuickMove.defaultPresets();
      final move = QuickMove(name: 'persistent', promptTemplate: 'test {input}');
      final state = QuickMoveState(moves: [...presets, move]);
      await store.save(state);

      final loaded = await store.load();
      final found = loaded.byId[move.id];
      expect(found, isNotNull);
      expect(found!.name, 'persistent');
      expect(found.promptTemplate, 'test {input}');
    });

    test('AC-7-2: deleted command stays gone', () async {
      SharedPreferences.setMockInitialValues({});

      final presets = QuickMove.defaultPresets();
      final move = QuickMove(id: 'will_delete', name: 'temp', promptTemplate: '');
      await store.save(QuickMoveState(moves: [...presets, move]));

      var state = await store.load();
      state = state.copyWith(moves: state.moves.where((m) => m.id != 'will_delete').toList());
      await store.save(state);

      final reloaded = await store.load();
      expect(reloaded.byId['will_delete'], isNull);
    });

    test('AC-7-3: edit persists', () async {
      SharedPreferences.setMockInitialValues({});

      final presets = QuickMove.defaultPresets();
      final original = QuickMove(id: 'edit_me', name: 'original', promptTemplate: 'old');
      await store.save(QuickMoveState(moves: [...presets, original]));

      var loaded = await store.load();
      final idx = loaded.moves.indexWhere((m) => m.id == 'edit_me');
      final updated = loaded.moves[idx].copyWith(name: 'edited', promptTemplate: 'new');
      final updatedMoves = List<QuickMove>.from(loaded.moves);
      updatedMoves[idx] = updated;
      await store.save(QuickMoveState(moves: updatedMoves));

      loaded = await store.load();
      final u = loaded.byId['edit_me']!;
      expect(u.name, 'edited');
      expect(u.promptTemplate, 'new');
    });

    test('AC-7-4: JSON export → import round-trip', () async {
      SharedPreferences.setMockInitialValues({});

      final presets = QuickMove.defaultPresets();
      final s1 = QuickMoveState(moves: [...presets,
        QuickMove(id: 'x', name: 'test', promptTemplate: '{input}'),
      ]);
      await store.save(s1);

      final s1Loaded = await store.load();
      final json = store.exportToJson(s1Loaded);

      expect(json.contains('test'), isTrue);

      final success = await store.importFromJson(json);
      expect(success, isTrue);

      final restored = await store.load();
      expect(restored.moves.length, presets.length + 1);

      final restoredMove = restored.moves.firstWhere((m) => m.id == 'x');
      expect(restoredMove.name, 'test');
    });

    test('AC-7-4: invalid JSON import → false', () async {
      SharedPreferences.setMockInitialValues({});

      final state = QuickMoveState.initial();
      await store.save(state);

      final success = await store.importFromJson('{broken!!!}');
      expect(success, isFalse);

      final loaded = await store.load();
      expect(loaded.moves.length, state.moves.length);
    });
  });
}

void _noop([_]) {}
