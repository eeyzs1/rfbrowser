import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rfbrowser/ui/scenes/capture/capture_scene.dart';
import 'package:rfbrowser/ui/widgets/ai_float.dart';

void main() {
  group('CaptureScene basic rendering', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CaptureScene(
                leftPanelExpanded: false,
                rightPanelExpanded: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CaptureScene), findsOneWidget);
    });

    testWidgets('AI Float appears in capture scene', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CaptureScene(
                leftPanelExpanded: false,
                rightPanelExpanded: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(AIFloat), findsOneWidget);
    });

    testWidgets('right panel renders with URL', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CaptureScene(
                leftPanelExpanded: false,
                rightPanelExpanded: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CaptureScene), findsOneWidget);
    });
  });
}
