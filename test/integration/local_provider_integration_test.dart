import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/data/models/ai_provider.dart';
import 'package:rfbrowser/services/local_service_scanner.dart';
import 'package:rfbrowser/services/connectivity_service.dart';
import 'package:rfbrowser/services/embedding_service.dart';
import 'package:rfbrowser/core/domain/model_discovery.dart';

void main() {
  group('Local Provider Integration', () {
    group('AIProvider.isLocal detection', () {
      test('detects localhost as local', () {
        final provider = AIProvider(
          id: 'p1',
          name: 'Local',
          protocol: ApiProtocol.openaiCompatible,
          baseUrl: 'http://localhost:11434/v1',
          requiresApiKey: false,
        );
        expect(provider.isLocal, isTrue);
      });

      test('detects 127.0.0.1 as local', () {
        final provider = AIProvider(
          id: 'p1',
          name: 'Local',
          protocol: ApiProtocol.openaiCompatible,
          baseUrl: 'http://127.0.0.1:1234/v1',
          requiresApiKey: false,
        );
        expect(provider.isLocal, isTrue);
      });

      test('detects 0.0.0.0 as local', () {
        final provider = AIProvider(
          id: 'p1',
          name: 'Local',
          protocol: ApiProtocol.openaiCompatible,
          baseUrl: 'http://0.0.0.0:8080/v1',
          requiresApiKey: false,
        );
        expect(provider.isLocal, isTrue);
      });

      test('detects [::1] as local', () {
        final provider = AIProvider(
          id: 'p1',
          name: 'Local',
          protocol: ApiProtocol.openaiCompatible,
          baseUrl: 'http://[::1]:11434/v1',
          requiresApiKey: false,
        );
        expect(provider.isLocal, isTrue);
      });

      test('detects remote URL as not local', () {
        final provider = AIProvider(
          id: 'p1',
          name: 'OpenAI',
          protocol: ApiProtocol.openaiCompatible,
          baseUrl: 'https://api.openai.com',
        );
        expect(provider.isLocal, isFalse);
      });

      test('detects custom domain as not local', () {
        final provider = AIProvider(
          id: 'p1',
          name: 'Custom',
          protocol: ApiProtocol.openaiCompatible,
          baseUrl: 'https://my-llm-server.example.com/v1',
        );
        expect(provider.isLocal, isFalse);
      });
    });

    group('AIProvider.requiresApiKey inference', () {
      test('local URL defaults to no API key', () {
        final provider = AIProvider(
          id: 'p1',
          name: 'Local',
          protocol: ApiProtocol.openaiCompatible,
          baseUrl: 'http://localhost:11434/v1',
        );
        expect(provider.requiresApiKey, isFalse);
      });

      test('remote URL defaults to requiring API key', () {
        final provider = AIProvider(
          id: 'p1',
          name: 'OpenAI',
          protocol: ApiProtocol.openaiCompatible,
          baseUrl: 'https://api.openai.com',
        );
        expect(provider.requiresApiKey, isTrue);
      });

      test('explicit requiresApiKey overrides inference', () {
        final provider = AIProvider(
          id: 'p1',
          name: 'Custom',
          protocol: ApiProtocol.openaiCompatible,
          baseUrl: 'https://custom-api.example.com',
          requiresApiKey: false,
        );
        expect(provider.requiresApiKey, isFalse);
      });

      test('local URL can be forced to require API key', () {
        final provider = AIProvider(
          id: 'p1',
          name: 'Auth Local',
          protocol: ApiProtocol.openaiCompatible,
          baseUrl: 'http://localhost:11434/v1',
          requiresApiKey: true,
        );
        expect(provider.requiresApiKey, isTrue);
      });
    });

    group('AIProvider endpoint computation', () {
      test('chatEndpoint for local provider with /v1 suffix', () {
        final provider = AIProvider(
          id: 'p1',
          name: 'Ollama',
          protocol: ApiProtocol.openaiCompatible,
          baseUrl: 'http://localhost:11434/v1',
          requiresApiKey: false,
        );
        expect(provider.chatEndpoint, 'http://localhost:11434/v1/chat/completions');
      });

      test('chatEndpoint for local provider without /v1 suffix', () {
        final provider = AIProvider(
          id: 'p1',
          name: 'Ollama',
          protocol: ApiProtocol.openaiCompatible,
          baseUrl: 'http://localhost:11434',
          requiresApiKey: false,
        );
        expect(provider.chatEndpoint, 'http://localhost:11434/v1/chat/completions');
      });

      test('modelsEndpoint for local provider with /v1 suffix', () {
        final provider = AIProvider(
          id: 'p1',
          name: 'Ollama',
          protocol: ApiProtocol.openaiCompatible,
          baseUrl: 'http://localhost:11434/v1',
          requiresApiKey: false,
        );
        expect(provider.modelsEndpoint, 'http://localhost:11434/v1/models');
      });

      test('embeddingEndpoint for local provider with /v1 suffix', () {
        final provider = AIProvider(
          id: 'p1',
          name: 'Ollama',
          protocol: ApiProtocol.openaiCompatible,
          baseUrl: 'http://localhost:11434/v1',
          requiresApiKey: false,
        );
        expect(provider.embeddingEndpoint, 'http://localhost:11434/v1/embeddings');
      });

      test('embeddingEndpoint for local provider without /v1 suffix', () {
        final provider = AIProvider(
          id: 'p1',
          name: 'Ollama',
          protocol: ApiProtocol.openaiCompatible,
          baseUrl: 'http://localhost:11434',
          requiresApiKey: false,
        );
        expect(provider.embeddingEndpoint, 'http://localhost:11434/v1/embeddings');
      });

      test('embeddingEndpoint for LM Studio', () {
        final provider = AIProvider(
          id: 'p1',
          name: 'LM Studio',
          protocol: ApiProtocol.openaiCompatible,
          baseUrl: 'http://localhost:1234/v1',
          requiresApiKey: false,
        );
        expect(provider.embeddingEndpoint, 'http://localhost:1234/v1/embeddings');
      });

      test('embeddingEndpoint for llama.cpp server', () {
        final provider = AIProvider(
          id: 'p1',
          name: 'llama.cpp',
          protocol: ApiProtocol.openaiCompatible,
          baseUrl: 'http://localhost:8080/v1',
          requiresApiKey: false,
        );
        expect(provider.embeddingEndpoint, 'http://localhost:8080/v1/embeddings');
      });
    });

    group('AIProvider displayIcon', () {
      test('local provider shows computer icon', () {
        final provider = AIProvider(
          id: 'p1',
          name: 'Ollama',
          protocol: ApiProtocol.openaiCompatible,
          baseUrl: 'http://localhost:11434/v1',
          requiresApiKey: false,
        );
        expect(provider.displayIcon, Icons.computer);
      });

      test('remote OpenAI provider shows cloud icon', () {
        final provider = AIProvider(
          id: 'p1',
          name: 'OpenAI',
          protocol: ApiProtocol.openaiCompatible,
          baseUrl: 'https://api.openai.com',
        );
        expect(provider.displayIcon, Icons.cloud);
      });

      test('remote Anthropic provider shows auto_awesome icon', () {
        final provider = AIProvider(
          id: 'p1',
          name: 'Anthropic',
          protocol: ApiProtocol.anthropic,
          baseUrl: 'https://api.anthropic.com',
        );
        expect(provider.displayIcon, Icons.auto_awesome);
      });
    });

    group('AIProvider authHeaders', () {
      test('local provider without API key returns empty headers', () {
        final provider = AIProvider(
          id: 'p1',
          name: 'Ollama',
          protocol: ApiProtocol.openaiCompatible,
          baseUrl: 'http://localhost:11434/v1',
          requiresApiKey: false,
        );
        expect(provider.authHeaders(), isEmpty);
      });

      test('local provider with API key returns Bearer header', () {
        final provider = AIProvider(
          id: 'p1',
          name: 'Auth Local',
          protocol: ApiProtocol.openaiCompatible,
          baseUrl: 'http://localhost:11434/v1',
          apiKey: 'test-key',
          requiresApiKey: true,
        );
        final headers = provider.authHeaders();
        expect(headers, contains('Authorization'));
        expect(headers['Authorization'], 'Bearer test-key');
      });
    });
  });

  group('Preset → Provider → End-to-End Integration', () {
    test('Ollama preset creates fully functional provider', () {
      final ollamaPreset = LocalServiceScanner.presets.firstWhere(
        (p) => p.name == 'Ollama',
      );
      final provider = ollamaPreset.toProvider();

      expect(provider.isLocal, isTrue);
      expect(provider.requiresApiKey, isFalse);
      expect(provider.protocol, ApiProtocol.openaiCompatible);
      expect(provider.chatEndpoint, 'http://localhost:11434/v1/chat/completions');
      expect(provider.modelsEndpoint, 'http://localhost:11434/v1/models');
      expect(provider.embeddingEndpoint, 'http://localhost:11434/v1/embeddings');
      expect(provider.authHeaders(), isEmpty);
      expect(provider.displayIcon, Icons.computer);
      expect(provider.isEnabled, isTrue);
    });

    test('LM Studio preset creates fully functional provider', () {
      final lmStudioPreset = LocalServiceScanner.presets.firstWhere(
        (p) => p.name == 'LM Studio',
      );
      final provider = lmStudioPreset.toProvider();

      expect(provider.isLocal, isTrue);
      expect(provider.requiresApiKey, isFalse);
      expect(provider.chatEndpoint, 'http://localhost:1234/v1/chat/completions');
      expect(provider.modelsEndpoint, 'http://localhost:1234/v1/models');
      expect(provider.embeddingEndpoint, 'http://localhost:1234/v1/embeddings');
    });

    test('llama.cpp preset creates fully functional provider', () {
      final llamaCppPreset = LocalServiceScanner.presets.firstWhere(
        (p) => p.name == 'llama.cpp Server',
      );
      final provider = llamaCppPreset.toProvider();

      expect(provider.isLocal, isTrue);
      expect(provider.requiresApiKey, isFalse);
      expect(provider.chatEndpoint, 'http://localhost:8080/v1/chat/completions');
      expect(provider.modelsEndpoint, 'http://localhost:8080/v1/models');
      expect(provider.embeddingEndpoint, 'http://localhost:8080/v1/embeddings');
    });

    test('all presets produce distinct provider IDs', () {
      final providers = LocalServiceScanner.presets.map((p) => p.toProvider()).toList();
      final ids = providers.map((p) => p.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });

  group('ConnectivityService + Local Provider Integration', () {
    test('ConnectivityState defaults to online', () {
      final state = ConnectivityState();
      expect(state.isOnline, isTrue);
    });

    test('OfflineNoModelError has correct message', () {
      final error = OfflineNoModelError();
      expect(error.toString(), contains('No local model'));
    });

    test('local provider isLocal matches connectivity offline fallback criteria',
        () {
      final localProvider = AIProvider(
        id: 'local1',
        name: 'Ollama',
        protocol: ApiProtocol.openaiCompatible,
        baseUrl: 'http://localhost:11434/v1',
        requiresApiKey: false,
      );
      final remoteProvider = AIProvider(
        id: 'remote1',
        name: 'OpenAI',
        protocol: ApiProtocol.openaiCompatible,
        baseUrl: 'https://api.openai.com',
      );

      expect(localProvider.isLocal && localProvider.isEnabled, isTrue);
      expect(remoteProvider.isLocal, isFalse);
    });
  });

  group('EmbeddingService + Local Provider Integration', () {
    test('EmbeddingService local fallback produces 128-dim vector', () {
      final service = EmbeddingService();
      final embedding = service.embed('test text');
      expect(embedding, completion(hasLength(128)));
    });

    test('EmbeddingService local fallback produces normalized vector',
        () async {
      final service = EmbeddingService();
      final embedding = await service.embed('test text for normalization');
      var normSquared = 0.0;
      for (final v in embedding) {
        normSquared += v * v;
      }
      expect(normSquared, closeTo(1.0, 0.01));
    });

    test('EmbeddingService different texts produce different embeddings',
        () async {
      final service = EmbeddingService();
      final emb1 = await service.embed('Flutter development');
      final emb2 = await service.embed('Python data science');
      var dotProduct = 0.0;
      for (var i = 0; i < emb1.length; i++) {
        dotProduct += emb1[i] * emb2[i];
      }
      expect(dotProduct, lessThan(1.0));
    });

    test('EmbeddingService setLocalBaseUrl and setLocalEmbeddingModel', () {
      final service = EmbeddingService();
      service.setLocalBaseUrl('http://localhost:1234/v1');
      service.setLocalEmbeddingModel('text-embedding-3-small');
    });
  });

  group('ModelDiscovery + Local Provider Integration', () {
    test('ModelDiscovery infers capabilities for local model IDs', () {
      final discovery = ModelDiscovery();

      final llamaCaps = discovery.inferCapabilities('llama3');
      expect(llamaCaps.contains(ModelCapability.text), isTrue);

      final llavaCaps = discovery.inferCapabilities('llava-13b');
      expect(llavaCaps.contains(ModelCapability.vision), isTrue);

      final mistralCaps = discovery.inferCapabilities('mistral-7b');
      expect(mistralCaps.contains(ModelCapability.text), isTrue);
    });

    test('ModelDiscovery humanizes local model IDs', () {
      final discovery = ModelDiscovery();

      expect(discovery.humanizeModelId('llama3'), 'llama3');
      expect(discovery.humanizeModelId('mistral-7b'), 'mistral-7b');
      expect(discovery.humanizeModelId('qwen2.5-coder'), 'qwen2.5-coder');
    });
  });

  group('AIProvider serialization with new fields', () {
    test('toJson includes requiresApiKey', () {
      final provider = AIProvider(
        id: 'p1',
        name: 'Local',
        protocol: ApiProtocol.openaiCompatible,
        baseUrl: 'http://localhost:11434/v1',
        requiresApiKey: false,
      );
      final json = provider.toJson();
      expect(json.containsKey('requiresApiKey'), isTrue);
      expect(json['requiresApiKey'], isFalse);
    });

    test('fromJson restores requiresApiKey', () {
      final provider = AIProvider(
        id: 'p1',
        name: 'Local',
        protocol: ApiProtocol.openaiCompatible,
        baseUrl: 'http://localhost:11434/v1',
        requiresApiKey: false,
      );
      final json = provider.toJson();
      final restored = AIProvider.fromJson(json);
      expect(restored.requiresApiKey, isFalse);
      expect(restored.isLocal, isTrue);
    });

    test('fromJson with missing requiresApiKey infers from baseUrl', () {
      final json = {
        'id': 'p1',
        'name': 'Local',
        'protocol': 0,
        'baseUrl': 'http://localhost:11434/v1',
        'isEnabled': true,
      };
      final restored = AIProvider.fromJson(json);
      expect(restored.requiresApiKey, isFalse);
      expect(restored.isLocal, isTrue);
    });

    test('fromJson with old protocol index 2 (was ollama) falls back to openaiCompatible', () {
      final json = {
        'id': 'p1',
        'name': 'Old Ollama',
        'protocol': 2,
        'baseUrl': 'http://localhost:11434/v1',
        'isEnabled': true,
      };
      final restored = AIProvider.fromJson(json);
      expect(restored.protocol, ApiProtocol.openaiCompatible);
      expect(restored.isLocal, isTrue);
    });

    test('round-trip preserves all local provider properties', () {
      final original = AIProvider(
        id: 'p1',
        name: 'Ollama',
        protocol: ApiProtocol.openaiCompatible,
        baseUrl: 'http://localhost:11434/v1',
        requiresApiKey: false,
      );
      final json = original.toJson();
      final restored = AIProvider.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.protocol, original.protocol);
      expect(restored.baseUrl, original.baseUrl);
      expect(restored.requiresApiKey, original.requiresApiKey);
      expect(restored.isLocal, original.isLocal);
      expect(restored.chatEndpoint, original.chatEndpoint);
      expect(restored.modelsEndpoint, original.modelsEndpoint);
      expect(restored.embeddingEndpoint, original.embeddingEndpoint);
    });

    test('round-trip preserves remote provider with API key requirement', () {
      final original = AIProvider(
        id: 'p2',
        name: 'OpenAI',
        protocol: ApiProtocol.openaiCompatible,
        baseUrl: 'https://api.openai.com',
        requiresApiKey: true,
      );
      final json = original.toJson();
      final restored = AIProvider.fromJson(json);

      expect(restored.requiresApiKey, isTrue);
      expect(restored.isLocal, isFalse);
      expect(restored.displayIcon, Icons.cloud);
    });
  });

  group('AIProvider copyWith with requiresApiKey', () {
    test('copyWith preserves requiresApiKey', () {
      final provider = AIProvider(
        id: 'p1',
        name: 'Local',
        protocol: ApiProtocol.openaiCompatible,
        baseUrl: 'http://localhost:11434/v1',
        requiresApiKey: false,
      );
      final copied = provider.copyWith(name: 'Renamed');
      expect(copied.requiresApiKey, isFalse);
      expect(copied.name, 'Renamed');
    });

    test('copyWith can change requiresApiKey', () {
      final provider = AIProvider(
        id: 'p1',
        name: 'Local',
        protocol: ApiProtocol.openaiCompatible,
        baseUrl: 'http://localhost:11434/v1',
        requiresApiKey: false,
      );
      final copied = provider.copyWith(requiresApiKey: true);
      expect(copied.requiresApiKey, isTrue);
    });
  });

  group('End-to-end: preset → provider → model discovery flow', () {
    test('Ollama preset provider has correct modelsEndpoint for discovery', () {
      final ollamaPreset = LocalServiceScanner.presets.firstWhere(
        (p) => p.name == 'Ollama',
      );
      final provider = ollamaPreset.toProvider();
      final discovery = ModelDiscovery();

      expect(provider.modelsEndpoint, 'http://localhost:11434/v1/models');
      expect(discovery.inferCapabilities('llama3'), contains(ModelCapability.text));
      expect(discovery.humanizeModelId('llama3'), 'llama3');
    });

    test('LM Studio preset provider has correct modelsEndpoint for discovery', () {
      final lmStudioPreset = LocalServiceScanner.presets.firstWhere(
        (p) => p.name == 'LM Studio',
      );
      final provider = lmStudioPreset.toProvider();

      expect(provider.modelsEndpoint, 'http://localhost:1234/v1/models');
    });

    test('embedding endpoint matches EmbeddingService expectations', () {
      for (final preset in LocalServiceScanner.presets) {
        final provider = preset.toProvider();
        final endpoint = provider.embeddingEndpoint;
        expect(endpoint, endsWith('/v1/embeddings'));
      }
    });
  });
}
