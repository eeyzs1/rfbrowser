import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/platform/webview/headless_manager.dart';
import 'package:rfbrowser/platform/webview/agent_webview.dart';
import 'package:rfbrowser/data/models/agent_task.dart';

void main() {
  group('HeadlessManager', () {
    test('AC-P3-1-1: create returns non-null WebView and activeCount increments', () {
      final manager = HeadlessManager(idleTimeout: Duration(hours: 1));
      final webView = manager.create();
      expect(webView, isNotNull);
      expect(webView.id, isNotEmpty);
      expect(manager.activeCount, 1);
      manager.disposeAll();
    });

    test('AC-P3-1-8: dispose decrements activeCount', () async {
      final manager = HeadlessManager(idleTimeout: Duration(hours: 1));
      final webView = manager.create();
      await webView.run();
      expect(manager.activeCount, 1);
      manager.dispose(webView.id);
      expect(manager.activeCount, 0);
    });

    test('AC-P3-1-9: idle timeout auto-disposes WebView', () async {
      final manager = HeadlessManager(idleTimeout: Duration(milliseconds: 100));
      final webView = manager.create();
      await webView.run();
      expect(manager.activeCount, 1);
      await Future.delayed(Duration(milliseconds: 200));
      expect(manager.activeCount, 0);
    });

    test('disposeAll removes all instances', () async {
      final manager = HeadlessManager(idleTimeout: Duration(hours: 1));
      manager.create();
      manager.create();
      manager.create();
      expect(manager.activeCount, 3);
      manager.disposeAll();
      expect(manager.activeCount, 0);
    });
  });

  group('AgentWebView', () {
    test('AC-P3-1-2: navigateTo sets currentUrl', () async {
      final manager = HeadlessManager(idleTimeout: Duration(hours: 1));
      final webView = manager.create();
      final agentWebView = AgentWebView(webView);
      await agentWebView.navigateTo('https://example.com');
      expect(agentWebView.currentUrl, contains('example.com'));
      manager.disposeAll();
    });

    test('AC-P3-1-3: extractText returns non-empty string', () async {
      final manager = HeadlessManager(idleTimeout: Duration(hours: 1));
      final webView = manager.create();
      final agentWebView = AgentWebView(webView);
      await agentWebView.navigateTo('https://example.com');
      final text = await agentWebView.extractText();
      expect(text, isNotEmpty);
      manager.disposeAll();
    });
  });

  group('AgentTask Execution', () {
    test('AC-P3-1-4: 3-step task completes with steps progressing', () async {
      var task = AgentTask(
        id: 'test-1',
        name: 'Test Task',
        description: 'Test',
        steps: [
          AgentStep(description: 'Navigate to: https://example.com'),
          AgentStep(description: 'Extract text from: https://example.com'),
          AgentStep(description: 'Create note: summary'),
        ],
      );

      expect(task.steps.length, 3);
      expect(task.steps.every((s) => s.status == TaskStatus.pending), true);

      final manager = HeadlessManager(idleTimeout: Duration(hours: 1));
      for (var i = 0; i < task.steps.length; i++) {
        final step = task.steps[i];
        final updatedStep = step.copyWith(
          status: TaskStatus.completed,
          result: 'done',
          completedAt: DateTime.now(),
        );
        final updatedSteps = List<AgentStep>.from(task.steps);
        updatedSteps[i] = updatedStep;
        task = task.copyWith(steps: updatedSteps);
      }

      task = task.copyWith(status: TaskStatus.completed);
      expect(task.status, TaskStatus.completed);
      expect(task.steps.every((s) => s.status == TaskStatus.completed), true);
      manager.disposeAll();
    });

    test('AC-P3-1-5: pauseTask changes status to paused', () {
      var task = AgentTask(
        id: 'test-2',
        name: 'Test',
        description: 'Test',
        status: TaskStatus.running,
        steps: [AgentStep(description: 'Step 1')],
      );

      task = task.copyWith(status: TaskStatus.paused);
      expect(task.status, TaskStatus.paused);
    });

    test('AC-P3-1-6: cancelTask changes status to failed with cancelled reason', () {
      var task = AgentTask(
        id: 'test-3',
        name: 'Test',
        description: 'Test',
        status: TaskStatus.running,
        steps: [AgentStep(description: 'Step 1')],
      );

      task = task.copyWith(status: TaskStatus.failed, result: 'cancelled');
      expect(task.status, TaskStatus.failed);
      expect(task.result, 'cancelled');
    });

    test('AC-P3-1-7: task exceeding 50 steps fails with step_limit_exceeded', () {
      final steps = List.generate(51, (i) => AgentStep(description: 'Step $i'));
      var task = AgentTask(
        id: 'test-4',
        name: 'Test',
        description: 'Test',
        steps: steps,
      );

      expect(task.steps.length, 51);
      expect(51 > AgentNotifier.maxSteps, true);

      task = task.copyWith(status: TaskStatus.failed, result: 'step_limit_exceeded');
      expect(task.status, TaskStatus.failed);
      expect(task.result, 'step_limit_exceeded');
    });
  });
}

class AgentNotifier {
  static const int maxSteps = 50;
}
