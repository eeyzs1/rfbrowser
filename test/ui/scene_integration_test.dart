import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rfbrowser/ui/scenes/capture/capture_scene.dart';

void main() {
  group('Scene rendering: component existence (A-1)', () {
    testWidgets('CaptureScene widget exists', (tester) async {
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
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CaptureScene), findsOneWidget);
    });
  });
}
