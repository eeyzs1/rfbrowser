import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/data/models/canvas_model.dart';
import 'package:rfbrowser/l10n/app_localizations.dart';
import 'package:rfbrowser/ui/pages/canvas/dialogs/add_tag_dialog.dart';
import 'package:rfbrowser/ui/pages/canvas/dialogs/background_color_picker_dialog.dart';
import 'package:rfbrowser/ui/pages/canvas/dialogs/color_picker_dialog.dart';
import 'package:rfbrowser/ui/pages/canvas/dialogs/move_to_layer_dialog.dart';
import 'package:rfbrowser/ui/pages/canvas/dialogs/remove_tag_dialog.dart';

/// Helper host widget that shows [dialogBuilder] when the button is tapped
/// and stores the result in [resultCompleter].
class _DialogHost<T> extends StatefulWidget {
  final WidgetBuilder dialogBuilder;
  final Completer<T?> resultCompleter;

  const _DialogHost({
    required this.dialogBuilder,
    required this.resultCompleter,
  });

  @override
  State<_DialogHost<T>> createState() => _DialogHostState<T>();
}

class _DialogHostState<T> extends State<_DialogHost<T>> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            final result = showDialog<T>(
              context: context,
              builder: widget.dialogBuilder,
            );
            widget.resultCompleter.complete(result);
          },
          child: const Text('Open Dialog'),
        ),
      ),
    );
  }
}

Widget _materialApp(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

/// Finds GestureDetector widgets that are descendants of a Wrap widget.
/// Used to locate color-swatch tappable areas.
Finder _colorSwatches() => find.descendant(
      of: find.byType(Wrap),
      matching: find.byType(GestureDetector),
    );

void main() {
  group('AddTagDialog', () {
    testWidgets('returns trimmed tag when Add is tapped', (tester) async {
      final completer = Completer<String?>();
      await tester.pumpWidget(_materialApp(
        _DialogHost<String>(
          resultCompleter: completer,
          dialogBuilder: (_) => const AddTagDialog(),
        ),
      ));

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '  my tag  ');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(await completer.future, 'my tag');
    });

    testWidgets('returns tag when Enter is pressed', (tester) async {
      final completer = Completer<String?>();
      await tester.pumpWidget(_materialApp(
        _DialogHost<String>(
          resultCompleter: completer,
          dialogBuilder: (_) => const AddTagDialog(),
        ),
      ));

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'quick');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(await completer.future, 'quick');
    });

    testWidgets('returns null when Cancel is tapped', (tester) async {
      final completer = Completer<String?>();
      await tester.pumpWidget(_materialApp(
        _DialogHost<String>(
          resultCompleter: completer,
          dialogBuilder: (_) => const AddTagDialog(),
        ),
      ));

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(await completer.future, isNull);
    });
  });

  group('RemoveTagDialog', () {
    testWidgets('returns the selected tag', (tester) async {
      final completer = Completer<String?>();
      await tester.pumpWidget(_materialApp(
        _DialogHost<String>(
          resultCompleter: completer,
          dialogBuilder: (_) =>
              const RemoveTagDialog(tags: ['work', 'important', 'idea']),
        ),
      ));

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('important'));
      await tester.pumpAndSettle();

      expect(await completer.future, 'important');
    });

    testWidgets('renders all provided tags', (tester) async {
      await tester.pumpWidget(_materialApp(
        _DialogHost<String>(
          resultCompleter: Completer<String?>(),
          dialogBuilder: (_) =>
              const RemoveTagDialog(tags: ['a', 'b', 'c']),
        ),
      ));

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('a'), findsOneWidget);
      expect(find.text('b'), findsOneWidget);
      expect(find.text('c'), findsOneWidget);
    });
  });

  group('ColorPickerDialog', () {
    testWidgets('returns the tapped color', (tester) async {
      final completer = Completer<Color?>();
      await tester.pumpWidget(_materialApp(
        _DialogHost<Color>(
          resultCompleter: completer,
          dialogBuilder: (_) => const ColorPickerDialog(
            currentColorValue: 0xFFFFFFFF,
          ),
        ),
      ));

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Tap the second color swatch inside the Wrap.
      final swatches = _colorSwatches();
      expect(swatches, findsNWidgets(ColorPickerDialog.presets.length));
      await tester.tap(swatches.at(1));
      await tester.pumpAndSettle();

      final result = await completer.future;
      expect(result, isNotNull);
      expect(result, ColorPickerDialog.presets[1]);
    });

    testWidgets('shows check mark on current color', (tester) async {
      await tester.pumpWidget(_materialApp(
        _DialogHost<Color>(
          resultCompleter: Completer<Color?>(),
          dialogBuilder: (_) => const ColorPickerDialog(
            currentColorValue: 0xFFFFFFFF,
          ),
        ),
      ));

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // The first preset (white) matches currentColorValue, so a check
      // icon should be rendered.
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('returns null when Cancel is tapped', (tester) async {
      final completer = Completer<Color?>();
      await tester.pumpWidget(_materialApp(
        _DialogHost<Color>(
          resultCompleter: completer,
          dialogBuilder: (_) => const ColorPickerDialog(
            currentColorValue: 0xFFFFFFFF,
          ),
        ),
      ));

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(await completer.future, isNull);
    });
  });

  group('MoveToLayerDialog', () {
    testWidgets('renders all layers and No Layer option', (tester) async {
      final layers = [
        const CanvasLayer(id: 'layer1', name: 'Layer 1', order: 0),
        const CanvasLayer(id: 'layer2', name: 'Layer 2', order: 1),
      ];

      await tester.pumpWidget(_materialApp(
        _DialogHost<({String? layerId})>(
          resultCompleter: Completer<({String? layerId})?>(),
          dialogBuilder: (_) => MoveToLayerDialog(
            currentLayerId: 'layer1',
            layers: layers,
          ),
        ),
      ));

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // "No Layer" option + two named layers.
      expect(find.textContaining('No Layer'), findsOneWidget);
      expect(find.text('Layer 1'), findsOneWidget);
      expect(find.text('Layer 2'), findsOneWidget);
    });

    testWidgets('returns null when Cancel is tapped', (tester) async {
      final completer = Completer<({String? layerId})?>();
      await tester.pumpWidget(_materialApp(
        _DialogHost<({String? layerId})>(
          resultCompleter: completer,
          dialogBuilder: (_) => MoveToLayerDialog(
            currentLayerId: null,
            layers: const [],
          ),
        ),
      ));

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(await completer.future, isNull);
    });

    testWidgets('returns selected layerId via Radio tap', (tester) async {
      final completer = Completer<({String? layerId})?>();
      final layers = [
        const CanvasLayer(id: 'layer1', name: 'Layer 1', order: 0),
        const CanvasLayer(id: 'layer2', name: 'Layer 2', order: 1),
      ];

      await tester.pumpWidget(_materialApp(
        _DialogHost<({String? layerId})>(
          resultCompleter: completer,
          dialogBuilder: (_) => MoveToLayerDialog(
            currentLayerId: 'layer1',
            layers: layers,
          ),
        ),
      ));

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Tap the Radio for "Layer 2" (third radio, index 2).
      // Note: use byWidgetPredicate with `is Radio` because byType(Radio)
      // does not match generic Radio<String?> instances (runtimeType differs).
      final radios = find.byWidgetPredicate((widget) => widget is Radio);
      // Index 0 = "No Layer", index 1 = "Layer 1", index 2 = "Layer 2".
      await tester.tap(radios.at(2));
      await tester.pumpAndSettle();

      final result = await completer.future;
      expect(result, isNotNull);
      expect(result!.layerId, 'layer2');
    });
  });

  group('BackgroundColorPickerDialog', () {
    testWidgets('returns selected colorValue', (tester) async {
      final completer = Completer<({int? colorValue})?>();
      await tester.pumpWidget(_materialApp(
        _DialogHost<({int? colorValue})>(
          resultCompleter: completer,
          dialogBuilder: (_) => const BackgroundColorPickerDialog(
            currentColorValue: null,
          ),
        ),
      ));

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Tap the first color swatch inside the Wrap.
      final swatches = _colorSwatches();
      expect(swatches, findsWidgets);
      await tester.tap(swatches.first);
      await tester.pumpAndSettle();

      final result = await completer.future;
      expect(result, isNotNull);
      expect(result!.colorValue, isNotNull);
    });

    testWidgets('returns null colorValue when Clear is tapped', (tester) async {
      final completer = Completer<({int? colorValue})?>();
      await tester.pumpWidget(_materialApp(
        _DialogHost<({int? colorValue})>(
          resultCompleter: completer,
          dialogBuilder: (_) => const BackgroundColorPickerDialog(
            currentColorValue: null,
          ),
        ),
      ));

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      final result = await completer.future;
      expect(result, isNotNull);
      expect(result!.colorValue, isNull);
    });

    testWidgets('returns null (cancelled) when Cancel is tapped',
        (tester) async {
      final completer = Completer<({int? colorValue})?>();
      await tester.pumpWidget(_materialApp(
        _DialogHost<({int? colorValue})>(
          resultCompleter: completer,
          dialogBuilder: (_) => const BackgroundColorPickerDialog(
            currentColorValue: null,
          ),
        ),
      ));

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(await completer.future, isNull);
    });
  });
}
