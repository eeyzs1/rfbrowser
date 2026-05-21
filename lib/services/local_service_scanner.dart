import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/ai_provider.dart';

class LocalServiceInfo {
  final String name;
  final String baseUrl;
  final String description;
  final IconData icon;
  final String defaultModel;

  const LocalServiceInfo({
    required this.name,
    required this.baseUrl,
    required this.description,
    required this.icon,
    required this.defaultModel,
  });

  AIProvider toProvider() => AIProvider(
    id: 'local_${name.toLowerCase().replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}',
    name: name,
    protocol: ApiProtocol.openaiCompatible,
    baseUrl: baseUrl,
    requiresApiKey: false,
  );
}

class LocalServiceScanner {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 3),
      receiveTimeout: const Duration(seconds: 3),
    ),
  );

  static const presets = <LocalServiceInfo>[
    LocalServiceInfo(
      name: 'Ollama',
      baseUrl: 'http://localhost:11434/v1',
      description: 'Run Llama, Mistral, and other models locally',
      icon: Icons.smart_toy,
      defaultModel: 'llama3',
    ),
    LocalServiceInfo(
      name: 'LM Studio',
      baseUrl: 'http://localhost:1234/v1',
      description: 'Discover, download, and run local LLMs',
      icon: Icons.psychology,
      defaultModel: '',
    ),
    LocalServiceInfo(
      name: 'llama.cpp Server',
      baseUrl: 'http://localhost:8080/v1',
      description: 'Lightweight llama.cpp HTTP server',
      icon: Icons.terminal,
      defaultModel: '',
    ),
  ];

  Future<List<LocalServiceInfo>> scan() async {
    final available = <LocalServiceInfo>[];
    final futures = presets.map((preset) async {
      if (await _isReachable(preset.baseUrl)) {
        available.add(preset);
      }
    });
    await Future.wait(futures);
    return available;
  }

  Future<bool> _isReachable(String baseUrl) async {
    try {
      await _dio.head(baseUrl);
      return true;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.unknown) {
        return false;
      }
      return e.response?.statusCode != null;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isServiceRunning(String baseUrl) async {
    return _isReachable(baseUrl);
  }
}

final localServiceScannerProvider = Provider<LocalServiceScanner>(
  (ref) => LocalServiceScanner(),
);

final detectedLocalServicesProvider = FutureProvider<List<LocalServiceInfo>>((ref) {
  final scanner = ref.read(localServiceScannerProvider);
  return scanner.scan();
});
