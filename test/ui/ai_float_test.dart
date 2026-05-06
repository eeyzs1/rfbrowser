import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/ui/widgets/ai_float.dart';

void main() {
  group('AIFloat', () {
    testWidgets('E2-AC1: AI Float collapsed button is visible', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: const Stack(
                children: [AIFloat()],
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.psychology), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('E2-AC2: tapping collapsed AI Float expands it', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: const Stack(
                children: [AIFloat()],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.psychology));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byIcon(Icons.close), findsAtLeastNWidgets(1));
    });

    testWidgets('E2-AC4b: clicking close collapses AI Float', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: const Stack(
                children: [AIFloat()],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.psychology));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byIcon(Icons.close), findsAtLeastNWidgets(1));

      await tester.tap(find.byIcon(Icons.close).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('AI Assistant'), findsNothing);
    });

    testWidgets('E2-AC2b: expanded panel has close button', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: const Stack(
                children: [AIFloat()],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.psychology));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byIcon(Icons.close), findsAtLeastNWidgets(1));
    });
  });
}
