import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/services/webhook_server.dart';

void main() {
  group('Webhook Server State', () {
    test('WebhookServerState defaults', () {
      final state = WebhookServerState();
      expect(state.isRunning, false);
      expect(state.port, 18765);
      expect(state.apiKey, isNull);
      expect(state.baseUrl, isNull);
    });

    test('WebhookServerState copyWith', () {
      final state = WebhookServerState();
      final updated = state.copyWith(
        isRunning: true,
        port: 9999,
        apiKey: 'test-key',
        baseUrl: 'http://localhost:9999',
      );

      expect(updated.isRunning, true);
      expect(updated.port, 9999);
      expect(updated.apiKey, 'test-key');
      expect(updated.baseUrl, 'http://localhost:9999');
      expect(state.isRunning, false);
    });

    test('WebhookServerState copyWith preserves unchanged values', () {
      final state = WebhookServerState(
        isRunning: true,
        port: 8080,
        apiKey: 'key123',
        baseUrl: 'http://localhost:8080',
      );
      final updated = state.copyWith();

      expect(updated.isRunning, true);
      expect(updated.port, 8080);
      expect(updated.apiKey, 'key123');
      expect(updated.baseUrl, 'http://localhost:8080');
    });
  });
}