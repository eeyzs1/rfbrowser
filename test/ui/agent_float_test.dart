import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rfbrowser/data/models/agent_task.dart';
import 'package:rfbrowser/l10n/app_localizations.dart';
import 'package:rfbrowser/services/agent_service.dart';
import 'package:rfbrowser/ui/widgets/agent_float.dart';

class _MockAgentNotifier extends AgentNotifier {
  final AgentState _state;
  _MockAgentNotifier(this._state);
  @override
  AgentState build() => _state;
  @override
  set state(AgentState newState) => super.state = newState;
}

Widget _wrapWithL10n(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('zh'),
    home: Scaffold(body: SizedBox(width: 1200, height: 800, child: child)),
  );
}

void main() {
  group('AgentFloat', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          agentProvider.overrideWith(() => _MockAgentNotifier(AgentState())),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    testWidgets('初始状态显示浮动按钮', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: _wrapWithL10n(const AgentFloat()),
        ),
      );

      expect(find.byIcon(Icons.smart_toy), findsOneWidget);
    });

    testWidgets('点击浮动按钮展开面板', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: _wrapWithL10n(const AgentFloat()),
        ),
      );

      await tester.tap(find.byIcon(Icons.smart_toy));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.close), findsWidgets);
    });

    testWidgets('展开后显示目标输入框', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: _wrapWithL10n(const AgentFloat()),
        ),
      );

      await tester.tap(find.byIcon(Icons.smart_toy));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('点击关闭按钮折叠面板', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: _wrapWithL10n(const AgentFloat()),
        ),
      );

      await tester.tap(find.byIcon(Icons.smart_toy));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('有任务时显示任务卡片', (tester) async {
      final agentState = AgentState(
        tasks: [
          AgentTask(
            id: 'ui-test-001',
            name: 'UI测试任务',
            description: 'UI测试',
            mode: TaskMode.reactLoop,
            steps: [
              AgentStep(
                description: '搜索',
                toolName: 'search_notes',
                args: {'query': 'test'},
                status: TaskStatus.completed,
              ),
            ],
            status: TaskStatus.running,
            created: DateTime.now(),
          ),
        ],
      );

      final taskContainer = ProviderContainer(
        overrides: [
          agentProvider.overrideWith(() => _MockAgentNotifier(agentState)),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: taskContainer,
          child: _wrapWithL10n(const AgentFloat()),
        ),
      );

      await tester.tap(find.byIcon(Icons.smart_toy));
      await tester.pumpAndSettle();

      expect(find.text('UI测试任务'), findsOneWidget);

      taskContainer.dispose();
    });
  });
}
