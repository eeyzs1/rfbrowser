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
        expect(
          discovery.humanizeModelId('claude-3-5-sonnet'),
          'Claude 3.5 Sonnet',
        );
        expect(
          discovery.humanizeModelId('claude-3-5-haiku'),
          'Claude 3.5 Haiku',
        );
        expect(discovery.humanizeModelId('claude-3-opus'), 'Claude 3 Opus');
        expect(discovery.humanizeModelId('claude-3-sonnet'), 'Claude 3 Sonnet');
        expect(discovery.humanizeModelId('claude-3-haiku'), 'Claude 3 Haiku');
        expect(discovery.humanizeModelId('claude-1.0'), 'Claude');
      });

      test('humanizes DeepSeek models', () {
        expect(
          discovery.humanizeModelId('deepseek-reasoner'),
          'DeepSeek Reasoner',
        );
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

      test('returns text-only for models without vision/tools keywords', () {
        // llama-3 is a real text-only model: no vision, no function calling
        // in its base open-weight release. Used here to verify the fallback
        // path returns just {text} when no capability keywords match.
        final caps = discovery.inferCapabilities('llama-3');
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

      test('detects tools capability via model ID keywords', () {
        // Models whose IDs contain function-calling family markers should
        // infer the tools capability (conservative: only well-known families).
        final toolsModels = [
          'gpt-4',
          'gpt-4-turbo',
          'gpt-3.5-turbo',
          'claude-3-5-sonnet',
          'claude-3-opus',
          'gemini-1.5-pro',
          'qwen-max',
          'qwen-plus',
          'qwen-turbo',
          'deepseek-chat',
        ];
        for (final modelId in toolsModels) {
          final caps = discovery.inferCapabilities(modelId);
          expect(
            caps.contains(ModelCapability.tools),
            isTrue,
            reason: '$modelId should have tools capability',
          );
        }
      });

      test('does not infer tools for unknown model families', () {
        // Unknown / local models must NOT get tools — avoids sending tools
        // array to models that may reject it.
        final nonToolsModels = [
          'llama-3',
          'mistral-7b',
          'some-unknown-model',
          'deepseek-reasoner',
        ];
        for (final modelId in nonToolsModels) {
          final caps = discovery.inferCapabilities(modelId);
          expect(
            caps.contains(ModelCapability.tools),
            isFalse,
            reason: '$modelId should NOT have tools capability',
          );
        }
      });

      test('case insensitive matching', () {
        final caps = discovery.inferCapabilities('GPT-4o');
        expect(caps.contains(ModelCapability.vision), isTrue);
        expect(caps.contains(ModelCapability.tools), isTrue);

        final caps2 = discovery.inferCapabilities('Claude-3-OPUS');
        expect(caps2.contains(ModelCapability.vision), isTrue);
        expect(caps2.contains(ModelCapability.tools), isTrue);
      });
    });
  });
}
