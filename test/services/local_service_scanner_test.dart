import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/services/local_service_scanner.dart';
import 'package:rfbrowser/data/models/ai_provider.dart';

void main() {
  group('LocalServiceInfo', () {
    test('toProvider creates correct AIProvider', () {
      const info = LocalServiceInfo(
        name: 'Ollama',
        baseUrl: 'http://localhost:11434/v1',
        description: 'Test description',
        icon: Icons.smart_toy,
        defaultModel: 'llama3',
      );

      final provider = info.toProvider();

      expect(provider.name, 'Ollama');
      expect(provider.baseUrl, 'http://localhost:11434/v1');
      expect(provider.protocol, ApiProtocol.openaiCompatible);
      expect(provider.requiresApiKey, isFalse);
      expect(provider.isLocal, isTrue);
      expect(provider.isEnabled, isTrue);
    });

    test(
      'toProvider generates unique IDs when created at different times',
      () async {
        const info = LocalServiceInfo(
          name: 'Ollama',
          baseUrl: 'http://localhost:11434/v1',
          description: '',
          icon: Icons.smart_toy,
          defaultModel: '',
        );

        final provider1 = info.toProvider();
        await Future.delayed(const Duration(milliseconds: 2));
        final provider2 = info.toProvider();

        expect(provider1.id, isNot(equals(provider2.id)));
        expect(provider1.id, startsWith('local_ollama_'));
      },
    );

    test('toProvider replaces spaces in name for ID', () {
      const info = LocalServiceInfo(
        name: 'LM Studio',
        baseUrl: 'http://localhost:1234/v1',
        description: '',
        icon: Icons.psychology,
        defaultModel: '',
      );

      final provider = info.toProvider();
      expect(provider.id, startsWith('local_lm_studio_'));
    });
  });

  group('LocalServiceScanner presets', () {
    test('presets contains exactly 3 entries', () {
      expect(LocalServiceScanner.presets.length, 3);
    });

    test('presets contain Ollama', () {
      final ollama = LocalServiceScanner.presets.firstWhere(
        (p) => p.name == 'Ollama',
      );
      expect(ollama.baseUrl, 'http://localhost:11434/v1');
      expect(ollama.defaultModel, 'llama3');
      expect(ollama.description, isNotEmpty);
    });

    test('presets contain LM Studio', () {
      final lmStudio = LocalServiceScanner.presets.firstWhere(
        (p) => p.name == 'LM Studio',
      );
      expect(lmStudio.baseUrl, 'http://localhost:1234/v1');
    });

    test('presets contain llama.cpp Server', () {
      final llamaCpp = LocalServiceScanner.presets.firstWhere(
        (p) => p.name == 'llama.cpp Server',
      );
      expect(llamaCpp.baseUrl, 'http://localhost:8080/v1');
    });

    test('all presets use localhost URLs', () {
      for (final preset in LocalServiceScanner.presets) {
        expect(
          preset.baseUrl.contains('localhost'),
          isTrue,
          reason: '${preset.name} should use localhost URL',
        );
      }
    });

    test('all presets have /v1 suffix', () {
      for (final preset in LocalServiceScanner.presets) {
        expect(
          preset.baseUrl.endsWith('/v1'),
          isTrue,
          reason: '${preset.name} should have /v1 suffix for OpenAI compat',
        );
      }
    });

    test('all preset names are unique', () {
      final names = LocalServiceScanner.presets.map((p) => p.name).toList();
      expect(names.toSet().length, names.length);
    });

    test('all preset baseUrls are unique', () {
      final urls = LocalServiceScanner.presets.map((p) => p.baseUrl).toList();
      expect(urls.toSet().length, urls.length);
    });

    test('all presets have non-empty descriptions', () {
      for (final preset in LocalServiceScanner.presets) {
        expect(preset.description, isNotEmpty);
      }
    });
  });

  group('LocalServiceScanner scan', () {
    test('scan returns empty list when no services are reachable', () async {
      final scanner = LocalServiceScanner();
      final results = await scanner.scan();
      expect(results, isA<List<LocalServiceInfo>>());
    });

    test('isServiceRunning returns false for unreachable URL', () async {
      final scanner = LocalServiceScanner();
      final result = await scanner.isServiceRunning('http://localhost:59999');
      expect(result, isFalse);
    });
  });

  group('Preset → Provider integration', () {
    test('each preset creates a valid local provider', () {
      for (final preset in LocalServiceScanner.presets) {
        final provider = preset.toProvider();

        expect(
          provider.isLocal,
          isTrue,
          reason: '${preset.name} provider should be local',
        );
        expect(
          provider.requiresApiKey,
          isFalse,
          reason: '${preset.name} should not require API key',
        );
        expect(
          provider.protocol,
          ApiProtocol.openaiCompatible,
          reason: '${preset.name} should use OpenAI compatible protocol',
        );
        expect(
          provider.chatEndpoint,
          contains('/v1/chat/completions'),
          reason: '${preset.name} chat endpoint should be correct',
        );
        expect(
          provider.modelsEndpoint,
          contains('/v1/models'),
          reason: '${preset.name} models endpoint should be correct',
        );
        expect(
          provider.embeddingEndpoint,
          contains('/v1/embeddings'),
          reason: '${preset.name} embedding endpoint should be correct',
        );
      }
    });

    test('preset provider authHeaders returns empty map', () {
      for (final preset in LocalServiceScanner.presets) {
        final provider = preset.toProvider();
        expect(
          provider.authHeaders(),
          isEmpty,
          reason: '${preset.name} should have no auth headers',
        );
      }
    });

    test('preset provider displayIcon is computer icon', () {
      for (final preset in LocalServiceScanner.presets) {
        final provider = preset.toProvider();
        expect(
          provider.displayIcon,
          Icons.computer,
          reason: '${preset.name} should show computer icon',
        );
      }
    });
  });
}
