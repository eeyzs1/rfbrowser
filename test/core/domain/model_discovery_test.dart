import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/core/domain/model_discovery.dart';
import 'package:rfbrowser/data/models/ai_provider.dart';

void main() {
  group('ModelDiscovery', () {
    late ModelDiscovery discovery;

    setUp(() {
      discovery = ModelDiscovery();
      HttpOverrides.global = null;
    });

    tearDown(() {
      HttpOverrides.global = null;
    });

    group('_humanizeModelId', () {
      test('humanizes GPT models', () {
        expect(discovery.humanizeModelId('gpt-4o-mini'), 'GPT-4o Mini');
        expect(discovery.humanizeModelId('gpt-4o'), 'GPT-4o');
        expect(discovery.humanizeModelId('gpt-4-turbo'), 'GPT-4 Turbo');
        expect(discovery.humanizeModelId('gpt-4'), 'GPT-4');
        expect(discovery.humanizeModelId('gpt-3.5-turbo'), 'GPT-3.5');
      });

      test('humanizes o1/o3 models', () {
        expect(discovery.humanizeModelId('o1-mini'), 'o1 Mini');
        expect(discovery.humanizeModelId('o1-preview'), 'o1 Preview');
        expect(discovery.humanizeModelId('o1-2024'), 'o1');
        expect(discovery.humanizeModelId('o3-mini'), 'o3 Mini');
        expect(discovery.humanizeModelId('o3-large'), 'o3');
      });

      test('humanizes Claude models', () {
        expect(discovery.humanizeModelId('claude-3-5-sonnet'), 'Claude 3.5 Sonnet');
        expect(discovery.humanizeModelId('claude-3-5-haiku'), 'Claude 3.5 Haiku');
        expect(discovery.humanizeModelId('claude-3-opus'), 'Claude 3 Opus');
        expect(discovery.humanizeModelId('claude-3-sonnet'), 'Claude 3 Sonnet');
        expect(discovery.humanizeModelId('claude-3-haiku'), 'Claude 3 Haiku');
        expect(discovery.humanizeModelId('claude-1.0'), 'Claude');
      });

      test('humanizes DeepSeek models', () {
        expect(discovery.humanizeModelId('deepseek-reasoner'), 'DeepSeek Reasoner');
        expect(discovery.humanizeModelId('deepseek-chat'), 'DeepSeek Chat');
        expect(discovery.humanizeModelId('deepseek-v2'), 'DeepSeek');
      });

      test('returns raw id for unknown models', () {
        expect(discovery.humanizeModelId('qwen-max'), 'qwen-max');
        expect(discovery.humanizeModelId('llama-3'), 'llama-3');
        expect(discovery.humanizeModelId('unknown-model'), 'unknown-model');
      });
    });

    group('_inferCapabilities', () {
      test('infers vision capability for vision models', () {
        final caps = discovery.inferCapabilities('gpt-4o');
        expect(caps.contains(ModelCapability.text), isTrue);
        expect(caps.contains(ModelCapability.vision), isTrue);
      });

      test('returns text-only for non-vision models', () {
        final caps = discovery.inferCapabilities('gpt-3.5-turbo');
        expect(caps, {ModelCapability.text});
      });

      test('detects vision via model ID keywords', () {
        final visionModels = [
          'gpt-4o',
          'gpt-4-turbo',
          'claude-3-5-sonnet',
          'claude-3-opus',
          'gemini-pro-vision',
          'qwen-vl-max',
          'llava-13b',
          'pixtral-large',
        ];
        for (final modelId in visionModels) {
          final caps = discovery.inferCapabilities(modelId);
          expect(
            caps.contains(ModelCapability.vision),
            isTrue,
            reason: '$modelId should have vision capability',
          );
        }
      });

      test('case insensitive matching', () {
        final caps = discovery.inferCapabilities('GPT-4o');
        expect(caps.contains(ModelCapability.vision), isTrue);

        final caps2 = discovery.inferCapabilities('Claude-3-OPUS');
        expect(caps2.contains(ModelCapability.vision), isTrue);
      });
    });
  });
}