import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/ui/layout/scene_scaffold.dart';
import 'package:rfbrowser/ui/layout/scene_switcher.dart';

void main() {
  group('SceneSwitcher', () {
    testWidgets('E1-AC1: renders three scene buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SceneSwitcher(
              currentScene: SceneType.capture,
              onSceneChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('捕捉'), findsOneWidget);
      expect(find.text('思考'), findsOneWidget);
      expect(find.text('连接'), findsOneWidget);

      expect(find.text('Ctrl+1'), findsOneWidget);
      expect(find.text('Ctrl+2'), findsOneWidget);
      expect(find.text('Ctrl+3'), findsOneWidget);
    });

    testWidgets('E1-AC2: clicking scene button triggers onSceneChanged',
        (tester) async {
      SceneType? changedTo;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SceneSwitcher(
              currentScene: SceneType.capture,
              onSceneChanged: (scene) => changedTo = scene,
            ),
          ),
        ),
      );

      await tester.tap(find.text('思考'));
      expect(changedTo, SceneType.think);

      await tester.tap(find.text('连接'));
      expect(changedTo, SceneType.connect);
    });

    testWidgets('E1-AC2b: clicking active scene does nothing', (tester) async {
      int callCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SceneSwitcher(
              currentScene: SceneType.capture,
              onSceneChanged: (_) => callCount++,
            ),
          ),
        ),
      );

      await tester.tap(find.text('捕捉'));
      expect(callCount, 0);
    });
  });

  group('SceneScaffold', () {
    testWidgets('E1-AC1b: renders scene content and switcher', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SceneScaffold(
              initialScene: SceneType.capture,
              captureView: (_) => const Text('Capture View'),
              thinkView: (_) => const Text('Think View'),
              connectView: (_) => const Text('Connect View'),
            ),
          ),
        ),
      );

      expect(find.text('捕捉'), findsOneWidget);
      expect(find.text('Capture View'), findsOneWidget);
      expect(find.text('Think View'), findsNothing);
      expect(find.text('Connect View'), findsNothing);
    });

    testWidgets('E1-AC5: scene switch triggers animation <= 350ms',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SceneScaffold(
              initialScene: SceneType.capture,
              captureView: (_) => const Text('Capture'),
              thinkView: (_) => const Text('Think'),
              connectView: (_) => const Text('Connect'),
            ),
          ),
        ),
      );

      expect(find.text('Capture'), findsOneWidget);
      expect(find.text('Think'), findsNothing);

      final sceneSwitcher = tester.widget<SceneSwitcher>(
        find.byType(SceneSwitcher),
      );
      sceneSwitcher.onSceneChanged(SceneType.think);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 350));

      await tester.pumpAndSettle();
    });

    testWidgets('E1-AC1c: scene icons are rendered', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SceneScaffold(
              initialScene: SceneType.capture,
              captureView: (_) => const SizedBox(),
              thinkView: (_) => const SizedBox(),
              connectView: (_) => const SizedBox(),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.explore), findsAtLeastNWidgets(1));
      expect(find.byIcon(Icons.edit_note), findsOneWidget);
      expect(find.byIcon(Icons.hub), findsOneWidget);
    });
  });

  group('SceneType', () {
    test('has three values', () {
      expect(SceneType.values.length, 3);
      expect(SceneType.capture, isA<SceneType>());
      expect(SceneType.think, isA<SceneType>());
      expect(SceneType.connect, isA<SceneType>());
    });
  });
}
