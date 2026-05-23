import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rfbrowser/data/models/ai_provider.dart';
import 'package:rfbrowser/services/ai_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ChatMessage', () {
    test('constructor sets role and content', () {
      final msg = ChatMessage(role: 'user', content: 'Hello');
      expect(msg.role, 'user');
      expect(msg.content, 'Hello');
      expect(msg.isStreaming, false);
      expect(msg.timestamp, isNotNull);
    });

    test('constructor sets isStreaming', () {
      final msg = ChatMessage(
        role: 'assistant',
        content: '',
        isStreaming: true,
      );
      expect(msg.isStreaming, true);
    });

    test('copyWith updates content', () {
      final msg = ChatMessage(role: 'user', content: 'Hello');
      final updated = msg.copyWith(content: 'Updated');
      expect(updated.content, 'Updated');
      expect(updated.role, 'user');
    });

    test('copyWith updates isStreaming', () {
      final msg = ChatMessage(
        role: 'assistant',
        content: 'test',
        isStreaming: true,
      );
      final updated = msg.copyWith(isStreaming: false);
      expect(updated.isStreaming, false);
    });

    test('copyWith preserves unchanged fields', () {
      final now = DateTime.now();
      final msg = ChatMessage(role: 'user', content: 'Hello', timestamp: now);
      final updated = msg.copyWith(content: 'Hi');
      expect(updated.timestamp, now);
      expect(updated.role, 'user');
    });
  });

  group('AIState', () {
    test('initial state has empty messages, not loading, no error', () {
      final state = AIState();
      expect(state.messages, isEmpty);
      expect(state.isLoading, false);
      expect(state.error, isNull);
      expect(state.activeProvider, isNull);
      expect(state.activeModel, isNull);
    });

    test('copyWith updates messages', () {
      final state = AIState();
      final msg = ChatMessage(role: 'user', content: 'Hi');
      final updated = state.copyWith(messages: [msg]);
      expect(updated.messages.length, 1);
    });

    test('copyWith updates isLoading', () {
      final state = AIState();
      final updated = state.copyWith(isLoading: true);
      expect(updated.isLoading, true);
    });

    test('copyWith updates error', () {
      final state = AIState();
      final updated = state.copyWith(error: 'Something wrong');
      expect(updated.error, 'Something wrong');
    });

    test('copyWith clearError sets error to null', () {
      final state = AIState(error: 'Existing error');
      final updated = state.copyWith(clearError: true);
      expect(updated.error, isNull);
    });

    test('copyWith clearError is false by default', () {
      final state = AIState(error: 'Keep me');
      final updated = state.copyWith(error: 'New error');
      expect(updated.error, 'New error');
    });

    test('copyWith updates activeProvider', () {
      final state = AIState();
      final provider = AIProvider(
        id: 'p1',
        name: 'Test',
        protocol: ApiProtocol.openaiCompatible,
        baseUrl: 'http://localhost:11434',
        requiresApiKey: false,
      );
      final updated = state.copyWith(activeProvider: provider);
      expect(updated.activeProvider!.id, 'p1');
    });

    test('copyWith clearProvider sets activeProvider to null', () {
      final provider = AIProvider(
        id: 'p1',
        name: 'Test',
        protocol: ApiProtocol.openaiCompatible,
        baseUrl: 'http://localhost:11434',
        requiresApiKey: false,
      );
      final state = AIState(activeProvider: provider);
      final updated = state.copyWith(clearProvider: true);
      expect(updated.activeProvider, isNull);
    });

    test('copyWith updates activeModel', () {
      final state = AIState();
      final model = AIModel(
        id: 'm1',
        providerId: 'p1',
        displayName: 'Test Model',
      );
      final updated = state.copyWith(activeModel: model);
      expect(updated.activeModel!.id, 'm1');
    });

    test('copyWith clearModel sets activeModel to null', () {
      final model = AIModel(
        id: 'm1',
        providerId: 'p1',
        displayName: 'Test Model',
      );
      final state = AIState(activeModel: model);
      final updated = state.copyWith(clearModel: true);
      expect(updated.activeModel, isNull);
    });
  });

  group('AINotifier', () {
    ProviderContainer createContainer() {
      return ProviderContainer();
    }

    test('build returns initial AIState', () {
      final container = createContainer();
      addTearDown(container.dispose);
      final state = container.read(aiProvider);
      expect(state.messages, isEmpty);
      expect(state.isLoading, false);
    });

    group('clearMessages', () {
      test('clears all messages', () {
        final container = createContainer();
        addTearDown(container.dispose);
        final notifier = container.read(aiProvider.notifier);

        notifier.clearMessages();
        expect(container.read(aiProvider).messages, isEmpty);
      });
    });

    group('clearError', () {
      test('clears the error', () {
        final container = createContainer();
        addTearDown(container.dispose);
        final notifier = container.read(aiProvider.notifier);

        notifier.clearError();
        expect(container.read(aiProvider).error, isNull);
      });
    });

    group('sendMessage guard clauses', () {
      test('does nothing when already loading', () async {
        final container = createContainer();
        addTearDown(container.dispose);
        final notifier = container.read(aiProvider.notifier);

        container.read(aiProvider.notifier).state = AIState(isLoading: true);

        await notifier.sendMessage('Hello');
        final state = container.read(aiProvider);
        expect(state.messages, isEmpty);
      });

      test('sets error when no provider configured', () async {
        final container = createContainer();
        addTearDown(container.dispose);
        final notifier = container.read(aiProvider.notifier);

        await notifier.sendMessage('Hello');
        final state = container.read(aiProvider);
        expect(state.error, isNotNull);
        expect(state.error!.contains('No AI provider'), isTrue);
      });
    });
  });
}
